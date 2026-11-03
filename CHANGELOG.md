# Changelog

Every change below keeps the UI, layout, wording and features exactly as they are.
Only correctness, stability and speed change.

## v5.3.0 — 2026-11-03
**Six new languages, and a worldwide collection (6,288 wallpapers)**
- **Languages: 9 → 15.** Spanish, French, German, Portuguese, Japanese and Chinese join English, Gujarati,
  Hindi, Kannada, Malayalam, Marathi, Punjabi, Tamil and Telugu. Each new language carries 107 translated UI
  strings (search, statuses, toasts, preview labels, all settings, credits, downloads). Category names are
  deliberately left in English so a chip never turns into an awkward half-translation; missing keys fall back
  to English, never to a raw `c_xxx` key.
- Fixed a long-standing gap found while testing: the language picker toasted `t_lang`, a key that was never
  defined, so switching language showed the literal text "t_lang". It now says "Language changed" in every
  language that has it.
- **Global collection: 4,487 → 6,288 wallpapers** (+1,801). Eighteen new regions, each ~100 images:
  Japan 110, China 101, Spain 109, France 110, Italy 103, Germany 110, United Kingdom 110, USA 107,
  Brazil 108, Africa 110, Middle East 110, Korea 107, Russia 97, Greece 110, Mexico 106, Egypt 97,
  Thailand 110, India 104. Same rules as before: real creator + licence from the Commons API, ≥1600×900,
  photo aspect ratio, maps/logos/scans rejected.
- Region chips (Japan, China, Spain, India) are pinned next to the topic chips, the rest of the regions follow
  by image count; the single chip row is unchanged.
- **The embedded list is stored compactly so 6,288 wallpapers still fit a light file:** each entry keeps only
  the thumbnail path (the host is added back at read time) and drops the Commons page URL, which is rebuilt
  from that path — verified lossless on all 6,288 entries (page, thumb, licence and credit identical). The
  per-image description line was dropped to keep the file small. 3.53 MB → **2.58 MB**.
- Verified: switching to Japanese, Chinese and Spanish renders the whole UI in that language (placeholder,
  chips, meta line, preview tabs) with 0 console errors; 15 languages in the picker; preview shows the rebuilt
  Commons page link and correct credit; boot 2.0 s in the test container (was 2.2 s).

## v5.2.1 — 2026-11-03
**Google Images now feeds in live — and a quota error can no longer kill a source**
- **Live polling is per source and walks deeper every time.** Google (and every relevance-sorted API)
  returns the same first page forever, so polling page 1 always found "nothing new". Each poll now asks
  for the next page and wraps around after six, so freshly indexed images keep arriving:
  verified `start=1 → 11 → 21` across three polls, with the "🆕 3 new wallpapers — see them" pill raised.
- **Google is polled every 20 minutes, not every 150 s.** The free Custom Search tier allows 100 queries a
  day; 150 s would burn it in about four hours. 20 minutes ≈ 72 queries/day, leaving headroom.
- **Quota is not a fault.** A 403/429 whose body says quota / rate limit / daily limit now pauses that
  source for an hour instead of counting as a failure, so it no longer gets marked dead and removed.
  Verified: with the endpoint answering `dailyLimitExceeded`, the Google chip stayed in the row and the
  rest of the feed was unaffected.
- Nothing else changed: same single chip row, same 4,487 Wikimedia wallpapers, same credits.

## v5.2.0 — 2026-11-03
**Google Images added — through Google's official Custom Search API, licence-filtered**
- New 12th source, **Google Images**. It does not scrape google.com/images (that breaks Google's terms and
  would pull in all-rights-reserved pictures with no licence); it uses the documented **Custom Search JSON
  API** with `searchType=image` and `rights=cc_publicdomain,cc_attribute,cc_sharealike`, i.e. the same
  "Usage rights" filter Google Images offers. Only Creative Commons / public-domain results come through.
