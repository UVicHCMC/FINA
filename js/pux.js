/* =========================
   TOC active heading
   ========================= */
(function () {
  "use strict";

  function initToc() {
	const toc = document.querySelector(".subnav");
	if (!toc) return;

	const links = Array.from(toc.querySelectorAll('a[href^="#"]'));
	if (!links.length) return;

	const items = links
	  .map((link) => {
		const href = link.getAttribute("href");
		if (!href || href.length < 2) return null;

		const id = decodeURIComponent(href.slice(1));
		const section = document.getElementById(id);
		if (!section) return null;

		// Track the section heading, not the whole section. This keeps
		// active-state changes tied to the actual section entry point.
		const heading = section.querySelector("h2");
		if (!heading) return null;

		return { id, link, heading };
	  })
	  .filter(Boolean);

	if (!items.length) return;

	// Fast lookups for observer targets and hash targets.
	const headingToId = new Map(items.map((item) => [item.heading, item.id]));
	const itemById = new Map(items.map((item) => [item.id, item]));

	// Headings currently intersecting the observer region.
	const visibleIds = new Set();

	let activeId = null;
	let rafId = 0;

	// Heading becomes active once it crosses this viewport line.
	let activationLine = 24;

	function updateActivationLine() {
	  const header = document.querySelector(".site-masthead");
	  const headerHeight = header ? header.getBoundingClientRect().height : 0;

	  // Push the switch point below the masthead so the TOC stays aligned
	  // with the visible reading area instead of raw viewport top.
	  activationLine = headerHeight + 24;
	}

	function setActive(id) {
	  if (!id || id === activeId) return;

	  activeId = id;

	  for (const item of items) {
		const isActive = item.id === id;
		item.link.classList.toggle("active", isActive);

		if (isActive) {
		  item.link.setAttribute("aria-current", "location");
		} else {
		  item.link.removeAttribute("aria-current");
		}
	  }
	}

	function findCurrentIdByScan() {
	  // Fallback resolver: headings are in document order, so binary search
	  // finds the last heading above the activation line with fewer reads
	  // than a full linear scan.
	  let low = 0;
	  let high = items.length - 1;
	  let result = items[0].id;

	  while (low <= high) {
		const mid = (low + high) >> 1;
		const top = items[mid].heading.getBoundingClientRect().top;

		if (top <= activationLine) {
		  result = items[mid].id;
		  low = mid + 1;
		} else {
		  high = mid - 1;
		}
	  }

	  return result;
	}

	function resolveFromVisibleHeadings() {
	  if (!visibleIds.size) return null;

	  let candidateId = null;

	  for (const item of items) {
		if (!visibleIds.has(item.id)) continue;

		const top = item.heading.getBoundingClientRect().top;

		// The current section is the last visible heading that has crossed
		// the activation line.
		if (top <= activationLine) {
		  candidateId = item.id;
		} else {
		  break;
		}
	  }

	  return candidateId;
	}

	function resolveActiveId() {
	  return resolveFromVisibleHeadings() || findCurrentIdByScan();
	}

	function update() {
	  rafId = 0;
	  setActive(resolveActiveId());
	}

	function scheduleUpdate() {
	  // Collapse scroll/resize/observer bursts into one paint-cycle update.
	  if (rafId) return;
	  rafId = window.requestAnimationFrame(update);
	}

	function handleScroll() {
	  scheduleUpdate();
	}

	function handleResize() {
	  updateActivationLine();
	  scheduleUpdate();
	}

	if ("IntersectionObserver" in window) {
	  const observer = new IntersectionObserver(
		(entries) => {
		  for (const entry of entries) {
			const id = headingToId.get(entry.target);
			if (!id) continue;

			if (entry.isIntersecting) {
			  visibleIds.add(id);
			} else {
			  visibleIds.delete(id);
			}
		  }

		  scheduleUpdate();
		},
		{
		  root: null,

		  // Bias observation toward the upper reading zone so headings lower
		  // in the viewport do not influence active state too early.
		  rootMargin: "0px 0px -70% 0px",
		  threshold: 0
		}
	  );

	  for (const item of items) {
		observer.observe(item.heading);
	  }
	}

	updateActivationLine();

	// Honour deep links immediately, then let the next scheduled update
	// reconcile against final layout/scroll position.
	if (location.hash) {
	  const id = decodeURIComponent(location.hash.slice(1));
	  if (itemById.has(id)) {
		setActive(id);
	  }
	}

	scheduleUpdate();

	window.addEventListener("scroll", handleScroll, { passive: true });
	window.addEventListener("resize", handleResize, { passive: true });
	window.addEventListener("pageshow", scheduleUpdate, { passive: true });

	window.addEventListener("hashchange", () => {
	  const id = decodeURIComponent(location.hash.slice(1));

	  if (itemById.has(id)) {
		setActive(id);
	  }

	  scheduleUpdate();
	});
  }

  if (document.readyState === "loading") {
	document.addEventListener("DOMContentLoaded", initToc);
  } else {
	initToc();
  }
})();


