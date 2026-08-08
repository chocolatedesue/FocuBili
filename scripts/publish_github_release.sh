#!/usr/bin/env bash
# 将本地产物目录上传到 GitHub Release（需 gh 已登录）。
#
# 期望目录内文件名（示例 v1.2.1）:
#   FocuBili-v1.2.1-android-arm64-v8a.apk
#   FocuBili-v1.2.1-android-armeabi-v7a.apk
#   FocuBili-v1.2.1-android-x86_64.apk
#   FocuBili-v1.2.1-windows-x64.zip
#   FocuBili-v1.2.1-macos.zip
#
# 用法:
#   ./scripts/publish_github_release.sh v1.2.1 /path/to/assets
#   ./scripts/publish_github_release.sh v1.2.1 /path/to/assets --notes-file docs/RELEASE_NOTES_v1.2.1.md
#
# 从 Codemagic 拉 split APK 可先手动下载，再重命名为上表后执行本脚本。
# Android 构建请使用: flutter build apk --release --split-per-abi
# 不要把 fat app-release.apk 当作发布物。
set -euo pipefail

TAG="${1:?usage: $0 <tag> <assets-dir> [--notes-file path] [--title title]}"
ASSETS_DIR="${2:?usage: $0 <tag> <assets-dir> [--notes-file path]}"
shift 2

REPO="${REPO:-chocolatedesue/FocuBili}"
NOTES_FILE=""
TITLE="FocuBili ${TAG}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes-file) NOTES_FILE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$ASSETS_DIR" ]]; then
  echo "assets dir not found: $ASSETS_DIR" >&2
  exit 1
fi

cd "$ASSETS_DIR"
mapfile -t FILES < <(find . -maxdepth 1 -type f ! -name '.*' | sed 's|^\./||' | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "no files in $ASSETS_DIR" >&2
  exit 1
fi

# Reject obvious fat android single-name if both fat and split present
if ls FocuBili-*-android.apk >/dev/null 2>&1 && ls FocuBili-*-android-arm64*.apk >/dev/null 2>&1; then
  echo "warn: both fat *-android.apk and split arm64 APKs present; prefer deleting fat before upload" >&2
fi

sha256sum FocuBili-* > SHA256SUMS.txt 2>/dev/null || sha256sum ./* > SHA256SUMS.txt
echo "SHA256SUMS.txt:"
cat SHA256SUMS.txt

ARGS=(release upload "$TAG" -R "$REPO" --clobber)
for f in "${FILES[@]}" SHA256SUMS.txt; do
  [[ -f "$f" ]] || continue
  ARGS+=("$f")
done

if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  echo "Updating existing release $TAG"
  if [[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]]; then
    gh release edit "$TAG" -R "$REPO" --title "$TITLE" --notes-file "$NOTES_FILE"
  fi
  gh "${ARGS[@]}"
else
  echo "Creating release $TAG"
  CREATE=(release create "$TAG" -R "$REPO" --title "$TITLE" --target master)
  if [[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]]; then
    CREATE+=(--notes-file "$NOTES_FILE")
  else
    CREATE+=(--generate-notes)
  fi
  for f in "${FILES[@]}" SHA256SUMS.txt; do
    [[ -f "$f" ]] || continue
    CREATE+=("$f")
  done
  gh "${CREATE[@]}"
fi

echo
gh release view "$TAG" -R "$REPO"
echo "Done: https://github.com/${REPO}/releases/tag/${TAG}"
