import { Controller } from "@hotwired/stimulus";

const DRAWER_EASE = "cubic-bezier(0.35, 0.75, 0, 1)";
const DEFAULT_OVERLAY_ENTER_DURATION_MS = 450; // Overlay fade-in duration used when opening the drawer.
const DEFAULT_OVERLAY_EXIT_DURATION_MS = 300; // Overlay fade-out duration used when closing the drawer.
const DRAWER_SNAP_DURATION_MS = 300; // Default transform animation duration when snapping to a target state/snap point.
const DRAWER_BOUNCE_IN_DURATION_MS = 150; // Quick "settle" animation duration for subtle bounce-in feedback.
const DRAWER_BOUNCE_OUT_DURATION_MS = 250; // Bounce-out animation duration when the drawer eases back after overdrag.
const DRAWER_MAX_OVERLAY_OPACITY = 0.5; // Highest backdrop opacity allowed while the drawer is open.
const DRAWER_DRAG_DAMPING_FACTOR = 0.24; // Resistance factor applied to drag movement to dampen gesture translation.
const DRAWER_MAX_OVERDRAG_PX = 36; // Maximum pixels the drawer can be pulled beyond bounds before clamping.
const DRAWER_STEP_SNAP_THRESHOLD_PX = 14; // Pixel distance from a snap point under which we auto-snap to that step.

// Shared global counter for open dialogs (modals, slideovers, and drawers)
if (!window.__openDialogCount) {
  window.__openDialogCount = 0;
}

// Reset dialog count on page navigation to prevent desync issues
// This handles cases where users navigate back/forward while dialogs are open
if (!window.__dialogCountResetBound) {
  window.__dialogCountResetBound = true;

  const resetDialogCount = () => {
    // Only reset if no dialogs are actually open
    const openDialogs = document.querySelectorAll("dialog[open]");
    if (openDialogs.length === 0) {
      window.__openDialogCount = 0;
      document.documentElement.style.removeProperty("--scrollbar-compensation");
      document.body.classList.remove("modal-open", "slideover-open", "drawer-open");
    } else {
      // Sync count with actual open dialogs
      window.__openDialogCount = openDialogs.length;
    }
  };

  document.addEventListener("turbo:before-cache", resetDialogCount);
  document.addEventListener("turbo:load", resetDialogCount);
}

export default class extends Controller {
  static targets = ["dialog", "handle", "snapIndicator", "template", "snapContent"];
  static values = {
    open: { type: Boolean, default: false },
    snapPoints: { type: Array, default: ["180px", "80%"] }, // Height positions: ["180px" = 180px tall, "50%" = half screen height]
    activeSnapPoint: { type: Number, default: 0 },
    dismissible: { type: Boolean, default: true },
    fadeFromIndex: { type: Number, default: -1 }, // how this works: -1 means no fade, 0 means fade from the first snap point, 1 means fade from the second snap point, etc.
    closeThreshold: { type: Number, default: 0.25 }, // Percentage of drawer height to trigger close
    velocityThreshold: { type: Number, default: 0.5 }, // Velocity threshold for flick gestures
    scrollLockTimeout: { type: Number, default: 100 }, // Time after scroll top hit during which drag close is blocked
    respectReducedMotion: { type: Boolean, default: true }, // Disable to force animations for debugging
    lazyLoad: { type: Boolean, default: false }, // Whether to lazy load the drawer content
    turboFrameSrc: { type: String, default: "" }, // URL for the turbo frame
  };

  connect() {
    this.boundBeforeCache = this.beforeCache.bind(this);
    document.addEventListener("turbo:before-cache", this.boundBeforeCache);

    this.isOpen = false;
    this.isOpening = false; // Add isOpening flag
    this.isDragging = false;
    this.isBouncing = false;
    this.isClosing = false; // Add flag to track closing state
    this.isLoadingContent = false; // Prevent duplicate lazy-load requests before first open
    this.closeTimeout = null;
    this.contentLoaded = false; // Track if lazy content has been loaded
    this.activePointerId = null;
    this.pointerCaptureElement = null;
    this.previousBodyCursor = null;
    this.openTime = 0;
    this.lastTimeDragPrevented = 0;
    this.isAllowedToDrag = false;
    this.dragSnapPointTransforms = null;
    this.dragFrame = null;
    this.pendingDragTransform = null;
    this.snapHeightSyncFrame = null;
    this.snapHeightSyncTimeout = null;
    this.snapHeightSyncTransitionEnd = null;
    this.focusTimeout = null;
    this.openFrame = null;
    this.openCompletionTimeout = null;
    this.autoHeightFrame = null;
    this.startY = 0;
    this.currentY = 0;
    this.lastY = 0;
    this.velocity = 0;
    this.lastTime = Date.now();

    // Initialize focus trapping
    this.focusableElements = [];
    this.firstFocusableElement = null;
    this.lastFocusableElement = null;
    this.contentWrapper = this.dialogTarget.querySelector(":scope > div");
    this.lastContentWrapperHeight = null;

    // Bind event handlers once
    this.boundHandleStart = this.handleStart.bind(this);
    this.boundHandleMove = this.handleMove.bind(this);
    this.boundHandleEnd = this.handleEnd.bind(this);
    this.boundHandleCancel = this.handleCancel.bind(this);
    this.boundHandleReducedMotionChange = this.handleReducedMotionChange.bind(this);
    this.boundHandleWindowBlur = this.handleWindowBlur.bind(this);

    this.reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    this.isReducedMotion = this.respectReducedMotionValue && this.reducedMotionQuery.matches;
    this.drawerOpenDurationMs = this.readCssDuration(
      "--overlay-motion-duration-enter",
      DEFAULT_OVERLAY_ENTER_DURATION_MS,
    );
    this.drawerCloseDurationMs = this.readCssDuration(
      "--overlay-motion-duration-exit",
      DEFAULT_OVERLAY_EXIT_DURATION_MS,
    );
    if (this.reducedMotionQuery.addEventListener) {
      this.reducedMotionQuery.addEventListener("change", this.boundHandleReducedMotionChange);
    } else {
      this.reducedMotionQuery.addListener(this.boundHandleReducedMotionChange);
    }

    // Add event listener for dialog close
    this.boundHandleDialogClose = this.handleDialogClose.bind(this);
    this.dialogTarget.addEventListener("close", this.boundHandleDialogClose);

    // Add event listener for escape key
    this.boundHandleEscape = this.handleEscape.bind(this);
    this.dialogTarget.addEventListener("cancel", this.boundHandleEscape);

    // Additional keydown listener for better escape key handling
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    this.dialogTarget.addEventListener("keydown", this.boundHandleKeydown);

    // Add resize observer for auto snap points
    this.resizeObserver = new ResizeObserver(() => {
      if (this.isOpen && this.snapPointsValue[this.activeSnapPointValue] === "auto") {
        // Debounce resize recalculations
        clearTimeout(this.resizeTimeout);
        this.resizeTimeout = setTimeout(() => {
          this.updateAutoHeight();
        }, 100);
      }
    });

    // Add mutation observer to watch for content changes
    this.mutationObserver = new MutationObserver(() => {
      if (this.isOpen && !this.isClosing && this.snapPointsValue[this.activeSnapPointValue] === "auto") {
        // Debounce mutation recalculations
        clearTimeout(this.mutationTimeout);
        this.mutationTimeout = setTimeout(() => {
          this.updateAutoHeight();
        }, 100);
      }
    });

    // Observe the dialog content for changes
    this.resizeObserver.observe(this.dialogTarget);

    // Start observing mutations (attributes, childList, and subtree)
    this.mutationObserver.observe(this.dialogTarget, {
      attributes: true,
      childList: true,
      subtree: true,
      attributeFilter: ["style", "class", "hidden", "data-state"], // Watch for common state changes
    });

    // Also listen to window resize for viewport changes
    this.boundHandleResize = this.handleResize.bind(this);
    window.addEventListener("resize", this.boundHandleResize);
    window.addEventListener("blur", this.boundHandleWindowBlur);

    // Set initial styles
    this.dialogTarget.style.transform = "translate3d(0, 100%, 0)";
    this.dialogTarget.style.transition = "none";
    if (this.hasHandleTarget) {
      // Let the drawer own vertical touch gestures on the handle to avoid spurious pointercancel events.
      this.handleTarget.style.touchAction = "none";
    }

    // Open if specified in data attribute (after all initialization is complete)
    if (this.openValue) {
      // Use requestAnimationFrame to ensure DOM is ready
      requestAnimationFrame(() => {
        this.open();
      });
    }
  }