/**
 * Popover navigation controller using the native Popover API.
 *
 * This script does NOT implement its own open/close logic. All visibility is controlled
 * entirely by HTML attributes such as:
 *
 *   - popover="auto" on the navigation element
 *   - popovertarget / popovertargetaction on buttons
 *
 * Instead, this script adds the behavioural rules and accessibility mechanics that the
 * Popover API does not handle automatically:
 *
 * 1) Desktop enforcement
 *    At or above the configured desktop breakpoint (--desktop-break in :root, pixels only),
 *    the navigation popover is forcibly closed and cannot remain open. This ensures the
 *    popover is strictly a mobile-only navigation pattern.
 *
 * 2) Focus trapping while open
 *    When the popover opens, keyboard focus is moved inside it and constrained so Tab and
 *    Shift+Tab cycle only within the popover. This prevents keyboard users from navigating
 *    to background content while the menu is open.
 *
 * 3) Focus restoration on close
 *    When the popover closes (via toggle button, close button, ESC, click-away, or breakpoint
 *    change), focus is restored to the element that originally opened it. This preserves
 *    logical keyboard navigation flow.
 *
 * 4) Popover API–driven state synchronization
 *    The script listens only to the Popover API "toggle" event, which fires for ALL open/close
 *    causes. This guarantees consistent behaviour regardless of how the popover was closed.
 *
 * This script intentionally avoids:
 *   - manual toggle logic
 *   - fallback implementations for unsupported browsers
 *   - redundant state tracking outside the Popover API
 *
 * Result: a minimal, standards-compliant mobile navigation controller.
 */

