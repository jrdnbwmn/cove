import { Controller } from "@hotwired/stimulus";

// Shared global counter for open dialogs (modals and slideovers)
// This ensures proper scrollbar compensation when mixing modals and slideovers
if (!window.__openDialogCount) {
  window.__openDialogCount = 0;
}

// Reset dialog count on page navigation to prevent desync issues
// This handles cases where users navigate back/forward while dialogs are open
if (!window.__dialogCountResetBound) {
  window.__dialogCountResetBound = true;

  const resetDialogCount = () => {
    // Sync native dialog-based overlays
    const openDialogs = document.querySelectorAll("dialog[open]");
    if (openDialogs.length === 0) {
      window.__openDialogCount = 0;
      document.documentElement.style.removeProperty("--scrollbar-compensation");
      document.body.classList.remove("modal-open", "slideover-open");
    } else {
      window.__openDialogCount = openDialogs.length;
    }
  };

  document.addEventListener("turbo:before-cache", resetDialogCount);
  document.addEventListener("turbo:load", resetDialogCount);
}

export default class extends Controller {
  static targets = ["dialog", "template"];
  static values = {
    open: { type: Boolean, default: false }, // Whether the modal is open
    lazyLoad: { type: Boolean, default: false }, // Whether to lazy load the modal content
    turboFrameSrc: { type: String, default: "" }, // URL for the turbo frame
    preventDismiss: { type: Boolean, default: false }, // Whether to prevent the modal from being dismissed
    autoFocus: { type: Boolean, default: false }, // True: focus first focusable element on open. False: don't focus on anything by default. (if an element has autofocus="true", it will focus on it whether this option is true or false)
  };

  connect() {
    if (!this.hasDialogTarget) return;

    // Cache the target element so div-based modals keep a stable reference
    // even when temporarily portaled outside the controller element.
    this.dialogElement = this.dialogTarget;

    // Initialize state
    this.contentLoaded = false;
    this.isBouncing = false;
    this.isOpen = false; // Track if this specific modal is open
    this.isOpening = false; // Prevent duplicate opens while lazy content is loading

    // Initialize focus trapping
    this.focusableElements = [];
    this.firstFocusableElement = null;
    this.lastFocusableElement = null;

    // Detect if we're using a div or dialog element
    this.isDialog = this.dialogElement.tagName.toLowerCase() === "dialog";

    if (!this.isDialog) {
      // Keep original DOM position so div-based modals can be portaled to <body> while open
      this.originalParent = this.dialogElement.parentNode;
      this.originalNextSibling = this.dialogElement.nextSibling;
      this.isPortaled = false;
    }

    // Check if dialog is already open (from previous page state) and close it
    if (this.isDialog && this.dialogElement.open) {
      // Mark as open temporarily to allow cleanup
      this.isOpen = true;
      this.dialogElement.close();
      this.cleanupScrollbarCompensation();
    } else if (!this.isDialog && this.dialogElement.classList.contains("modal-open")) {
      // For div-based modals, check if they have the open class
      this.isOpen = true;
      this.hideDivModal(false);
      this.cleanupScrollbarCompensation();
    }

    // Now handle the intended open state
    if (this.openValue) this.open();

    // Set up event listeners
    this.boundBeforeCache = this.beforeCache.bind(this);
    this.boundBeforeVisit = this.beforeVisit.bind(this);
    document.addEventListener("turbo:before-cache", this.boundBeforeCache);
    document.addEventListener("turbo:before-visit", this.boundBeforeVisit);

    if (this.isDialog) {
      // Add event listener for when dialog is closed by any means (including Escape key)
      this.boundHandleDialogClose = this.handleDialogClose.bind(this);
      this.dialogElement.addEventListener("close", this.boundHandleDialogClose);

      // Prevent Escape key from closing if preventDismiss is true
      this.boundHandleDialogCancel = this.handleDialogCancel.bind(this);
      this.dialogElement.addEventListener("cancel", this.boundHandleDialogCancel);
    }

    // Additional keydown listener for better escape key handling
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    this.dialogElement.addEventListener("keydown", this.boundHandleKeydown);

    // For div-based modals, add global escape key listener
    if (!this.isDialog) {
      this.boundHandleGlobalKeydown = this.handleGlobalKeydown.bind(this);
      document.addEventListener("keydown", this.boundHandleGlobalKeydown);

      // When div modals are portaled to <body>, Stimulus action scope is lost.
      // Keep close/backdrop behavior working with direct delegated listeners.
      this.boundDivBackdropClose = this.backdropClose.bind(this);
      this.boundDivClick = this.handleDivModalClick.bind(this);
      this.dialogElement.addEventListener("mousedown", this.boundDivBackdropClose);
      this.dialogElement.addEventListener("click", this.boundDivClick, true);
    }
  }

