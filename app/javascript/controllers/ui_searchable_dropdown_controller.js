import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "item", "results", "noResults"];
  static values = {
    placeholder: { type: String, default: "Search..." },
    noResultsText: { type: String, default: "No results found" },
  };

  connect() {
    this.originalItems = [...this.itemTargets];
    this.selectedIndex = -1;
    this.keyboardNavigation = false; // Track if user is navigating with keyboard

    this.setupAccessibility();
    this.bindEvents();
    this.bindHoverEvents();
  }

  disconnect() {
    this.unbindEvents();
    this.unbindHoverEvents();
  }

  setupAccessibility() {
    // Set up ARIA attributes for better accessibility
    if (this.hasInputTarget) {
      this.inputTarget.setAttribute("role", "combobox");
      this.inputTarget.setAttribute("aria-expanded", "false");
      this.inputTarget.setAttribute("aria-autocomplete", "list");
      this.inputTarget.setAttribute("aria-haspopup", "listbox");

      // Generate unique IDs if not present
      if (!this.inputTarget.id) {
        this.inputTarget.id = `searchable-dropdown-input-${Math.random().toString(36).substring(7)}`;
      }
    }

    if (this.hasResultsTarget) {
      this.resultsTarget.setAttribute("role", "listbox");
      if (this.hasInputTarget) {
        this.resultsTarget.setAttribute("aria-labelledby", this.inputTarget.id);
      }
    }

    // Set up items with proper roles and IDs
    this.itemTargets.forEach((item, index) => {
      item.setAttribute("role", "option");
      item.setAttribute("aria-selected", "false");
      if (!item.id) {
        item.id = `searchable-dropdown-option-${index}-${Math.random().toString(36).substring(7)}`;
      }
    });
  }

  bindEvents() {
    // Bind regular event handlers (arrow functions don't need binding)
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleInputFocus = this.handleInputFocus.bind(this);

    if (this.hasInputTarget) {
      this.inputTarget.addEventListener("keydown", this.handleKeydown);
      this.inputTarget.addEventListener("focus", this.handleInputFocus);
    }
  }

  bindHoverEvents() {
    this.itemTargets.forEach((item) => {
      // Use capture phase to intercept events before menu controller
      item.addEventListener("mouseenter", this.handleItemMouseEnter, true);
      item.addEventListener("mouseleave", this.handleItemMouseLeave, true);
      // Reset keyboard navigation when mouse moves
      item.addEventListener("mousemove", this.handleMouseMove, true);
    });

    // Add mouse leave to the results container to clear selection when leaving all items
    if (this.hasResultsTarget) {
      this.resultsTarget.addEventListener("mouseleave", this.handleResultsMouseLeave, true);
    }
  }

  unbindEvents() {
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener("keydown", this.handleKeydown);
      this.inputTarget.removeEventListener("focus", this.handleInputFocus);
    }
  }

  unbindHoverEvents() {
    this.itemTargets.forEach((item) => {
      item.removeEventListener("mouseenter", this.handleItemMouseEnter, true);
      item.removeEventListener("mouseleave", this.handleItemMouseLeave, true);
      item.removeEventListener("mousemove", this.handleMouseMove, true);
    });

    // Remove results container event listener
    if (this.hasResultsTarget) {
      this.resultsTarget.removeEventListener("mouseleave", this.handleResultsMouseLeave, true);
    }
  }

  handleInputFocus() {
    if (this.hasInputTarget) {
      this.inputTarget.setAttribute("aria-expanded", "true");
    }
  }

  handleItemMouseEnter = (event) => {
    // Prevent the menu controller from handling this event
    event.preventDefault();
    event.stopPropagation();

    // Don't interfere with keyboard navigation
    if (this.keyboardNavigation) {
      return;
    }

    const visibleItems = this.getVisibleItems();
    const hoveredItem = event.currentTarget;

    // Only update selection if the item is visible
    if (!hoveredItem.classList.contains("hidden")) {
      this.selectedIndex = visibleItems.indexOf(hoveredItem);
      this.updateSelection(visibleItems);
    }
  };

  handleItemMouseLeave = (event) => {
    // Prevent the menu controller from handling this event
    event.preventDefault();
    event.stopPropagation();

    // Keep the input focused when leaving an item
    this.ensureInputFocus();
  };

  handleResultsMouseLeave = (event) => {
    // During keyboard navigation, scrolling items under a stationary cursor can trigger mouseleave
    // and we don't want that to clear the selection / "snap" the experience.
    if (this.keyboardNavigation) {
      return;
    }

    // Clear selection when mouse leaves the entire results area
    this.clearSelection();
    this.ensureInputFocus();
  };

  handleMouseMove = (event) => {
    // Ignore mousemove events where the mouse didn't actually move.
    // This happens when content scrolls under a stationary cursor (e.g., during keyboard navigation).
    if (event.movementX === 0 && event.movementY === 0) return;

    // Reset keyboard navigation flag when mouse moves
    this.keyboardNavigation = false;
  };

  handleKeydown(event) {
    const visibleItems = this.getVisibleItems();

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.navigateDown(visibleItems);
        break;
      case "ArrowUp":
        event.preventDefault();
        this.navigateUp(visibleItems);
        break;
      case "Enter":
        event.preventDefault();
        this.selectCurrentItem(visibleItems);
        break;
      case "Escape":
        event.preventDefault();
        this.closeDropdown();
        break;
      case "Tab":
        this.clearSelection();
        break;
      case "Home":
        event.preventDefault();
        this.navigateToFirst(visibleItems);
        break;
      case "End":
        event.preventDefault();
        this.navigateToLast(visibleItems);
        break;
    }
  }

  search(event) {
    // Reset keyboard navigation when user starts typing
    this.keyboardNavigation = false;

    const query = event.target.value.toLowerCase().trim();
    let hasVisibleItems = false;

    this.originalItems.forEach((item) => {
      const searchText = item.dataset.searchableText || item.textContent.toLowerCase();
      const matches = searchText.includes(query);

      if (matches) {
        item.classList.remove("hidden");
        hasVisibleItems = true;
      } else {
        item.classList.add("hidden");
      }
    });

    // Reset selection when searching
    this.clearSelection();

    // Show/hide no results message
    this.toggleNoResults(!hasVisibleItems);

    // Update ARIA live region for screen readers
    this.announceResults(hasVisibleItems, query);

    // Ensure input stays focused during search
    this.ensureInputFocus();
  }

  getVisibleItems() {
    return this.itemTargets.filter((item) => !item.classList.contains("hidden"));
  }

  navigateDown(visibleItems) {
    if (visibleItems.length === 0) return;

    this.keyboardNavigation = true;
    this.selectedIndex = Math.min(this.selectedIndex + 1, visibleItems.length - 1);
    this.updateSelection(visibleItems);
  }

  navigateUp(visibleItems) {
    if (visibleItems.length === 0) return;

    this.keyboardNavigation = true;
    this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
    this.updateSelection(visibleItems);
  }

  navigateToFirst(visibleItems) {
    if (visibleItems.length === 0) return;

    this.keyboardNavigation = true;
    this.selectedIndex = 0;
    this.updateSelection(visibleItems);
  }

  navigateToLast(visibleItems) {
    if (visibleItems.length === 0) return;

    this.keyboardNavigation = true;
    this.selectedIndex = visibleItems.length - 1;
    this.updateSelection(visibleItems);
  }

  updateSelection(visibleItems) {
    // Clear all selections
    this.itemTargets.forEach((item) => {
      item.setAttribute("aria-selected", "false");
      item.classList.remove("bg-neutral-100", "dark:bg-neutral-700/50");
    });

    // Update input aria-activedescendant
    if (this.hasInputTarget) {
      if (this.selectedIndex >= 0 && visibleItems[this.selectedIndex]) {
        const selectedItem = visibleItems[this.selectedIndex];
        this.inputTarget.setAttribute("aria-activedescendant", selectedItem.id);
        selectedItem.setAttribute("aria-selected", "true");
        selectedItem.classList.add("bg-neutral-100", "dark:bg-neutral-700/50");

        // Only scroll item into view for keyboard navigation, not mouse hover
        if (this.keyboardNavigation) {
          this.scrollItemIntoView(selectedItem);
        }

        // Keep focus on input for continuous typing
        this.inputTarget.focus();
      } else {
        this.inputTarget.removeAttribute("aria-activedescendant");
        // Keep focus on input
        this.inputTarget.focus();
      }
    }
  }

  scrollItemIntoView(item) {
    if (this.hasResultsTarget) {
      const container = this.resultsTarget;
      const containerRect = container.getBoundingClientRect();
      const itemRect = item.getBoundingClientRect();

      // Calculate the item's position relative to the scrollable content
      const itemRelativeTop = itemRect.top - containerRect.top;
      const itemRelativeBottom = itemRelativeTop + itemRect.height;
      const containerScrollTop = container.scrollTop;
      const containerHeight = containerRect.height;

      // Define padding: scroll when the item is within this distance from the edge
      // This ensures we can see approximately one more item beyond the current selection
      const scrollPadding = itemRect.height + 6;

      // Check if we need to scroll down
      if (itemRelativeBottom > containerHeight - scrollPadding) {
        container.scrollTop = containerScrollTop + (itemRelativeBottom - containerHeight + scrollPadding);
      }
      // Check if we need to scroll up
      else if (itemRelativeTop < scrollPadding) {
        container.scrollTop = containerScrollTop + (itemRelativeTop - scrollPadding);
      }
    }
  }

  selectCurrentItem(visibleItems) {
    if (this.selectedIndex >= 0 && visibleItems[this.selectedIndex]) {
      const selectedItem = visibleItems[this.selectedIndex];
      this.selectItem(selectedItem);
    }
  }

  selectItem(item) {
    // Dispatch custom event with selected item data
    const selectEvent = new CustomEvent("searchable-dropdown:select", {
      detail: {
        item: item,
        value: item.dataset.value || item.textContent.trim(),
        text: item.textContent.trim(),
      },
      bubbles: true,
    });

    this.element.dispatchEvent(selectEvent);

    // Optional: Update input with selected value
    if (this.hasInputTarget) {
      // You might want to clear the input or set it to the selected value
      // this.inputTarget.value = item.textContent.trim()
    }

    // Close dropdown (this will be handled by the ui-dropdown-popover controller)
    this.closeDropdown();
  }

  closeDropdown() {
    // Update aria-expanded before closing
    if (this.hasInputTarget) {
      this.inputTarget.setAttribute("aria-expanded", "false");
    }

    // Get the ui-dropdown-popover controller and call its close method.
    // The searchable controller can live on a menu that is portaled outside the
    // dropdown wrapper, so find the owner by cached menu element when needed.
    const dropdownController = this.#dropdownController();

    if (dropdownController) {
      dropdownController.close();
    }

    this.clearSelection();
  }

  clearSelection() {
    this.selectedIndex = -1;
    this.keyboardNavigation = false;
    this.itemTargets.forEach((item) => {
      item.setAttribute("aria-selected", "false");
      item.classList.remove("bg-neutral-100", "dark:bg-neutral-700/50");
    });

    if (this.hasInputTarget) {
      this.inputTarget.removeAttribute("aria-activedescendant");
    }
  }

  toggleNoResults(show) {
    if (this.hasNoResultsTarget) {
      if (show) {
        this.noResultsTarget.classList.remove("hidden");
      } else {
        this.noResultsTarget.classList.add("hidden");
      }
    }
  }

  announceResults(hasResults, query) {
    // Create or update ARIA live region for screen reader announcements
    let liveRegion = this.element.querySelector("[aria-live]");
    if (!liveRegion) {
      liveRegion = document.createElement("div");
      liveRegion.setAttribute("aria-live", "polite");
      liveRegion.setAttribute("aria-atomic", "true");
      liveRegion.className = "sr-only";
      this.element.appendChild(liveRegion);
    }

    if (query.length > 0) {
      const visibleCount = this.getVisibleItems().length;
      if (hasResults) {
        liveRegion.textContent = `${visibleCount} ${visibleCount === 1 ? "result" : "results"} available`;
      } else {
        liveRegion.textContent = "No results found";
      }
    } else {
      liveRegion.textContent = "";
    }
  }

  // Action method for clicking on items
  itemClick(event) {
    event.preventDefault();
    event.stopPropagation();
    this.selectItem(event.currentTarget);
  }

  // Reset search when dropdown opens
  reset() {
    this.keyboardNavigation = false;

    if (this.hasInputTarget) {
      this.inputTarget.value = "";
    }

    // Show all items
    this.originalItems.forEach((item) => {
      item.classList.remove("hidden");
    });

    // Hide no results
    this.toggleNoResults(false);

    // Clear selection
    this.clearSelection();

    // Focus input and ensure it stays focused
    this.ensureInputFocus();
  }

  // Ensure input maintains focus for continuous typing
  ensureInputFocus() {
    if (this.hasInputTarget) {
      // Use setTimeout to ensure focus happens after any other focus changes
      setTimeout(() => {
        this.inputTarget.focus();
      }, 0);
    }
  }

  // Handle when new items are added (Stimulus target callbacks)
  itemTargetConnected(element) {
    // Bind hover events to new items with capture phase
    element.addEventListener("mouseenter", this.handleItemMouseEnter, true);
    element.addEventListener("mouseleave", this.handleItemMouseLeave, true);
    element.addEventListener("mousemove", this.handleMouseMove, true);
  }

  itemTargetDisconnected(element) {
    // Clean up hover events from removed items
    element.removeEventListener("mouseenter", this.handleItemMouseEnter, true);
    element.removeEventListener("mouseleave", this.handleItemMouseLeave, true);
    element.removeEventListener("mousemove", this.handleMouseMove, true);
  }

  #dropdownController() {
    const closestDropdown = this.element.closest('[data-controller~="ui-dropdown-popover"]');
    if (closestDropdown) {
      const controller = this.application.getControllerForElementAndIdentifier(closestDropdown, "ui-dropdown-popover");
      if (controller) return controller;
    }

    return this.application.controllers.find(
      (controller) => controller.identifier === "ui-dropdown-popover" && controller.menuElement === this.element,
    );
  }
}
