# Changelog

Every change below keeps the UI, layout, wording and features exactly as they are.
Only correctness, stability and speed change.

## v5.3.6 — 2026-11-09
**Arrow keys and the Android Back button no longer reach through an open sheet, and a language
switch no longer wipes the message that explains an empty page**

- **ArrowLeft / ArrowRight changed the wallpaper behind an open sheet.** The window's arrow
  handler is the one document-level key listener that never got the guard Escape received in
  v5.3.4 — it only asked `if(!isOpen)return`, so a sheet sitting on top of the window did not stop
  the keys from reaching the wallpaper underneath. Measured in headless Chromium against the live
  CDN: open **"Flower jtca001"** → **All credits** → press ArrowRight twice — before: the window
  behind the sheet had moved on to **"Aceras anthropophora (detail)"**, so closing the sheet showed
  a different wallpaper than the one the user opened; after: the title is still **"Flower jtca001"**
  through the whole observation, and with no sheet open the same two presses still move it to
  **"Wind Point Lighthouse 071104"**. The guard is now `!isOpen || credOpen || langOpen || popOpen`.
  The **F** fullscreen shortcut was missing only the language sheet (`isOpen || popOpen || credOpen`),
  and it was reachable: open the language sheet, click the sheet's heading so the search field loses
  focus, press **F** — before: `document.fullscreenElement` became non-null, i.e. the app went
  fullscreen behind the sheet; after: nothing happens. With nothing open **F** still enters
  fullscreen exactly as before.
- **Switching language on an empty result deleted the only explanation on the page.**
  `applyLang()` re-renders every translated string, and it rebuilt the status pill with an *empty*
  kind — `showStatus('')` — so the pill was cleared and nothing ever raised it again. Measured:
  search **"zzzqqqxyz"** → **"😕 Nothing found — try another keyword or filter"** with 0 cards;
  switch to **हिन्दी** — before: the pill is gone and the page is **0 cards with no message at
  all**; after: **"😕 कुछ नहीं मिला — कोई दूसरा कीवर्ड या फ़िल्टर आज़माएं"** is still on screen, in
  the new language. `showStatus()` now remembers the last kind and message, and `applyLang()`
  re-renders *that* instead of an empty one. When no status is showing nothing changes — verified on
  a populated view (the Art chip after the same language switch: status still empty, 59 cards).
- **Android Back quit the app while the language sheet was open, and closed the wallpaper that was
  open under the credits sheet.** `MainActivity.onBackPressed()` tests the wallpaper window first,
  the credits sheet second, the settings popover third, and never tests the language sheet at all.
  Measured by running the exact JS that `onBackPressed()` evaluates inside the page: language sheet
  open → **`'exit'`** (the activity would be finished, with the sheet still on screen and `lock`
  still on `<html>`); now **`'closed'`**, sheet hidden, `lock` off. Card open → **All credits** →
  Back — before: `#overlay` went to `none` at **900 ms** and the `lock` class came off while the
  credits sheet was still `flex`, i.e. the wallpaper the user was reading was thrown away and the
  grid behind the sheet started scrolling; after: the sheet closes within **100 ms** and the window
  stays open (`#overlay` `flex`, `lock` on) for the whole 2.5 s observation. Back is now the mirror
  of Escape: sheets first, the window last.
- **Nothing visual changed.** 2,751,905 → 2,752,030 bytes; every byte before the single `<script>`
  block and after `</script>` is identical, and the script diff is **5 lines changed, 1 added**
  (comments included). Computed style and geometry of 22 elements (header, title, search box, chip
  row, the chip lens, meta line, cell, card, face, caption, title, credit line, more button, the
  three header buttons, the 4D logo, backdrop, status line, toast) across 22 properties each: **0**
  differences, measured with images blocked so paint order cannot vary. With images live the only
  differences are the y of the status line and the more button, which sit below the grid and follow
  how many cards that run happened to render. The top 190 px of the first screen differs by
  **24,338** px against a **39,947** px same-build run-to-run noise floor. Real-CDN run at
  1280×900: **0** HTTP 429, **0** failed requests (**69/69** thumbnails 200), **0** console errors,
  **0** unhandled rejections; boot FCP **1,200 ms**, dcl **1,375 ms**, **240** cards, **69** images
  by 14 s; 12-step scroll **420** cards, **143** images, **21** long tasks (3.43 s, max 586 ms) —
  unchanged from v5.3.5's 456 / 151 / 23 (2.95 s, max 494 ms), which is layout-bound, not
  script-bound.