  disconnect() {
    if (!this.dialogElement) return;

    // If this modal was open when disconnecting, clean up scrollbar compensation
    if (this.isOpen) {
      this.cleanupScrollbarCompensation();
    }

    document.removeEventListener("turbo:before-cache", this.boundBeforeCache);
    document.removeEventListener("turbo:before-visit", this.boundBeforeVisit);

    if (this.isDialog) {
      this.dialogElement.removeEventListener("close", this.boundHandleDialogClose);
      this.dialogElement.removeEventListener("cancel", this.boundHandleDialogCancel);
    }

    this.dialogElement.removeEventListener("keydown", this.boundHandleKeydown);

    if (!this.isDialog && this.boundHandleGlobalKeydown) {
      document.removeEventListener("keydown", this.boundHandleGlobalKeydown);
    }

    if (!this.isDialog) {
      this.dialogElement.removeEventListener("mousedown", this.boundDivBackdropClose);
      this.dialogElement.removeEventListener("click", this.boundDivClick, true);
      this.restoreDivModalMount();
    }
  }

  async open(event) {
    // If already open, don't do anything
    if (this.isOpen || this.isOpening) return;

    this.isOpening = true;
    const triggerElement =
      event?.currentTarget instanceof HTMLElement &&
      event.currentTarget.matches('button, [role="button"], input[type="button"], input[type="submit"], a[href]')
        ? event.currentTarget
        : null;
    const shouldShowLoadingState = this.lazyLoadValue && !this.contentLoaded;
    let lockAcquired = false;

    try {
      // Acquire scrollbar compensation immediately so page scroll is locked
      // before any async lazy-loading delay.
      window.__openDialogCount++;
      this.isOpen = true;
      lockAcquired = true;

      if (window.__openDialogCount === 1) {
        const scrollbarWidth = this.getScrollbarWidth();
        if (scrollbarWidth > 0) {
          document.documentElement.style.setProperty("--scrollbar-compensation", `${scrollbarWidth}px`);
        } else {
          document.documentElement.style.removeProperty("--scrollbar-compensation");
        }
      }
      document.body.classList.add("modal-open");

      // If lazy loading is enabled and content hasn't been loaded yet, load it now
      if (shouldShowLoadingState) {
        this.setTriggerLoadingState(triggerElement, true);
        try {
          await this.#loadTemplateContent();
          this.contentLoaded = true;
        } finally {
          this.setTriggerLoadingState(triggerElement, false);
        }
      }

      if (this.isDialog) {
        this.dialogElement.showModal();
      } else {
        this.mountDivModalToBody();
        this.showDivModal();
      }

      // Set up focus trapping
      this.setupFocusTrapping();

      // On touch devices, remove initial focus to prevent awkward focus rings
      // But respect native autofocus attributes
      if (this.isTouchDevice()) {
        // Find the currently focused element within the dialog
        const focusedElement = this.dialogElement.querySelector(":focus");
        if (focusedElement && !focusedElement.hasAttribute("autofocus")) {
          // Only blur if it doesn't have native autofocus
          focusedElement.blur();
        }
      }
    } catch (error) {
      // Roll back provisional lock if opening fails (e.g. lazy-load error).
      if (lockAcquired && this.isOpen) {
        this.cleanupScrollbarCompensation();
      }
      throw error;
    } finally {
      this.isOpening = false;
    }
  }

