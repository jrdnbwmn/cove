import { Controller } from "@hotwired/stimulus";
import { computePosition, flip, shift, offset } from "@floating-ui/dom";

const DEBUG_PREDICTION_CONE = false; // Set to true to show the prediction cone
const HOVER_CLOSE_DELAY = 150; // Delay before closing the menu when hovering over a nested dropdown
const NESTED_PREDICTION_CONE_CLOSE_DELAY = 500; // Delay before closing the menu when hovering over a nested dropdown

export default class extends Controller {
  static targets = ["button", "menu", "template"];
  static classes = ["flip"];
  static values = {
    autoClose: { type: Boolean, default: true }, // Whether to close the menu when clicking on an item
    nested: { type: Boolean, default: false }, // Whether the menu is nested
    hover: { type: Boolean, default: false }, // Whether to show the menu on hover
    autoPosition: { type: Boolean, default: true }, // Whether to automatically position the menu
    lazyLoad: { type: Boolean, default: false }, // Whether to lazy load the menu content
    placement: { type: String, default: "bottom-start" }, // The placement(s) of the menu - can be multiple separated by spaces
    dialogMode: { type: Boolean, default: true }, // Whether to use dialog mode
    portal: { type: Boolean, default: true }, // Whether to move top-level menus to the body while open
    turboFrameSrc: { type: String, default: "" }, // URL for Turbo Frame lazy loading
    lockScroll: { type: Boolean, default: false }, // Whether to lock scroll when menu is open
  };