- Checked and found already fine, so not touched: **the embedded data** — 6,288 entries, **0**
  duplicate ids and **0** duplicate titles, and all **3,424** entries that store no Commons page URL
  rebuild a valid one from the thumbnail path (percent-encoded names included). **The thumbnail
  loader** — 6 slots / 45 ms gap, **69/69** 200s and **0** 429s across a boot and a 12-step scroll.
  **The settings popover after tapping "Language"** — `#pop` can stay `display:block` for a moment
  behind the language sheet, but the sheet's dim layer is above it (hit-testing the popover's centre
  returns `ldim`) and it hides itself, so nothing is visible and it was left alone. **The About line
  in the settings popover** still reads "2,322 · Wikimedia Commons" while the file embeds 6,288
  wallpapers — that is user-visible wording, so it is left exactly as it is.

## v5.3.5 — 2026-11-08
**A reconnected phone fills the gallery in 8 s instead of 18 s, dead cards come back, and the
Favourite button stops lying about what it saved**

- **The image loader never gave its back-off back after the network returned.** Every failed
  thumbnail teaches `retryImg()` to be more careful — `IMG_MAX` 6 → 3, `IMG_GAP` 45 → 200 ms and up
  to 20 s of `imgCooldown` — which is right while the connection is broken, but nothing ever undid
  it. Measured in headless Chromium against the live CDN (thumbnails and the API aborted for 30 s
  with the app open, then released, which is what a phone does when it goes through a tunnel and
  comes out): before, the grid showed **0 thumbnails for the first 8 s**, the first one arrived at
  **+9 s** and the screen was full (**69** images) only at **+18 s**; after, **8** thumbnails are on
  screen at **+1 s** and the screen is full (**70**) at **+8 s**. The browser's `online` event is the
  one moment we know for certain the network is back, so `reviveImgs()` now drops the learned
  back-off there (`IMG_MAX` 6, gap 45 ms, cooldown 0) and re-arms the pump.
- **A card that had used up its three retries stayed on the failed placeholder for the rest of the
  session.** `retryImg()` ends with `face.classList.add('failed')` and returns, and nothing
  re-queues that `<img>` afterwards: `nearIO` had already stamped the cell with `data-ld`, so
  scrolling the card out of the band and back in did not retry it either. In the same 30 s outage
  measurement **1** card ended up in that state and was still failed at **+25 s**, i.e. 16 s after
  the network was healthy again — a blank cell until the app was reloaded. `reviveImgs()` clears
  `attempt` on the failed faces of the loaded band and puts them back at the front of the queue:
  after the fix the failed count goes to **0** in the first second and stays there.
- **The Favourite button never showed that it had saved.** `toggleFav()` writes localStorage and
  toasts *"♥ Saved to favourites"*, but the button's label was built once inside `fillModal()` and
  never touched again, so it kept offering to save something already saved until the window was
  closed and reopened. Measured: click it on a card → `ww_favs` length **1**, label still
  `♡ Favourite`; after: label is `♥ Saved` on the click and back to `♡ Favourite` on the second
  click (`ww_favs` **1 → 0**). Same two strings as before, just shown at the right time.