  // Allows for a closing animation since display transitions don't work yet
  close() {
    // If not open, don't do anything
    if (!this.isOpen) return;

    this.dialogElement.setAttribute("closing", "");

    Promise.allSettled(this.dialogElement.getAnimations().map((animation) => animation.finished)).then(() => {
      this.dialogElement.removeAttribute("closing");

      if (this.isDialog) {
        this.dialogElement.close();
        // The handleDialogClose method will handle the cleanup when the dialog actually closes
      } else {
        // For div modals, wait until hide transition completes before cleanup
        this.hideDivModal(true, () => {
          this.handleDialogClose();
        });
      }

      // Reset bouncing flag
      this.isBouncing = false;
    });
  }

  backdropClose(event) {
    // For dialog elements: only close if clicking on the actual backdrop area (outside the dialog's content box)
    // For div elements: check if clicking on the backdrop wrapper
    let isBackdropClick = false;

    if (this.isDialog) {
      // Check if click target is the dialog itself (not a child element)
      if (event.target.nodeName === "DIALOG") {
        // Get the dialog's bounding rect to check if click is outside content area
        const rect = this.dialogElement.getBoundingClientRect();
        // Click is on backdrop if it's outside the dialog's content box
        // This prevents scrollbar clicks from being treated as backdrop clicks
        isBackdropClick =
          event.clientX < rect.left ||
          event.clientX > rect.right ||
          event.clientY < rect.top ||
          event.clientY > rect.bottom;
      }
    } else {
      isBackdropClick = event.target === this.dialogElement || event.target.hasAttribute("data-ui-modal-backdrop");
    }

    if (isBackdropClick) {
      // Stop propagation to prevent closing parent dialogs
      event.stopPropagation();

      if (this.preventDismissValue) {
        this.bounce();
      } else {
        this.close();
      }
    }
  }

  // For showing non-modally
  show() {
    this.dialogElement.show();
  }

  hide() {
    this.close();
  }

  beforeCache() {
    // Close immediately without animation during navigation
    if (this.isOpen) {
      this.dialogElement.removeAttribute("closing");
      if (this.isDialog) {
        this.dialogElement.close();
      } else {
        this.hideDivModal(false);
      }
      this.cleanupScrollbarCompensation();
    }
  }

  beforeVisit() {
    // Close immediately without animation during navigation
    if (this.isOpen) {
      this.dialogElement.removeAttribute("closing");
      if (this.isDialog) {
        this.dialogElement.close();
      } else {
        this.hideDivModal(false);
      }
      this.cleanupScrollbarCompensation();
    }
  }

  // Calculate actual scrollbar width
  getScrollbarWidth() {
    // Create a temporary div to measure scrollbar width
    const outer = document.createElement("div");
    outer.style.visibility = "hidden";
    outer.style.overflow = "scroll";
    outer.style.msOverflowStyle = "scrollbar"; // Force scrollbars on IE/Edge
    document.body.appendChild(outer);

    const inner = document.createElement("div");
    outer.appendChild(inner);

    const scrollbarWidth = outer.offsetWidth - inner.offsetWidth;
    outer.parentNode.removeChild(outer);

    return scrollbarWidth;
  }