  connect() {
    // Cache the menu before it is portaled outside the controller element.
    this.menuElement = this.menuTarget;
    this.originalParent = this.menuElement.parentNode;
    this.originalNextSibling = this.menuElement.nextSibling;
    this.isPortaled = false;

    // Initialize scroll lock state
    this.isScrollLocked = false;

    // Initialize non-dialog menu if dialogMode is false
    if (!this.dialogModeValue && !this.menuElement.hasAttribute("role")) {
      this.menuElement.setAttribute("role", "menu");
      this.menuElement.setAttribute("aria-modal", "false");
      this.menuElement.setAttribute("tabindex", "-1");
    }

    this.menuItemClickedHandler = () => {
      if (this.autoCloseValue) {
        this.close();
        let parentController = this.#parentDropdownController();
        while (parentController) {
          if (parentController && parentController.autoCloseValue) {
            parentController.close();
          }
          parentController = parentController.#parentDropdownController();
        }
      }
    };
    this.menuElement.addEventListener("menu-item-clicked", this.menuItemClickedHandler);

    this.documentKeydownHandler = (event) => {
      if (event.key === "Escape" && this.isOpen) {
        this.close();
      }
    };
    document.addEventListener("keydown", this.documentKeydownHandler);

    // Portaled menus leave the controller scope, so keep outside-click handling direct.
    this.documentClickHandler = this.closeOnClickOutside.bind(this);
    document.addEventListener("click", this.documentClickHandler);

    this.menuActionHandler = this.#handleMenuAction.bind(this);
    this.menuElement.addEventListener("click", this.menuActionHandler);

    this.buttonTarget.addEventListener("keydown", (event) => {
      if (!this.isOpen) return;

      const menuController = this.application.getControllerForElementAndIdentifier(this.menuElement, "ui-menu");
      if (!menuController) return;

      if (event.key === "ArrowDown") {
        event.preventDefault();
        menuController.selectFirst();
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        menuController.selectLast();
      }
    });

    // Add scroll listener to update position
    this.scrollHandler = () => {
      if (this.isOpen && this.autoPositionValue) {
        this.#updatePosition();
      }
    };
    window.addEventListener("scroll", this.scrollHandler, true);

    // Update position when window is resized or menu content changes
    this.resizeObserver = new ResizeObserver(() => {
      if (this.isOpen) {
        this.#updatePosition();
      }
    });

    // Observe both document.body and the menuTarget element
    this.resizeObserver.observe(document.body);
    this.resizeObserver.observe(this.menuElement);

    // Add MutationObserver to detect content changes inside the menu
    this.mutationObserver = new MutationObserver(() => {
      if (this.isOpen) {
        // Slight delay to allow DOM changes to complete
        setTimeout(() => this.#updatePosition(), 10);
      }
    });

    this.mutationObserver.observe(this.menuElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["style", "class"],
    });

    // Add hover functionality for hover-enabled dropdowns
    if (this.hoverValue) {
      this.isMouseOverDropdown = false;

      this.buttonTarget.addEventListener("mouseenter", (event) => {
        if (this.nestedValue && this.#openSiblingPredictionConeContains(event)) return;

        this.isMouseOverDropdown = true;
        this.predictionConeOrigin = { x: event.clientX, y: event.clientY };
        this.#clearHoverTimers();

        // For nested dropdowns, add a small delay before opening to prevent
        // multiple submenus from opening when quickly moving between triggers
        if (this.nestedValue) {
          this.openTimeout = setTimeout(() => {
            this.show();
          }, 80); // 80ms delay for nested submenus
        } else {
          this.show();
        }
      });

      this.buttonTarget.addEventListener("mousemove", (event) => {
        if (!this.nestedValue || !this.isOpen) return;

        this.predictionConeOrigin = { x: event.clientX, y: event.clientY };
        this.#updatePredictionCone();
      });

      this.buttonTarget.addEventListener("mouseleave", (event) => {
        if (this.#isMovingWithinDropdown(event.relatedTarget)) return;

        this.isMouseOverDropdown = false;
        clearTimeout(this.openTimeout); // Cancel pending open if mouse leaves
        // Check if mouse is not over the menu
        this.hoverTimeout = setTimeout(
          () => {
            if (!this.isMouseOverDropdown && this.isOpen && !this.#hasHoveredDropdownDescendant()) {
              this.close();
            }
          },
          this.nestedValue ? NESTED_PREDICTION_CONE_CLOSE_DELAY : HOVER_CLOSE_DELAY,
        );
      });

      this.menuElement.addEventListener("mouseenter", () => {
        this.isMouseOverDropdown = true;
        clearTimeout(this.hoverTimeout);
      });

      this.menuElement.addEventListener("mouseleave", (event) => {
        if (this.#isMovingWithinDropdown(event.relatedTarget)) return;

        this.isMouseOverDropdown = false;
        this.hoverTimeout = setTimeout(
          () => {
            if (!this.isMouseOverDropdown && this.isOpen && !this.#hasHoveredDropdownDescendant()) {
              this.close();
            }
          },
          this.nestedValue ? NESTED_PREDICTION_CONE_CLOSE_DELAY : HOVER_CLOSE_DELAY,
        );
      });

      this.menuHoverHandler = this.#handleMenuHover.bind(this);
      this.menuElement.addEventListener("mouseover", this.menuHoverHandler);

      // Keep the existing element mouseleave for nested menu handling
      this.element.addEventListener("mouseleave", (event) => {
        const toElement = event.relatedTarget;
        const isMovingToNestedMenu =
          toElement &&
          (toElement.closest('[data-ui-dropdown-popover-target="menu"]') ||
            toElement.closest('[data-ui-dropdown-popover-target="button"]') ||
            // Check if moving to a child menu
            toElement.closest('[data-controller~="ui-dropdown-popover"][data-ui-dropdown-popover-nested-value="true"]'));

        if (!isMovingToNestedMenu) {
          this.hoverTimeout = setTimeout(
            () => {
              if (!this.isMouseOverDropdown && !this.#hasHoveredDropdownDescendant()) {
                this.close();

                // Reset focus state when menu is closed with hover
                if (this.nestedValue) {
                  this.buttonTarget.classList.remove("active-menu-path");
                  this.buttonTarget.removeAttribute("data-state");
                  // Only reset the parent menu if we're not still inside it
                  // (e.g., don't reset when moving from nested dropdown to another item in the same menu)
                  const parentMenu = this.element.closest('[data-controller~="ui-menu"]');
                  if (parentMenu && toElement && !parentMenu.contains(toElement)) {
                    const menuController = this.application.getControllerForElementAndIdentifier(parentMenu, "ui-menu");
                    if (menuController) {
                      menuController.reset();
                    }
                  }
                }
              }
            },
            this.nestedValue ? NESTED_PREDICTION_CONE_CLOSE_DELAY : 100,
          );
        }
      });
    } else {
      // For non-hover dropdowns, close any open hover dropdowns when hovering the button
      this.buttonTarget.addEventListener("mouseenter", () => {
        const allHoverDropdowns = this.application.controllers.filter(
          (c) => c.identifier === "ui-dropdown-popover" && c !== this && c.isOpen && c.hoverValue,
        );

        allHoverDropdowns.forEach((controller) => {
          controller.close();
        });
      });
    }

    this.#setupTouchPrelock();
  }

  disconnect() {
    clearTimeout(this.closeTimeout);

    // Make sure to unlock scroll when controller disconnects
    if (this.isScrollLocked) {
      this.unlockScroll();
    }

    if (this.menuItemClickedHandler) {
      this.menuElement.removeEventListener("menu-item-clicked", this.menuItemClickedHandler);
    }
    if (this.documentKeydownHandler) {
      document.removeEventListener("keydown", this.documentKeydownHandler);
    }
    if (this.documentClickHandler) {
      document.removeEventListener("click", this.documentClickHandler);
    }
    if (this.menuActionHandler) {
      this.menuElement.removeEventListener("click", this.menuActionHandler);
    }
    if (this.menuHoverHandler) {
      this.menuElement.removeEventListener("mouseover", this.menuHoverHandler);
    }

    this.resizeObserver.disconnect();
    // Disconnect mutation observer
    this.mutationObserver.disconnect();
    // Remove scroll listener
    window.removeEventListener("scroll", this.scrollHandler, true);

    if (this.buttonTouchStartHandler) {
      this.buttonTarget.removeEventListener("touchstart", this.buttonTouchStartHandler);
      this.buttonTouchStartHandler = null;
    }

    if (this.buttonTouchEndHandler) {
      this.buttonTarget.removeEventListener("touchend", this.buttonTouchEndHandler);
      this.buttonTarget.removeEventListener("touchcancel", this.buttonTouchEndHandler);
      this.buttonTouchEndHandler = null;
    }

    this.prelockedFromTouch = false;
    this.#clearHoverTimers();
    this.#removePredictionConeDebug();
    this.#restoreMenuMount();
  }

  get isOpen() {
    if (this.dialogModeValue) {
      return this.menuElement.open;
    } else {
      return this.menuElement.classList.contains("hidden") === false;
    }
  }

  async show() {
    clearTimeout(this.closeTimeout);
    this.closeTimeout = null;

    // Close all other open dropdowns that aren't in the same hierarchy
    const allDropdowns = this.application.controllers.filter(
      (c) => c.identifier === "ui-dropdown-popover" && c !== this && c.isOpen,
    );

    allDropdowns.forEach((controller) => {
      if (!this.#isInSameDropdownHierarchy(controller)) {
        controller.close();
      }
    });

    // Close any sibling nested dropdowns first (immediately, no animation)
    if (this.nestedValue) {
      const parentMenu = this.element.closest('[data-controller~="ui-menu"]');
      if (parentMenu) {
        const siblingDropdowns = parentMenu.querySelectorAll(
          '[data-controller~="ui-dropdown-popover"][data-ui-dropdown-popover-nested-value="true"]',
        );
        siblingDropdowns.forEach((dropdown) => {
          const controller = this.application.getControllerForElementAndIdentifier(dropdown, "ui-dropdown-popover");
          if (controller && controller !== this && controller.isOpen) {
            controller.closeImmediate(); // Close immediately to prevent both being visible
          }
        });
      }
    }

    // If we have lazy loading enabled, load the content now
    if (this.lazyLoadValue && !this.contentLoaded) {
      await this.#loadTemplateContent();
      this.contentLoaded = true;
    }

    // Only top-level dropdowns should lock scroll.
    // Locking on nested submenus can constrain/clamp submenu positioning.
    if (this.lockScrollValue && !this.nestedValue) {
      this.lockScroll();
      this.prelockedFromTouch = false;
    }

    let previousVisibility = "";
    if (this.dialogModeValue) {
      // Keep the menu hidden at a safe position while measuring to avoid Safari scroll jumps.
      previousVisibility = this.menuElement.style.visibility;
      this.menuElement.style.visibility = "hidden";
      this.menuElement.style.left = "0px";
      this.menuElement.style.top = "0px";
      if (!this.menuElement.open) {
        this.menuElement.show();
      }
    } else {
      this.menuElement.classList.remove("hidden");
    }

    this.#preservePortalMenuWidth();
    this.#mountMenuForOpen();

    this.#updateExpanded();
    this.#resetPortaledMenuControllers();
    try {
      await this.#updatePosition();
    } catch (_error) {
      // Fallback near the trigger if Floating UI fails.
      const rect = this.buttonTarget.getBoundingClientRect();
      this.menuElement.style.left = `${rect.left}px`;
      this.menuElement.style.top = `${rect.bottom + 4}px`;
    }

    // Set state attribute for all dropdowns
    this.buttonTarget.setAttribute("data-state", "open");

    // Add active-menu-path class to the button when showing the dropdown
    if (this.nestedValue) {
      this.buttonTarget.classList.add("active-menu-path");
      if (this.hoverValue) {
        this.#updatePredictionCone();
      }
    }

    requestAnimationFrame(() => {
      if (this.dialogModeValue) {
        this.menuElement.style.visibility = previousVisibility;
      }

      // Add appropriate classes based on placement
      if (this.placementValue.startsWith("top")) {
        this.menuElement.classList.add("[&[open]]:scale-100", "[&[open]]:opacity-100", "scale-100", "opacity-100");
      } else {
        this.menuElement.classList.add("[&[open]]:scale-100", "[&[open]]:opacity-100", "scale-100", "opacity-100");
      }

      // Check for autofocus elements inside the menu
      const autofocusElement = this.menuElement.querySelector('[autofocus="true"], [autofocus]');
      if (autofocusElement) {
        // Focus the autofocus element
        setTimeout(() => {
          this.#focusWithoutScroll(autofocusElement);

          // If it's an input or textarea, position cursor at the end
          if (autofocusElement.tagName === "INPUT" || autofocusElement.tagName === "TEXTAREA") {
            const length = autofocusElement.value.length;
            autofocusElement.setSelectionRange(length, length);
          }
        }, 0);
      } else if (this.nestedValue) {
        this.#focusWithoutScroll(this.menuElement);
      } else {
        this.#focusWithoutScroll(this.buttonTarget);
      }
    });
  }

  close() {
    this.#closeInternal(false);
  }

  // Immediate close without animation - used when closing sibling menus
  closeImmediate() {
    this.#closeInternal(true);
  }

  #closeInternal(immediate = false) {
    clearTimeout(this.closeTimeout);
    this.closeTimeout = null;

    // Unlock scroll if it was locked
    if (this.isScrollLocked) {
      this.unlockScroll();
    }

    // Reset focus states in the menu before closing
    const menuController = this.application.getControllerForElementAndIdentifier(this.menuElement, "ui-menu");
    if (menuController) {
      menuController.reset();
    }

    // Close any child dropdowns first
    const childDropdowns = this.menuElement.querySelectorAll('[data-controller~="ui-dropdown-popover"]');
    childDropdowns.forEach((dropdown) => {
      const controller = this.application.getControllerForElementAndIdentifier(dropdown, "ui-dropdown-popover");
      if (controller && controller.isOpen) {
        immediate ? controller.closeImmediate() : controller.close();
      }
    });

    // Remove all active-menu-path classes within this menu
    this.menuElement.querySelectorAll(".active-menu-path").forEach((el) => {
      el.classList.remove("active-menu-path");
    });
    // Also remove from the button that triggered this dropdown and remove state attribute
    this.buttonTarget.classList.remove("active-menu-path");
    this.buttonTarget.removeAttribute("data-state");

    // If this is a hover-enabled dropdown, ensure we blur any focused elements
    if (this.hoverValue) {
      const focusedElement = this.element.querySelector(":focus") || this.menuElement.querySelector(":focus");
      if (focusedElement) {
        focusedElement.blur();
      }
    }

    this.menuElement.classList.remove("scale-100", "opacity-100", "[&[open]]:scale-100", "[&[open]]:opacity-100");
    this.#removePredictionConeDebug();

    const finishClose = () => {
      if (this.dialogModeValue) {
        if (this.menuElement.open) {
          this.menuElement.close();
        }
      } else {
        this.menuElement.classList.add("hidden");
      }
      this.#updateExpanded();
      this.#restoreMenuMount();
      this.#restorePortalMenuWidth();
      this.closeTimeout = null;
    };

    if (immediate) {
      // Close immediately without animation delay
      finishClose();
    } else {
      // Animated close with delay
      this.closeTimeout = setTimeout(finishClose, 100);
    }
  }

  toggle() {
    this.isOpen ? this.close() : this.show();
  }

  closeOnClickOutside({ target }) {
    if (!this.isOpen) return;
    if (!(target instanceof Element)) return;

    const isClickInNestedDropdown = target.closest('[data-ui-dropdown-popover-nested-value="true"]');
    if (isClickInNestedDropdown) return;

    if (!this.element.contains(target) && !this.menuElement.contains(target)) {
      this.close();
    }
  }

  // Prevent close method to stop click propagation
  preventClose(event) {
    // Stop propagation to prevent the closeOnClickOutside handler from being triggered
    event.stopPropagation();
  }

  shouldKeepOpenForPointer(event) {
    if (!this.nestedValue || !this.hoverValue || !this.isOpen || !this.predictionCone) return false;
    if (!Number.isFinite(event.clientX) || !Number.isFinite(event.clientY)) return false;

    return this.#isPointInPredictionCone({ x: event.clientX, y: event.clientY });
  }

  #handleMenuHover(event) {
    if (!(event.target instanceof Element)) return;

    const button = event.target.closest('[data-ui-dropdown-popover-target="button"]');
    if (!button || !this.menuElement.contains(button)) return;
    if (event.relatedTarget instanceof Element && button.contains(event.relatedTarget)) return;

    const dropdownElement = button.closest(
      '[data-controller~="ui-dropdown-popover"][data-ui-dropdown-popover-nested-value="true"]',
    );
    if (!dropdownElement || !this.menuElement.contains(dropdownElement) || dropdownElement === this.element) return;

    const controller = this.application.getControllerForElementAndIdentifier(dropdownElement, "ui-dropdown-popover");
    if (!controller?.hoverValue) return;
    if (controller.#openSiblingPredictionConeContains(event)) return;

    this.isMouseOverDropdown = true;
    this.#clearHoverTimers();
    controller.isMouseOverDropdown = true;
    controller.predictionConeOrigin = { x: event.clientX, y: event.clientY };
    controller.#clearHoverTimers();
    if (controller.isOpen) {
      controller.#updatePredictionCone();
      return;
    }

    controller.show();
  }

  #handleMenuAction(event) {
    if (this.element.contains(this.menuElement)) return;
    if (!(event.target instanceof Element)) return;

    const actionElement = event.target.closest("[data-action]");
    if (!actionElement || !this.menuElement.contains(actionElement)) return;

    const closestDropdown = actionElement.closest('[data-controller~="ui-dropdown-popover"]');
    if (closestDropdown && closestDropdown !== this.element) return;

    const actionNames = this.#localDropdownActionNamesFor(event);
    if (actionNames.length === 0) return;

    actionNames.forEach((actionName) => {
      if (actionName === "preventClose") {
        this.preventClose(event);
        return;
      }

      event.preventDefault();
      this[actionName]();
    });
  }

  #localDropdownActionNamesFor(event) {
    const handledActions = new Set(["close", "show", "toggle", "preventClose"]);
    if (!(event.target instanceof Element)) return [];

    const actionElement = event.target.closest("[data-action]");
    if (!actionElement || !this.menuElement.contains(actionElement)) return [];

    return (actionElement.getAttribute("data-action") || "")
      .split(/\s+/)
      .map((descriptor) => {
        const match = descriptor.match(/^(?:(?:click)(?:\.[^@-]+)?->)?ui-dropdown-popover#([A-Za-z0-9_]+)$/);
        return match?.[1];
      })
      .filter((actionName) => handledActions.has(actionName));
  }

  // Reset method to handle dialog close events
  reset() {
    // This method is called when the dialog is closed
    // It's responsible for any cleanup needed after closing

    // If we have a menu controller, reset its state
    const menuController = this.application.getControllerForElementAndIdentifier(this.menuElement, "ui-menu");
    if (menuController && typeof menuController.reset === "function") {
      menuController.reset();
    }

    // Dispatch a custom event that can be listened for by other controllers
    const resetEvent = new CustomEvent("dropdown-reset", {
      bubbles: true,
      detail: { controller: this },
    });
    this.element.dispatchEvent(resetEvent);
  }

  #updateExpanded() {
    this.buttonTarget.ariaExpanded = this.isOpen;
  }