- **Nothing visual changed.** The 2,548,321 bytes of HTML+CSS that precede the single `<script>`
  block and the 26 bytes after it — markup, all CSS, the embedded wallpaper JSON, every i18n
  string — are **byte-identical** to v5.3.4, and the script diff is **2 lines changed, 18 added**
  (comments included). Computed style and geometry of 23 elements (header, title, search box, chip
  row, the chip lens, meta line, cell, card, face, caption, title, credit line, more button, the
  three header buttons, the 4D logo, backdrop, status line, credits sheet, settings panel) across 22
  properties each are identical, as are all seven CSS variables — the only difference anywhere is
  the y of the more-button and the status line, which sit below the grid and follow how many cards
  that run happened to have rendered. The top 190 px of the first screen differs by **33,196** px,
  below the **40,748** px same-build run-to-run noise floor. Real-CDN run at 1280×900: **0** HTTP 429, **0** failed
  requests, **0** console errors, **0** unhandled rejections; boot FCP **812 ms**, dcl **1,509 ms**,
  first card **2.5 s**, 204 cards; 12-step scroll **600** cards, **14** long tasks (2.9 s, max
  784 ms) — unchanged from v5.3.4's 18 tasks / 3.2 s, which is layout-bound, not script-bound.
  Modal open → tabs → 3× ArrowRight → All credits → Escape → Escape, the settings popover, a
  slider, the Lite switch, the language sheet (→ te), a search (*"ansel adams"*, 72 cards), an
  empty search (*"😕 Nothing found"*), rapid chip switching (0 duplicates) and favourites all
  behave exactly as before.
- Checked and found already fine, so not touched: **the boot script's own hot spot** — `moveLens()`
  runs **4** times during boot (the chip row is built twice, by the module-level `renderChips()`
  and again by `buildSrcChips()` after `apply()`, and the lens is then measured twice more with
  nothing changed in between). Removing the duplicates is 2 fewer `moveLens()` calls and one fewer
  chip build, but three runs per build with stubbed thumbnails showed no boot difference outside
  noise (long-task total 1,750 → 1,904 ms, first card 1,781 → 1,717 ms, cells 168 vs 204), so the
  change was reverted rather than shipped as an unverified claim. **The 429 storm on thumbnails**
  — 25 s of real `429`s left only 1 card failed, because the loader throttles itself to ~6 requests
  in that window; no request was ever retried into a second storm. **The credits sheet** —
  2,322 rows in 80/120-row batches, no growth beyond the data. **Scroll jank** — still the layout of
  a non-virtualised grid, unchanged and not fixable without changing scroll behaviour.

## v5.3.4 — 2026-11-07
**Refresh can no longer wedge itself, and Escape no longer closes the window behind a sheet**

- **Switching view during a Refresh left the refresh spinner on screen for the rest of the session
  and made the Refresh button dead.** The Wikimedia branch of `refreshFeed()` reset `refreshing`,
  the pull indicator and the button's busy ring inside `finally` — but only `if(my===token)`, and a
  category/source switch bumps the token. The refresh was over, its UI state never was: `#pull`
  kept `class="pull spin on"` with `opacity:1; transform:translate(-50%,calc(-160% + 84px))` (the
  spinner parked over the header, reading *"Fetching the latest wallpapers…"*), `#refresh` kept
  `.busy`, and `refreshing` stayed `true`, so every later Refresh press returned on its first line.
  Measured in headless Chromium against the live CDN: press Refresh, switch to the **Art** chip
  300 ms into the fetch — before: spinner and busy ring still there **6 s later**, and a second
  Refresh press produced **0** `api.php` calls and no toast (grid frozen at 193 cards); after: the
  pull indicator is back to `class="pull"` with its inline style cleared, and the next press makes
  **3** API calls, answers *"✅ Already up to date"* and the meta line moves to *"synced just now"*.
  The flag is a singleton for the one refresh that can be running, so it is now always cleared; only
  the meta line (which describes the page that was refreshed) stays behind its token check.
- **Escape with the credits sheet open over a wallpaper closed both, losing the wallpaper.**
  Two `document` keydown handlers listen for Escape — the window's (`closeModal`) and the sheets'
  (`closeCredits`, `closeLangs`) — and nothing stopped both from running, so one key press dismissed
  the sheet *and* the window underneath it. Measured: open a card → **All credits** → Escape — before:
  sheet `display:none` at 150 ms and by 800 ms `#overlay` also `none`, `lock` gone and the card's
  `visibility:hidden` already undone, i.e. the wallpaper the user was reading was thrown away; after:
  the sheet closes at 150 ms and the window stays open (`#overlay` still `flex`, `lock` still on) for
  the full 3 s observation, a second Escape closes the window and restores the card (**0** cells left
  hidden), and a third Escape does nothing. A sheet that is open on top now owns Escape; with no
  sheet open the window closes exactly as before.
