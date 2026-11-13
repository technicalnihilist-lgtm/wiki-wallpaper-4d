# Changelog

Every change below keeps the UI, layout, wording and features exactly as they are.
Only correctness, stability and speed change.

## v5.4.1 — 2026-11-14
**A connection that stalled instead of failing froze the app: the pull indicator, the refresh ring and
every later Refresh press stayed dead for ever**

- **One hung Wikimedia request wedged the whole refresh path, permanently.** `api()` had no deadline
  of its own — its only `AbortController` is the caller's `ctrl`, and that is aborted when the *view*
  changes, never when the network goes quiet. A connection that stalls after the TCP handshake (a
  phone that walked out of Wi-Fi range, a captive portal that accepts and then says nothing) leaves
  the `fetch()` promise pending indefinitely, so `refreshing` / `loading` are never cleared: the pull
  indicator sits on screen reading **"Fetching the latest wallpapers…"**, the header's Refresh button
  keeps its busy ring, and every further Refresh press returns at once because `refreshing` is still
  true. Switching category does not clear it either — the spinner stays over the new grid.
  Measured in headless Chromium through a local CONNECT proxy against the live CDN, with the proxy
  rewritten to accept connections to `commons.wikimedia.org` and never answer them: **boot → Refresh
  → sampled at 6.2 s / 12.3 s / 22.4 s / 32.6 s / 42.7 s / 60.9 s — `pull on`, `spin`, `busy` all
  true at every sample, no toast, no status** (a longer run held the same state past **120 s**); a
  second Refresh press changed nothing. After the fix the same stall clears at **20.7 s** and
  **22.6 s** in two runs (`pull`/`spin`/`busy` all false, the "already up to date" toast shown, the
  grid usable, and the next Refresh after the network returns does a real fetch again).
  Each attempt in `api()` now carries its own `AbortController` plus a 20 s deadline; the caller's
  abort is still relayed to it at once, so changing the view cancels exactly as before. A deadline
  hit is reported as `err.rateLimited` — the existing "temporary failure" path — so `loadLive()`
  clears the status pill **without** setting `liveDone` (a timeout must not end the feed) and sets a
  15 s cooldown instead of hammering a dead socket. The deadline covers the body too, because
  `fetch()` resolves at the headers and the JSON is read afterwards.
- **Nothing visual changed.** The 2,548,730 bytes of HTML+CSS and embedded wallpaper data that precede
  the single `<script>` block, and the 26 bytes after `</script>`, are **byte-identical** to v5.4.0;
  the script diff is **27 lines changed, 26 added** (10 of them the comment explaining the deadline)
  and **1 removed** (the old bare `fetch(u,{signal})`). The whole normal-path suite was re-run on the
  built file and behaves exactly as v5.4.0: open a card → Credit tab → ♡ Favourite → ⛶ Fullscreen →
  Fill → › next → Exit → close, the settings popover (anim → Off), the credits sheet (80 rows,
  "ansel" → 2 rows), the language sheet (हिन्दी → ♥ Favourites shows the saved card → All → English),
  **0** console errors, **0** unhandled rejections, **0** HTTP 429. Boot and scroll on the same
  harness: boot **276–312** cards, FCP **1.9–2.1 s**, **0** failed faces; 12-step scroll **402** cards,
  **176** images, **0** failed faces, **66** long tasks (8.9 s) against **62** (9.6 s) for v5.4.0 on
  the same harness — i.e. unchanged, live-CDN variance. ⬇ Original still writes a **1,568,881**-byte
  JPEG and ⬇ HD a **412,416**-byte one from the live CDN, and 40 open/close cycles leave the heap flat
  at **12.1 MB** with **950** DOM nodes.