- Google returns no per-image licence text and no creator, so those items honestly show
  **"Unknown creator"**, a licence line of "CC / PD (Google filter)" and a **View original** link to the page
  the image was found on. Nothing is invented.
- Two credentials are needed (API key + search engine ID / CX) and both are entered in
  **Settings → 🌐 Image sources**; the source stays hidden until both are present, exactly like the other
  key-gated sources. Free tier is 100 queries/day.
- Verified with a stubbed Custom Search response: the chip appears once both credentials exist, items render
  with correct resolution and credit rows, the settings section now shows 6 key fields (4 single-key sources
  + 2 for Google) and the run finished with 0 console errors. The fetch path was also checked against the
  live `www.googleapis.com` endpoint (reachable; without a key it answers 400, which the source treats as a
  failure and removes itself as usual).

## v5.1.1 — 2026-11-03
**All chips on one line**
- The two chip rows (image sources on top, categories below) are now a **single scrollable row**:
  every category first — All, 🆕 New, Cars, Animal, Art, Cartoons, Robots, Anime & Manga, Motorcycles, …
  — then a thin divider, then the image sources (Wikimedia, All sources (N), ♥ Favourites and each source).
- The sliding glass lens stays on the active category; the selected source is marked with a soft filled
  chip in the same row, so both states are readable without a second row.
- Header is one row shorter on every screen. Verified at 1280×900 and 390×844: row height 37 px, no
  wrapping (scrollWidth 3270 px, clientWidth 1096 / 342 px), lens lands exactly on the clicked chip,
  category and source clicks still switch the feed.

## v5.1.0 — 2026-11-03
**Wikimedia library doubled to 4,487 wallpapers — and broken sources now remove themselves**
- **Library 2,322 → 4,487** (+2,165 new images), with 19 new topics on top of the old set: Cars (116),
  Motorcycles (129), Art (128), Animal (170), Cartoons (129), Anime & Manga (78), Robots (124),
  Spacecraft (123), Aircraft (53), Trains (112), Ships (128), Castles (108), Street art (130),
  Underwater (77), Aurora (144), Volcano (132), City (186), Neon (127), Food (127).
  Every new entry was pulled from the Commons API with its **real** creator, licence name, licence URL and
  file page; nothing was invented and no entry is included without an Artist and a licence. Filters applied:
  JPEG/PNG/WebP only, at least 1600×900, photo-like aspect ratio (0.5–2.2), and maps / diagrams / charts /
  logos / posters / scans / certificates / coats of arms rejected by title.
- **Category chips** now lead with the topics that were missing — Cars, Animal, Art, Cartoons, Robots,
  Anime & Manga, Motorcycles — then the rest by image count (28 chips). A category with no translation now
  falls back to a readable name instead of showing a raw `c_xxx` key.
- **Sources that return no images remove themselves.** Each fetch retries once; two failed attempts with no
  success marks the source dead, hides its chip, rebuilds the row and says so in a toast (the mark persists).
  Turning the source back on in Settings clears it. Key-only sources (Flickr, Smithsonian, Rijksmuseum,
  Europeana) stay hidden until a key is entered, so the row only ever lists sources that really work.
  The "All sources" chip and the meta line now show the live count instead of claiming 11.
- Verified with a harness where six sources are made to fail: after one load the row shrank from 7 sources to
  the single working one, with the rest of the feed unaffected. Wikimedia untouched: 60 cards on boot,
  chips and preview unchanged; boot on the bigger dataset 2.0 s → 2.2 s in the test container.

## v5.0.0 — 2026-11-03
**11 new wallpaper sources, unified search, full creator credits, favourites and real wallpaper setting**
- **Sources added alongside Wikimedia (never replacing it):** Openverse, Flickr Creative Commons, NASA Images,
  Smithsonian Open Access, Rijksmuseum, Cleveland Museum of Art, Art Institute of Chicago, Europeana,
  Library of Congress, Internet Archive and The Met. Each one talks to its own official API; Wikimedia's
  existing embedded library and Commons live search are untouched.