- **Nothing visual changed.** Everything outside the single `<script>` block — all 2,548,313 bytes of
  HTML+CSS, the embedded wallpaper JSON and every i18n string — is **byte-identical** to v5.3.3, and
  the script diff is **2 lines removed, 11 added** (comments included), all inside an error path and
  one keydown guard. Computed style and geometry of the header, the title, the search box, the chip
  row, the meta line, a cell, a face and a caption are identical, and the top 190 px of the first
  screen is pixel-identical (the only differing pixels are card thumbnails, whose paint order varies
  run to run). Real-CDN run at 1280×900: **0** HTTP 429, **0** failed requests (**186/186**
  thumbnails 200), **0** console errors, **0** unhandled rejections; boot FCP **880 ms**, first card
  **2.28 s**; 12-step scroll **654** cards, **51** long tasks (9.7 s, max 796 ms). Favourites
  (1 saved → removed from the modal → 0 cards), ArrowRight then Escape, Escape during the opening
  animation, re-opening the same card, rapid chip switching (art → cars → japan → 131 cards, 0
  duplicates) and an empty search (*"😕 Nothing found"*, then **All** back to 6,288) all behave
  exactly as before.
- Checked and found already fine, so not touched: **no memory leak** from the grid cells the
  observers hold — 8 category switches with a forced GC leave the JS heap at **8.9 MB** (from 8.8 MB
  at boot) and live DOM nodes at 2,373 (from 3,517), 1 document, so `clearGrid()` not unobserve-ing
  costs nothing measurable. Long tasks were attributed with a CDP CPU profile: `pumpImgs` looked like
  the hot spot (**683 ms** of self time) but instrumentation inside it shows **762** calls, **186**
  image starts and **19 ms** spent in the `img.src` assignments, i.e. the sample was native
  resource-setup work, not the pump. One change was tried and **rejected**: `contain:layout style` on
  `.cell` — over the same 12-step scroll it gave **3.66 s** of layout and 48 long tasks (max 982 ms)
  against **3.36 s** and 36 (max 712 ms) without it, so it is not shipped. The remaining scroll cost
  is layout and paint of the glass cards themselves (one step at ~500 cards: **715 ms** of layout over
  5 layouts, 95 ms of style, **16 ms** of script), which is the cost of inserting 18 cards per chunk
  and would change what appears per scroll if touched.

## v5.3.3 — 2026-11-06
**A burst of 429s no longer ends the live feed, and switching category while a source loads no longer
leaves a blank page**

- **One burst of HTTP 429s killed the live Wikimedia feed for the whole session.** `api()` retried a
  `429`/`5xx` three times and then threw a plain `Error`, and `loadLive()` answered *any* error by
  setting `liveDone = true`. From then on `more()` took the "no more to load" branch, so the view sat on
  a finished-looking state and never asked the API again. Measured in headless Chromium against the live
  CDN with the first 3 API responses replaced by a real CORS `429`: search **"ansel adams"** (2 embedded
  matches) — before: **2 cards, "✨ That's all! Try another category or search", 3 API calls in total and
  0 further calls** across three "Load more" presses, i.e. the feed was dead until reload; after: **2 → 72
  → 105 cards**, requests resume (2–3 per press) and the pill honestly says *"Could not reach Wikimedia"*
  while the API is still refusing. With an empty pool the same burst used to print
  **"😕 Nothing found — try another keyword or filter"** — a search that never ran, reported as a search
  that found nothing; it now reports the connection problem. The retry is not a spin: `loadLive()` returns
  before doing anything while `apiCooldown` is running, so a 12 s back-off costs 0 requests instead of a
  request every 80 ms.
- **Switching category while a source view was still loading left the grid empty, for good.**
  `multiLoad()` starts with `if(mloading)return;` and only clears that flag when its own request finishes,
  while `start()` had already emptied the pool and bumped the token — so the new load returned immediately,
  the old one threw its result away, and nothing rendered. Measured with 1.8 s of added latency on every
  request, in the **All sources** view: press a category chip 0.9 s into the load — before: **0 cards for
  the next 20 s** (and it only recovered if the user happened to scroll), the meta line still reading
  *"6,288 wallpapers · all from Wikimedia Commons"* from the previous view, and no status at all; after:
  **42 cards at 5 s**, meta *"42 wallpapers · All sources (2) · Nature"*. `multiReset()` now clears the
  guard, because it is the function that throws the old page away.