- Checked and found already fine, so not touched: **image recovery after a network blip** — with the
  thumbnail CDN blocked for 40 s and the page scrolled through 366 cards, only **2** cards reached the
  terminal `.failed` state; the rest stayed queued and the loader drained the whole 184-item queue on
  its own once the block was lifted (**2 → 2** failed before/after unblocking, then **0** after the
  app's own `reviveImgs()`), so the retry/back-off already recovers without a fix. **The `✅ Already
  up to date` toast after a failed refresh** — `fetchFresh()` swallows both API errors and returns an
  empty list, so a failed refresh reports "already up to date" instead of "⚠️ Could not reach
  Wikimedia"; that is wrong-but-cosmetic and fixing it changes wording, so it was left alone.
  **Robustness sweep** — 40 random UI actions (cards, tabs, fullscreen, arrows, popover switches,
  credits, chips, sources, search submits, Escape, ArrowRight, refresh, F) in one session: **0**
  exceptions, **0** unhandled rejections, **0** 429, heap **9.5 MB**; every `$('…')` id in the script
  exists in the markup (the only one built at runtime is `#fsFit`), no duplicate ids, and all 168 `en`
  keys plus the 17 `data-i18n` attributes resolve (the category keys missing from some languages are
  the intended `catTitle()` fallback). **390×844** — three columns, no horizontal overflow, three
  pull-to-refreshes in a row (All → ✨ 40 added → All → 🆕 Naye → 40 cards) with **0** errors.
  **The Android shell** — `MainActivity` reviewed: the back-button sheet ordering, the wallpaper
  bridge's async `__wallResult`, the asset interception and the 120 Hz request are all sound.

## v5.4.0 — 2026-11-13
**A refreshed wallpaper came back twice in the newest-uploads feed, and the Android "set wallpaper"
button stayed greyed out after it had worked**

- **Refreshing the 🆕 Naye view and then loading the next page showed the same wallpaper twice.**
  `refreshFeed()` adds what it found to `seen` (the id set) and to `offered` / `offeredT` (the
  session-wide "already announced as new" pair), but never to `seenT` — the "titles already in this
  view" set that every feed filters against. `loadFreshPage()` (and `loadLive()`) therefore still
  counted the refreshed wallpaper as unseen, and the next page of the feed handed back that same
  file again: the gallery showed it once with its **NEW** tag and once without. `applyFresh()`, the
  ✨ pill, had the same gap, so a polled wallpaper could come back the same way.
  Measured in headless Chromium against the live CDN, with the first `list=allimages` answer
  rewritten to hide its newest pick — so it arrives exactly like a genuinely new upload between the
  two loads: **🆕 Naye** → 40 cards, **Refresh** → "✨ 1 new wallpapers added" → 41 cards, then three
  taps on **more**: before **43 cards with 1 duplicate title** ("Asmolova park", reproduced in two
  separate runs), after **42 cards, 0 duplicates** (second run: refresh added 2 → 42 cards, still
  **0**). Both lines now add `seenT.add(tkey(d.title))`; the ordering of `seen` / `offered` /
  `offeredT` is untouched, so nothing is announced as new twice.
- **The wallpaper-set buttons stayed disabled after the wallpaper had been set.** In the Android app
  the bridge answers `"started"` at once and reports the real result later through
  `window.__wallResult`. `setW()` disabled the tapped button, saw `"started"` and returned before
  re-enabling it, and `__wallResult` only showed a toast — so the button the user had just pressed
  stayed greyed out for the rest of the window's life, underneath a "✅ Wallpaper set" toast.
  Measured with a stand-in bridge that behaves exactly like `MainActivity.WallpaperBridge`: after the
  click the button is `disabled=true` in both builds; after `__wallResult('ok')` — before
  **`disabled=true`** (still stuck), after **`disabled=false`**. The buttons waiting for that result
  are now kept in `wallWait` and released when it arrives; the synchronous path (`ok` / `error: …`)
  behaves exactly as before.
- **Nothing visual changed.** The 67,661 bytes of HTML+CSS before the wallpaper data, the
  2,485,737-byte embedded data block and the 26 bytes after the last `</script>` are
  **byte-identical** to v5.3.9; the script diff is **4 statements changed, 14 lines added** (8 of
  them comments, 1 a `let wallWait=[]` declaration). Real-CDN run at 1280×900: **0** HTTP 429,
  **0** failed requests, **0** console errors, **0** unhandled rejections; boot FCP **900 ms**, dcl
  **1,507 ms**, **168** cards, **71** thumbnails, **0** failed faces, **21** long tasks (2.63 s);
  12-step scroll **600** cards, **292** images, **0** failed faces, **45** long tasks (8.36 s) —
  against **582** cards, **257** images and **49** long tasks (10.65 s) for v5.3.9 on the same
  harness, which is live-CDN variance rather than this change.
- Checked and found already fine, so not touched: **the 40-category-switch memory question** — after
  forty switches and a forced GC the heap is **7.0 MB** against **7.5 MB** at boot, so `nearIO` does
  not retain the cells of cleared grids (Chromium keeps observer targets weak); nothing to fix
  there. **Escape ordering** — the credits sheet, then the language sheet, then the settings
  popover, then the window, each closing alone (credits over the window: sheet `none`, overlay still
  `flex`, same wallpaper). **The fullscreen photo controls** — Fill → Fit flips `object-fit`
  contain → cover and back, › / ‹ move to the next / previous wallpaper, Exit leaves fullscreen with
  the window still open, and all five controls report `pointer-events:auto`. **The settings
  popover** — all 23 switches, the five segmented controls and both themes round-trip (light
  `rgb(232,236,244)` ↔ dark `rgb(11,13,18)`). **Favourites** — saving from the Credit tab writes
  `ww_favs` and the ♥ view shows it. **The credits sheet** — 80 rows on open, "ansel" filters to 2
  rows and the header count follows. **The source round trip** — Wikimedia → All sources (2 usable
  here) → back to Wikimedia rebuilds the grid. **390×844** — three columns, chip row scrolls, no
  horizontal overflow. **Offline → online** — the meta line flips ○ Offline → ● Live and the loader
  picks up again. **i18n** — every one of the 95 `t('…')` keys used in the script and all 17
  `data-i18n` attributes exist in `en`; no duplicate element ids in the markup. **The scroll
  profile** — of 26.6 s of sampled CPU time over a 12-step scroll, **0.75 s** is JavaScript and
  **16.2 s** is layout/paint of the 690-card grid, so there is no JS micro-optimisation left worth
  claiming.

## v5.3.9 — 2026-11-12
**Tapping the 🆕 Naye chip a second time emptied the feed, a language switch threw away the tab you
were reading, and a search lost its "no chip selected" state on the same switch**

- **Tapping the active 🆕 Naye chip wiped the gallery.** `start()` begins a new view and resets
  `seen` (the id set) but never reset `seenT`, the "titles already in this view" set that every
  feed filters against. `loadFreshPage()` drops any item whose title is already in `seenT`, so on
  the second entry into the newest-uploads feed all forty titles were still in it from the first
  load and nothing was added. Measured in headless Chromium against the live CDN: boot → **🆕
  Naye** = **40** cards; tap it again = **1** card, still labelled "newest uploads"; **All** →
  **🆕 Naye** = **0** cards with **"✨ That's all! Try another category or search"**. After the fix:
  **40 → 40 → 40** on the same three taps, and the same path from the **Wikimedia** source chip
  (which re-enters the feed through `start('#fresh')`) comes back with 40 cards instead of 1.
  `start()` now clears `seenT` with `seen`; `offered` / `offeredT`, the session-wide "already
  announced as new" set that the ✨ pill relies on, are untouched, so nothing is announced twice.
- **A language switch threw away the tab you were reading.** `applyLang()` re-renders the open
  wallpaper through `fillModal()`, which always ends on the Info tab, and the `showTab(tab)` that
  followed could never put anything back — `tab` had already been overwritten by `fillModal()` by
  the time it ran. Measured: open **"Flower jtca001"** → **Credit** tab → switch to **हिन्दी** —
  before: the window is on **Info** (`p-info` shown, `p-credit` hidden) with the credit text only
  reachable by tapping Credit again; after: still on **Credit**, now in Hindi. The tab is captured
  before the re-render and restored after it; opening a wallpaper from the grid still lands on Info
  exactly as before.
- **The fullscreen credit bar kept the old language.** It is built by `updateFsCredit()`, which
  `fillModal()` does not call, so its two buttons stayed in the previous language while the rest of
  the page switched. Measured: open a wallpaper → **⛶ Fullscreen** → switch to **ગુજરાતી** — before:
  **"◻ Fill" / "⤡ Exit"** in English under a Gujarati window; after: **"◻ ભરો" / "⤡ બહાર નીકળો"**.
  `applyLang()` now rebuilds the bar when fullscreen is on (same two strings, right language).
- **A search lost its empty chip row on a language switch.** `submit()` clears every chip on a
  typed search and that empty row is the correct state, but `renderChips()` rebuilds the row from
  state and re-invented a selection whenever it found none, so the switch lit **All** and slid the
  lens under it above a grid still showing search results. Measured: search **"ansel adams"** →
  chips on **[]**, lens opacity **0**; switch language — before: **["All"]**, lens **1**; after:
  **[]**, **0**, i.e. exactly the state `submit()` left (a run without the language switch gives
  **[]** / **0** in both builds). The row is now rebuilt from what was actually lit: only the very
  first build falls back to the current view, and a rebuild with nothing lit stays unlit. Category
  and source chips are covered, so **Animal** after a search is still the only lit chip.
- **Nothing visual changed.** The 2,548,730 bytes of HTML+CSS and embedded wallpaper data that
  precede the single `<script>` block, and the 26 bytes after `</script>`, are **byte-identical**
  to v5.3.8; the script diff is **5 lines changed, 25 added** (comments included). Computed style
  and geometry of **108** element/state pairs (header, title, search box, chip row, the chip lens,
  meta line, cell, card, face, caption, title, credit line, more button, the three header buttons,
  the 4D logo, backdrop, status line, toast, pull indicator, window, title bar, tabs, tab lens,
  photo, both download buttons, fullscreen button, arrows, credit bar, popover, language sheet,
  credits sheet and its rows) across **42** properties each: **0** differences; the only 6 entries
  that differ are `html` / `body` / `#grid` / `#status` / `#moreBtn` / `#sentinel`, and they differ
  by exactly the same 6 in a same-build pair (how many cards that run happened to render).
  Real-CDN run at 1280×900: **0** HTTP 429, **0** failed requests, **0** console errors, **0**
  unhandled rejections; boot FCP **1,988 ms**, dcl **1,287 ms**, **420** cards, **39** thumbnails,
  **0** failed faces, **9** long tasks (1.04 s); 12-step scroll **690** cards, **135** images, **0**
  failed faces, **20** long tasks (4.05 s, max 617 ms), which is layout-bound as before. ⬇ Original
  on an open card still fetches `200` from `upload.wikimedia.org`; at 390×844 a pull-to-refresh
  still goes `pull on` → `pull on spin` → **"✨ 40 new wallpapers added"** with 0 errors.
- Checked and found already fine, so not touched: **the keyboard path** — Escape closes the credits
  sheet first and the window second (`overlay` `flex` → `none`, `lock` off), ArrowRight moves the
  open window on to the next wallpaper, favourites still flip `♡ Favourite` → `♥ Saved` with
  `ww_favs` 0 → 1, and the language sheet's own pull guard still swallows nothing. **The image
  loader** — 3.4–23 ms of `pumpImgs()` per boot and 20–31 ms across a 12-step scroll (measured with
  an instrumented copy of the file), **0** failed faces and **0** 429s. **Number formatting** —
  `toLocaleString('en-IN')` runs 11–19 times per boot for **0.8–2.1 ms** in total; a hand-rolled
  Indian-grouping helper was written, verified to produce identical text for 0..40,000 and for
  1,00,000 / 1,23,456 / 12,34,567, and then **reverted**: it saves under 2 ms, so there was no
  measurable win to claim (one 98 ms reading in a cold container was a first-launch artefact — the
  same call measured 0.1 ms on every later run). **The 17.7 s freeze on "📋 Copy all credits"** is
  still there: it copies 6,288 credits (~1.5 MB) and `execCommand('copy')` is the cost, so fixing it
  means copying fewer lines, which is a feature change. **The multi-source feeds** (Openverse,
  Flickr, NASA, …) could not be exercised here — those hosts are not reachable from this sandbox —
  so their code was read but not measured.
- **The repository copy of `index.html` is up to date again.** v5.3.7 and v5.3.8 shipped only as
  release assets: `git push` is denied for this connection, the Git Data API refuses blobs, and the
  one remaining route into the repository carried the file inline in the tool call, which cannot
  carry 2.7 MB. The file does not have to go through the tool call at all — the maintenance program
  reads it from disk and hands the bytes to that same API call — so `index.html`
  (**2,755,634** bytes), `android/assets/index.html`, `android/AndroidManifest.xml` (versionCode
  **30** / versionName **5.3.9**) and this changelog were all committed in this run, and
  `main/index.html` now hashes to the exact file that is inside the APK (sha256
  `06b93f9d…3743b4`). Because this build is made on top of the v5.3.8 file, the v5.3.7 and v5.3.8
  fixes are in the repository for the first time as well.

## v5.3.8 — 2026-11-11
**Every control in fullscreen photo mode works again, and the "newest uploads" view can actually
refresh**

- **The fullscreen photo view was drawn with five controls that did nothing when tapped.** `#overlay`
  carries `pointer-events:none` on purpose — a click outside the window has to reach the dim layer
  behind it, which is what closes the window — and `.win` turns pointer events back on for its own
  contents. The two side arrows (`#fsPrev`, `#fsNext`) and the credit bar (`#fsCredit`: its
  **Fill/Fit** button, its **Exit** button and its **Commons ↗** link) are children of `#overlay`,
  not of `.win`, so they inherited the switch-off. They were painted on top of the photo and were
  simply transparent to the mouse and the finger. Measured in headless Chromium against the live
  CDN, open **"Wind Point Lighthouse 071104"** → **⛶ Fullscreen**: `getComputedStyle` reported
  `pointer-events: none` for all five, `document.elementFromPoint` at the centre of each returned
  `IMG#pimg`, and real clicks changed nothing — the title stayed **"Wind Point Lighthouse 071104"**
  after **›** and after **‹**, `object-fit` stayed **contain** after **Fill**, no tab opened from
  **Commons ↗**, and `#overlay` was still `overlay fs` after **Exit**. The keyboard path
  (ArrowLeft/ArrowRight) worked, which is why this stayed invisible. Now those five carry
  `pointer-events:auto`: **›** gives **"Aceras anthropophora (detail)"** and **‹** returns to
  **"Wind Point Lighthouse 071104"**, **Fill** flips `object-fit` to **cover** and the label to
  **"◱ Fit"** (and back to **contain / "◻ Fill"**), **Commons ↗** opens
  `https://commons.wikimedia.org/wiki/File:Wind_Point_Lighthouse_071104.jpg`, and **Exit** leaves
  fullscreen (`overlay fs` → `overlay`, window still open). Nothing else about the layer changed:
  the bar's background is still click-through, so tapping or dragging it still reaches the photo.
- **Pull-to-refresh on the "🆕 Naye" view always answered "Already up to date" and never added a
  wallpaper.** `refreshFeed()` filters what the Commons API returned through `inPool()`, which is
  the *search term* filter — and `#fresh` is a mode, not a term, so it looked for the literal string
  `"#fresh"` inside every title and description and rejected the whole page. Measured with the
  Commons API answered by a stub that adds one genuinely new upload (**"Newone.jpg"**) between the
  two fetches: before, the view held **3** cards before and **3** after the refresh, with the toast
  **"✅ Already up to date"**; after, **3 → 4** cards, toast **"✨ 1 new wallpapers added"**, and the
  new wallpaper is the first card. The same flow against the live CDN went **40 → 42** cards instead
  of staying at 40. The filter still applies where it belongs: on the **cars** chip the same mocked
  refresh stays at **116 → 116** with "Already up to date", and the plain gallery view is unchanged.
- **Nothing visual changed.** The 67,244 bytes of HTML+CSS before the single `<script>` block are
  identical apart from three CSS rules that gain `pointer-events:auto` and one 4-line comment, and
  the script diff is **1 expression changed, 3 comment lines added**; the 26 bytes after `</script>`
  are byte-identical. 2,753,105 → 2,753,796 bytes (+691). Proof that nothing moved or recoloured: with the
  live API and all images blocked (so the grid cannot vary between runs) and animations frozen, a
  screenshot of the whole 1280×900 screen differs by **0 px of 1,152,000** and the open window by
  **0 px**, against a same-build run-to-run noise floor of **0 px**; the fullscreen view is **0 px**
  different too. Computed style and geometry of **40** elements (header, title, search box, chip row,
  the chip lens, meta line, cell, card, face, caption, title, credit line, more button, the three
  header buttons, the 4D logo, status line, toast, pull indicator, window, title bar, tabs, tab lens,
  photo, download buttons, fullscreen button, both arrows, the credit bar and its buttons, the new
  pill, the popover, the language sheet and the credits sheet) across **35** properties each: **0**
  differences, except the four `pointer-events` values that are the fix.
- Real-CDN run at 1280×900: **0** HTTP 429, **0** failed requests, **0** console errors, **0**
  unhandled rejections; boot FCP **832 ms**, **20** long tasks (2.04 s, max 614 ms), **168** cards,
  **68** thumbnails, every one **200** (69 responses in all, the document included), **0** failed
  faces; 12-step scroll **600** cards, **236** images, **62**
  long tasks (9.53 s, max 794 ms) against v5.3.7's 22 (2.37 s) / 57 (9.3 s) — the same within this
  machine's noise. Profiled again with CDP to be sure no script win was left on the table: over
  those 12 scroll steps the page spent **0.53 s** in script, **3.61 s** in layout and **0.84 s** in
  style, i.e. the jank is layout and raster of the glass cards, not JavaScript.
- Checked and found already fine, so not touched: **"📋 Copy all credits"** blocks the main thread
  for **17.7 s** (the toast lands **19.6 s** after the tap) because it copies all 6,288 credits —
  about **1.5 MB** — and `document.execCommand('copy')` on a payload that size costs **11.6 s per
  MB** here on its own. Filling the hidden textarea *after* focusing it (in isolation that turned a
  15.9 s `focus()` into 0.1 s) was tried and **reverted**: in the real button path the freeze went
  **17.7 → 17.9 s**, so the copy itself is the cost and the only real fix would be copying fewer
  lines, which is a feature change. **The rest of the app after the two edits** — Escape, ArrowLeft/
  ArrowRight and **F** guards, the Android Back JS (unchanged), open/close/maximise of the window,
  favourites add/remove/refresh, credits copy / .txt download / load-more, mobile pull-to-refresh at
  390×844, a language switch in the middle of a search, and 10 rapid category switches followed by a
  30 s offline/online cycle: **0** failed faces after reconnect, **0** stuck `lock` classes, **0**
  429s. **The repository copy of `index.html`** was still the v5.3.6 file, because v5.3.7 shipped
  only as a release asset. This session's write path is the same one v5.3.7 ran into: `git push` is
  denied for the connection (**403**), the Git Data API refuses blobs (*Resource not accessible by
  integration*), and the only route into the repository carries the file inline in the tool call,
  which cannot carry 2.7 MB — so `android/AndroidManifest.xml` (versionCode 29 / versionName 5.3.8)
  was updated normally, and the fixed `index.html` and this changelog are attached to the **v5.3.8**
  release (the `index.html` there is the file inside the APK). Copying the release's `index.html`
  over the repository copy is still the one remaining step, for v5.3.7 and v5.3.8 alike.

## v5.3.7 — 2026-11-10
**Every wallpaper's "Download Original" works again, and pulling down inside the language sheet
no longer rebuilds the gallery behind it**

- **"⬇ Original" saved nothing for all 6,288 embedded wallpapers, and "⬇ Download HD" / the
  Android "Set wallpaper" failed for the 353 whose width is 1920 or less.** The embedded list
  stores only each thumbnail's path, so `origOf()` rebuilds the original by dropping the `/thumb/`
  part of it — but it kept the *thumbnail* host, producing
  `thumb.wikimedia.org/wikipedia/commons/1/18/Bradypus.jpg`. That host answers a non-thumb path
  with a **301 to `https://commons.wikimedia.org/`**, an HTML page on another origin, so the
  download's `fetch()` never got an image. Measured in headless Chromium against the live CDN:
  open **"Bradypus"** (1536 × 2048) → **⬇ Original** — before: one request to the thumb host,
  **0** blobs created, toast *"Download was blocked. Open the image and long-press to save it."*
  whose **Open ↗** link went to the Commons homepage; after: `200 image/jpeg` from
  `upload.wikimedia.org`, blob **2,857,782 bytes**, toast *"✅ Downloaded — don't forget the
  credit!"*. The same click on **⬇ Download HD** went from **0** blobs to the same
  **2,857,782**-byte JPEG, and on **"Inside Balconies Cave at Pinnacles National Monument 1"**
  (1257 × 1874) the window's photo went from the **500 × 745** thumbnail to the full
  **1257 × 1874** original and its **⬇ Original** from **0** to **2,462,000** bytes. `origOf()`
  now maps the thumbnail host to `upload.wikimedia.org`, which is where the same path really
  lives (8 of 8 sampled entries `200 image/jpeg`; `access-control-allow-origin: *`, so the
  download's CORS fetch succeeds). `bigUrl()` hands exactly this URL to the APK's
  `Wallpaper.set()` bridge, so the 353 smaller originals no longer come back as
  *"could not decode image"* — that is the same value measured above, not a separate run on a
  device. For a 2500 × 1625 entry (whose HD download already used the 1920 px thumbnail) nothing
  changed: `1920px-…jpg`, **479,670** bytes, before and after.
- **Dragging down inside the open language sheet started a pull-to-refresh and threw away the
  gallery behind it.** The `touchstart` guard tested `isOpen || popOpen || credOpen` and had never
  been given `langOpen`, and the language list is taller than the sheet on a phone (measured
  **770 px of rows in a 565 px box**), so the natural gesture of scrolling it back up landed in
  the pull handler: every `touchmove` was `preventDefault`-ed — **8 of 8** — which stops the list
  from scrolling at all, and releasing past the threshold ran `refreshFeed()`, rebuilding the grid
  under the sheet and scrolling it to the top. Measured at 390 × 844 with touch emulation, a
  160 px down-drag on `#llist`: before: **8/8** moves prevented, `#pull` became `pull on` with
  *"Release to refresh!"*, and on release `#refresh` went busy and the grid went **70 → 50 → 30**
  cards while the sheet was still open; after: **0/8** prevented, `#pull` never leaves `pull`,
  no refresh, grid **50 → 50**. The credits sheet was already guarded and still is (**0/8**,
  grid unchanged), and a pull on the gallery itself still works exactly as before (**8/8**
  prevented, `pull on` → `pull on spin`, `#refresh` busy). `langOpen` is now in the guard, the
  same list of sheets that Escape, the arrow keys and **F** already use.
- **Nothing visual changed.** The 2,548,313 bytes of HTML+CSS that precede the single `<script>`
  block are **byte-identical**, and the script diff is **2 statements changed, 15 lines added**
  (comments included). The two edits touch no markup, no CSS, no string, no class and no
  geometry: one is a host rewrite inside a URL builder, the other adds one identifier to an `if`.
  Real-CDN run at 1280×900: **0** HTTP 429, **0** failed requests, **0** console errors, **0**
  unhandled rejections; boot FCP **808 ms**, **168** cards, **60** thumbnails loaded, **0**
  failed faces; 12-step scroll **155** cards, **112** images, **0** failed faces; credits sheet
  **80** rows, **0** broken images, **0** 429s.
- Checked and found already fine, so not touched: **`strip()`'s DOMParser** — the profiler blamed
  **78 ms** of a live-feed batch on it, but a 200-call benchmark of the same HTML measured
  **4 ms** in total, so the cost was the profiler attributing parse work, and an `innerHTML`
  rewrite measured the same 4 ms: not shipped. **The `nearIO` observer** — it is never
  disconnected, so I expected detached cards to pile up; `Memory.getDOMCounters` after 30 category
  switches showed **4,127 → 3,208** live nodes (no growth) and `usedJSHeapSize` **7,188 → 7,357 KB**,
  so nothing is retained and there was nothing to fix. **The 1,200 ms sentinel interval** — opening
  the credits sheet at the bottom of the page left the card count at **294** for 16 s, because the
  observer had already moved the sentinel out of range: no background filling to stop. **A 40-step
  random UI fuzz** (chips, cards, Escape, arrows, credits, popover, language, refresh, Load more)
  left no stuck `lock` class, no stuck pull spinner, no stuck busy ring and no disabled Load-more
  button. **The i18n tables** — all 168 English keys exist, every `data-i18n` / `data-i18n-ph`
  attribute in the markup and every `t('…')` call resolves; the keys the nine Indian languages and
  the six others are missing fall back to English on purpose.
- **Published as a release, not as a commit to `index.html`.** The GitHub write path this
  maintenance session has can only carry a file inline in the tool call, and `git push` is denied
  for the connection, so the 2.75 MB `index.html` and `android/assets/index.html` could not be
  replaced in the repository; the fixed file is attached to the **v5.3.7** release (and is the one
  inside the APK). `android/AndroidManifest.xml` (versionCode 28 / versionName 5.3.7) was updated
  normally. Copying the release's `index.html` over the repository copy is the only remaining step
  for v5.3.7.

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
