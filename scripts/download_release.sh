#!/usr/bin/env bash
# 从 GitHub Release 下载 FocuBili 多端产物（默认 v1.2.1）。
# 用法:
#   ./scripts/download_release.sh
#   ./scripts/download_release.sh v1.2.1 ./dist
#   ./scripts/download_release.sh v1.2.1 ./dist arm64   # 仅 Android arm64-v8a
set -euo pipefail

TAG="${1:-v1.2.1}"
OUT_DIR="${2:-./dist/${TAG}}"
FILTER="${3:-all}" # all | arm64 | android | windows | macos
REPO="${REPO:-chocolatedesue/FocuBili}"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

download() {
  local name="$1"
  echo ">> $name"
  gh release download "$TAG" -R "$REPO" -p "$name" --clobber
}

case "$FILTER" in
  arm64)
    download "FocuBili-${TAG#v}-android-arm64-v8a.apk" 2>/dev/null \
      || download "FocuBili-v1.2.1-android-arm64-v8a.apk"
    ;;
  android)
    gh release download "$TAG" -R "$REPO" -p "FocuBili-*-android-*.apk" --clobber
    ;;
  windows)
    gh release download "$TAG" -R "$REPO" -p "FocuBili-*-windows*.zip" --clobber
    ;;
  macos)
    gh release download "$TAG" -R "$REPO" -p "FocuBili-*-macos*.zip" --clobber
    ;;
  all|*)
    gh release download "$TAG" -R "$REPO" --clobber
    ;;
esac

echo
echo "Saved under: $(pwd)"
ls -lh
if [[ -f SHA256SUMS.txt ]]; then
  echo
  echo "Verifying SHA256SUMS.txt (files present only)..."
  sha256sum -c SHA256SUMS.txt --ignore-missing 2>/dev/null || sha256sum -c SHA256SUMS.txt || true
fi
