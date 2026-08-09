#!/usr/bin/env bash
# Trigger FocuBili cloud builds: Codemagic Android/macOS and GHA Windows.
# Can run from repo root or from this skill directory.
#
# Usage:
#   .grok/skills/focubili-build/scripts/trigger_cloud_builds.sh
#   .grok/skills/focubili-build/scripts/trigger_cloud_builds.sh android
#   .grok/skills/focubili-build/scripts/trigger_cloud_builds.sh android macos windows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
  # .../repo/.grok/skills/focubili-build/scripts → four levels up
  ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

REPO="${REPO:-chocolatedesue/FocuBili}"
APP_ID="${CM_APP_ID:-6a769232581b36b2411fd1e6}"
BRANCH="${BRANCH:-master}"

if [[ $# -eq 0 ]]; then
  set -- android windows macos
fi

if [[ -f "${HOME}/.cmtoken" ]]; then
  CM_TOKEN=$(grep -oE '[^=]+$' "${HOME}/.cmtoken" | head -1 | tr -d ' \n\r')
else
  CM_TOKEN="${CM_API_TOKEN:-}"
fi

trigger_cm() {
  local wf="$1"
  if [[ -z "${CM_TOKEN:-}" ]]; then
    echo "skip CM $wf (no ~/.cmtoken or CM_API_TOKEN)" >&2
    return 0
  fi
  echo "Codemagic → $wf @ $BRANCH (app $APP_ID)"
  curl -sS -X POST "https://api.codemagic.io/builds" \
    -H "Content-Type: application/json" \
    -H "x-auth-token: $CM_TOKEN" \
    -d "{\"appId\":\"$APP_ID\",\"workflowId\":\"$wf\",\"branch\":\"$BRANCH\"}"
  echo
}

echo "repo root: $ROOT"

for t in "$@"; do
  case "$t" in
    android|apk)
      trigger_cm android-apk
      ;;
    macos|mac)
      trigger_cm macos-build
      ;;
    windows|win)
      if command -v gh >/dev/null 2>&1; then
        echo "GHA → Windows Build @ $BRANCH"
        gh workflow run "Windows Build" -R "$REPO" --ref "$BRANCH"
        sleep 2
        gh run list -R "$REPO" -L 3
      else
        echo "gh not installed; skip Windows" >&2
      fi
      ;;
    cm-windows)
      trigger_cm windows-build
      ;;
    *)
      echo "unknown target: $t (android|macos|windows|cm-windows)" >&2
      ;;
  esac
done