- **Unified feed.** A new glass source row under the category chips: Wikimedia (default), *All 11 sources*,
  ♥ Favourites, then each source on its own. Results from every enabled source are fetched in parallel and
  **interleaved** so the grid mixes them instead of showing one source at a time. Duplicates are dropped by
  item id *and* by normalised image URL.
- **15 wallpaper categories** (Nature, Mountains, Space & Galaxy, Ocean, Animals, Flowers, Cars & Bikes,
  Architecture, Minimal & Abstract, Digital Art, Vintage Photography, Paintings, Indian Culture, Dark AMOLED,
  Illustrations) replace the Wikimedia category row while a non-Wikimedia source is selected; Wikimedia keeps
  its original category chips exactly as before.
- **Credits.** The preview now shows creator (linked to the creator's profile where the API provides one),
  original title, source platform (linked), original image page, licence name and licence URL — all clickable.
  The copy-credit line names the real source. Nothing is ever invented: when an API gives no creator the item
  says "Unknown creator" rather than guessing.
- **Licence gate.** Only CC0, Public Domain, CC BY and CC BY-SA material is accepted; `by-nc`, `by-nd` and
  unlicensed items are filtered out per source (Internet Archive items must carry an explicit Creative Commons
  licence URL; Cleveland and The Met must report CC0 / public domain).
- **Live.** The 150 s background poll and the refresh button now work across the selected sources, so newly
  published wallpapers arrive on their own.
- **Favourites** are stored with their credit block (localStorage, last 300) and get their own filter chip.
- **Settings → 🌐 Image sources**: per-source on/off switches and API-key fields with "get key" links for the
  four sources that require one (Flickr, Smithsonian, Rijksmuseum, Europeana). Keys are stored only on the
  device (localStorage) — there is no server to hold them, and none is sent anywhere except that source's API.
- **Android: set wallpaper for real.** New `Wallpaper.set(url, 'home'|'lock'|'both')` JS bridge in the shell —
  downloads and downsamples off the UI thread, applies via `WallpaperManager` (FLAG_SYSTEM / FLAG_LOCK) and
  reports back asynchronously. The "Set wallpaper" tab shows Home / Lock / Both buttons when the bridge exists
  and the old instructions when it does not.
- **Verified:** Wikimedia regression (172 thumbnails, all 200, search + categories + preview unchanged);
  NASA and Internet Archive exercised against their live APIs from this build; all 11 parsers exercised
  end-to-end with recorded/documented response payloads (54 wallpapers across all 11 sources, credit block
  correct for each, 0 console errors).
- **Not in this release:** a dedicated crop/position editor and an offline store for downloaded files — both
  need their own screens and are left for a follow-up rather than half-built here.

## v4.9.2 — 2026-11-03
**Performance pass: the image pipeline was effectively serial, and interaction paths thrashed layout**
- **The loader never reached its own concurrency.** `pumpImgs()` starts one image per tick and expects
  the gap timer to schedule the next tick, but it never re-armed it — so a new image only started when
  a previous one *finished*. Six parallel requests were configured, one was used.
- **`loading="lazy"` fought the loader.** The app sets `img.src` itself when a card should load, but the
  attribute made the browser silently defer the fetch for cards outside the viewport; those requests
  never fired `load`/`error`, their six slots stayed occupied and the queue starved — visible cards sat
  on grey shimmer with 40+ images queued. The attribute is gone from grid images (the app owns loading).
- **Cards now load by proximity.** An IntersectionObserver (800 px band) decides when a card may fetch;
  cards outside it get `.far`, which stops their shimmer animation and drops its composited layer. Before,
  every card ever rendered kept a decoded bitmap *and* a running animation.
- **Visible cards are fetched first.** A high-priority FIFO queue serves the cards on screen in document
  order; the rest wait behind them.
- **Forced synchronous layout removed from every interaction path.** The card tilt measured its own rect
  on every pointer frame, the header icon measured itself on every mouse move anywhere in the app, the
  modal photo did the same, `checkSentinel()` read layout on every scroll frame and a 900 ms watchdog read
  `scrollHeight`. All geometry is now cached and invalidated on scroll/resize, and the sentinel check is
  limited to one layout read per 150 ms with a trailing check.
- `renderChunk()` inserts a whole chunk with one `DocumentFragment` instead of 18 separate appends, and
  observers are attached after insertion; `updateMoreBtn()` writes to the DOM only when its label changes.
- Measured (deterministic harness, ~500 cards, images stubbed): style recalc **21,702 ms → 2,543 ms**,
  total long-task time **111,407 ms → 68,298 ms**, pointer-tilt long tasks **36,858 ms → 14,925 ms**
  (style 8,823 → 338 ms), modal open/close layout **420 ms → 33 ms**, settings panel style 117 → 18 ms.
  Real CDN after a fast 18,000 px scroll: images loaded **45 → 133** (3×), 0 × HTTP 429, 0 failed requests.
- Visual regression: pixel-identical first screen and wallpaper preview (0 px difference), 0.04 % on the
  settings panel / light theme (five off-screen cards that are now intentionally not pre-loaded).
  Layout, colours, spacing, wording, icons, animations, glass effects and the 2,322 embedded wallpapers
  are untouched. Full detail in `PERF-REPORT.md`.

## v4.9.1 — 2026-11-03
**"🆕 Naye" kept showing the same wallpapers, and kept calling them new**
- **Same images announced again and again.** The "new wallpapers" pill and the refresh button dedupe with
  `seen` / `seenT`, and `start()` rebuilds both of them for the current filter. So every category chip or search
  wiped the memory of what had already been added, and the next refresh/pill put the *same* pictures back on top
  marked NEW. Reproduced in headless Chromium: refresh → 35 added; switch category and back → refresh again →
  **"✨ 35 new wallpapers added" with the identical 12 titles at the top**; the pill also came back with the same
  count. Now a session-long `offered` set (page id + normalised title) records everything already shown or
  announced, and every add path checks it. After: the same sequence ends in **"✅ Already up to date"**, the pill
  stays hidden after a category switch, and a full run shows **0 duplicate cards** in the grid.
- **The feed itself was stale.** The "new" stream was `Category:Featured pictures on Wikimedia Commons` sorted by
  promotion date — new members arrive a few times a week, so the newest card was **2026-10-30 (4 days old)** and
  the tab looked identical every day. `fetchFresh()` now merges that curated stream with the genuinely newest
  uploads (`list=allimages`, timestamp descending): a cheap index, then full credit metadata for the few picks.
  Bulk/bot batches are filtered out (an uploader with more than 8 files in the window is skipped — that is how
  47 near-identical "ISS073-E-…" frames and a flood of logo PNGs used to own the top of the list), only JPEGs pass,
  obvious non-photos (logos, maps, charts, coats of arms, scans, certificates…) are dropped, and one image per
  upload series is kept. Result: the first screen of 🆕 Naye now leads with today's uploads
  (e.g. "Narrow-Gauge-Railway Narentabahn Komadina-Quelle", "Ivory Monument of Kartonyono Ngawi") followed by the
  curated featured pictures.
- Cost: a user refresh / opening 🆕 Naye makes two extra API calls (≈320 KB index + ≈40 KB metadata); the 150 s
  background check uses the small 200-item index instead (≈130 KB). Nothing is fetched on a normal page load.
- Unchanged: layout, colours, spacing, wording, icons, animations, features, and the 2,322 embedded wallpapers.
  Verified over the real CDN: 101 thumbnail requests all `200`, 0 console errors, 0 unhandled rejections,
  0 failed requests, search / 🆕 Naye / modal open-close all working.

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
