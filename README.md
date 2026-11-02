<div align="center">

<img src="screenshots/app-icon.png" alt="Wiki Wallpapers 4D icon" width="120">

# Wiki Wallpapers 4D

**2,322 free wallpapers from Wikimedia Commons — liquid-glass UI, 4D depth, live updates, and full credits for every single image.**

[![Web](https://img.shields.io/badge/web-open%20index.html-4c82ff)](#-run-it)
[![Android](https://img.shields.io/badge/android-APK%20v4.0.0-3ddc84)](../../releases/latest)
[![License](https://img.shields.io/badge/code-MIT-blue)](LICENSE)
[![Images](https://img.shields.io/badge/images-CC%20BY--SA%20%2F%20PD-orange)](CREDITS.md)

<img src="screenshots/01-desktop-4d-grid.jpg" alt="Wiki Wallpapers 4D desktop" width="100%">

</div>

---

## What it is

A single-file wallpaper app (one HTML file, no build step, no framework) that turns
[Wikimedia Commons](https://commons.wikimedia.org) — the free media library behind Wikipedia —
into a wallpaper feed. Every image carries its photographer, license and source page,
because most of Commons is CC BY / CC BY-SA and **attribution is required**.

The Android app is a thin WebView shell around the exact same HTML, so web and APK
always behave identically.

## Screenshots

| Mobile feed | Fullscreen viewer | Credits |
|---|---|---|
| <img src="screenshots/02-mobile-feed.jpg" width="240"> | <img src="screenshots/03-fullscreen-viewer.jpg" width="240"> | <img src="screenshots/04-credits.jpg" width="240"> |

| 4D depth settings | Light theme |
|---|---|
| <img src="screenshots/05-settings-4d.jpg" width="240"> | <img src="screenshots/06-light-theme.jpg" width="620"> |

## Features

**4D glass UI**
Liquid-glass panels with real refraction (`feDisplacementMap`), a 3D tilt + glare on every
card, parallax backdrop, and optional gyroscope depth on phones. Every knob — blur,
transparency, saturation, corner radius, shine, tilt depth, animation curve and speed —
is live-tweakable from the settings popover and saved to `localStorage`.

**2,322 wallpapers, instantly**
The whole curated library is embedded in the HTML, so the feed opens with zero network
and zero layout shift. 61 categories, mixed portrait/landscape masonry, lazy loading,
infinite scroll.

**Live from Commons**
- 🔄 **Pull down to refresh** — newest featured pictures are fetched and prepended with a `NEW` badge
- 🆕 **"Naye" chip** — the latest uploads from `Category:Featured pictures on Wikimedia Commons`, newest first
- ⏱️ **Auto-update** — checks every 2.5 minutes and offers a "N naye wallpapers" pill
- 🌐 **Live search merged in** — any keyword also queries Commons directly
- ● **Live / ○ Offline** indicator, plus a full offline fallback on the embedded library

**4D app icon**
The launcher icon is a real 4D tile — an extruded depth slab under a glass face with a
specular highlight and a drop shadow — and the same icon sits next to the title inside the app.

**Fullscreen**
Edge-to-edge viewer with `Fit` / `Fill`, `‹ ›` arrows, `←` `→` keys, swipe navigation,
a credit strip that stays visible, and `Esc` to exit. The whole app also has an
`F` / header-button fullscreen mode.

**Credits, everywhere**
- `© Photographer · License` on every card
- Copy-ready credit line + license + source link in each image's window
- A searchable credits sheet (by photographer, license or title) with **Copy all** and **Credits .txt**
- [`CREDITS.md`](CREDITS.md) — all 2,322 images, one row each

**No accidental copying**
Text selection, long-press callouts, image dragging and the context menu are disabled
everywhere except input fields and links — so holding a card never opens a copy popup.
The "Copy credit" buttons still work.

## Run it

**Web** — open [`index.html`](index.html) in any modern browser. That's it.

**Android** — download `wiki-wallpapers-4d.apk` from the [latest release](../../releases/latest)
and install it (you'll need to allow "install unknown apps" for your browser/file manager).

| | |
|---|---|
| Package | `net.wikiwallpapers.app` |
| Version | 4.1.0 (versionCode 5) |
| Min / Target SDK | 24 (Android 7) / 34 |
| Size | ~480 KB |
| Permissions | Internet, network state, set wallpaper |

## Build the APK

The APK is built **without Gradle** — just `aapt2` + `javac` + `d8` + `apksigner`,
so it builds in seconds and needs no dependency downloads.

```bash
# needs JDK 17 and Android SDK build-tools 34 + platform 34
export ANDROID_SDK=/path/to/android-sdk
export JAVA_HOME=/path/to/jdk-17
cd android && ./build-apk.sh
# → android/build/wiki-wallpapers-4d.apk
```

`android/assets/index.html` is a copy of the root `index.html` — update both when you change the app.

The signing key is committed at `android/tools/keystore.jks`
(store & key password `wikiwallpapers`, alias `wikiwallpapers`) so that future builds
can be installed as an update over this one. Replace it with your own key for a real release.

## Project layout

```
index.html                  the whole app (UI + data + logic, single file)
screenshots/                README images
CREDITS.md                  per-image attribution for all 2,322 wallpapers
android/
  AndroidManifest.xml
  src/net/wikiwallpapers/app/MainActivity.java   WebView shell + back-button handling
  res/                                            launcher icons, strings
  assets/index.html                               copy of the app
  build-apk.sh                                    Gradle-free build script
```

## How the data works

The embedded library stores, per image: `i` id, `t` title, `a` artist, `l` license,
`lu` license URL, `p` Commons file page, `th` thumbnail, `w`/`h` size, `d` description,
`c` category. Live results are fetched from the Commons API
(`action=query`, `prop=imageinfo`, `iiprop=url|size|mime|extmetadata`) and normalised into
the same shape, so the UI never cares where an image came from.

## Credits & license

**Code:** [MIT](LICENSE).

**Images:** each wallpaper keeps its own license from Wikimedia Commons — CC BY-SA 4.0
(1,237), CC BY-SA 3.0 (410), Public domain (203), CC BY 4.0 (139), CC0 (71), and others.
Full attribution for every image is in [`CREDITS.md`](CREDITS.md). Images are loaded from
Wikimedia's servers, not re-hosted. If you repost a wallpaper, keep the credit line.

Built with ❤️ for Wikipedia's photographers.