  setTriggerLoadingState(triggerElement, isLoading) {
    if (!(triggerElement instanceof HTMLElement)) return;

    const supportsDisabled = "disabled" in triggerElement;

    if (isLoading) {
      triggerElement.classList.add("!cursor-wait");
      triggerElement.setAttribute("aria-busy", "true");

      if (supportsDisabled) {
        triggerElement.dataset.overlayOriginalDisabled = triggerElement.disabled ? "true" : "false";
        triggerElement.disabled = true;
      } else {
        triggerElement.dataset.overlayOriginalAriaDisabled = triggerElement.getAttribute("aria-disabled") || "";
        triggerElement.dataset.overlayHadPointerEventsNone = triggerElement.classList.contains("pointer-events-none")
          ? "true"
          : "false";
        triggerElement.setAttribute("aria-disabled", "true");
        triggerElement.classList.add("pointer-events-none");
      }

      return;
    }

    triggerElement.classList.remove("!cursor-wait");
    triggerElement.removeAttribute("aria-busy");

    if (supportsDisabled) {
      triggerElement.disabled = triggerElement.dataset.overlayOriginalDisabled === "true";
      delete triggerElement.dataset.overlayOriginalDisabled;
    } else {
      const originalAriaDisabled = triggerElement.dataset.overlayOriginalAriaDisabled;
      if (originalAriaDisabled) {
        triggerElement.setAttribute("aria-disabled", originalAriaDisabled);
      } else {
        triggerElement.removeAttribute("aria-disabled");
      }

      if (triggerElement.dataset.overlayHadPointerEventsNone !== "true") {
        triggerElement.classList.remove("pointer-events-none");
      }

      delete triggerElement.dataset.overlayOriginalAriaDisabled;
      delete triggerElement.dataset.overlayHadPointerEventsNone;
    }
  }

  async #loadTemplateContent() {
    // Find the container in the dialog to append content to
    const container = this.dialogElement.querySelector("[data-ui-modal-content]") || this.dialogElement;