  disconnect() {
    if (this.reducedMotionQuery?.removeEventListener) {
      this.reducedMotionQuery.removeEventListener("change", this.boundHandleReducedMotionChange);
    } else if (this.reducedMotionQuery?.removeListener) {
      this.reducedMotionQuery.removeListener(this.boundHandleReducedMotionChange);
    }

    if (this.closeTimeout) {
      clearTimeout(this.closeTimeout);
    }
    this.cancelDeferredMotionWork();
    this.clearPendingFocusTimeout();
    if (this.dragFrame !== null) {
      cancelAnimationFrame(this.dragFrame);
      this.dragFrame = null;
    }
    this.stopSnapHeightSync();
    this.releaseActivePointerCapture();
    this.clearDraggingCursor();

    if (this.isOpen) {
      window.__openDialogCount = Math.max(0, window.__openDialogCount - 1);
      this.isOpen = false;

      if (window.__openDialogCount === 0) {
        document.documentElement.style.removeProperty("--scrollbar-compensation");
        document.body.classList.remove("modal-open", "slideover-open", "drawer-open");
      } else {
        this.syncBodyOverlayClasses();
      }
    }

    document.removeEventListener("turbo:before-cache", this.boundBeforeCache);
    this.dialogTarget.removeEventListener("close", this.boundHandleDialogClose);
    this.dialogTarget.removeEventListener("cancel", this.boundHandleEscape);
    this.dialogTarget.removeEventListener("keydown", this.boundHandleKeydown);
    window.removeEventListener("resize", this.boundHandleResize);
    window.removeEventListener("blur", this.boundHandleWindowBlur);

    // Clean up observers
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }

    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
    }

    // Clear any pending timeouts
    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout);
    }

    if (this.mutationTimeout) {
      clearTimeout(this.mutationTimeout);
    }

    this.removeEventListeners();
    this.dragSnapPointTransforms = null;
  }

  handleReducedMotionChange(event) {
    this.isReducedMotion = this.respectReducedMotionValue && event.matches;
  }

  getDuration(durationMs) {
    return this.isReducedMotion ? 0 : durationMs;
  }

  readCssDuration(variableName, fallbackMs) {
    const rawValue = getComputedStyle(document.documentElement).getPropertyValue(variableName).trim();
    if (!rawValue) return fallbackMs;

    if (rawValue.endsWith("ms")) {
      const parsed = parseFloat(rawValue);
      return Number.isFinite(parsed) ? parsed : fallbackMs;
    }

    if (rawValue.endsWith("s")) {
      const parsed = parseFloat(rawValue);
      return Number.isFinite(parsed) ? parsed * 1000 : fallbackMs;
    }

    return fallbackMs;
  }

  getTransformTransition(durationMs) {
    const duration = this.getDuration(durationMs);
    if (duration === 0) return "none";
    return `transform ${duration}ms ${DRAWER_EASE}`;
  }

  translateY(value) {
    const y = typeof value === "number" ? `${value}px` : value;
    this.dialogTarget.style.transform = `translate3d(0, ${y}, 0)`;
  }

  flushPendingDragVisualUpdate() {
    if (this.pendingDragTransform === null) return;

    const pendingTransform = this.pendingDragTransform;
    this.translateY(pendingTransform);
    this.updateScrollableHeight(this.getVisibleDrawerHeight(pendingTransform));

    this.pendingDragTransform = null;
  }

  scheduleDragVisualUpdate(transform) {
    this.pendingDragTransform = transform;

    if (this.dragFrame !== null) return;

    this.dragFrame = requestAnimationFrame(() => {
      this.dragFrame = null;
      this.flushPendingDragVisualUpdate();
    });
  }

  cancelDeferredMotionWork() {
    if (this.openCompletionTimeout !== null) {
      clearTimeout(this.openCompletionTimeout);
      this.openCompletionTimeout = null;
    }

    if (this.openFrame !== null) {
      cancelAnimationFrame(this.openFrame);
      this.openFrame = null;
    }

    if (this.autoHeightFrame !== null) {
      cancelAnimationFrame(this.autoHeightFrame);
      this.autoHeightFrame = null;
    }
  }

  stopSnapHeightSync() {
    if (this.snapHeightSyncFrame !== null) {
      cancelAnimationFrame(this.snapHeightSyncFrame);
      this.snapHeightSyncFrame = null;
    }

    if (this.snapHeightSyncTimeout !== null) {
      clearTimeout(this.snapHeightSyncTimeout);
      this.snapHeightSyncTimeout = null;
    }

    if (this.snapHeightSyncTransitionEnd) {
      this.dialogTarget.removeEventListener("transitionend", this.snapHeightSyncTransitionEnd);
      this.snapHeightSyncTransitionEnd = null;
    }
  }

  syncScrollableHeightDuringSnap(transitionDuration) {
    this.stopSnapHeightSync();

    const finalizeSync = () => {
      this.stopSnapHeightSync();
      this.updateScrollableHeight();
    };

    const tick = () => {
      this.updateScrollableHeight();
      this.snapHeightSyncFrame = requestAnimationFrame(tick);
    };

    this.snapHeightSyncFrame = requestAnimationFrame(tick);

    this.snapHeightSyncTransitionEnd = (event) => {
      if (event.target !== this.dialogTarget || event.propertyName !== "transform") return;
      finalizeSync();
    };
    this.dialogTarget.addEventListener("transitionend", this.snapHeightSyncTransitionEnd);

    const fallbackDelayMs = Math.max(transitionDuration + 50, 100);
    this.snapHeightSyncTimeout = setTimeout(() => {
      finalizeSync();
    }, fallbackDelayMs);
  }

  queueFinishClosing(durationMs) {
    if (this.closeTimeout) {
      clearTimeout(this.closeTimeout);
    }

    if (durationMs === 0) {
      this.finishClosing();
      return;
    }

    this.closeTimeout = setTimeout(() => {
      this.finishClosing();
    }, durationMs);
  }

  clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  getMaxSnapIndex() {
    return Math.max(0, this.snapPointsValue.length - 1);
  }

  getSnapStepFromVelocity(velocity) {
    const safeThreshold = Math.max(this.velocityThresholdValue, 0.01);
    const normalizedVelocity = velocity / safeThreshold;
    if (normalizedVelocity < 1.5) return 1;
    if (normalizedVelocity < 2.5) return 2;
    return 3;
  }

  dampenDistance(distance) {
    const dampedDistance = distance * DRAWER_DRAG_DAMPING_FACTOR;
    return (DRAWER_MAX_OVERDRAG_PX * dampedDistance) / (dampedDistance + DRAWER_MAX_OVERDRAG_PX);
  }

  getSnapPointTransformY(index) {
    const cachedTransform = this.dragSnapPointTransforms?.[index];
    if (typeof cachedTransform === "number") {
      return cachedTransform;
    }

    const snapPoint = this.snapPointsValue[index];
    if (!snapPoint || !this.dialogTarget) return null;

    const dialogHeight = this.dialogTarget.offsetHeight;
    if (!dialogHeight) return null;

    if (snapPoint === "auto") {
      // Auto snap points are measured dynamically. When active, the live transform is the most reliable value.
      if (index === this.activeSnapPointValue) {
        return this.getCurrentTransformY();
      }

      const autoTranslate = this.calculateAutoTranslateY();
      const match = autoTranslate.match(/calc\(100%\s*-\s*([0-9.]+)px\)/);
      if (match) {
        return this.clamp(dialogHeight - parseFloat(match[1]), 0, dialogHeight);
      }
      return null;
    }

    if (typeof snapPoint === "string" && snapPoint.endsWith("px")) {
      return this.clamp(dialogHeight - parseFloat(snapPoint), 0, dialogHeight);
    }

    if (typeof snapPoint === "string" && snapPoint.endsWith("%")) {
      const percentage = parseFloat(snapPoint) / 100;
      const pixelHeight = window.innerHeight * percentage;
      return this.clamp(dialogHeight - pixelHeight, 0, dialogHeight);
    }

    return null;
  }

  captureDragSnapPointTransforms() {
    if (!this.snapPointsValue?.length) {
      this.dragSnapPointTransforms = null;
      return;
    }

    const currentTransformY = this.getCurrentTransformY();
    this.dragSnapPointTransforms = this.snapPointsValue.map((_snapPoint, index) => {
      if (index === this.activeSnapPointValue) {
        return currentTransformY;
      }
      return this.getSnapPointTransformY(index);
    });
  }

  trySnapToAdjacentPointDuringDrag(clientY, proposedTransform, deltaY) {
    const maxSnapIndex = this.getMaxSnapIndex();
    const currentSnapIndex = this.activeSnapPointValue;
    const upperAdjacentIndex = Math.min(currentSnapIndex + 1, maxSnapIndex);
    const lowerAdjacentIndex = Math.max(currentSnapIndex - 1, 0);

    const clearPendingDragUpdate = () => {
      if (this.dragFrame !== null) {
        cancelAnimationFrame(this.dragFrame);
        this.dragFrame = null;
      }
      this.pendingDragTransform = null;
    };

    if (deltaY < 0 && upperAdjacentIndex !== currentSnapIndex) {
      const upperTransform = this.getSnapPointTransformY(upperAdjacentIndex);
      if (upperTransform !== null && proposedTransform < upperTransform - DRAWER_STEP_SNAP_THRESHOLD_PX) {
        clearPendingDragUpdate();
        this.applySnapPointState(upperAdjacentIndex);
        const shouldRubberBandAtTopEdge = upperAdjacentIndex === maxSnapIndex && proposedTransform < upperTransform;
        const handoffTransform = shouldRubberBandAtTopEdge
          ? upperTransform - this.dampenDistance(upperTransform - proposedTransform)
          : proposedTransform;

        this.initialTransform = handoffTransform;
        this.startY = clientY;
        this.currentY = clientY;
        this.lastY = clientY;
        this.translateY(handoffTransform);
        this.updateScrollableHeight(this.getVisibleDrawerHeight(handoffTransform));
        return true;
      }
    }

    if (deltaY > 0 && lowerAdjacentIndex !== currentSnapIndex) {
      const lowerTransform = this.getSnapPointTransformY(lowerAdjacentIndex);
      if (lowerTransform !== null && proposedTransform > lowerTransform + DRAWER_STEP_SNAP_THRESHOLD_PX) {
        clearPendingDragUpdate();
        this.applySnapPointState(lowerAdjacentIndex);
        const shouldRubberBandAtBottomEdge =
          lowerAdjacentIndex === 0 && !this.dismissibleValue && proposedTransform > lowerTransform;
        const handoffTransform = shouldRubberBandAtBottomEdge
          ? lowerTransform + this.dampenDistance(proposedTransform - lowerTransform)
          : proposedTransform;

        this.initialTransform = handoffTransform;
        this.startY = clientY;
        this.currentY = clientY;
        this.lastY = clientY;
        this.translateY(handoffTransform);
        this.updateScrollableHeight(this.getVisibleDrawerHeight(handoffTransform));
        return true;
      }
    }

    return false;
  }

  isInteractiveElement(target) {
    if (!(target instanceof Element)) return false;
    return Boolean(target.closest("input, textarea, select, button, a, [contenteditable='true']"));
  }

  shouldDrag(target, isDraggingDown) {
    if (this.hasHandleTarget && target instanceof Node && this.handleTarget.contains(target)) {
      return true;
    }

    if (!(target instanceof Element)) return true;
    if (target.closest("[data-drawer-no-drag]")) return false;
    if (this.isInteractiveElement(target)) return false;

    const highlightedText = window.getSelection()?.toString();
    if (highlightedText && highlightedText.length > 0) return false;

    const now = Date.now();
    if (isDraggingDown && now - this.lastTimeDragPrevented < this.scrollLockTimeoutValue) {
      return false;
    }

    let element = target;
    while (element && element !== this.dialogTarget) {
      if (element instanceof HTMLElement && element.scrollHeight > element.clientHeight + 1) {
        if (element.scrollTop > 0) {
          this.lastTimeDragPrevented = now;
          return false;
        }
      }

      element = element.parentElement;
    }

    // Right after open, avoid accidental close drags while users start scrolling.
    if (isDraggingDown && now - this.openTime < this.scrollLockTimeoutValue) {
      return false;
    }

    return true;
  }

  computeOverlayOpacity(index) {
    const maxOpacity = DRAWER_MAX_OVERLAY_OPACITY;
    if (this.fadeFromIndexValue < 0) return maxOpacity;

    const maxSnapIndex = this.getMaxSnapIndex();
    if (maxSnapIndex <= 0) return maxOpacity;
    if (index < this.fadeFromIndexValue) return 0;

    const denominator = maxSnapIndex - this.fadeFromIndexValue;
    if (denominator <= 0) return maxOpacity;

    const progress = this.clamp((index - this.fadeFromIndexValue) / denominator, 0, 1);
    return maxOpacity * progress;
  }

  setOverlayOpacity(opacity) {
    const clampedOpacity = this.clamp(opacity, 0, DRAWER_MAX_OVERLAY_OPACITY);
    this.dialogTarget.style.setProperty("--drawer-overlay-opacity", `${clampedOpacity}`);
  }

  resetClosedVisualState() {
    this.dialogTarget.style.transition = "none";
    this.translateY("100%");
    this.setOverlayOpacity(0);
  }

  async open(event) {
    if (this.isOpen || this.isOpening || this.isLoadingContent) return;

    this.isOpening = true;
    let lockAcquired = false;

    const triggerElement =
      event?.currentTarget instanceof HTMLElement &&
      event.currentTarget.matches('button, [role="button"], input[type="button"], input[type="submit"], a[href]')
        ? event.currentTarget
        : null;
    const shouldShowLoadingState = this.lazyLoadValue && !this.contentLoaded;

    try {
      // Acquire scrollbar compensation immediately so page scroll is locked
      // before any async lazy-loading delay.
      window.__openDialogCount++;
      this.isOpen = true;
      lockAcquired = true;
      this.openTime = Date.now();

      if (window.__openDialogCount === 1) {
        const scrollbarWidth = this.getScrollbarWidth();
        if (scrollbarWidth > 0) {
          document.documentElement.style.setProperty("--scrollbar-compensation", `${scrollbarWidth}px`);
        } else {
          document.documentElement.style.removeProperty("--scrollbar-compensation");
        }
      }
      document.body.classList.add("drawer-open");

      // If lazy loading is enabled and content hasn't been loaded yet, load it now
      if (shouldShowLoadingState) {
        this.isLoadingContent = true;
        this.setTriggerLoadingState(triggerElement, true);
        try {
          await this.#loadTemplateContent();
          this.contentLoaded = true;
        } finally {
          this.isLoadingContent = false;
          this.setTriggerLoadingState(triggerElement, false);
        }
      }

      // Always start from fully closed so lazy drawers still run full enter motion.
      this.dialogTarget.removeAttribute("closing");
      this.resetClosedVisualState();
      this.dialogTarget.showModal();

      // Set up focus trapping
      this.setupFocusTrapping();
      this.normalizeInitialFocus();

      // Always start from first snap point
      this.activeSnapPointValue = 0;
      this.primeContentHeightForSnapPoint(this.activeSnapPointValue);

      const openDuration = this.getDuration(this.drawerOpenDurationMs);
      // Animate in with spring-like easing
      this.openFrame = requestAnimationFrame(() => {
        this.openFrame = null;
        if (!this.isOpen || this.isClosing) return;

        this.snapToPoint(this.activeSnapPointValue, {
          duration: this.drawerOpenDurationMs,
          syncHeightDuringTransition: false,
        });

        // Reset opening flag after animation duration
        this.openCompletionTimeout = setTimeout(() => {
          this.openCompletionTimeout = null;
          if (!this.isOpen || this.isClosing) return;

          this.isOpening = false;

          // Force update height in case viewport changed during animation (e.g., mobile address bar)
          if (this.snapPointsValue[this.activeSnapPointValue] === "auto") {
            this.updateAutoHeight();
          }
        }, openDuration);
      });

      // Add drag listeners
      if (this.dismissibleValue) {
        this.addEventListeners();
      }
    } catch (error) {
      // Roll back provisional lock if opening fails (e.g. lazy-load error).
      if (lockAcquired && this.isOpen) {
        window.__openDialogCount = Math.max(0, window.__openDialogCount - 1);
        this.isOpen = false;

        if (window.__openDialogCount === 0) {
          document.documentElement.style.removeProperty("--scrollbar-compensation");
          document.body.classList.remove("modal-open", "slideover-open", "drawer-open");
        } else {
          this.syncBodyOverlayClasses();
        }
      }

      this.isOpening = false;
      throw error;
    }
  }

  close() {
    if (!this.isOpen || this.isClosing) return;

    this.cancelDeferredMotionWork();
    this.isOpening = false; // Cancel any in-flight opening state when closing early.
    this.isClosing = true; // Set closing flag
    this.stopSnapHeightSync();
    this.releaseActivePointerCapture();
    this.clearDraggingCursor();
    this.isDragging = false;
    this.isAllowedToDrag = false;
    this.dragSnapPointTransforms = null;
    this.activePointerId = null;
    this.dialogTarget.setAttribute("closing", "");
    this.dialogTarget.style.transition = this.getTransformTransition(this.drawerCloseDurationMs);
    this.translateY("100%");
    this.setOverlayOpacity(0);

    const closeDuration = this.getDuration(this.drawerCloseDurationMs);
    this.queueFinishClosing(closeDuration);
  }

  finishClosing() {
    if (this.closeTimeout) {
      clearTimeout(this.closeTimeout);
      this.closeTimeout = null;
    }
    this.cancelDeferredMotionWork();
    this.stopSnapHeightSync();
    this.releaseActivePointerCapture();
    this.clearDraggingCursor();
    this.clearPendingFocusTimeout();

    const wasOpen = this.isOpen;
    this.isOpen = false;

    this.dialogTarget.removeAttribute("closing");
    this.dialogTarget.close();
    this.resetClosedVisualState();

    if (wasOpen) {
      window.__openDialogCount = Math.max(0, window.__openDialogCount - 1);
    }
    this.isOpening = false;
    this.isClosing = false; // Reset closing flag

    if (window.__openDialogCount === 0) {
      document.documentElement.style.removeProperty("--scrollbar-compensation");
      document.body.classList.remove("modal-open", "slideover-open", "drawer-open");
    } else {
      this.syncBodyOverlayClasses();
    }

    this.removeEventListeners();

    // Reset to initial snap point for next opening
    this.activeSnapPointValue = 0;

    // Reset drag-related state
    this.isDragging = false;
    this.velocity = 0;
    this.startY = 0;
    this.currentY = 0;
    this.lastY = 0;
    this.initialTransform = 0;
    this.activePointerId = null;
    this.isAllowedToDrag = false;

    // For template-based lazy drawers, restore loading state before the next open.
    if (this.lazyLoadValue && this.hasTemplateTarget) {
      this.contentLoaded = false;
      const container = this.dialogTarget.querySelector("[data-drawer-content]");
      if (container) {
        container.innerHTML = `
          <div class="px-6 pb-6 pt-4 text-center">
            <div class="inline-block size-6 animate-spin rounded-full border-[3px] border-current border-t-transparent text-neutral-600 dark:text-neutral-400" role="status">
              <span class="sr-only">Loading...</span>
            </div>
            <p class="mt-2 text-sm text-neutral-500 dark:text-neutral-400">Loading content...</p>
          </div>
        `;
      }
    }
  }

  applySnapPointState(index, snapPoint = this.snapPointsValue[index]) {
    if (!snapPoint) return;

    this.activeSnapPointValue = index;

    // New logic for revealing content based on snap points
    if (this.hasSnapContentTarget) {
      this.snapContentTargets.forEach((content) => {
        // Default to 0 if the attribute is missing
        const showFromIndex = parseInt(content.dataset.showFromSnapPoint, 10);
        const effectiveShowFromIndex = isNaN(showFromIndex) ? 0 : showFromIndex;

        if (index >= effectiveShowFromIndex) {
          content.classList.remove("hidden");
        } else {
          content.classList.add("hidden");
        }
      });
    }

    // Update snap indicator if present
    if (this.hasSnapIndicatorTarget) {
      this.snapIndicatorTarget.textContent =
        snapPoint === "auto" ? `${Math.min(this.dialogTarget.scrollHeight, window.innerHeight * 0.8)}px` : snapPoint;
    }

    // Handle overlay fade effect
    this.setOverlayOpacity(this.computeOverlayOpacity(index));
  }

  snapToPoint(index, options = {}) {
    const {
      animate = true,
      duration = DRAWER_SNAP_DURATION_MS,
      primeHeightBeforeSync = true,
      syncHeightDuringTransition = true,
    } = options;
    const snapPoint = this.snapPointsValue[index];
    if (!snapPoint) return;
    this.stopSnapHeightSync();

    this.applySnapPointState(index, snapPoint);

    // Store whether we should animate
    const shouldAnimate = animate && !this.isDragging;
    const transitionDuration = shouldAnimate ? this.getDuration(duration) : 0;
    const hasTransformTransition = transitionDuration > 0;

    // Calculate transform based on snap point
    let translateY = 0;
    if (snapPoint === "auto") {
      // For "auto", calculate the actual content height
      translateY = this.calculateAutoTranslateY();
    } else if (snapPoint.endsWith("px")) {
      translateY = `calc(100% - ${snapPoint})`;
    } else if (snapPoint.endsWith("%")) {
      // Use window.innerHeight for percentage-based snap points to account for mobile browser UI
      const percentage = parseInt(snapPoint) / 100;
      const pixelHeight = window.innerHeight * percentage;
      translateY = `calc(100% - ${pixelHeight}px)`;
    }

    // Apply transform with or without animation
    if (hasTransformTransition) {
      this.dialogTarget.style.transition = this.getTransformTransition(duration);
    } else {
      this.dialogTarget.style.transition = "none";
    }
    this.translateY(translateY);

    if (hasTransformTransition) {
      if (!syncHeightDuringTransition) return;

      // Prime layout before snap transitions to avoid content jumps on drag release.
      if (primeHeightBeforeSync) {
        this.updateScrollableHeight();
      }

      // Keep layout updates in lockstep with transform animation.
      this.syncScrollableHeightDuringSnap(transitionDuration);
    } else {
      this.updateScrollableHeight();
    }
  }

  // Touch and mouse event handlers
  addEventListeners() {
    this.dialogTarget.addEventListener("pointerdown", this.boundHandleStart);
    this.dialogTarget.addEventListener("pointermove", this.boundHandleMove);
    this.dialogTarget.addEventListener("pointerup", this.boundHandleEnd);
    this.dialogTarget.addEventListener("pointercancel", this.boundHandleCancel);
  }

  removeEventListeners() {
    this.dialogTarget.removeEventListener("pointerdown", this.boundHandleStart);
    this.dialogTarget.removeEventListener("pointermove", this.boundHandleMove);
    this.dialogTarget.removeEventListener("pointerup", this.boundHandleEnd);
    this.dialogTarget.removeEventListener("pointercancel", this.boundHandleCancel);
  }

  handleStart(event) {
    if (event.button !== undefined && event.button !== 0) return;
    // Ignore secondary touches while one drag interaction is active.
    if (this.isDragging) return;

    // Only start dragging from handle or if no handle exists
    const target = event.target;
    if (target === this.dialogTarget) return;
    const isHandle = this.hasHandleTarget && target instanceof Node && this.handleTarget.contains(target);
    const hasNoHandle = !this.hasHandleTarget;

    if (!isHandle && !hasNoHandle) return;
    if (!isHandle && !this.shouldDrag(target, false)) return;

    this.stopSnapHeightSync();
    this.isDragging = true;
    this.isAllowedToDrag = Boolean(isHandle);
    this.activePointerId = event.pointerId;
    this.dialogTarget.style.transition = "none";

    const clientY = event.clientY;
    this.startY = clientY;
    this.currentY = clientY;
    this.lastY = clientY;
    this.lastTime = Date.now();

    // Reset velocity at the start of each drag
    this.velocity = 0;

    // Store the initial transform
    this.initialTransform = this.getCurrentTransformY();
    this.captureDragSnapPointTransforms();
    this.captureActivePointer(event.pointerId);
    this.applyDraggingCursor(event.pointerType);

    if (event.pointerType === "touch") {
      event.preventDefault();
    }
  }

  handleMove(event) {
    if (!this.isDragging) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;

    // If mouse/pen button is no longer pressed, force-end drag.
    // This handles cases where pointerup happens outside the browser window/chrome.
    if ((event.pointerType === "mouse" || event.pointerType === "pen") && (event.buttons & 1) === 0) {
      this.cancelActiveDrag();
      return;
    }

    const clientY = event.clientY;
    const deltaY = clientY - this.startY;
    const isDraggingDown = deltaY > 0;

    if (!this.isAllowedToDrag && !this.shouldDrag(event.target, isDraggingDown)) return;
    this.isAllowedToDrag = true;

    this.currentY = clientY;

    // Calculate velocity
    const currentTime = Date.now();
    const timeDelta = currentTime - this.lastTime;
    this.velocity = timeDelta > 0 ? (clientY - this.lastY) / timeDelta : 0;

    this.lastY = clientY;
    this.lastTime = currentTime;

    const proposedTransform = this.initialTransform + deltaY;
    if (this.trySnapToAdjacentPointDuringDrag(clientY, proposedTransform, deltaY)) {
      if (event.pointerType === "touch") {
        event.preventDefault();
      }
      return;
    }

    // Provide live movement across snap points.
    // Apply rubber-banding only at global extremes to avoid a jump when crossing each snap boundary.
    const maxSnapIndex = this.getMaxSnapIndex();
    const minTransform = this.getSnapPointTransformY(maxSnapIndex) ?? this.initialTransform;
    const maxTransform = this.getSnapPointTransformY(0) ?? this.initialTransform;
    const isOverdraggingUp = proposedTransform < minTransform;
    const isOverdraggingDown =
      proposedTransform > maxTransform && !(this.activeSnapPointValue === 0 && this.dismissibleValue);

    let newTransform = proposedTransform;
    if (isOverdraggingUp) {
      const overdrag = minTransform - proposedTransform;
      newTransform = minTransform - this.dampenDistance(overdrag);
    } else if (proposedTransform > maxTransform) {
      if (this.activeSnapPointValue === 0 && this.dismissibleValue) {
        // Keep close drag direct at the first snap point for predictable dismiss gestures.
        newTransform = proposedTransform;
      } else {
        const overdrag = proposedTransform - maxTransform;
        newTransform = maxTransform + this.dampenDistance(overdrag);
      }
    }
    // Batch drag-related layout reads/writes to animation frames for smoother motion.
    this.scheduleDragVisualUpdate(newTransform);

    if (event.pointerType === "touch") {
      event.preventDefault();
    }
  }

  handleEnd(event) {
    if (!this.isDragging) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;

    if (this.dragFrame !== null) {
      cancelAnimationFrame(this.dragFrame);
      this.dragFrame = null;
    }
    this.flushPendingDragVisualUpdate();

    this.releaseActivePointerCapture();
    this.clearDraggingCursor();

    this.isDragging = false;
    this.isAllowedToDrag = false;
    this.activePointerId = null;
    this.dragSnapPointTransforms = null;

    const deltaY = this.currentY - this.startY;
    const drawerHeight = this.dialogTarget.offsetHeight;
    const threshold = drawerHeight * this.closeThresholdValue;
    const absVelocity = Math.abs(this.velocity);
    const maxSnapIndex = this.getMaxSnapIndex();
    const canMoveUp = this.activeSnapPointValue < maxSnapIndex;
    const canMoveDown = this.activeSnapPointValue > 0;

    // Upward swipe: move to a larger snap point and optionally skip points based on velocity.
    if (deltaY < -30 || this.velocity < -this.velocityThresholdValue) {
      if (canMoveUp) {
        const maxStep = maxSnapIndex - this.activeSnapPointValue;
        const step = Math.min(this.getSnapStepFromVelocity(absVelocity), maxStep);
        this.snapToPoint(this.activeSnapPointValue + step);
      } else {
        this.snapToPoint(this.activeSnapPointValue);
      }
      return;
    }

    // Downward swipe: move to a smaller snap point, skip points with velocity, or close.
    if (deltaY > 30 || this.velocity > this.velocityThresholdValue) {
      if (canMoveDown) {
        const maxStep = this.activeSnapPointValue;
        const step = Math.min(this.getSnapStepFromVelocity(absVelocity), maxStep);
        const nextIndex = this.activeSnapPointValue - step;
        const shouldCloseFromFirstSnap =
          nextIndex === 0 && (deltaY > threshold || this.velocity > this.velocityThresholdValue * 1.35);

        if (shouldCloseFromFirstSnap) {
          if (this.dismissibleValue) {
            this.close();
          } else {
            this.bounce();
            this.snapToPoint(this.activeSnapPointValue);
          }
        } else {
          this.snapToPoint(nextIndex);
        }
      } else if (deltaY > threshold || this.velocity > this.velocityThresholdValue) {
        if (this.dismissibleValue) {
          this.close();
        } else {
          this.bounce();
          this.snapToPoint(this.activeSnapPointValue);
        }
      } else {
        this.snapToPoint(this.activeSnapPointValue);
      }
      return;
    }

    // No decisive swipe: snap back to current point.
    this.snapToPoint(this.activeSnapPointValue);
  }

  handleCancel(event) {
    if (!this.isDragging) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;
    this.cancelActiveDrag();
  }

  cancelActiveDrag() {
    if (!this.isDragging) return;

    if (this.dragFrame !== null) {
      cancelAnimationFrame(this.dragFrame);
      this.dragFrame = null;
    }
    this.flushPendingDragVisualUpdate();

    this.releaseActivePointerCapture();
    this.clearDraggingCursor();

    this.isDragging = false;
    this.isAllowedToDrag = false;
    this.activePointerId = null;
    this.dragSnapPointTransforms = null;
    this.snapToPoint(this.activeSnapPointValue);
  }

  handleWindowBlur() {
    this.cancelActiveDrag();
  }

  getCurrentTransformY() {
    const transform = window.getComputedStyle(this.dialogTarget).transform;
    if (transform === "none") {
      // If no transform matrix, calculate from the current position
      const rect = this.dialogTarget.getBoundingClientRect();
      const windowHeight = window.innerHeight;
      return rect.top - (windowHeight - this.dialogTarget.offsetHeight);
    }

    const matrix3d = transform.match(/matrix3d\((.+)\)/);
    if (matrix3d) {
      const values = matrix3d[1].split(/,\s*/);
      return parseFloat(values[13]);
    }

    const matrix2d = transform.match(/matrix\((.+)\)/);
    if (matrix2d) {
      const values = matrix2d[1].split(/,\s*/);
      return parseFloat(values[5]);
    }
    return 0;
  }

  applyDraggingCursor(pointerType) {
    if (pointerType === "touch") return;
    this.dialogTarget.style.cursor = "grabbing";
    if (this.hasHandleTarget) {
      this.handleTarget.style.cursor = "grabbing";
    }
    this.previousBodyCursor = document.body.style.cursor || "";
    document.body.style.cursor = "grabbing";
  }

  clearDraggingCursor() {
    this.dialogTarget.style.removeProperty("cursor");
    if (this.hasHandleTarget) {
      this.handleTarget.style.removeProperty("cursor");
    }

    if (this.previousBodyCursor === null) return;
    if (this.previousBodyCursor.length > 0) {
      document.body.style.cursor = this.previousBodyCursor;
    } else {
      document.body.style.removeProperty("cursor");
    }
    this.previousBodyCursor = null;
  }

  captureActivePointer(pointerId) {
    const captureElement = this.hasHandleTarget ? this.handleTarget : this.dialogTarget;
    if (!captureElement?.setPointerCapture) return;

    try {
      captureElement.setPointerCapture(pointerId);
      this.pointerCaptureElement = captureElement;
    } catch (_error) {
      this.pointerCaptureElement = null;
    }
  }

  releaseActivePointerCapture() {
    if (this.activePointerId === null) {
      this.pointerCaptureElement = null;
      return;
    }

    if (this.pointerCaptureElement?.releasePointerCapture) {
      try {
        this.pointerCaptureElement.releasePointerCapture(this.activePointerId);
      } catch (_error) {
        // Ignore release errors on unsupported/browser edge cases.
      }
    }

    this.pointerCaptureElement = null;
  }

  backdropClose(event) {
    // Only close if clicking on the actual backdrop area (outside the dialog's content box)
    if (event.target.nodeName === "DIALOG") {
      // Get the dialog's bounding rect to check if click is outside content area
      const rect = this.dialogTarget.getBoundingClientRect();
      // Click is on backdrop if it's outside the dialog's content box
      // This prevents scrollbar clicks from being treated as backdrop clicks
      const isBackdropClick =
        event.clientX < rect.left ||
        event.clientX > rect.right ||
        event.clientY < rect.top ||
        event.clientY > rect.bottom;

      if (isBackdropClick) {
        event.stopPropagation();
        // Only close if dismissible
        if (this.dismissibleValue) {
          this.close();
        } else {
          // Show bounce animation when trying to dismiss
          this.bounce();
        }
      }
    }
  }

  show(event) {
    this.open(event);
  }

  hide(event) {
    if (event) event.preventDefault();
    this.close();
  }

  beforeCache() {
    // Close immediately without animation during navigation
    if (this.isOpen) {
      this.finishClosing();
    }
  }

  getScrollbarWidth() {
    const outer = document.createElement("div");
    outer.style.visibility = "hidden";
    outer.style.overflow = "scroll";
    outer.style.msOverflowStyle = "scrollbar";
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

  handleDialogClose() {
    this.cancelDeferredMotionWork();

    if (this.isOpen) {
      window.__openDialogCount = Math.max(0, window.__openDialogCount - 1);
      this.isOpen = false;

      if (window.__openDialogCount === 0) {
        document.documentElement.style.removeProperty("--scrollbar-compensation");
        document.body.classList.remove("modal-open", "slideover-open", "drawer-open");
      } else {
        this.syncBodyOverlayClasses();
      }
    }

    this.isOpening = false;
    this.isClosing = false;
    this.dialogTarget.removeAttribute("closing");
    this.resetClosedVisualState();
  }

  syncBodyOverlayClasses() {
    const hasOpenModalDialog = document.querySelector('dialog[open][data-modal-target="dialog"]');
    const hasOpenModalDiv = document.querySelector('[data-modal-target="dialog"].modal-open');
    const hasOpenSlideover = document.querySelector('dialog[open][data-slideover-target="dialog"]');
    const hasOpenDrawer = document.querySelector('dialog[open][data-drawer-target="dialog"]');

    document.body.classList.toggle("modal-open", Boolean(hasOpenModalDialog || hasOpenModalDiv));
    document.body.classList.toggle("slideover-open", Boolean(hasOpenSlideover));
    document.body.classList.toggle("drawer-open", Boolean(hasOpenDrawer));
  }

  // Handle keydown events
  handleKeydown(event) {
    if (event.key === "Escape" && !this.dismissibleValue) {
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

  // Handle escape key press (cancel event)
  handleEscape(event) {
    if (!this.dismissibleValue) {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      this.bounce();
      return false;
    }

    // Only close if dismissible
    event.preventDefault();
    this.close();
  }

  // Add bounce animation to indicate drawer won't close
  bounce() {
    // Prevent multiple bounces in quick succession
    if (this.isBouncing) return;

    this.isBouncing = true;

    // Save the current transform
    const currentTransform = this.dialogTarget.style.transform;

    // Calculate bounce distance (smaller bounce for drawers)
    const currentY = this.getCurrentTransformY();
    const bounceDistance = -20; // pixels

    // Apply quick bounce animation
    this.dialogTarget.style.transition = this.getTransformTransition(DRAWER_BOUNCE_IN_DURATION_MS);
    this.translateY(currentY + bounceDistance);

    setTimeout(() => {
      // Bounce back
      this.dialogTarget.style.transition = this.getTransformTransition(DRAWER_BOUNCE_OUT_DURATION_MS);
      this.dialogTarget.style.transform = currentTransform;

      setTimeout(() => {
        // Reset bouncing flag after animation completes
        this.isBouncing = false;
      }, this.getDuration(DRAWER_BOUNCE_OUT_DURATION_MS));
    }, this.getDuration(DRAWER_BOUNCE_IN_DURATION_MS));
  }

  // Handle window resize
  handleResize() {
    if (!this.isOpen || this.isOpening) return; // Ignore resizes during opening animation

    // For any snap point, recalculate on resize
    // Use debouncing to avoid too many recalculations
    clearTimeout(this.resizeTimeout);
    this.resizeTimeout = setTimeout(() => {
      this.resizeTimeout = null;
      if (!this.isOpen || this.isClosing) return;

      // Store current transition
      const currentTransition = this.dialogTarget.style.transition;

      // Disable transition for immediate repositioning
      this.dialogTarget.style.transition = "none";

      // Recalculate position
      this.snapToPoint(this.activeSnapPointValue);

      // Re-enable transition after a frame
      requestAnimationFrame(() => {
        if (!this.isOpen || this.isClosing) return;
        this.dialogTarget.style.transition = currentTransition || this.getTransformTransition(DRAWER_SNAP_DURATION_MS);
      });
    }, 150);
  }

  getVisibleDrawerHeight(transformY = null) {
    const resolvedTransformY = Number.isFinite(transformY) ? transformY : this.getCurrentTransformY();
    if (Number.isFinite(resolvedTransformY)) {
      return this.clamp(window.innerHeight - resolvedTransformY, 0, window.innerHeight);
    }

    const rect = this.dialogTarget.getBoundingClientRect();
    const top = Math.max(rect.top, 0);
    const bottom = Math.min(rect.bottom, window.innerHeight);
    return Math.max(0, bottom - top);
  }

  getSnapPointHeight(index = this.activeSnapPointValue) {
    const snapPoint = this.snapPointsValue[index];
    if (!snapPoint) return null;

    if (snapPoint === "auto") {
      return this.measureAutoContentHeight();
    }

    if (snapPoint.endsWith("px")) {
      const parsedHeight = parseFloat(snapPoint);
      return Number.isFinite(parsedHeight) ? parsedHeight : null;
    }

    if (snapPoint.endsWith("%")) {
      const parsedPercent = parseFloat(snapPoint);
      if (!Number.isFinite(parsedPercent)) return null;
      return window.innerHeight * (parsedPercent / 100);
    }

    return null;
  }

  getContentWrapper() {
    if (this.contentWrapper?.isConnected) return this.contentWrapper;

    this.contentWrapper = this.dialogTarget.querySelector(":scope > div");
    this.lastContentWrapperHeight = null;
    return this.contentWrapper;
  }

  setContentWrapperHeight(heightPx) {
    const contentWrapper = this.getContentWrapper();
    if (!contentWrapper || !Number.isFinite(heightPx)) return;

    const clampedHeight = this.clamp(heightPx, 0, window.innerHeight);
    const heightValue = `${clampedHeight.toFixed(2)}px`;
    if (this.lastContentWrapperHeight === heightValue) return;

    this.lastContentWrapperHeight = heightValue;

    contentWrapper.style.height = heightValue;
    if (contentWrapper.style.maxHeight !== heightValue) {
      contentWrapper.style.maxHeight = heightValue;
    }
    if (contentWrapper.style.minHeight !== "0px") {
      contentWrapper.style.minHeight = "0px";
    }
  }

  primeContentHeightForSnapPoint(index = this.activeSnapPointValue) {
    const snapHeight = this.getSnapPointHeight(index);
    if (!Number.isFinite(snapHeight)) return;
    this.setContentWrapperHeight(snapHeight);
  }

  measureAutoContentHeight() {
    const contentWrapper = this.getContentWrapper();
    if (!contentWrapper) return window.innerHeight * 0.8;

    const originalMaxHeight = contentWrapper.style.maxHeight;
    const originalHeight = contentWrapper.style.height;
    const originalMinHeight = contentWrapper.style.minHeight;
    contentWrapper.style.maxHeight = "none";
    contentWrapper.style.height = "auto";
    contentWrapper.style.minHeight = "0px";
    contentWrapper.offsetHeight;
    const naturalHeight = contentWrapper.scrollHeight;
    contentWrapper.style.maxHeight = originalMaxHeight;
    contentWrapper.style.height = originalHeight;
    contentWrapper.style.minHeight = originalMinHeight;

    return Math.min(naturalHeight, window.innerHeight * 0.8);
  }

  // Keep scrollable area tied to the drawer's actual visible height.
  updateScrollableHeight(visibleDrawerHeight = null) {
    const nextVisibleHeight = Number.isFinite(visibleDrawerHeight)
      ? visibleDrawerHeight
      : this.getVisibleDrawerHeight();
    this.setContentWrapperHeight(nextVisibleHeight);
  }

  // New method to calculate auto height translateY
  calculateAutoTranslateY() {
    const effectiveHeight = this.measureAutoContentHeight();
    return `calc(100% - ${effectiveHeight}px)`;
  }

  // New method to update height when content changes
  updateAutoHeight() {
    if (!this.isOpen || this.isDragging || this.isClosing) return;

    const currentSnapPoint = this.snapPointsValue[this.activeSnapPointValue];
    if (currentSnapPoint !== "auto") return;

    // Wait for any animations to complete
    if (this.autoHeightFrame !== null) {
      cancelAnimationFrame(this.autoHeightFrame);
    }

    this.autoHeightFrame = requestAnimationFrame(() => {
      this.autoHeightFrame = null;
      if (!this.isOpen || this.isDragging || this.isClosing) return;

      // Calculate new height
      const newTranslateY = this.calculateAutoTranslateY();

      // Apply transform with smooth transition
      this.dialogTarget.style.transition = this.getTransformTransition(DRAWER_SNAP_DURATION_MS);
      this.translateY(newTranslateY);

      // Update scrollable height
      this.updateScrollableHeight();
    });
  }

  async #loadTemplateContent() {
    // Find the container in the dialog to append content to
    const container = this.dialogTarget.querySelector("[data-drawer-content]") || this.dialogTarget;

    // Check if we should use Turbo Frame lazy loading
    if (this.turboFrameSrcValue) {
      // Look for a turbo-frame in the container
      let turboFrame = container.querySelector("turbo-frame");

      if (!turboFrame) {
        // Create a turbo-frame if it doesn't exist
        turboFrame = document.createElement("turbo-frame");
        turboFrame.id = "drawer-lazy-content";

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
      // Use template-based lazy loading
      const templateContent = this.templateTarget.content.cloneNode(true);

      // Clear any loading indicators or placeholder content
      const container = this.dialogTarget.querySelector("[data-drawer-content]") || this.dialogTarget;
      container.innerHTML = "";

      // Append the template content
      container.appendChild(templateContent);
    }
  }

  // Set up focus trapping for the drawer
  setupFocusTrapping() {
    // Get all focusable elements within the drawer
    this.updateFocusableElements();

    this.clearPendingFocusTimeout();

    // Delay focus slightly so the drawer can start animating.
    // Keep focus on the dialog itself to avoid initial control focus on open.
    this.focusTimeout = setTimeout(() => {
      this.focusTimeout = null;
      if (!this.isOpen || this.isClosing) return;
      this.focusDialogContainer();
    }, 100);
  }

  clearPendingFocusTimeout() {
    if (this.focusTimeout) {
      clearTimeout(this.focusTimeout);
      this.focusTimeout = null;
    }
  }

  focusElementWithoutScroll(element) {
    if (!(element instanceof HTMLElement)) return;

    try {
      element.focus({ preventScroll: true });
    } catch (_error) {
      element.focus();
    }
  }

  focusDialogContainer() {
    if (!this.dialogTarget.hasAttribute("tabindex")) {
      this.dialogTarget.setAttribute("tabindex", "-1");
    }
    this.focusElementWithoutScroll(this.dialogTarget);
  }

  // Some browsers move focus to the first focusable control when showModal() runs.
  // Normalize by keeping initial focus on the dialog container.
  normalizeInitialFocus() {
    const focusedElement = this.dialogTarget.querySelector(":focus");
    if (!(focusedElement instanceof HTMLElement)) return;
    if (focusedElement === this.dialogTarget) return;

    focusedElement.blur();
    this.focusDialogContainer();
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

    this.focusableElements = Array.from(this.dialogTarget.querySelectorAll(focusableSelector)).filter((element) => {
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
}