- **The same guard made Refresh lie in a source view.** `refreshFeed()` cleared the grid and then called
  `multiLoad(true)`, which returned at once, so the toast said *"Already up to date"* over an empty grid.
  It now also bumps the token, so a load still in flight for the discarded page can neither block the new
  one nor append its items twice.
- **A poll started for the previous view could fill the "🆕 N new wallpapers" pill of the new one.**
  `multiCheckFresh()` and `checkFresh()` had no token check across their `await`, so a poll that began in
  the old view wrote `pendingFresh` and raised the pill after the user had already switched; pressing it
  unshifted those foreign items into the current pool, cleared the grid and re-rendered 30 cards. Both
  now drop their result if the view changed while they were waiting.
- **Nothing visual changed.** The markup, the whole `<style>` block (2,548,313 bytes of HTML+CSS), the
  embedded wallpaper JSON and every i18n string are **byte-identical** to v5.3.2 — the diff is 3 JS lines
  removed and 24 added, all inside error and race paths. Computed style and geometry of the header, the
  chip row, the title, the first card/face/caption, the meta line and the modal are identical, and the top
  180 px of the first screen is **pixel-identical** (the remaining differences are below the fold and come
  from how many cards the boot filler had rendered by screenshot time, which varies run to run in both
  builds). Real-CDN run at 1280×900: **0** HTTP 429, **0** failed requests (**127/127** thumbnails 200),
  **0** console errors, **0** unhandled rejections; boot FCP **900 ms**, first card **2.48 s**; 12-step
  scroll **600** cards with **127** images loaded. Favourites (3 → un-favourite from the modal → 2 cards,
  no duplication), the Art category (192 cards), Refresh in both the wiki and the source view, and a
  Japanese switch with the modal open (0 raw keys) all behave exactly as before.
