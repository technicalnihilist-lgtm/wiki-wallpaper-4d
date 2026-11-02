#!/usr/bin/env bash
# Downloads a JDK + Android SDK pieces into ./tools so android/build-apk.sh can run.
# Safe to re-run: skips anything already present.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$HERE/tools"
mkdir -p "$T"

if ! ls -d "$T"/jdk-17* >/dev/null 2>&1; then
  echo "==> downloading JDK 17"
  curl -sL --max-time 900 -o "$T/jdk.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"
  tar xzf "$T/jdk.tar.gz" -C "$T" && rm -f "$T/jdk.tar.gz"
fi

if [ ! -f "$T/sdk/platforms/android-34/android.jar" ]; then
  echo "==> downloading Android platform 34"
  mkdir -p "$T/sdk/platforms"
  curl -sL --max-time 900 -o "$T/plat.zip" "https://dl.google.com/android/repository/platform-34-ext7_r03.zip"
  unzip -q -o "$T/plat.zip" -d "$T/sdk/platforms/" && rm -f "$T/plat.zip"
fi

if [ -z "$(ls -d "$T"/sdk/build-tools/*/aapt2 2>/dev/null | head -1)" ]; then
  echo "==> downloading Android build-tools 34"
  mkdir -p "$T/sdk/build-tools"
  curl -sL --max-time 900 -o "$T/bt.zip" "https://dl.google.com/android/repository/build-tools_r34-linux.zip"
  unzip -q -o "$T/bt.zip" -d "$T/sdk/build-tools/" && rm -f "$T/bt.zip"
fi

echo "==> ready"
echo "ANDROID_SDK=$T/sdk"
ls -d "$T"/jdk-17* "$T"/sdk/platforms/* "$T"/sdk/build-tools/*