    // Check if we should use Turbo Frame lazy loading
    if (this.turboFrameSrcValue) {
      // Look for a turbo-frame in the container
      let turboFrame = container.querySelector("turbo-frame");

      if (!turboFrame) {
        // Create a turbo-frame if it doesn't exist
        turboFrame = document.createElement("turbo-frame");
        turboFrame.id = "modal-lazy-content";

        // Clear any loading indicators or placeholder content
        container.innerHTML = "";
        container.appendChild(turboFrame);
      }

      // Set the src to trigger the lazy load
      turboFrame.src = this.turboFrameSrcValue;

      // Wait for the turbo-frame to load
      return new Promise((resolve) => {
        const handleLoad = () => {
          turboFrame.removeEventListener("turbo:frame-load", handleLoad);
          resolve();
        };

        turboFrame.addEventListener("turbo:frame-load", handleLoad);

        // Fallback timeout in case the frame doesn't load
        setTimeout(() => {
          turboFrame.removeEventListener("turbo:frame-load", handleLoad);
          resolve();
        }, 5000);
      });
    } else if (this.hasTemplateTarget) {
      // Use template-based lazy loading (existing behavior)
      const templateContent = this.templateTarget.content.cloneNode(true);

      // Clear any loading indicators or placeholder content
      container.innerHTML = "";

      // Append the template content
      container.appendChild(templateContent);
    }
  }

  // Handle cleanup when dialog is closed by any means
  handleDialogClose() {
    // If the modal was open, decrement the counter
    if (this.isOpen) {
      this.cleanupScrollbarCompensation();
    }

    // Ensure the closing attribute is removed
    this.dialogElement.removeAttribute("closing");

    // Reset bouncing flag
    this.isBouncing = false;
  }

  // Centralized method to handle scrollbar compensation cleanup
  cleanupScrollbarCompensation() {
    if (!this.isOpen) return;

    window.__openDialogCount = Math.max(0, window.__openDialogCount - 1);
    this.isOpen = false;

    // Only remove scrollbar compensation if no dialogs are open
    if (window.__openDialogCount === 0) {
      document.documentElement.style.removeProperty("--scrollbar-compensation");
      document.body.classList.remove("modal-open", "slideover-open");
    } else {
      this.syncBodyOverlayClasses();
    }

    if (!this.isDialog) {
      this.restoreDivModalMount();
    }
  }

  // Keep body classes aligned with actual open overlay types when dialogs are nested
  syncBodyOverlayClasses() {
    const hasOpenModalDialog = document.querySelector('dialog[open][data-ui-modal-target="dialog"]');
    const hasOpenModalDiv = document.querySelector('[data-ui-modal-target="dialog"].modal-open');
    const hasOpenSlideover = document.querySelector('dialog[open][data-slideover-target="dialog"]');

    document.body.classList.toggle("modal-open", Boolean(hasOpenModalDialog || hasOpenModalDiv));
    document.body.classList.toggle("slideover-open", Boolean(hasOpenSlideover));
  }

  mountDivModalToBody() {
    if (this.isDialog || this.isPortaled) return;

    if (!this.originalParent) {
      this.originalParent = this.dialogElement.parentNode;
      this.originalNextSibling = this.dialogElement.nextSibling;
    }

    document.body.appendChild(this.dialogElement);
    this.isPortaled = true;
  }

  restoreDivModalMount() {
    if (this.isDialog || !this.isPortaled) return;

    const parent = this.originalParent;
    if (!parent) {
      this.isPortaled = false;
      return;
    }

    if (this.originalNextSibling && this.originalNextSibling.parentNode === parent) {
      parent.insertBefore(this.dialogElement, this.originalNextSibling);
    } else {
      parent.appendChild(this.dialogElement);
    }

    this.isPortaled = false;
  }

  // Handle keydown events
  handleKeydown(event) {
    if (event.key === "Escape" && this.preventDismissValue) {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      this.bounce();
      return false;
    }

    // Handle Tab key for focus trapping
    if (event.key === "Tab") {
      this.handleTabKey(event);
    }
  }

  // Handle cancel event (Escape key)
  handleDialogCancel(event) {
    if (this.preventDismissValue) {
      event.preventDefault();
      event.stopPropagation();
      this.bounce();
      return false;
    }
  }

  // Add bounce animation to indicate modal won't close
  bounce() {
    // Prevent multiple bounces in quick succession
    if (this.isBouncing) return;

    this.isBouncing = true;

    // For a more pronounced effect, we can combine with scale
    this.dialogElement.classList.add("scale-105", "transition-transform");

    setTimeout(() => {
      this.dialogElement.classList.remove("scale-105");
      this.dialogElement.classList.add("scale-100");

      setTimeout(() => {
        // Remove all animation classes
        this.dialogElement.classList.remove("scale-100", "transition-transform");

        // Allow bouncing again after a short cooldown
        setTimeout(() => {
          this.isBouncing = false;
        }, 200); // Additional cooldown to prevent rapid bouncing
      }, 150);
    }, 150);
  }

  // Check if the device supports touch
  isTouchDevice() {
    return "ontouchstart" in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0;
  }

  // Set up focus trapping for the modal
  setupFocusTrapping() {
    // Get all focusable elements within the modal
    this.updateFocusableElements();

    // Check for elements with native autofocus attribute first
    const autofocusElement = this.dialogElement.querySelector("[autofocus]");
    if (autofocusElement) {
      // Always respect native autofocus, regardless of device type
      autofocusElement.focus();
    } else if (this.autoFocusValue && this.firstFocusableElement && !this.isTouchDevice()) {
      // Fall back to auto-focusing first element if no native autofocus and not on touch device
      this.firstFocusableElement.focus();
    }
  }

  // Update the list of focusable elements
  updateFocusableElements() {
    const focusableSelector = [
      "a[href]",
      "area[href]",
      'input:not([disabled]):not([tabindex="-1"])',
      'button:not([disabled]):not([tabindex="-1"])',
      'textarea:not([disabled]):not([tabindex="-1"])',
      'select:not([disabled]):not([tabindex="-1"])',
      "details",
      '[tabindex]:not([tabindex="-1"])',
      '[contenteditable]:not([contenteditable="false"])',
    ].join(",");

    this.focusableElements = Array.from(this.dialogElement.querySelectorAll(focusableSelector)).filter((element) => {
      // Filter out elements that are not visible or have display: none
      return (
        element.offsetWidth > 0 &&
        element.offsetHeight > 0 &&
        getComputedStyle(element).display !== "none" &&
        getComputedStyle(element).visibility !== "hidden"
      );
    });

    this.firstFocusableElement = this.focusableElements[0] || null;
    this.lastFocusableElement = this.focusableElements[this.focusableElements.length - 1] || null;
  }

  // Handle Tab key for focus trapping
  handleTabKey(event) {
    // Update focusable elements in case the DOM has changed
    this.updateFocusableElements();

    if (this.focusableElements.length === 0) {
      // If no focusable elements, prevent tab and keep focus on dialog
      event.preventDefault();
      return;
    }

    if (this.focusableElements.length === 1) {
      // If only one focusable element, prevent tab and keep focus on it
      event.preventDefault();
      this.firstFocusableElement.focus();
      return;
    }

    // Handle normal tab navigation with wrapping
    if (event.shiftKey) {
      // Shift+Tab: moving backwards
      if (document.activeElement === this.firstFocusableElement) {
        event.preventDefault();
        this.lastFocusableElement.focus();
      }
    } else {
      // Tab: moving forwards
      if (document.activeElement === this.lastFocusableElement) {
        event.preventDefault();
        this.firstFocusableElement.focus();
      }
    }
  }

  // Show div-based modal
  showDivModal() {
    this.dialogElement.classList.add("modal-open");
    this.dialogElement.style.display = "flex";
    // Force a reflow to ensure the display change is applied before the opacity transition
    this.dialogElement.offsetHeight;
    this.dialogElement.classList.add("modal-visible");
  }

  getDivModalTransitionDurationMs() {
    if (this.isDialog) return 0;

    const contentElement = this.dialogElement.querySelector(":scope > div");
    return Math.max(
      this.getTransitionDurationMs(this.dialogElement),
      contentElement ? this.getTransitionDurationMs(contentElement) : 0,
    );
  }

  getTransitionDurationMs(element) {
    const computed = window.getComputedStyle(element);
    const durations = computed.transitionDuration.split(",").map((value) => this.parseTimeToMs(value));
    const delays = computed.transitionDelay.split(",").map((value) => this.parseTimeToMs(value));

    const longestListLength = Math.max(durations.length, delays.length);
    let maxDuration = 0;

    for (let i = 0; i < longestListLength; i++) {
      const duration = durations[i] ?? durations[durations.length - 1] ?? 0;
      const delay = delays[i] ?? delays[delays.length - 1] ?? 0;
      maxDuration = Math.max(maxDuration, duration + delay);
    }

    return maxDuration;
  }

  parseTimeToMs(rawValue) {
    const value = rawValue.trim();
    if (!value) return 0;
    if (value.endsWith("ms")) return parseFloat(value);
    if (value.endsWith("s")) return parseFloat(value) * 1000;
    return 0;
  }

  // Hide div-based modal
  hideDivModal(animate = true, onHidden = null) {
    this.dialogElement.classList.remove("modal-visible");

    const completeHide = () => {
      this.dialogElement.style.display = "none";
      this.dialogElement.classList.remove("modal-open");
      if (typeof onHidden === "function") {
        onHidden();
      }
    };

    if (!animate) {
      completeHide();
      return;
    }

    const transitionDuration = this.getDivModalTransitionDurationMs();
    if (transitionDuration === 0) {
      completeHide();
      return;
    }

    setTimeout(() => {
      completeHide();
    }, transitionDuration);
  }

  // Handle global keydown for div-based modals (escape key)
  handleGlobalKeydown(event) {
    // Only handle if this modal is open and is the topmost modal
    if (!this.isOpen) return;

    // Check if this is the topmost modal by comparing with all open modals
    const allOpenModals = document.querySelectorAll('[data-ui-modal-target="dialog"].modal-open');
    const isTopmost = allOpenModals.length === 0 || allOpenModals[allOpenModals.length - 1] === this.dialogElement;

    if (event.key === "Escape" && isTopmost) {
      if (this.preventDismissValue) {
        event.preventDefault();
        event.stopPropagation();
        this.bounce();
      } else {
        event.preventDefault();
        this.close();
      }
    }
  }

  handleDivModalClick(event) {
    if (!this.isOpen) return;

    // Support buttons/links using Stimulus actions like click->ui-modal#close:prevent
    // even after the modal is portaled outside controller scope.
    const closeTrigger = event.target.closest('[data-action*="modal#close"]');
    if (!closeTrigger || !this.dialogElement.contains(closeTrigger)) return;

    event.preventDefault();
    event.stopPropagation();
    this.close();
  }
}