- Checked and found already fine, so not touched: **0** HTTP 429 from `thumb.wikimedia.org` over a
  12-step scroll (the loader's 6-slot / 45 ms-gap budget holds); no card left stuck at
  `visibility:hidden` after opening a card and pressing Escape inside the open animation, or after
  ArrowRight + Escape; no leaked reveal animations (finished ones are dropped by the engine — 99 → 115
  live animations over 14 scroll steps while the grid grew 186 → 564 cards). The scroll jank that remains
  is the cost of inserting 18 glass cards per chunk (measured 84 ms at 186 cards, 107 ms at 564 — the
  per-card style/raster work, not a growing re-layout) plus image decode; both are inherent to the design
  and any change to them would alter how many cards appear per scroll, so they were left alone.

## v5.3.2 — 2026-11-05
**Category chips now return the category, the favourites view stops claiming it is empty**
- **A category chip matched its name as a substring of the whole credit line.** `buildPool()` tested
  `hay.includes(word)` over title + creator + category + description + licence, so "art" matched every
  "artist", "earth", "smart" and "quarter", "city" matched "electricity", "japan" matched "Japanese"
  names, and "cars" pulled in castles because their photographers are called **Carsten** and
  **Carschten**. Measured on the embedded list: the **Art** chip offered **832** wallpapers of which
  only **128** were art (**704** wrong), **City** 299 of 186, **Japan** 209 of 101, **India** 191 of 133,
  **Cars** 136 of 116 — the first three Art cards were a butterfly, an Earth-at-night composite and a
  frog. A category chip is now an exact category match (`d.cat === term`); a typed search still matches
  titles, creators and descriptions exactly as before ("ansel adams" → 2 wallpapers, "art" typed in the
  search box → 797 mixed results, unchanged). After: **Art 128, City 186, Japan 101, India 133,
  Cars 116** real matches (+ whatever the live Commons feed adds at the end), and the first Art cards
  are paintings. Scrolling the Art view now renders **252** cards over a 10-step scroll instead of
  **491**, because the view no longer queues 704 wallpapers that do not belong to it.
- **The favourites view announced "😕 Nothing found — try another keyword or filter" under a list of
  favourites, and showed a dead "Load more from Wikimedia ↓" button.** `more()` sent this view into
  `multiLoad()`, whose `activeSources()` list is empty for favourites, so the very first sentinel check
  answered "nothing found"; `updateMoreBtn()` computed `canLoad` from the live-feed rule, which is true
  for this view. Measured with 3 favourites on screen: **"Nothing found" pill + visible button** before,
  **no status pill and no button** after; the 3 cards stay put while scrolling and while pressing the
  old button's position. Nothing about the grid, the chips or the cards changed.
- **`#fresh` leaked out of the Wikimedia feed.** "🆕 Naye" is a Wikimedia pseudo-query; carried into a
  source view it went out as `q=%23fresh` to every API and the meta line read `All sources (2) ·
  "#fresh"` with 15 wallpapers. `start()` now drops the pseudo-term for non-Wikimedia feeds: the same
  view reads `All sources (2)` and returns 16 live wallpapers.
- **The live "🆕 N new wallpapers" offer respects the filter.** It is offered from the newest uploads
  overall, so in a category view it could add a flower to the Cars feed; the poll and Refresh now skip
  items the current filter excludes.
- **Nothing visual changed.** The header markup, every chip label and class, the meta line, the tabs, the
  settings sheet text, the CSS variables, and the computed style of the header, a card, a face and the
  title are byte-identical between the two files, as are the geometry, title, credit and aspect ratio of
  the first six cards. Real-CDN run at 1280×900: **0** HTTP 429, **0** failed requests (**427/427**
  thumbnails 200), **0** console errors, **0** unhandled rejections; boot first card **1.80 s**, FCP
  **820 ms**; 12-step scroll **528** cards with **182** images loaded.
- One measurement worth recording: shrinking the backdrop image to a 250 px variant looked like a win
  but **added 371 KB** of downloads per 24 hovers, because the 500 px thumbnail the backdrop uses is
  already in the cache from the card that is being hovered. Reverted, not shipped.

## v5.3.1 — 2026-11-04
**Favourites view, quota handling and the scroll loader fixed — the UI is unchanged**
- **Un-favouriting a card duplicated the whole grid.** In the ♥ Favourites view `favLoad()` never cleared
  the grid, and `renderChunk()` appends from `pos=0`, so every favourite or unfavourite appended the entire
  list on top of the one already there. Measured in headless Chromium against the live CDN: 3 favourites,
  open one card, un-favourite it — **5 cards** before, **2 cards** after.
- **Refresh emptied the favourites view.** `refreshFeed()` sent the favourites view through `multiLoad()`,
  whose `activeSources()` list is empty for that view, after `clearGrid()` had already wiped the grid, so
  the view went to **0 cards showing "😕 Nothing found — try another keyword or filter"** while toasting
  "Already up to date". The favourites view now re-renders from localStorage and toasts; measured
  **3 → 0 cards + "Nothing found"** before, **3 cards and no status message** after.
- **A spent daily quota answered with 429 was never recognised as quota.** The generic `429/503` back-off in
  `getJSON()` threw before the quota-body check, so a quota-exhausted source was counted as a failure twice
  and removed from the chip row instead of being paused for an hour. The quota check now runs first and the
  generic back-off only after it.
- **The scroll loader forced a full relayout on every tick.** `checkSentinel()` called
  `getBoundingClientRect()` on the sentinel for every throttled scroll tick, and that read relayouts the
  whole grid. It now reuses the rect the `IntersectionObserver` already reports. Measured over a 12-step,
  16,800 px scroll: **31 forced layout reads** in the previous file, **0** now — while the grid still grows
  as you scroll (168 → 618 cards) and images keep loading (32 → 99 loaded faces).
- **Nothing visual changed.** At 1280×900 the first screen of the previous file and of this release are
  pixel-identical — **0 of 1,152,000 pixels differ** — with identical element geometry, computed styles,
  fonts, colours, radii, shadows, wording, chips, icons and animations. A 12-step scroll and four category
  switches (Cars, Animal, Art, Cartoons) finished with **0 console errors**, every request 200, and images
  still loading afterwards (21 → 40 loaded faces in the 3 s after the last switch).

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
