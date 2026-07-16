import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static classes = ["activeTab", "inactiveTab"];
  static targets = ["tab", "panel", "select", "tabList", "progressBar", "template"];
  static values = {
    index: 0, // Index of the tab to show on load
    updateAnchor: Boolean, // Whether to update the anchor
    scrollToAnchor: Boolean, // Whether to scroll to the anchor
    scrollActiveTabIntoView: Boolean, // Whether to scroll the active tab into view
    autoSwitch: Boolean, // Whether to auto-switch tabs
    autoSwitchInterval: { type: Number, default: 5000 }, // Interval in ms for auto-switching
    pauseOnHover: { type: Boolean, default: true }, // Whether to pause auto-switching when hovering over a tab
    showProgressBar: Boolean, // Whether to show the progress bar
    lazyLoad: { type: Boolean, default: false }, // Whether to lazy load the tab content
    turboFrameSrc: { type: String, default: "" }, // URL for the turbo frame
    arrowFocusOnly: { type: Boolean, default: false }, // Whether arrow keys only change focus without changing content (Depending on if you prefer to have Tabs change content or just focus | based on tips from https://www.w3.org/WAI/ARIA/apg/patterns/tabs#examples)
  };

  initialize() {
    // Track initial page load to avoid adding anchor when none exists
    this.initialLoad = true;
    this.hadInitialAnchor = !!this.anchor;

    if (this.updateAnchorValue && this.anchor) {
      this.indexValue = this.tabTargets.findIndex((tab) => tab.id === this.anchor);
    }

    // Initialize auto-switch properties
    this.autoSwitchTimer = null;
    this.startTime = null;
    this.isPaused = false;
    this.remainingTime = 0;
    this.currentProgress = 0;

    // Initialize lazy loading tracking
    this.loadedPanels = new Set();

    // Initialize focus tracking for arrow-focus-only mode
    this.focusedTabIndex = this.indexValue;
  }

  async connect() {
    if (this.tabsCount === 0) return;

    this.indexValue = this.normalizedEnabledIndex(this.indexValue);
    this.focusedTabIndex = this.indexValue;

    await this.showTab();
    this.setInitialFocus();
    this.revealTabs();
    this.addKeyboardEventListeners();

    // Start auto-switching if enabled
    if (this.autoSwitchValue) {
      this.startAutoSwitch();
      this.addHoverEventListeners();
    }

    // Mark initial load as complete
    this.initialLoad = false;
  }

  disconnect() {
    this.removeKeyboardEventListeners();
    this.removeHoverEventListeners();
    this.stopAutoSwitch();
  }

  addKeyboardEventListeners() {
    this.keydownHandler = this.handleKeydown.bind(this);
    this.focusHandler = this.handleFocus.bind(this);
    this.tabTargets.forEach((tab) => {
      tab.addEventListener("keydown", this.keydownHandler);
      tab.addEventListener("focus", this.focusHandler);
    });
  }

  removeKeyboardEventListeners() {
    if (this.keydownHandler) {
      this.tabTargets.forEach((tab) => {
        tab.removeEventListener("keydown", this.keydownHandler);
        tab.removeEventListener("focus", this.focusHandler);
      });
    }
  }

  addHoverEventListeners() {
    if (this.pauseOnHoverValue) {
      this.mouseEnterHandler = this.pauseAutoSwitch.bind(this);
      this.mouseLeaveHandler = this.resumeAutoSwitch.bind(this);
      this.focusHandler = this.pauseAutoSwitch.bind(this);
      this.blurHandler = this.resumeAutoSwitch.bind(this);

      this.element.addEventListener("mouseenter", this.mouseEnterHandler);
      this.element.addEventListener("mouseleave", this.mouseLeaveHandler);
      this.element.addEventListener("focusin", this.focusHandler);
      this.element.addEventListener("focusout", this.blurHandler);
    }
  }

  removeHoverEventListeners() {
    if (this.mouseEnterHandler) {
      this.element.removeEventListener("mouseenter", this.mouseEnterHandler);
      this.element.removeEventListener("mouseleave", this.mouseLeaveHandler);
      this.element.removeEventListener("focusin", this.focusHandler);
      this.element.removeEventListener("focusout", this.blurHandler);
    }
  }

  handleFocus(event) {
    // When a tab receives focus, sync the focusedTabIndex with the tab that actually has focus
    const focusedTab = event.target.closest('[data-ui-tabs-target="tab"]');
    if (focusedTab && !this.isTabDisabled(focusedTab)) {
      const tabIndex = this.tabTargets.indexOf(focusedTab);
      if (tabIndex !== -1) {
        this.focusedTabIndex = tabIndex;
      }
    }
  }

  handleKeydown(event) {
    // Only handle keyboard events when focus is on a tab
    if (!this.tabTargets.includes(event.target) && !event.target.closest('[data-ui-tabs-target="tab"]')) {
      return;
    }

    const orientation = this.getOrientation();

    switch (event.key) {
      case "ArrowLeft":
        // Handle left arrow based on orientation
        if (orientation === "vertical") {
          // For vertical tabs, left/right arrows should not be handled by tabs
          return;
        }
        event.preventDefault();
        if (this.arrowFocusOnlyValue) {
          this.previousTabFocusOnly();
        } else {
          this.previousTab();
        }
        break;
      case "ArrowRight":
        // Handle right arrow based on orientation
        if (orientation === "vertical") {
          // For vertical tabs, left/right arrows should not be handled by tabs
          return;
        }
        event.preventDefault();
        if (this.arrowFocusOnlyValue) {
          this.nextTabFocusOnly();
        } else {
          this.nextTab();
        }
        break;
      case "ArrowUp":
        // Handle up arrow based on orientation
        if (orientation === "horizontal") {
          // For horizontal tabs, up/down arrows should not be handled by tabs
          return;
        }
        event.preventDefault();
        if (this.arrowFocusOnlyValue) {
          this.previousTabFocusOnly();
        } else {
          this.previousTab();
        }
        break;
      case "ArrowDown":
        // Handle down arrow based on orientation
        if (orientation === "horizontal") {
          // For horizontal tabs, up/down arrows should not be handled by tabs
          return;
        }
        event.preventDefault();
        if (this.arrowFocusOnlyValue) {
          this.nextTabFocusOnly();
        } else {
          this.nextTab();
        }
        break;
      case "Home":
        event.preventDefault();
        if (this.arrowFocusOnlyValue) {
          this.firstTabFocusOnly();
        } else {
          this.firstTab();
        }
        break;
      case "End":
        event.preventDefault();
        if (this.arrowFocusOnlyValue) {
          this.lastTabFocusOnly();
        } else {
          this.lastTab();
        }
        break;
    }
  }

  // Changes to the clicked tab
  change(event) {
    let targetIndex;

    if (event.currentTarget.tagName === "SELECT") {
      targetIndex = event.currentTarget.selectedIndex;

      // If target specifies an index, use that
    } else if (event.currentTarget.dataset.index) {
      targetIndex = parseInt(event.currentTarget.dataset.index);

      // If target specifies an id, use that
    } else if (event.currentTarget.dataset.id) {
      targetIndex = this.tabTargets.findIndex((tab) => tab.id === event.currentTarget.dataset.id);

      // Otherwise, use the index of the current target
    } else {
      if (this.isTabDisabled(event.currentTarget)) return;
      targetIndex = this.tabTargets.indexOf(event.currentTarget);
    }

    if (!Number.isInteger(targetIndex) || targetIndex < 0 || targetIndex >= this.tabsCount) return;

    const enabledIndex = this.normalizedEnabledIndex(targetIndex);
    if (enabledIndex === -1 || enabledIndex === this.indexValue) return;

    this.indexValue = enabledIndex;

    // Sync the focused tab index with the active tab
    this.focusedTabIndex = this.indexValue;

    // Set focus to the newly active tab
    this.setFocusToActiveTab();

    // Restart auto-switch timer when user manually changes tabs
    if (this.autoSwitchValue) {
      this.restartAutoSwitch();
    }
  }

  nextTab(shouldFocus = true) {
    const nextIndex = this.nextEnabledTabIndex(this.indexValue);
    if (nextIndex === -1) return;
    this.indexValue = nextIndex;

    // Sync the focused tab index
    this.focusedTabIndex = this.indexValue;

    if (shouldFocus) {
      this.setFocusToActiveTab();
      // Restart auto-switch timer when user manually changes tabs via keyboard
      if (this.autoSwitchValue) {
        this.restartAutoSwitch();
      }
    }
  }

  previousTab() {
    const previousIndex = this.previousEnabledTabIndex(this.indexValue);
    if (previousIndex === -1) return;
    this.indexValue = previousIndex;

    // Sync the focused tab index
    this.focusedTabIndex = this.indexValue;

    this.setFocusToActiveTab();
    // Restart auto-switch timer when user manually changes tabs via keyboard
    if (this.autoSwitchValue) {
      this.restartAutoSwitch();
    }
  }

  firstTab() {
    const firstEnabledIndex = this.firstEnabledTabIndex();
    if (firstEnabledIndex === -1) return;
    this.indexValue = firstEnabledIndex;

    // Sync the focused tab index
    this.focusedTabIndex = this.indexValue;

    this.setFocusToActiveTab();
    // Restart auto-switch timer when user manually changes tabs via keyboard
    if (this.autoSwitchValue) {
      this.restartAutoSwitch();
    }
  }

  lastTab() {
    const lastEnabledIndex = this.lastEnabledTabIndex();
    if (lastEnabledIndex === -1) return;
    this.indexValue = lastEnabledIndex;

    // Sync the focused tab index
    this.focusedTabIndex = this.indexValue;

    this.setFocusToActiveTab();
    // Restart auto-switch timer when user manually changes tabs via keyboard
    if (this.autoSwitchValue) {
      this.restartAutoSwitch();
    }
  }

  // Focus-only navigation methods (don't change content)
  nextTabFocusOnly() {
    const nextIndex = this.nextEnabledTabIndex(this.focusedTabIndex);
    if (nextIndex === -1) return;
    this.focusedTabIndex = nextIndex;
    this.setFocusToTab(this.focusedTabIndex);
  }

  previousTabFocusOnly() {
    const previousIndex = this.previousEnabledTabIndex(this.focusedTabIndex);
    if (previousIndex === -1) return;
    this.focusedTabIndex = previousIndex;
    this.setFocusToTab(this.focusedTabIndex);
  }

  firstTabFocusOnly() {
    const firstEnabledIndex = this.firstEnabledTabIndex();
    if (firstEnabledIndex === -1) return;
    this.focusedTabIndex = firstEnabledIndex;
    this.setFocusToTab(this.focusedTabIndex);
  }

  lastTabFocusOnly() {
    const lastEnabledIndex = this.lastEnabledTabIndex();
    if (lastEnabledIndex === -1) return;
    this.focusedTabIndex = lastEnabledIndex;
    this.setFocusToTab(this.focusedTabIndex);
  }

  // Auto-switch methods
  startAutoSwitch() {
    if (!this.autoSwitchValue || this.tabsCount <= 1) return;

    this.stopAutoSwitch(); // Clear any existing timers
    this.startTime = Date.now();
    this.remainingTime = this.autoSwitchIntervalValue;
    this.currentProgress = 0; // Always start from 0 for a new cycle
    this.isPaused = false; // Ensure we're not in paused state

    this.autoSwitchTimer = setTimeout(() => {
      this.nextTab(false); // Don't focus when auto-switching
      this.startAutoSwitch(); // Restart for next cycle
    }, this.autoSwitchIntervalValue);

    if (this.showProgressBarValue) {
      this.startProgressBar();
    }
  }

  stopAutoSwitch() {
    if (this.autoSwitchTimer) {
      clearTimeout(this.autoSwitchTimer);
      this.autoSwitchTimer = null;
    }
    this.stopProgressBar();
    this.resetProgressBar();
  }

  stopProgressBar() {
    if (this.hasProgressBarTarget) {
      // Stop the transition by removing it and keeping current width
      const currentWidth = this.progressBarTarget.getBoundingClientRect().width;
      const containerWidth = this.progressBarTarget.parentElement.getBoundingClientRect().width;
      const currentProgress = (currentWidth / containerWidth) * 100;

      this.progressBarTarget.style.transition = "none";
      this.progressBarTarget.style.width = `${currentProgress}%`;
      this.currentProgress = currentProgress;
    }
  }

  pauseAutoSwitch() {
    if (!this.autoSwitchValue || this.isPaused) return;

    this.isPaused = true;
    const elapsed = Date.now() - this.startTime;
    this.remainingTime = Math.max(0, this.autoSwitchIntervalValue - elapsed);

    // Stop progress bar and calculate remaining time
    if (this.showProgressBarValue) {
      this.stopProgressBar();
    }

    if (this.autoSwitchTimer) {
      clearTimeout(this.autoSwitchTimer);
      this.autoSwitchTimer = null;
    }
  }

  resumeAutoSwitch() {
    if (!this.autoSwitchValue || !this.isPaused) return;

    this.isPaused = false;
    this.startTime = Date.now() - (this.autoSwitchIntervalValue - this.remainingTime); // Adjust start time to account for elapsed time

    this.autoSwitchTimer = setTimeout(() => {
      this.nextTab(false); // Don't focus when auto-switching
      this.startAutoSwitch(); // Restart for next cycle
    }, this.remainingTime);

    if (this.showProgressBarValue) {
      this.resumeProgressBar();
    }
  }

  restartAutoSwitch() {
    if (!this.autoSwitchValue) return;

    const wasAlreadyPaused = this.isPaused;
    this.stopAutoSwitch();
    this.currentProgress = 0;

    if (wasAlreadyPaused) {
      // If we were paused (e.g., due to hover), stay paused after manual tab change
      this.isPaused = true;
      this.remainingTime = this.autoSwitchIntervalValue;
      // Don't start the timer, just reset the progress bar
      if (this.showProgressBarValue) {
        this.resetProgressBar();
      }
    } else {
      // If we weren't paused, restart normally
      this.isPaused = false;
      this.startAutoSwitch();
    }
  }

  // Progress bar methods
  startProgressBar() {
    if (!this.hasProgressBarTarget) return;

    // Always start from 0% for a new cycle
    this.progressBarTarget.style.transition = "none";
    this.progressBarTarget.style.width = "0%";

    // Force a reflow to ensure the position is set
    this.progressBarTarget.offsetHeight;

    // Set up the linear transition and animate to 100%
    this.progressBarTarget.style.transition = `width ${this.autoSwitchIntervalValue}ms linear`;
    this.progressBarTarget.style.width = "100%";
  }

  resumeProgressBar() {
    if (!this.hasProgressBarTarget) return;

    // Continue from current progress
    const startProgress = this.currentProgress || 0;

    // Set starting position without transition
    this.progressBarTarget.style.transition = "none";
    this.progressBarTarget.style.width = `${startProgress}%`;

    // Force a reflow to ensure the position is set
    this.progressBarTarget.offsetHeight;

    // Set up the linear transition for remaining time
    this.progressBarTarget.style.transition = `width ${this.remainingTime}ms linear`;
    this.progressBarTarget.style.width = "100%";
  }

  updateProgressBar(progress) {
    // This method is no longer needed with CSS transitions, but keeping for compatibility
    if (this.hasProgressBarTarget && typeof progress === "number") {
      this.progressBarTarget.style.transition = "none";
      this.progressBarTarget.style.width = `${progress}%`;
    }
  }

  resetProgressBar() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.transition = "none";
      this.progressBarTarget.style.width = "0%";
      this.currentProgress = 0;
    }
  }

  async indexValueChanged() {
    if (this.tabsCount === 0) return;

    const normalizedIndex = this.normalizedEnabledIndex(this.indexValue);
    if (normalizedIndex === -1) return;

    if (normalizedIndex !== this.indexValue) {
      this.indexValue = normalizedIndex;
      return;
    }

    const activeTab = this.tabTargets[this.indexValue];
    if (!activeTab) return;

    await this.showTab();
    this.dispatch("tab-change", {
      target: activeTab,
      detail: {
        activeIndex: this.indexValue,
      },
    });

    // Update URL with the tab ID if it has one
    // Only update URL if:
    // 1. Not during initial load, OR
    // 2. There was an anchor in the URL when the page loaded
    if (this.updateAnchorValue && (!this.initialLoad || this.hadInitialAnchor)) {
      const newTabId = activeTab.id;
      if (newTabId) {
        if (this.scrollToAnchorValue) {
          location.hash = newTabId;
        } else {
          const currentUrl = window.location.href;
          const newUrl = currentUrl.split("#")[0] + "#" + newTabId;
          if (typeof Turbo !== "undefined") {
            Turbo.navigator.history.replace(new URL(newUrl));
          } else {
            history.replaceState({}, document.title, newUrl);
          }
        }
      }
    }
  }

  async showTab() {
    this.panelTargets.forEach((panel, index) => {
      const tab = this.tabTargets[index];
      if (!tab) return;
      const disabled = this.isTabDisabled(tab);

      if (!disabled && index === this.indexValue) {
        // Show active panel
        panel.classList.remove("hidden");

        // Set active tab attributes and classes
        tab.setAttribute("aria-selected", "true");
        tab.setAttribute("tabindex", "0");
        tab.dataset.active = "true";

        if (this.hasInactiveTabClass) {
          tab.classList.remove(...this.inactiveTabClasses);
        }
        if (this.hasActiveTabClass) {
          tab.classList.add(...this.activeTabClasses);
        }
      } else {
        // Hide inactive panels
        panel.classList.add("hidden");

        // Set inactive tab attributes and classes
        tab.setAttribute("aria-selected", "false");
        tab.setAttribute("tabindex", "-1");
        delete tab.dataset.active;

        if (this.hasActiveTabClass) {
          tab.classList.remove(...this.activeTabClasses);
        }
        if (this.hasInactiveTabClass) {
          tab.classList.add(...this.inactiveTabClasses);
        }
      }
    });

    // Update select element if present
    if (this.hasSelectTarget) {
      this.selectTarget.selectedIndex = this.indexValue;
    }

    // Scroll active tab into view if needed
    if (this.scrollActiveTabIntoViewValue) {
      this.scrollToActiveTab();
    }

    // Load content if lazy loading is enabled (after making panel visible)
    if (this.lazyLoadValue && !this.loadedPanels.has(this.indexValue)) {
      // Small delay to ensure panel is visible before loading
      requestAnimationFrame(() => {
        this.#loadPanelContent(this.indexValue);
      });
    }
  }

  setInitialFocus() {
    if (this.tabsCount === 0) return;

    const normalizedIndex = this.normalizedEnabledIndex(this.indexValue);
    if (normalizedIndex === -1) {
      this.tabTargets.forEach((tab) => {
        tab.setAttribute("tabindex", "-1");
        tab.setAttribute("aria-selected", "false");
      });
      this.focusedTabIndex = -1;
      return;
    }

    if (normalizedIndex !== this.indexValue) {
      this.indexValue = normalizedIndex;
      return;
    }

    // Set initial tabindex values
    this.tabTargets.forEach((tab, index) => {
      const disabled = this.isTabDisabled(tab);
      if (!disabled && index === this.indexValue) {
        tab.setAttribute("tabindex", "0");
        tab.setAttribute("aria-selected", "true");
      } else {
        tab.setAttribute("tabindex", "-1");
        tab.setAttribute("aria-selected", "false");
      }
    });

    // Ensure focusedTabIndex is in sync with the active tab
    this.focusedTabIndex = this.indexValue;
  }

  setFocusToActiveTab() {
    const activeTab = this.tabTargets[this.indexValue];
    if (activeTab && !this.isTabDisabled(activeTab)) {
      // Find the focusable element within the tab (likely the <a> tag)
      const focusableElement = activeTab.querySelector("a") || activeTab;
      focusableElement.focus();
    }
  }

  setFocusToTab(tabIndex) {
    const tab = this.tabTargets[tabIndex];
    if (tab && !this.isTabDisabled(tab)) {
      // Find the focusable element within the tab (likely the <a> tag)
      const focusableElement = tab.querySelector("a") || tab;
      focusableElement.focus();
    }
  }

  scrollToActiveTab() {
    const activeTab = this.tabTargets[this.indexValue];
    if (activeTab) {
      activeTab.scrollIntoView({ inline: "center", behavior: "smooth" });
    }
  }

  revealTabs() {
    // Show the tabs after styling has been applied
    if (this.hasTabListTarget) {
      this.tabListTarget.classList.remove("opacity-0");
    }
  }

  get tabsCount() {
    return this.tabTargets.length;
  }

  isTabDisabled(tab) {
    if (!tab) return true;
    return tab.disabled || tab.getAttribute("aria-disabled") === "true";
  }

  isIndexDisabled(index) {
    return this.isTabDisabled(this.tabTargets[index]);
  }

  firstEnabledTabIndex() {
    return this.tabTargets.findIndex((tab) => !this.isTabDisabled(tab));
  }

  lastEnabledTabIndex() {
    for (let i = this.tabsCount - 1; i >= 0; i -= 1) {
      if (!this.isIndexDisabled(i)) return i;
    }
    return -1;
  }

  nextEnabledTabIndex(fromIndex) {
    if (this.tabsCount === 0) return -1;

    for (let step = 1; step <= this.tabsCount; step += 1) {
      const index = (fromIndex + step + this.tabsCount) % this.tabsCount;
      if (!this.isIndexDisabled(index)) return index;
    }
    return -1;
  }

  previousEnabledTabIndex(fromIndex) {
    if (this.tabsCount === 0) return -1;

    for (let step = 1; step <= this.tabsCount; step += 1) {
      const index = (fromIndex - step + this.tabsCount) % this.tabsCount;
      if (!this.isIndexDisabled(index)) return index;
    }
    return -1;
  }

  normalizedEnabledIndex(index) {
    if (this.tabsCount === 0) return -1;

    const parsed = Number.isFinite(index) ? index : parseInt(index, 10);
    const clampedIndex = Number.isFinite(parsed) ? Math.max(0, Math.min(parsed, this.tabsCount - 1)) : 0;

    if (!this.isIndexDisabled(clampedIndex)) return clampedIndex;

    const nextIndex = this.nextEnabledTabIndex(clampedIndex);
    if (nextIndex !== -1) return nextIndex;

    const previousIndex = this.previousEnabledTabIndex(clampedIndex);
    if (previousIndex !== -1) return previousIndex;

    return clampedIndex;
  }

  get anchor() {
    return document.URL.split("#").length > 1 ? document.URL.split("#")[1] : null;
  }

  getOrientation() {
    // Check if tabList target has aria-orientation attribute
    if (this.hasTabListTarget) {
      const orientation = this.tabListTarget.getAttribute("aria-orientation");
      if (orientation === "vertical") {
        return "vertical";
      } else if (orientation === "horizontal") {
        return "horizontal";
      }
    }

    // Default behavior when no aria-orientation is present: allow both directions
    // This matches your requirement: "if no aria-orientation is present, let's allow both"
    return "both";
  }

  #loadPanelContent(panelIndex) {
    const panel = this.panelTargets[panelIndex];
    if (!panel) return;

    // Mark as loaded to prevent multiple load attempts
    this.loadedPanels.add(panelIndex);

    // Check if we should use Turbo Frame lazy loading
    if (this.turboFrameSrcValue) {
      const turboFrame = panel.querySelector("turbo-frame");

      if (turboFrame) {
        // Only set src if it hasn't been set yet
        if (!turboFrame.src || turboFrame.src === "" || turboFrame.src === "about:blank") {
          // Set the src with the panel index to load specific content
          const baseUrl = this.turboFrameSrcValue;
          const separator = baseUrl.includes("?") ? "&" : "?";
          turboFrame.src = `${baseUrl}${separator}tab=${panelIndex}`;
          // Turbo will handle the loading asynchronously
        }
      }
    } else if (this.hasTemplateTarget) {
      // Use template-based lazy loading (this is synchronous and fast)
      const templates = this.templateTargets;
      const template = templates[panelIndex];

      if (template) {
        const templateContent = template.content.cloneNode(true);

        // Clear any loading indicators or placeholder content
        panel.innerHTML = "";

        // Append the template content
        panel.appendChild(templateContent);
      }
    }
  }
}
