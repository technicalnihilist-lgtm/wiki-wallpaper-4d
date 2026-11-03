# Wiki Wallpapers 4D — performance audit (v4.9.2)

Everything below was measured, not estimated. The harness is a headless Chromium driven over CDP
through a small CONNECT relay so the app talks to the real Wikimedia CDN; for the deterministic
figures every image request is answered with one fixed bitmap, which removes network variance and
leaves layout, style and script time — the things the UI thread actually spends frames on.

Absolute numbers come from a 2-core container and are therefore inflated (a phone lays out a
500-card grid far faster). The before/after deltas, not the absolutes, are the result.

## 1. Problems found

1. **The image loader never reached its own concurrency limit.** `pumpImgs()` starts one image per
   tick and relies on the gap timer to schedule the next tick, but it never re-armed the timer after
   a start. In practice a new image was only started when a previous one *finished*, so the loader
   ran effectively serially instead of six at a time.
2. **`loading="lazy"` on grid images fought the loader.** The app sets `img.src` itself when it
   decides to load, but the attribute made the browser silently defer the fetch for any card outside
   the viewport. Those requests never fired `load`/`error`, so their six loader slots stayed occupied
   and the queue starved: cards in the viewport sat on grey shimmer with 40+ images queued.
3. **Every rendered card held an image and a running animation forever.** After a deep scroll the
   grid holds 500+ cards; all of them had requested, decoded and kept a bitmap, and every unloaded
   card ran a composited shimmer animation (`will-change: transform`), i.e. hundreds of layers.
4. **Forced synchronous layout on interaction paths.** `applyTilt()` called
   `getBoundingClientRect()` on the hovered card *on every pointer frame*; the header icon did the
   same on every mouse move anywhere in the app; the modal photo did it on every move inside the
   preview; `checkSentinel()` read layout on every scroll frame while the grid was being extended;
   and a 900 ms watchdog read `document.documentElement.scrollHeight` for good measure.
5. **One DOM insertion per card.** `renderChunk()` appended 18 cards one by one to a live grid.

## 2. Root causes

- (1) is a control-flow bug: the `while` loop `return`s after a single start and the only thing that
  re-entered the pump was an image event.
- (2)+(3) are a policy conflict: three different lazy-loading mechanisms (the app's own loader, the
  `loading` attribute, and the viewport) were stacked on top of each other without a single owner.
- (4) is layout thrash: reads of geometry interleaved with style writes force a full layout of a
  document that contains thousands of nodes, several times per frame.
- (5) is batching: each `append` invalidates layout for the whole grid instead of once per chunk.

## 3. Files and components modified

`index.html` only (the app is one self-contained file): the image loader, the grid renderer, the
tilt/parallax handlers, the sentinel/scroll watchdog, the more-button, and two CSS rules for
off-screen cards. No HTML, no strings, no colours, no layout rules, no API integration changed.

## 4. Optimisations implemented

- Loader: the tick re-arms itself (`setTimeout(pumpImgs, IMG_GAP)`) so the six-way concurrency is
  actually used; `loading="lazy"` removed from grid images (the app owns loading now).
- Two queues: cards inside the viewport band go to a high-priority FIFO queue, everything else to
  the normal one — visible cards are fetched first, in document order.
- `IntersectionObserver` (800 px band) decides when a card may request its image; cards outside the
  band get `.far`, which stops their shimmer animation and drops its composited layer.
- Geometry caching: card rect per hover (invalidated on scroll), header-icon rect per scroll offset,
  modal photo rect per window open. Zero `getBoundingClientRect()` calls per pointer frame.
- `checkSentinel()` limited to one layout read per 150 ms with a trailing check; the 900 ms
  `scrollHeight` watchdog replaced by a visibility-gated call that needs no layout read.
- `renderChunk()` builds a `DocumentFragment` and inserts the chunk once; observers are attached
  after insertion (observing a detached node never reports an intersection).
- `updateMoreBtn()` only writes to the DOM when its label actually changes.

## 5. Before / after

Deterministic harness (images stubbed), same viewport, same scenario, ~500 cards in the DOM:

| metric (whole run)        | before   | after    |
|---------------------------|----------|----------|
| style recalc time         | 21,702 ms| 2,543 ms |
| style recalcs             | 807      | 729      |
| total long-task time      | 111,407 ms | 68,298 ms |
| pointer-tilt long tasks   | 36,858 ms| 14,925 ms |
| pointer-tilt style time   | 8,823 ms | 338 ms   |
| modal open/close layout   | 420 ms   | 33 ms    |
| modal open/close long tasks| 1,014 ms| 632 ms   |
| settings panel style time | 117 ms   | 18 ms    |
| first contentful paint    | 2,200 ms | 2,240 ms |

Real CDN, after a fast 18,000 px scroll: images actually loaded **45 → 133** in the same window
(3×), with **0** HTTP 429, **0** failed requests and 151 thumbnail requests all `200`.

Visual regression: pixel comparison of the same frame in both builds — first screen **0 px**
different, wallpaper preview **0 px** different, settings panel and light theme 0.04 % (five
off-screen cards that are now intentionally not pre-loaded).

## 6. Remaining limitations

- The grid is not virtualised: every card ever rendered stays in the DOM, so a full layout pass still
  costs more the deeper you scroll. Windowing would cut this further but changes scroll anchoring and
  the "N more wallpapers" behaviour, so it was left alone.
- Bitmaps for cards that have been on screen stay decoded until Chromium evicts them under memory
  pressure; there is no explicit LRU. Releasing them manually would flash placeholders on scroll-back.
- No physical Android device or emulator was available here, so there are no GPU/CPU profiler traces
  and no battery measurements; the figures above are UI-thread timings from headless Chromium.
- 90/120 Hz frame pacing could not be measured (no real display). All animations remain
  transform/opacity only, so they follow the display refresh rate as before.