(function initWhenReady() {

	// Ensure initialization runs only after the DOM is fully parsed.
	// This guarantees required elements can be found safely.
	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", init);
	} else {
		init();
	}

	function init() {

		// Locate the toggle button and the popover navigation element.
		// These IDs must match the HTML structure.
		const toggleBtn = document.getElementById("site-menu-toggle");
		const popoverEl = document.getElementById("site-navigation");

		// Abort initialization if required elements are missing.
		if (!toggleBtn || !popoverEl) return;


		// Verify Popover API support before attaching any behaviour.
		// This script relies entirely on native Popover API methods.
		const hasPopoverAPI =
			typeof popoverEl.showPopover === "function" &&
			typeof popoverEl.hidePopover === "function" &&
			typeof popoverEl.togglePopover === "function";

		// Abort if Popover API is not available.
		if (!hasPopoverAPI) return;


		// Determine whether the popover is currently open.
		// The :popover-open pseudo-class reflects the actual open state.
		function isOpen() {
			return popoverEl.matches(":popover-open");
		}


		// Close the popover only if it is open.
		// This avoids unnecessary toggle events.
		function closePopover() {
			if (popoverEl.matches(":popover-open")) {
				popoverEl.hidePopover();
			}
		}


		// Read the desktop breakpoint from CSS custom property --desktop-break.
		// Accepts values in pixels ("768px" or "768").
		// Falls back to 768px if missing or invalid.
		function readDesktopBreakPx() {

			const raw = getComputedStyle(document.documentElement)
				.getPropertyValue("--desktop-break")
				.trim();

			if (!raw) return 768;

			const match = raw.match(/^([0-9]*\.?[0-9]+)\s*(px)?$/i);

			return match ? Number(match[1]) : 768;
		}


		// Create a MediaQueryList that tracks whether viewport is at desktop width.
		const breakPx = readDesktopBreakPx();
		const mqDesktop = window.matchMedia(`(min-width: ${breakPx}px)`);


		// Enforce rule: popover must not remain open at desktop width.
		// If open when entering desktop width, it is immediately closed.
		function enforceDesktopClosed() {

			if (mqDesktop.matches) {
				closePopover();
			}
		}


		// Selector list defining elements considered keyboard-focusable.
		// Used to build the focus trap inside the popover.
		const FOCUSABLE_SELECTOR = [
			"a[href]",
			"area[href]",
			"button:not([disabled])",
			"input:not([disabled]):not([type='hidden'])",
			"select:not([disabled])",
			"textarea:not([disabled])",
			"iframe",
			"object",
			"embed",
			"[contenteditable='true']",
			"[tabindex]:not([tabindex='-1'])"
		].join(",");


		// Collect focusable descendants of the popover and filter out elements
		// that are hidden, non-interactive, or not currently visible.
		function getFocusable() {

			const candidates = Array.from(
				popoverEl.querySelectorAll(FOCUSABLE_SELECTOR)
			);

			return candidates.filter((el) => {

				// Ignore elements explicitly marked hidden.
				if (el.hasAttribute("hidden")) return false;

				// Ignore elements inside closed <details>.
				const details = el.closest("details");
				if (details && !details.open) return false;

				// Ignore elements that are not visible.
				const style = getComputedStyle(el);
				if (style.display === "none" || style.visibility === "hidden") {
					return false;
				}

				// Ignore elements without rendered layout boxes.
				return el.getClientRects().length > 0;
			});
		}


		// Store the element that had focus before the popover opened.
		// Used to restore focus after closing.
		let restoreFocusTo = null;


		// Track whether focus trapping is currently active.
		let trapActive = false;


		// Move focus to the first focusable element inside the popover.
		// If none exist, focus the popover container itself.
		function focusFirstInside() {

			const focusables = getFocusable();

			if (focusables.length > 0) {

				focusables[0].focus({ preventScroll: true });
				return;
			}

			// Ensure popover itself can receive programmatic focus.
			if (!popoverEl.hasAttribute("tabindex")) {
				popoverEl.setAttribute("tabindex", "-1");
			}

			popoverEl.focus({ preventScroll: true });
		}


		// Handle Tab and Shift+Tab to prevent focus from escaping the popover.
		function onKeydownTrap(event) {

			if (!isOpen()) return;

			if (event.key !== "Tab") return;

			const focusables = getFocusable();

			if (focusables.length === 0) {

				event.preventDefault();
				return;
			}

			const first = focusables[0];
			const last = focusables[focusables.length - 1];

			const active = document.activeElement;


			// Wrap backward navigation from first element to last.
			if (event.shiftKey && active === first) {

				event.preventDefault();
				last.focus();
				return;
			}


			// Wrap forward navigation from last element to first.
			if (!event.shiftKey && active === last) {

				event.preventDefault();
				first.focus();
			}
		}


		// Activate focus trap when popover opens.
		// Saves previous focus and binds keyboard handler.
		function activateTrap() {

			if (trapActive) return;

			trapActive = true;

			restoreFocusTo = document.activeElement;

			document.addEventListener("keydown", onKeydownTrap);

			queueMicrotask(focusFirstInside);
		}


		// Deactivate focus trap when popover closes.
		// Removes keyboard handler and restores prior focus.
		function deactivateTrap() {

			if (!trapActive) return;

			trapActive = false;

			document.removeEventListener("keydown", onKeydownTrap);

			const target =
				restoreFocusTo && document.contains(restoreFocusTo)
					? restoreFocusTo
					: toggleBtn;

			const active = document.activeElement;

			const shouldRestore =
				!active ||
				active === document.body ||
				(active && popoverEl.contains(active));

			if (shouldRestore) {

				queueMicrotask(() => {
					target.focus({ preventScroll: true });
				});
			}

			restoreFocusTo = null;
		}


		// Listen for Popover API toggle events.
		// Fires on open and close regardless of trigger source.
		popoverEl.addEventListener("toggle", (event) => {

			const open =
				event && event.newState
					? event.newState === "open"
					: isOpen();


			// Prevent popover from remaining open at desktop width.
			if (open && mqDesktop.matches) {

				closePopover();
				return;
			}


			// Enable or disable focus trap based on open state.
			if (open) {
				activateTrap();
			} else {
				deactivateTrap();
			}
		});


		// Listen for viewport breakpoint transitions.
		// Ensures popover closes immediately when entering desktop width.
		if (typeof mqDesktop.addEventListener === "function") {

			mqDesktop.addEventListener("change", enforceDesktopClosed);

		} else {

			mqDesktop.addListener(enforceDesktopClosed);
		}


		// Apply desktop enforcement immediately during initialization.
		enforceDesktopClosed();


		// Activate focus trap if popover starts open on mobile.
		if (isOpen() && !mqDesktop.matches) {

			activateTrap();
		}
	}
})();

