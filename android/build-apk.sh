#!/usr/bin/env bash
# Build Wiki Wallpapers 4D APK without Gradle (aapt2 + javac + d8 + apksigner)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK:-$HERE/../tools/sdk}"
JAVA_HOME="${JAVA_HOME:-$(ls -d $HERE/../tools/jdk-17* | head -1)}"
BT="$(ls -d $SDK/build-tools/* | head -1)"
PLATFORM="$(ls -d $SDK/platforms/* | head -1)"
export PATH="$JAVA_HOME/bin:$PATH"
export _JAVA_OPTIONS="${_JAVA_OPTIONS:--Xmx192m -Xss512k -XX:CompressedClassSpaceSize=32m -XX:MaxMetaspaceSize=96m -XX:ReservedCodeCacheSize=24m}"

OUT="$HERE/build"
rm -rf "$OUT"; mkdir -p "$OUT/obj" "$OUT/dex" "$OUT/res"

echo "==> aapt2 compile"
"$BT/aapt2" compile --dir "$HERE/res" -o "$OUT/res.zip"

echo "==> aapt2 link"
"$BT/aapt2" link -o "$OUT/base.apk" \
  -I "$PLATFORM/android.jar" \
  --manifest "$HERE/AndroidManifest.xml" \
  -R "$OUT/res.zip" \
  --auto-add-overlay \
  -A "$HERE/assets" \
  --min-sdk-version 24 --target-sdk-version 34

echo "==> javac"
javac -source 8 -target 8 -nowarn -encoding UTF-8 \
  -classpath "$PLATFORM/android.jar" -d "$OUT/obj" \
  $(find "$HERE/src" -name '*.java')

echo "==> d8"
"$BT/d8" --lib "$PLATFORM/android.jar" --min-api 24 --release \
  --output "$OUT/dex" $(find "$OUT/obj" -name '*.class')

echo "==> package dex"
( cd "$OUT/dex" && zip -q -X "$OUT/base.apk" classes.dex )

echo "==> zipalign"
"$BT/zipalign" -f -p 4 "$OUT/base.apk" "$OUT/aligned.apk"

if [ ! -f "$HERE/tools/keystore.jks" ]; then
  echo "==> keystore"
  mkdir -p "$HERE/tools"
  keytool -genkeypair -v -keystore "$HERE/tools/keystore.jks" -storepass wikiwallpapers \
    -keypass wikiwallpapers -alias wikiwallpapers -keyalg RSA -keysize 2048 -validity 10950 \
    -dname "CN=Wiki Wallpapers 4D, O=Wiki Wallpapers, C=IN" >/dev/null 2>&1
fi

echo "==> sign"
"$BT/apksigner" sign --ks "$HERE/tools/keystore.jks" --ks-pass pass:wikiwallpapers \
  --key-pass pass:wikiwallpapers --ks-key-alias wikiwallpapers \
  --out "$HERE/build/wiki-wallpapers-4d.apk" "$OUT/aligned.apk"

"$BT/apksigner" verify --print-certs "$HERE/build/wiki-wallpapers-4d.apk" | head -4
ls -lh "$HERE/build/wiki-wallpapers-4d.apk"
