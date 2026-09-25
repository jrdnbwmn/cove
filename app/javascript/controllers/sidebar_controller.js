import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = [
    "desktopSidebar",
    "mobileSidebar",
    "contentTemplate",
    "sharedContent",
    "desktopContent",
    "mobileBackdrop",
    "mobilePanel",
  ];
  static values = {
    storageKey: { type: String, default: "sidebarOpen" },
  };

  connect() {
    // Bind the handler once so we can properly remove it later
    this.boundHandleToggle = this.handleToggle.bind(this);
    this.boundHandleBreakpointChange = this.handleBreakpointChange.bind(this);
    // AIDEV-NOTE: 1024px (Tailwind's `lg`) is the line between the auto-collapsed
    // rail (768-1023px) and the full sidebar default (1024px+). Only used as a
    // *default* when the user hasn't manually toggled yet (see handleToggle).
    this.desktopBreakpoint = window.matchMedia("(min-width: 1024px)");

    // Clone the sidebar content for both mobile and desktop
    if (this.hasContentTemplateTarget) {
      // Clone content for desktop (only if not already cloned)
      // Check if nav element exists (the actual cloned content)
      if (this.hasDesktopContentTarget && !this.desktopContentTarget.querySelector("nav")) {
        const desktopClone = this.contentTemplateTarget.content.cloneNode(true);
        this.desktopContentTarget.appendChild(desktopClone);
      }

      // Clone content for mobile (only if not already cloned)
      if (this.hasSharedContentTarget && !this.sharedContentTarget.querySelector("nav")) {
        const mobileClone = this.contentTemplateTarget.content.cloneNode(true);
        this.sharedContentTarget.appendChild(mobileClone);

        // Update the close button in mobile view to show X icon and have mobile close action
        const mobileNav = this.sharedContentTarget.querySelector("nav");
        if (mobileNav) {
          const closeButton = mobileNav.querySelector('[data-action*="sidebar#close"]');
          if (closeButton) {
            closeButton.setAttribute("data-action", "click->sidebar#closeMobile");
            closeButton.classList.remove("cursor-w-resize");
            closeButton.setAttribute("aria-label", "Close sidebar");

            // Replace the collapse icon with an X icon
            const svg = closeButton.querySelector("svg");
            if (svg) {
              svg.innerHTML =
                '<g fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" stroke="currentColor"><line x1="13.25" y1="4.75" x2="4.75" y2="13.25"></line><line x1="13.25" y1="13.25" x2="4.75" y2="4.75"></line></g>';
            }
          }
        }
      }
    }

    if (this.hasDesktopSidebarTarget) {
      // Temporarily disable transitions to prevent animation on page load
      this.desktopSidebarTarget.style.transition = "none";

      const initialOpen = this.desiredOpenState();

      // AIDEV-NOTE: the native `toggle` event fires asynchronously, so it
      // can land *after* this method returns even though addEventListener
      // is called below — attach-order alone doesn't protect against this
      // assignment being mistaken for a manual toggle and persisted. Guard
      // with a flag the handler itself clears instead, and only set it when
      // the value is actually changing (no change means no event, which
      // would otherwise leave the flag stuck for the next real toggle).
      if (this.desktopSidebarTarget.open !== initialOpen) {
        this.isProgrammaticToggle = true;
      }
      this.desktopSidebarTarget.open = initialOpen;

      // Re-enable transitions after a brief delay
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          this.desktopSidebarTarget.style.transition = "";
        });
      });

      // Listen for toggle events to save the state.
      this.desktopSidebarTarget.addEventListener("toggle", this.boundHandleToggle);
      // Re-apply the breakpoint default on resize, but only until the user
      // manually toggles (see handleToggle/handleBreakpointChange).
      this.desktopBreakpoint.addEventListener("change", this.boundHandleBreakpointChange);
    }
  }

  disconnect() {
    if (this.hasDesktopSidebarTarget && this.boundHandleToggle) {
      this.desktopSidebarTarget.removeEventListener("toggle", this.boundHandleToggle);
    }
    if (this.desktopBreakpoint && this.boundHandleBreakpointChange) {
      this.desktopBreakpoint.removeEventListener("change", this.boundHandleBreakpointChange);
    }
  }

  // AIDEV-NOTE: below 1024px the auto-collapsed rail always resets on the
  // next load/resize, regardless of any previously saved preference —
  // localStorage is only ever consulted (read or written) at 1024px+.
  desiredOpenState() {
    if (!this.desktopBreakpoint.matches) return false;

    const savedState = localStorage.getItem(this.storageKeyValue);
    return savedState !== null ? savedState === "true" : true;
  }

  // AIDEV-NOTE: open()/close()/toggle() persist synchronously, right here,
  // instead of relying on the native `toggle` event the way the programmatic
  // corrections below do. Chrome coalesces same-tick `.open` writes into a
  // single (sometimes misleadingly-labeled) toggle event — if a breakpoint
  // correction (handleBreakpointChange) lands in the same tick as a user's
  // click, an event-driven save can silently lose the user's change
  // entirely rather than merely being late. Persisting here has no such
  // race: it runs at the exact moment we know this is a real user choice.
  persist() {
    if (!this.desktopBreakpoint.matches) return;
    localStorage.setItem(this.storageKeyValue, this.desktopSidebarTarget.open.toString());
  }

  handleToggle(event) {
    if (this.isProgrammaticToggle) {
      // A programmatic default change (initial load or breakpoint resize),
      // not a manual toggle: don't persist it as if the user had made an
      // explicit choice.
      this.isProgrammaticToggle = false;
      return;
    }

    // Fallback for toggles that don't go through open()/close()/toggle()
    // below — e.g. a native click on the collapsed rail's own clickable
    // area, which toggles the <details> directly. Redundant (and harmless)
    // for toggles that already persisted synchronously above.
    this.persist();
  }

  handleBreakpointChange(event) {
    if (!this.hasDesktopSidebarTarget) return;

    const desiredOpen = this.desiredOpenState();
    if (this.desktopSidebarTarget.open === desiredOpen) return;

    this.isProgrammaticToggle = true;
    this.desktopSidebarTarget.open = desiredOpen;
  }

  open() {
    if (this.hasDesktopSidebarTarget) {
      this.desktopSidebarTarget.open = true;
      this.persist();
    }
  }

  close() {
    if (this.hasDesktopSidebarTarget) {
      this.desktopSidebarTarget.open = false;
      this.persist();
    }
  }

  toggle() {
    if (this.hasDesktopSidebarTarget) {
      this.desktopSidebarTarget.open = !this.desktopSidebarTarget.open;
      this.persist();
    }
  }

  openMobile() {
    if (this.hasMobileSidebarTarget) {
      // Set initial hidden states
      if (this.hasMobileBackdropTarget) {
        this.mobileBackdropTarget.style.opacity = "0";
      }
      if (this.hasMobilePanelTarget) {
        this.mobilePanelTarget.style.transform = "translateX(-100%)";
      }

      // Remove hidden class
      this.mobileSidebarTarget.classList.remove("hidden");

      // Trigger transition on next frame
      requestAnimationFrame(() => {
        if (this.hasMobileBackdropTarget) {
          this.mobileBackdropTarget.style.opacity = "1";
        }
        if (this.hasMobilePanelTarget) {
          this.mobilePanelTarget.style.transform = "translateX(0)";
        }
      });
    }
  }

  closeMobile() {
    if (this.hasMobileSidebarTarget) {
      // Trigger closing transition
      if (this.hasMobileBackdropTarget) {
        this.mobileBackdropTarget.style.opacity = "0";
      }
      if (this.hasMobilePanelTarget) {
        this.mobilePanelTarget.style.transform = "translateX(-100%)";
      }

      // Wait for transition to complete before hiding
      setTimeout(() => {
        if (this.hasMobileSidebarTarget) {
          this.mobileSidebarTarget.classList.add("hidden");
        }
      }, 300); // Match the transition duration
    }
  }
}