/* =========================
   Splash arrow bounce
   ========================= */
(function () {
  "use strict";

  function initSplashBounce() {
	const el = document.querySelector(".splash-down-link img");
	if (!el) return;

	function restartBounceCycle() {
	  el.classList.remove("bounce-run");
	  void el.offsetWidth;
	  el.classList.add("bounce-run");

	  setTimeout(restartBounceCycle, (1.6 * 5 * 1000) + 7000);
	}

	restartBounceCycle();
  }

  if (document.readyState === "loading") {
	document.addEventListener("DOMContentLoaded", initSplashBounce);
  } else {
	initSplashBounce();
  }
})();

/* =========================
   Header opacity on scroll
   ========================= */
(function () {
  "use strict";

  function initHeaderOpacity() {
	const header = document.querySelector("header");
	if (!header) return;

	const threshold = 40;

	function updateHeaderOpacity() {
	  header.classList.toggle("header-transparent", window.scrollY > threshold);
	}

	updateHeaderOpacity();
	window.addEventListener("scroll", updateHeaderOpacity, { passive: true });
  }

  if (document.readyState === "loading") {
	document.addEventListener("DOMContentLoaded", initHeaderOpacity);
  } else {
	initHeaderOpacity();
  }
})();

/* =========================
   Fade-up reveal on scroll
   ========================= */
(function () {
  "use strict";

  function isInViewport(el) {
	const rect = el.getBoundingClientRect();
	const vh = window.innerHeight || document.documentElement.clientHeight;
	return rect.top < vh && rect.bottom > 0;
  }

  function initFadeSelected() {
	const main = document.querySelector("main");
	if (!main) return;

	const elements = main.querySelectorAll(
	  "h1, h2, h3, h4, h5, h6, img, div"
	);
	if (!elements.length) return;

	if (
	  window.matchMedia &&
	  window.matchMedia("(prefers-reduced-motion: reduce)").matches
	) {
	  elements.forEach(el =>
		el.classList.remove("fade-up-init", "fade-up-visible")
	  );
	  return;
	}

	const toObserve = [];

	elements.forEach(el => {
	  if (isInViewport(el)) {
		el.classList.remove("fade-up-init", "fade-up-visible");
	  } else {
		el.classList.add("fade-up-init");
		toObserve.push(el);
	  }
	});

	if (!toObserve.length) return;

	if (!("IntersectionObserver" in window)) {
	  toObserve.forEach(el => el.classList.add("fade-up-visible"));
	  return;
	}

	function handleIntersection(entries, observer) {
	  entries.forEach(entry => {
		if (!entry.isIntersecting) return;
		entry.target.classList.add("fade-up-visible");
		observer.unobserve(entry.target);
	  });
	}

	const observer = new IntersectionObserver(handleIntersection, {
	  threshold: 0.2
	});

	toObserve.forEach(el => observer.observe(el));
  }

  if (document.readyState === "loading") {
	document.addEventListener("DOMContentLoaded", initFadeSelected);
  } else {
	initFadeSelected();
  }
})();

/* =========================
   Scroll-to-top button
   ========================= */
(function () {
  "use strict";

  function initScrollToTop() {
	const scrollBtn = document.querySelector("#scroll-to-top");
	if (!scrollBtn) return;

	const threshold = 300;

	function updateScrollButtonVisibility() {
	  scrollBtn.classList.toggle("is-visible", window.scrollY > threshold);
	}

	function handleScrollToTopClick() {
	  window.scrollTo({ top: 0, behavior: "smooth" });
	}

	scrollBtn.addEventListener("click", handleScrollToTopClick);
	window.addEventListener("scroll", updateScrollButtonVisibility, { passive: true });
	updateScrollButtonVisibility();
  }

  if (document.readyState === "loading") {
	document.addEventListener("DOMContentLoaded", initScrollToTop);
  } else {
	initScrollToTop();
  }
})();