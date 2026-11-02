# Changelog

Every change below keeps the UI, layout, wording and features exactly as they are.
Only correctness, stability and speed change.

## v4.9.0 — 2026-11-03
**The image loader could die for good; a card could stay invisible after arrow-key browsing**
- **Loader stall (severe).** Replacing the grid — a category chip, the search form, the refresh button, the
  "new wallpapers" snackbar — calls `grid.replaceChildren()`, which aborts the image requests that are in flight.
  Those aborted `<img>` elements never fire `load` or `error`, so the loader's in-flight counter (`imgActive`)
  never came back down. As soon as it reached the concurrency cap (6) the queue stopped being served for the rest
  of the session: every card stayed a grey shimmer, `imgQ` grew without bound, and nothing recovered it — not the
  cool-down, not a timer, not switching category again. Reproduced deterministically in headless Chromium against
  the live Wikimedia CDN (scroll deep so the loader is busy, then switch category 4×): `imgActive` pinned at 6,
  180 images queued, **0 of 76 cards had an image 12 s later and it never recovered**. In-flight slots are now
  tracked in a `Set` and released when the grid is dropped (`clearGrid()`), which also prunes detached entries out
  of the queue. After: `imgActive` drains 1 → 5 → 4 → 3 → 0, queue empties, **61 of 61 cards loaded in ~10 s**.
- **Invisible card after arrow-key browsing.** `openModal()` hides the clicked card with `visibility:hidden`, and
  `closeModal()` only un-hid `curCell` — but ← / → navigation (`navModal`) sets `curCell=null`, so closing the
  window left the card you opened as a permanent hole in the grid. The hidden cell is now remembered separately
  (`hiddenCell`) and always restored. Verified: `visibility` after open → ← → → close was `hidden`, now `(visible)`.
- Faster pool build on every category switch: the 2,322-item list is normalised once (`allNorm()`) and each item's
  search haystack is cached in a `WeakMap` instead of being rebuilt on every filter — **4.4 ms → 0.6 ms** per build
  (same 52 matches before and after).
- Removed the 1.2 s `querySelectorAll('.cell:not(.in)')` sweep: every cell gets `.in` when it is created, so it
  matched nothing (0 matches in every run) and only cost a full-grid DOM query every 1.2 s.
- Unchanged: layout, colours, spacing, wording, icons, animations, features. Verified over the real CDN in headless
  Chromium: 223 thumbnail requests, all `200`, 0 failed images, 0 console errors, 0 unhandled rejections, 0 failed
  requests. Scroll jank is unchanged within run-to-run noise (17 long tasks / 2.04 s over 12 scroll steps vs
  14 / 1.75 s before).

## v4.8.0 — 2026-11-02
**120 Hz support**
- The Android shell now asks the window to run at the panel's fastest refresh rate instead of the
  platform's 60 Hz default: `LayoutParams.preferredRefreshRate` is set to the highest rate the display
  reports (90 / 120 / 144 Hz panels all differ), and on Android 11+ `Window.setFrameRate(hz,
  FRAME_RATE_COMPATIBILITY_DEFAULT)` is called reflectively so the system keeps the high rate.
- Re-applied in `onResume()` because some OEM builds reset the window frame rate when the activity returns.
- No visual change: same UI, same animations — they simply get 120 samples per second instead of 60.
- The web build already follows the display (requestAnimationFrame is driven by the compositor), so no
  page-side change was needed.

## v4.7.0 — 2026-11-02
**Glass restored + measured performance work**
- Removed the phone blur cap — full 22px liquid glass, refraction, glare and shine are back on touch devices
- Startup: the 2,322-wallpaper dataset moved from a 1.35 MB JS object literal into inert JSON + `JSON.parse`
  — first paint 320 ms → **196 ms**, script finished 3030 ms → **1706 ms**
- Blurred backdrop: full-screen `filter: blur(46px)` replaced by a 20 px layer scaled ~48× (identical look, near-zero cost)
- Loading shimmer: `background-position` animation replaced by a composited `translateX` sweep
- Image loader is adaptive: 6 parallel / 45 ms when healthy, 3 / 200 ms + cool-down after a failure
- Verified against the live CDN: 82 requests, all `200`, 0 failed images, 0 console errors

## v4.6.0 — 2026-11-02
**429 image-loading fix**
- Wikimedia's thumbnail CDN was rate-limiting the app (HTTP 429) during rapid category switching, leaving
  broken grey cards. Added a throttled loader with exponential back-off and a global cool-down.
  Verified: 10 × 429 → **0**, 34/44 images → **38/38**

## v4.5.0 — 2026-11-02
**9-language interface**
- English, Gujarati, Hindi, Kannada, Malayalam, Marathi, Punjabi, Tamil, Telugu
- 131 UI strings per language; the wallpapers themselves are never touched

## v4.4.0 — 2026-11-02
**Real-network fixes**
- The "new wallpapers" pill no longer covers the header (now a bottom snackbar)
- Infinite scroll can no longer stall: scroll listener + interval + an explicit "N more wallpapers ↓" button

## v4.3.0 — 2026-11-02
- Extruded 3D launcher icon; the in-app icon tilts live with pointer/gyro
- Responsive thumbnails, `preconnect`, Performance mode

## v4.2.0 — 2026-11-02
- Cards could stay invisible (IntersectionObserver on a masonry layout); now visible on creation + a 1.2 s sweep
- Thumbnails that failed once no longer remove the whole card
- Modal open/close race fixed; live results de-duplicated by title

## v4.1.0 — 2026-11-02
- 4D app icon (launcher, in-app header, favicon)

## v4.0.0 — 2026-11-02
- First release: 2,322 credited Wikimedia Commons wallpapers, liquid-glass 4D UI, live updates, fullscreen, credits