  #resetPortaledMenuControllers() {
    const searchableController = this.application.getControllerForElementAndIdentifier(
      this.menuElement,
      "searchable-dropdown",
    );
    if (searchableController && typeof searchableController.reset === "function") {
      searchableController.reset();
    }
  }

  #isMovingWithinDropdown(target) {
    if (!(target instanceof Element)) return false;

    return this.element.contains(target) || this.menuElement.contains(target);
  }

  #clearHoverTimers() {
    clearTimeout(this.hoverTimeout);
    clearTimeout(this.openTimeout);
    this.hoverTimeout = null;
    this.openTimeout = null;
  }

  #hasHoveredDropdownDescendant() {
    if (this.element.matches(":hover") || this.menuElement.matches(":hover")) return true;

    return this.application.controllers.some((controller) => {
      if (controller.identifier !== "ui-dropdown-popover" || controller === this || !controller.isOpen) return false;
      if (!this.#containsDropdownController(controller)) return false;

      return controller.element.matches(":hover") || controller.menuElement?.matches(":hover");
    });
  }

  #openSiblingPredictionConeContains(event) {
    const parentMenu = this.element.closest('[data-controller~="ui-menu"]');
    if (!parentMenu) return false;

    return Array.from(
      parentMenu.querySelectorAll('[data-controller~="ui-dropdown-popover"][data-ui-dropdown-popover-nested-value="true"]'),
    ).some((dropdown) => {
      const controller = this.application.getControllerForElementAndIdentifier(dropdown, "ui-dropdown-popover");
      return controller && controller !== this && controller.isOpen && controller.shouldKeepOpenForPointer?.(event);
    });
  }

  #updatePredictionCone() {
    if (!this.nestedValue || !this.hoverValue) return;

    const buttonRect = this.buttonTarget.getBoundingClientRect();
    const menuRect = this.menuElement.getBoundingClientRect();
    if (buttonRect.width === 0 || buttonRect.height === 0 || menuRect.width === 0 || menuRect.height === 0) return;

    const opensRight = menuRect.left >= buttonRect.left;
    const pointerX = this.#clamp(
      this.predictionConeOrigin?.x ?? buttonRect.left + buttonRect.width / 2,
      buttonRect.left,
      buttonRect.right,
    );
    const targetX = opensRight ? menuRect.left : menuRect.right;
    const originY = this.#clamp(
      this.predictionConeOrigin?.y ?? buttonRect.top + buttonRect.height / 2,
      buttonRect.top,
      buttonRect.bottom,
    );
    const padding = 12;

    this.predictionCone = {
      origin: { x: pointerX, y: originY },
      upper: { x: targetX, y: menuRect.top - padding },
      lower: { x: targetX, y: menuRect.bottom + padding },
    };

    this.#renderPredictionConeDebug();
  }

  #isPointInPredictionCone(point) {
    const { origin, upper, lower } = this.predictionCone;
    const area = this.#triangleArea(origin, upper, lower);
    const areaA = this.#triangleArea(point, upper, lower);
    const areaB = this.#triangleArea(origin, point, lower);
    const areaC = this.#triangleArea(origin, upper, point);

    return Math.abs(area - (areaA + areaB + areaC)) < 0.5;
  }

  #triangleArea(a, b, c) {
    return Math.abs((a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)) / 2);
  }

  #clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  #renderPredictionConeDebug() {
    if (!DEBUG_PREDICTION_CONE || !this.predictionCone) return;

    if (!this.predictionConeDebugElement) {
      this.predictionConeDebugElement = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      this.predictionConeDebugElement.setAttribute("data-ui-dropdown-popover-prediction-cone", "");
      Object.assign(this.predictionConeDebugElement.style, {
        position: "fixed",
        inset: "0",
        width: "100vw",
        height: "100vh",
        pointerEvents: "none",
        zIndex: "2147483647",
      });
      document.body.appendChild(this.predictionConeDebugElement);
    }

    const { origin, upper, lower } = this.predictionCone;
    this.predictionConeDebugElement.innerHTML = `
      <polygon
        points="${origin.x},${origin.y} ${upper.x},${upper.y} ${lower.x},${lower.y}"
        fill="rgba(59, 130, 246, 0.12)"
        stroke="rgba(96, 165, 250, 0.95)"
        stroke-width="1.5"
        stroke-dasharray="6 4"
      />
      <circle cx="${origin.x}" cy="${origin.y}" r="3" fill="rgba(96, 165, 250, 1)" />
      <circle cx="${upper.x}" cy="${upper.y}" r="3" fill="rgba(96, 165, 250, 1)" />
      <circle cx="${lower.x}" cy="${lower.y}" r="3" fill="rgba(96, 165, 250, 1)" />
    `;
  }

  #removePredictionConeDebug() {
    this.predictionCone = null;
    this.predictionConeDebugElement?.remove();
    this.predictionConeDebugElement = null;
  }

  #preservePortalMenuWidth() {
    if (!this.portalValue || this.nestedValue || this.menuElement.parentElement !== this.originalParent) return;

    const inlineWidth = this.menuElement.style.width;
    const hasPercentageWidth = inlineWidth.trim().endsWith("%") || this.menuElement.classList.contains("w-full");
    if (!hasPercentageWidth) return;

    const measuredWidth = this.menuElement.getBoundingClientRect().width;
    if (measuredWidth <= 0) return;

    this.previousMenuInlineWidth = inlineWidth;
    this.menuElement.style.width = `${measuredWidth}px`;
  }

  #restorePortalMenuWidth() {
    if (this.previousMenuInlineWidth === undefined) return;

    this.menuElement.style.width = this.previousMenuInlineWidth;
    this.previousMenuInlineWidth = undefined;
  }

  #mountMenuForOpen() {
    if (!this.portalValue || this.nestedValue) return;

    const appendTarget = this.element.closest("dialog[open]") || document.body;
    if (this.menuElement.parentElement !== appendTarget) {
      appendTarget.appendChild(this.menuElement);
    }
    this.isPortaled = this.menuElement.parentElement !== this.originalParent;
  }

  #restoreMenuMount() {
    if (!this.isPortaled || !this.originalParent) return;

    if (this.originalNextSibling && this.originalNextSibling.parentNode === this.originalParent) {
      this.originalParent.insertBefore(this.menuElement, this.originalNextSibling);
    } else {
      this.originalParent.appendChild(this.menuElement);
    }

    this.isPortaled = false;
  }

  #isInSameDropdownHierarchy(controller) {
    return this.#containsDropdownController(controller) || controller.#containsDropdownController(this);
  }

  #containsDropdownController(controller) {
    if (!controller || !controller.element || !controller.menuElement) return false;

    return (
      this.element.contains(controller.element) ||
      this.menuElement.contains(controller.element) ||
      this.element.contains(controller.menuElement) ||
      this.menuElement.contains(controller.menuElement)
    );
  }

  #parentDropdownController() {
    const dropdownControllers = this.application.controllers.filter(
      (controller) => controller.identifier === "ui-dropdown-popover" && controller !== this,
    );
    let current = this.element.parentElement;

    while (current) {
      if (current.matches?.('[data-controller~="ui-dropdown-popover"]')) {
        return this.application.getControllerForElementAndIdentifier(current, "ui-dropdown-popover");
      }

      const menuOwner = dropdownControllers.find((controller) => controller.menuElement === current);
      if (menuOwner) return menuOwner;

      current = current.parentElement;
    }

    return null;
  }

  async #loadTemplateContent() {
    // Find the container in the menu to append content to
    const container = this.menuElement.querySelector("[data-ui-dropdown-popover-content]") || this.menuElement;

    // Check if we should use Turbo Frame lazy loading
    if (this.turboFrameSrcValue) {
      // Look for a turbo-frame in the container
      let turboFrame = container.querySelector("turbo-frame");

      if (!turboFrame) {
        // Create a turbo-frame if it doesn't exist
        turboFrame = document.createElement("turbo-frame");
        turboFrame.id = "dropdown-lazy-content";

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
          this.#refreshMenuController();
          resolve();
        };

        turboFrame.addEventListener("turbo:frame-load", handleLoad);

        // Fallback timeout in case the frame doesn't load
        setTimeout(() => {
          turboFrame.removeEventListener("turbo:frame-load", handleLoad);
          this.#refreshMenuController();
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

      this.#refreshMenuController();
    }
  }

  #refreshMenuController() {
    // Refresh the menu controller to pick up new targets from the loaded content
    setTimeout(() => {
      const menuController = this.application.getControllerForElementAndIdentifier(this.menuElement, "ui-menu");
      if (menuController) {
        // Disconnect and reconnect the menu controller to refresh its targets
        menuController.disconnect();
        menuController.connect();
      }
    }, 10);
  }

  async #updatePosition() {
    // Parse placement value to support multiple placements
    const placements = this.placementValue.split(/[\s,]+/).filter(Boolean);
    const primaryPlacement = placements[0] || "bottom-start";
    const fallbackPlacements = placements.slice(1);

    const middleware = [
      offset(this.nestedValue ? -4 : 4), // 0 offset for nested, 4px for regular
      flip({
        fallbackPlacements: fallbackPlacements.length > 0 ? fallbackPlacements : ["top-start", "bottom-start"],
      }),
      shift({ padding: 8 }), // Keep 8px padding from window edges
    ];

    if (this.nestedValue) {
      // For nested dropdowns, position to the right of the button
      const { x, y } = await computePosition(this.buttonTarget, this.menuElement, {
        placement: "right-start",
        middleware,
      });

      Object.assign(this.menuElement.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    } else {
      // Use the primary placement from the controller
      const { x, y } = await computePosition(this.buttonTarget, this.menuElement, {
        placement: primaryPlacement,
        middleware: this.autoPositionValue ? middleware : [offset(this.nestedValue ? -4 : 4)],
      });

      Object.assign(this.menuElement.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    }
  }

  #focusWithoutScroll(element) {
    if (!element || typeof element.focus !== "function") return;

    try {
      element.focus({ preventScroll: true });
    } catch (_error) {
      element.focus();
    }
  }

  #setupTouchPrelock() {
    if (!this.lockScrollValue || this.hoverValue || this.nestedValue || !this.hasButtonTarget) return;

    this.buttonTouchStartHandler = (event) => {
      if (this.isOpen || this.isScrollLocked) return;

      const target = event.target;
      if (!(target instanceof Element)) return;
      if (target.closest("a, input, textarea, select")) return;

      this.lockScroll();
      this.prelockedFromTouch = true;
    };

    this.buttonTouchEndHandler = () => {
      if (!this.prelockedFromTouch) return;

      // If touch interaction did not open the dropdown, revert the pre-lock.
      setTimeout(() => {
        if (!this.prelockedFromTouch || this.isOpen) return;
        if (this.isScrollLocked) {
          this.unlockScroll();
        }
        this.prelockedFromTouch = false;
      }, 0);
    };

    this.buttonTarget.addEventListener("touchstart", this.buttonTouchStartHandler, { passive: true });
    this.buttonTarget.addEventListener("touchend", this.buttonTouchEndHandler);
    this.buttonTarget.addEventListener("touchcancel", this.buttonTouchEndHandler);
  }

  // Add scroll locking methods
  lockScroll() {
    if (this.isScrollLocked) return;

    this.scrollLockTarget = this.#getScrollLockTarget();

    if (this.scrollLockTarget !== document.body) {
      this.previousTargetOverflow = this.scrollLockTarget.style.overflow;
      this.previousTargetPaddingRight = this.scrollLockTarget.style.paddingRight;
      this.previousTargetOverscrollBehavior = this.scrollLockTarget.style.overscrollBehavior;

      const targetStyles = window.getComputedStyle(this.scrollLockTarget);
      const borderLeft = parseFloat(targetStyles.borderLeftWidth) || 0;
      const borderRight = parseFloat(targetStyles.borderRightWidth) || 0;
      const rawDelta = this.scrollLockTarget.offsetWidth - this.scrollLockTarget.clientWidth;
      const scrollbarWidth = Math.max(0, rawDelta - borderLeft - borderRight);
      if (scrollbarWidth > 0) {
        const computedPaddingRight = parseFloat(targetStyles.paddingRight) || 0;
        this.scrollLockTarget.style.paddingRight = `${computedPaddingRight + scrollbarWidth}px`;
      }

      this.scrollLockTarget.style.overflow = "hidden";
      this.scrollLockTarget.style.overscrollBehavior = "contain";
      this.isScrollLocked = true;
      return;
    }

    this.#lockBodyScrollWithCompensation();

    this.isScrollLocked = true;
  }

  unlockScroll() {
    if (!this.isScrollLocked) return;

    if (this.scrollLockTarget && this.scrollLockTarget !== document.body) {
      this.scrollLockTarget.style.overflow = this.previousTargetOverflow || "";
      this.scrollLockTarget.style.paddingRight = this.previousTargetPaddingRight || "";
      this.scrollLockTarget.style.overscrollBehavior = this.previousTargetOverscrollBehavior || "";
      this.scrollLockTarget = null;
      this.isScrollLocked = false;
      return;
    }

    this.#unlockBodyScrollWithCompensation();

    this.isScrollLocked = false;
    this.scrollLockTarget = null;
  }

  #getScrollLockTarget() {
    const parentOverlay = this.element.closest(
      'dialog[open][data-modal-target="dialog"], dialog[open][data-slideover-target="dialog"], dialog[open][data-drawer-target="dialog"], dialog[open], .modal-div.modal-open',
    );

    if (parentOverlay instanceof HTMLElement) {
      const nearestScrollableWithinOverlay = this.#findNearestScrollableAncestor(this.buttonTarget, parentOverlay);
      return nearestScrollableWithinOverlay || parentOverlay;
    }

    return document.body;
  }

  #findNearestScrollableAncestor(fromElement, boundaryElement) {
    let current = fromElement?.parentElement;

    while (current && current !== boundaryElement) {
      const style = window.getComputedStyle(current);
      const overflowY = style.overflowY;
      const isScrollable =
        (overflowY === "auto" || overflowY === "scroll") && current.scrollHeight > current.clientHeight;

      if (isScrollable) return current;
      current = current.parentElement;
    }

    if (boundaryElement instanceof HTMLElement) {
      const style = window.getComputedStyle(boundaryElement);
      const overflowY = style.overflowY;
      const isScrollable =
        (overflowY === "auto" || overflowY === "scroll") && boundaryElement.scrollHeight > boundaryElement.clientHeight;
      if (isScrollable) return boundaryElement;
    }

    return null;
  }

  #lockBodyScrollWithCompensation() {
    if (this.hasRegisteredBodyLock) return;

    const state = this.#getBodyLockState();
    if (state.count === 0) {
      const scrollbarWidth = this.#measureScrollbarWidth();
      state.previousBodyOverflow = document.body.style.overflow;
      state.previousBodyPaddingRight = document.body.style.paddingRight;

      if (scrollbarWidth > 0) {
        const bodyStyles = window.getComputedStyle(document.body);
        const computedBodyPaddingRight = parseFloat(bodyStyles.paddingRight) || 0;
        document.body.style.paddingRight = `${computedBodyPaddingRight + scrollbarWidth}px`;
      }

      document.body.style.overflow = "hidden";

      state.compensatedFixedElements = [];
      if (scrollbarWidth > 0) {
        document.querySelectorAll(".fixed").forEach((element) => {
          if (!(element instanceof HTMLElement) || this.#shouldSkipFixedCompensation(element)) return;

          state.compensatedFixedElements.push({
            element,
            previousPaddingRight: element.style.paddingRight,
          });

          const fixedStyles = window.getComputedStyle(element);
          const computedFixedPaddingRight = parseFloat(fixedStyles.paddingRight) || 0;
          element.style.paddingRight = `${computedFixedPaddingRight + scrollbarWidth}px`;
        });
      }
    }

    state.count += 1;
    this.hasRegisteredBodyLock = true;
  }

  #unlockBodyScrollWithCompensation() {
    if (!this.hasRegisteredBodyLock) return;

    const state = this.#getBodyLockState();
    state.count = Math.max(0, state.count - 1);

    if (state.count === 0) {
      document.body.style.overflow = state.previousBodyOverflow || "";
      document.body.style.paddingRight = state.previousBodyPaddingRight || "";
      state.previousBodyOverflow = "";
      state.previousBodyPaddingRight = "";

      state.compensatedFixedElements.forEach(({ element, previousPaddingRight }) => {
        if (!(element instanceof HTMLElement)) return;
        element.style.paddingRight = previousPaddingRight || "";
      });
      state.compensatedFixedElements = [];
    }

    this.hasRegisteredBodyLock = false;
  }

  #measureScrollbarWidth() {
    const outer = document.createElement("div");
    outer.style.visibility = "hidden";
    outer.style.overflow = "scroll";
    outer.style.msOverflowStyle = "scrollbar";
    document.body.appendChild(outer);

    const inner = document.createElement("div");
    outer.appendChild(inner);

    const scrollbarWidth = Math.max(0, outer.offsetWidth - inner.offsetWidth);
    outer.parentNode?.removeChild(outer);

    return scrollbarWidth;
  }

  #getBodyLockState() {
    if (!window.__floatingBodyScrollLockState) {
      window.__floatingBodyScrollLockState = {
        count: 0,
        previousBodyOverflow: "",
        previousBodyPaddingRight: "",
        compensatedFixedElements: [],
      };
    }

    return window.__floatingBodyScrollLockState;
  }

  #shouldSkipFixedCompensation(element) {
    return Boolean(
      element.closest(
        'dialog[data-context-menu-target="menu"], [data-slideover-target="dialog"], [data-drawer-target="dialog"]',
      ),
    );
  }
}
