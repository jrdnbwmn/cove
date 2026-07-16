import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item"]; // Targets for the menu items
  static values = { index: Number }; // Index of the current item

  connect() {
    this.indexValue = -1;
    this.searchString = "";
    this.keyboardNavigation = false; // Track keyboard navigation state
    this.#updateTabstops();

    if (!this.documentKeydownHandler) {
      this.documentKeydownHandler = (event) => {
        if (document.activeElement.tagName === "INPUT") return;

        this.keyboardNavigation = true;

        if (this.element.open && event.key.length === 1 && /\S/.test(event.key)) {
          event.preventDefault();
          event.stopPropagation();
          this.#handleTextSearch(event.key.toLowerCase());
        }
      };
      document.addEventListener("keydown", this.documentKeydownHandler);
    }

    this.itemTargets.forEach((item) => {
      if (item.dataset.menuControllerListenersAttached === "true") return;
      item.dataset.menuControllerListenersAttached = "true";

      item.addEventListener("click", (event) => {
        if (this.keyboardInputActivation) return;

        // Ensure the item maintains focus when clicked
        this.#focusWithoutScroll(item);

        // Update the index to match the clicked item
        this.indexValue = this.itemTargets.indexOf(item);
        this.#updateTabstops();

        // If clicking on a label with checkbox/radio, prevent the input from stealing focus
        const input = item.querySelector('input[type="checkbox"], input[type="radio"]');
        if (input && event.target !== input) {
          // Allow the click to propagate to toggle the checkbox, but maintain focus on the label
          setTimeout(() => {
            this.#focusWithoutScroll(item);
          }, 0);
        }

        if (!this.#isNestedDropdownButton(item)) {
          if (this.#shouldAutoClose()) {
            this.element.dispatchEvent(new Event("menu-item-clicked", { bubbles: true }));
          }
        }
      });

      item.addEventListener("mousemove", (event) => {
        // Ignore mousemove events fired when content scrolls under a stationary cursor.
        if (event.movementX === 0 && event.movementY === 0) return;
        this.keyboardNavigation = false;
      });

      item.addEventListener("mouseenter", (event) => {
        if (!this.element.open) return;
        event.preventDefault();

        // Don't interfere with keyboard navigation
        if (this.keyboardNavigation) {
          return;
        }

        // Only handle mouse enter for visible items
        const currentItem = event.currentTarget;
        if (
          currentItem.disabled ||
          currentItem.classList.contains("disabled") ||
          currentItem.classList.contains("hidden") ||
          currentItem.style.display === "none"
        ) {
          return;
        }

        // Check computed styles for actual visibility (handles Tailwind responsive classes)
        const computedStyle = window.getComputedStyle(currentItem);
        if (computedStyle.display === "none" || computedStyle.visibility === "hidden") {
          return;
        }

        const openNestedControllers = this.#openNestedDropdownControllers();
        const pointerInPredictionCone = openNestedControllers.some((controller) =>
          controller.shouldKeepOpenForPointer?.(event),
        );
        const isCurrentItemOpenNestedTrigger = openNestedControllers.some(
          (controller) => controller.buttonTarget === event.currentTarget,
        );
        if (pointerInPredictionCone && !isCurrentItemOpenNestedTrigger) {
          this.#scheduleDeferredHover(event.currentTarget, event);
          return;
        }

        // Close any sibling nested dropdowns with a delay
        const siblingDropdowns = this.element.querySelectorAll(
          '[data-controller~="ui-dropdown-popover"][data-ui-dropdown-popover-nested-value="true"]',
        );
        siblingDropdowns.forEach((dropdown) => {
          const controller = this.application.getControllerForElementAndIdentifier(dropdown, "ui-dropdown-popover");
          const isHoverEnabled = controller?.hoverValue;
          const isCurrentItemNestedDropdown = event.currentTarget.hasAttribute("data-ui-dropdown-popover-target");

          // Only close if hover is enabled and current item is not a nested dropdown
          if (
            controller &&
            controller.isOpen &&
            !dropdown.contains(event.currentTarget) &&
            isHoverEnabled &&
            !isCurrentItemNestedDropdown &&
            !controller.shouldKeepOpenForPointer?.(event)
          ) {
            setTimeout(() => {
              if (!controller.shouldKeepOpenForPointer?.(event)) {
                controller.close();
              }
            }, 100);
          }
        });

        this.#applyHoverToItem(event.currentTarget);
      });

      item.addEventListener("mouseleave", (event) => {
        if (!this.element.open) return;

        if (this.deferredHoverItem === event.currentTarget) {
          this.#clearDeferredHover();
        }

        // During keyboard navigation, scrolling items under a stationary cursor can trigger mouseleave.
        // Don't let that steal focus back to the button / reset state.
        if (this.keyboardNavigation) {
          return;
        }

        const contextMenuController = this.#owningContextMenuController();
        const dropdownController = this.#owningDropdownController();

        // Find all open nested dropdown controllers within this menu
        const openNestedControllers = this.#openNestedDropdownControllers();

        // If pointer is moving into an open nested submenu, don't steal focus back
        // to the submenu trigger button. Let child item mouseenter manage highlight/focus.
        const relatedTarget = event.relatedTarget;
        const movingIntoOpenNestedMenuController =
          relatedTarget &&
          openNestedControllers.find(
            (controller) =>
              controller.menuElement.contains(relatedTarget) ||
              controller.buttonTarget?.contains(relatedTarget) ||
              controller.element.contains(relatedTarget),
          );
        if (
          movingIntoOpenNestedMenuController &&
          (movingIntoOpenNestedMenuController.buttonTarget === event.currentTarget ||
            movingIntoOpenNestedMenuController.element.contains(event.currentTarget))
        ) {
          return;
        }

        const pointerInPredictionCone = openNestedControllers.some((controller) =>
          controller.shouldKeepOpenForPointer?.(event),
        );
        if (pointerInPredictionCone) {
          return;
        }

        if (openNestedControllers.length > 0) {
          // Focus the last (deepest) open nested controller's button
          const deepestController = openNestedControllers[openNestedControllers.length - 1];
          const parentMenu = deepestController.buttonTarget.closest('[data-controller~="ui-menu"]');
          const parentMenuController = this.application.getControllerForElementAndIdentifier(parentMenu, "ui-menu");

          // Update tabindex state in the parent menu using public method
          const buttonIndex = parentMenuController.itemTargets.indexOf(deepestController.buttonTarget);
          parentMenuController.updateTabstopsWithIndex(buttonIndex);
          this.#focusWithoutScroll(deepestController.buttonTarget);
        } else if (this.indexValue === this.itemTargets.indexOf(event.currentTarget)) {
          if (contextMenuController) {
            this.#focusWithoutScroll(this.element);
          } else if (dropdownController) {
            this.#focusWithoutScroll(dropdownController.buttonTarget);
          }
          // Remove state attribute when leaving item
          event.currentTarget.removeAttribute("data-state");
          this.indexValue = -1;
          this.#updateTabstops();
        }
      });

      item.addEventListener("keydown", (event) => {
        this.keyboardNavigation = true;
        if (event.key === "Home") {
          event.preventDefault();
          this.selectFirst();
        } else if (event.key === "End") {
          event.preventDefault();
          this.selectLast();
        } else if (this.#isActivationKey(event)) {
          this.#activateItem(item, event);
        } else if (event.key === "ArrowRight") {
          if (this.#isNestedDropdownButton(item)) {
            event.preventDefault();
            this.#stopEvent(event);
            const dropdownController = this.#dropdownControllerForItem(item);
            dropdownController?.show();
            // Add state attribute when opening nested dropdown
            if (dropdownController?.nestedValue) {
              item.setAttribute("data-state", "open");
            }
          }
        } else if (event.key === "ArrowLeft") {
          const parentDropdownController = this.#parentNestedDropdownController();
          if (parentDropdownController) {
            event.stopPropagation();
            // Remove state attribute when closing nested dropdown
            parentDropdownController.buttonTarget.removeAttribute("data-state");
            parentDropdownController.close();
            this.#focusWithoutScroll(parentDropdownController.buttonTarget);
          }
        } else if (event.key === "ArrowUp" || event.key === "ArrowDown") {
          this.element.querySelectorAll(".active-menu-path").forEach((el) => {
            el.classList.remove("active-menu-path");
          });

          if (this.#isNestedDropdownButton(item)) {
            const dropdownController = this.#dropdownControllerForItem(item);

            if (dropdownController?.isOpen) {
              event.preventDefault();
              event.stopPropagation();
              const childMenuController = this.application.getControllerForElementAndIdentifier(
                dropdownController.menuElement,
                "menu",
              );

              // Add active path class and state attribute to parent item
              item.classList.add("active-menu-path");
              item.setAttribute("data-state", "open");

              if (event.key === "ArrowDown") {
                childMenuController.selectFirst();
              } else {
                childMenuController.selectLast();
              }
              return;
            }
          }
        }
      });
    });

    if (!this.elementKeydownHandler) {
      this.elementKeydownHandler = (event) => {
        if (this.#isActivationKey(event) && !event.defaultPrevented) {
          const item = this.#eventItemOrCurrentItem(event);
          if (item) {
            this.#activateItem(item, event);
          }
        } else if (event.key === "ArrowRight" && !event.defaultPrevented) {
          const item = this.#eventItemOrCurrentItem(event);
          if (item && this.#isNestedDropdownButton(item)) {
            event.preventDefault();
            this.#stopEvent(event);
            const dropdownController = this.#dropdownControllerForItem(item);
            dropdownController?.show();
            if (dropdownController?.nestedValue) {
              item.setAttribute("data-state", "open");
            }
          }
        } else if (event.key === "ArrowLeft") {
          const parentDropdownController = this.#parentNestedDropdownController();
          if (parentDropdownController) {
            event.stopPropagation();
            // Remove state attribute when closing nested dropdown
            parentDropdownController.buttonTarget.removeAttribute("data-state");
            parentDropdownController.close();
            this.#focusWithoutScroll(parentDropdownController.buttonTarget);
          }
        }
      };
      this.element.addEventListener("keydown", this.elementKeydownHandler);
    }

    if (!this.elementMouseleaveHandler) {
      this.elementMouseleaveHandler = (event) => {
        if (!this.element.open) return;

        // Same idea as above: ignore scroll-induced mouseleave while keyboard navigating.
        if (this.keyboardNavigation) {
          return;
        }

        // Check all nested dropdown controllers for open state
        const hasOpenNested = this.#openNestedDropdownControllers().length > 0;

        if (!hasOpenNested) {
          const dropdownController = this.#owningDropdownController();
          if (dropdownController?.buttonTarget) {
            this.#focusWithoutScroll(dropdownController.buttonTarget);
          }
        }
      };
      this.element.addEventListener("mouseleave", this.elementMouseleaveHandler);
    }
  }

  reset() {
    this.indexValue = -1;
    this.searchString = "";
    this.#updateTabstops();
  }

  // Helper method to get only visible and enabled items
  #getVisibleItems() {
    return this.itemTargets.filter((item) => {
      // Check if item is disabled
      if (item.disabled || item.classList.contains("disabled")) {
        return false;
      }

      // Check if item is explicitly hidden
      if (item.classList.contains("hidden")) {
        return false;
      }

      // Check if item has inline style display none
      if (item.style.display === "none") {
        return false;
      }

      // Check computed styles for actual visibility (handles Tailwind responsive classes)
      const computedStyle = window.getComputedStyle(item);
      if (computedStyle.display === "none" || computedStyle.visibility === "hidden") {
        return false;
      }

      return true;
    });
  }

  prev() {
    this.keyboardNavigation = true;
    this.element.querySelectorAll(".active-menu-path").forEach((el) => {
      el.classList.remove("active-menu-path");
      el.removeAttribute("data-state");
    });

    // Get only visible and enabled items
    const visibleItems = this.#getVisibleItems();
    if (visibleItems.length === 0) return;

    const currentVisibleIndex = visibleItems.indexOf(this.itemTargets[this.indexValue]);

    if (currentVisibleIndex === -1) {
      this.indexValue = this.itemTargets.indexOf(visibleItems[visibleItems.length - 1]);
    } else if (currentVisibleIndex > 0) {
      this.indexValue = this.itemTargets.indexOf(visibleItems[currentVisibleIndex - 1]);
    } else {
      this.indexValue = this.itemTargets.indexOf(visibleItems[visibleItems.length - 1]);
    }

    this.#updateTabstops();
    this.#focusCurrentItem();
  }

  next() {
    this.keyboardNavigation = true;
    this.element.querySelectorAll(".active-menu-path").forEach((el) => {
      el.classList.remove("active-menu-path");
      el.removeAttribute("data-state");
    });

    // Get only visible and enabled items
    const visibleItems = this.#getVisibleItems();
    if (visibleItems.length === 0) return;

    const currentVisibleIndex = visibleItems.indexOf(this.itemTargets[this.indexValue]);

    if (currentVisibleIndex === -1) {
      this.indexValue = this.itemTargets.indexOf(visibleItems[0]);
    } else if (currentVisibleIndex < visibleItems.length - 1) {
      this.indexValue = this.itemTargets.indexOf(visibleItems[currentVisibleIndex + 1]);
    } else {
      this.indexValue = this.itemTargets.indexOf(visibleItems[0]);
    }

    this.#updateTabstops();
    this.#focusCurrentItem();
  }

  preventScroll(event) {
    event.preventDefault();
  }

  #updateTabstops() {
    this.itemTargets.forEach((element, index) => {
      const isHighlighted = index === this.indexValue && this.indexValue !== -1;
      element.tabIndex = isHighlighted ? 0 : -1;

      // Add/remove data-highlighted attribute for CSS styling (Base UI pattern)
      if (isHighlighted) {
        element.setAttribute("data-highlighted", "");
      } else {
        element.removeAttribute("data-highlighted");
      }
    });
  }

  #focusCurrentItem(options = {}) {
    const item = this.itemTargets[this.indexValue];
    this.#focusWithoutScroll(item, options);
  }

  #applyHoverToItem(item) {
    this.indexValue = this.itemTargets.indexOf(item);
    this.#updateTabstops();
    // Focus without scrolling for mouse hover to prevent aggressive auto-scroll
    this.#focusCurrentItem({ preventScroll: true });

    if (this.#isNestedDropdownButton(item)) {
      const dropdownController = this.#dropdownControllerForItem(item);
      if (dropdownController?.hoverValue && !dropdownController.isOpen) {
        dropdownController.show();
      }
    }
  }

  #scheduleDeferredHover(item, event) {
    this.deferredHoverItem = item;
    this.deferredHoverPointer = { clientX: event.clientX, clientY: event.clientY };
    clearTimeout(this.deferredHoverTimeout);

    this.deferredHoverTimeout = setTimeout(() => {
      if (!this.element.open || this.keyboardNavigation || this.deferredHoverItem !== item || !item.matches(":hover")) {
        this.#clearDeferredHover();
        return;
      }

      const pointerInPredictionCone = this.#openNestedDropdownControllers().some((controller) =>
        controller.shouldKeepOpenForPointer?.(this.deferredHoverPointer),
      );

      if (pointerInPredictionCone) {
        this.#scheduleDeferredHover(item, this.deferredHoverPointer);
        return;
      }

      this.#clearDeferredHover();
      this.#applyHoverToItem(item);
    }, 100);
  }

  #clearDeferredHover() {
    clearTimeout(this.deferredHoverTimeout);
    this.deferredHoverTimeout = null;
    this.deferredHoverItem = null;
    this.deferredHoverPointer = null;
  }

  #focusWithoutScroll(element, options = {}) {
    if (!element || typeof element.focus !== "function") return;

    try {
      element.focus({ preventScroll: true, ...options });
    } catch (_error) {
      element.focus(options);
    }
  }

  #activateItem(item, event) {
    if (this.#isDisabledItem(item)) {
      event.preventDefault();
      this.#stopEvent(event);
      return;
    }

    const input = item.querySelector('input[type="checkbox"], input[type="radio"]');
    if (input) {
      event.preventDefault();
      this.#stopEvent(event);
      this.#activateInputItem(item, input);
      return;
    }

    if (this.#isNestedDropdownButton(item)) {
      event.preventDefault();
      this.#stopEvent(event);
      const dropdownController = this.#dropdownControllerForItem(item);
      dropdownController?.show();
      if (dropdownController?.nestedValue) {
        item.setAttribute("data-state", "open");
      }
      return;
    }

    const activatable = item.matches("a, button") ? item : item.querySelector("a, button");
    if (!activatable) return;

    event.preventDefault();
    this.#stopEvent(event);
    activatable.click();
  }

  #activateInputItem(item, input) {
    if (input.type === "checkbox") {
      input.checked = !input.checked;
      this.#dispatchInputChange(input);
    } else if (input.type === "radio" && !input.checked) {
      if (input.name) {
        document.querySelectorAll('input[type="radio"]').forEach((radio) => {
          if (radio !== input && radio.name === input.name && radio.form === input.form) {
            radio.checked = false;
          }
        });
      }

      input.checked = true;
      this.#dispatchInputChange(input);
    }

    this.indexValue = this.itemTargets.indexOf(item);
    this.#updateTabstops();
    this.#focusWithoutScroll(item);

    if (this.#shouldAutoClose()) {
      this.element.dispatchEvent(new Event("menu-item-clicked", { bubbles: true }));
    }
  }

  #isDisabledItem(item) {
    const input = item.querySelector('input[type="checkbox"], input[type="radio"]');
    return (
      item.disabled ||
      item.getAttribute("aria-disabled") === "true" ||
      item.classList.contains("disabled") ||
      input?.disabled
    );
  }

  #isActivationKey(event) {
    return event.key === "Enter" || event.key === " " || event.key === "Space" || event.key === "Spacebar";
  }

  #itemFromEvent(event) {
    return this.itemTargets.find((item) => item === event.target || item.contains(event.target));
  }

  #eventItemOrCurrentItem(event) {
    const eventItem = this.#itemFromEvent(event);
    if (eventItem) return eventItem;

    // Nested menus live inside parent menus. Do not let the parent menu
    // activate its highlighted submenu trigger for key events from child menu content.
    if (event.target !== this.element) return null;

    return this.itemTargets[this.indexValue];
  }

  #dispatchInputChange(input) {
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  #stopEvent(event) {
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    } else {
      event.stopPropagation();
    }
  }

  #isNestedDropdownButton(item) {
    return item.hasAttribute("data-ui-dropdown-popover-target");
  }

  #shouldAutoClose() {
    const dropdownController = this.#owningDropdownController();
    if (dropdownController) return dropdownController.autoCloseValue;

    const contextMenuController = this.#owningContextMenuController();
    if (contextMenuController) return contextMenuController.autoCloseValue;

    return true;
  }

  #owningDropdownController() {
    const closestDropdown = this.element.closest('[data-controller~="ui-dropdown-popover"]');
    const closestController =
      closestDropdown && this.application.getControllerForElementAndIdentifier(closestDropdown, "ui-dropdown-popover");

    if (closestController) return closestController;

    return this.application.controllers.find(
      (controller) =>
        controller.identifier === "ui-dropdown-popover" &&
        (controller.menuElement === this.element || controller.menuElement?.contains(this.element)),
    );
  }

  #owningContextMenuController() {
    const closestContextMenu = this.element.closest('[data-controller~="context-menu"]');
    const closestController =
      closestContextMenu && this.application.getControllerForElementAndIdentifier(closestContextMenu, "context-menu");

    if (closestController) return closestController;

    return this.application.controllers.find(
      (controller) =>
        controller.identifier === "context-menu" &&
        (controller.menuElement === this.element || controller.menuElement?.contains(this.element)),
    );
  }

  #dropdownControllerForItem(item) {
    const dropdown = item.closest('[data-controller~="ui-dropdown-popover"]');
    const controller = dropdown && this.application.getControllerForElementAndIdentifier(dropdown, "ui-dropdown-popover");
    if (controller) return controller;

    return this.application.controllers.find(
      (controller) => controller.identifier === "ui-dropdown-popover" && controller.buttonTarget === item,
    );
  }

  #parentNestedDropdownController() {
    const parentDropdown = this.element.closest('[data-ui-dropdown-popover-nested-value="true"]');
    return parentDropdown && this.application.getControllerForElementAndIdentifier(parentDropdown, "ui-dropdown-popover");
  }

  #openNestedDropdownControllers() {
    return Array.from(this.element.querySelectorAll('[data-controller~="ui-dropdown-popover"]'))
      .map((dropdown) => this.application.getControllerForElementAndIdentifier(dropdown, "ui-dropdown-popover"))
      .filter((controller) => controller?.isOpen);
  }

  get #lastIndex() {
    return this.itemTargets.length - 1;
  }

  selectFirst() {
    this.keyboardNavigation = true;
    const visibleItems = this.#getVisibleItems();
    if (visibleItems.length === 0) return;

    this.indexValue = this.itemTargets.indexOf(visibleItems[0]);
    this.#updateTabstops();
    this.#focusCurrentItem();
  }

  selectLast() {
    this.keyboardNavigation = true;
    const visibleItems = this.#getVisibleItems();
    if (visibleItems.length === 0) return;

    this.indexValue = this.itemTargets.indexOf(visibleItems[visibleItems.length - 1]);
    this.#updateTabstops();
    this.#focusCurrentItem();
  }

  #handleTextSearch(key) {
    this.keyboardNavigation = true;
    clearTimeout(this.searchTimeout);
    this.searchString += key;

    const searchStr = this.searchString;
    const visibleItems = this.#getVisibleItems();
    const matchedItem = visibleItems.find((item) => {
      const textElement = item.querySelector(".menu-item-text") || item;
      return textElement.textContent.trim().toLowerCase().startsWith(searchStr);
    });

    if (matchedItem) {
      this.indexValue = this.itemTargets.indexOf(matchedItem);
      this.#updateTabstops();
      this.#focusCurrentItem();
    }

    this.searchTimeout = setTimeout(() => {
      this.searchString = "";
    }, 500);
  }

  // Add public method for external access
  updateTabstopsWithIndex(newIndex) {
    this.indexValue = newIndex;
    this.#updateTabstops();
  }
}
