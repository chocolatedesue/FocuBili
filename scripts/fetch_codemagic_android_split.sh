#!/usr/bin/env bash
# 从 Codemagic 某次 android-apk 构建下载 split APK，并重命名为 Release 风格文件名。
#
# 依赖: curl, python3, ~/.cmtoken 内容为 CM_API_TOKEN=... 或纯 token
#
# 用法:
#   ./scripts/fetch_codemagic_android_split.sh <buildId> [out-dir] [version]
# 示例:
#   ./scripts/fetch_codemagic_android_split.sh 6a76c8b1342a2c4888389cf9 ./dist/android 1.2.1
set -euo pipefail

BUILD_ID="${1:?usage: $0 <codemagic-build-id> [out-dir] [version]}"
OUT_DIR="${2:-./dist/android-split}"
VERSION="${3:-1.2.1}"

if [[ -f "${HOME}/.cmtoken" ]]; then
  CM_TOKEN=$(grep -oE '[^=]+$' "${HOME}/.cmtoken" | head -1 | tr -d ' \n\r')
elif [[ -n "${CM_API_TOKEN:-}" ]]; then
  CM_TOKEN="$CM_API_TOKEN"
else
  echo "need ~/.cmtoken or CM_API_TOKEN" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
export BUILD_ID OUT_DIR VERSION CM_TOKEN

python3 - <<'PY'
import json, os, urllib.request, hashlib

token = os.environ["CM_TOKEN"]
build_id = os.environ["BUILD_ID"]
out_dir = os.environ["OUT_DIR"]
version = os.environ["VERSION"]

req = urllib.request.Request(
    f"https://api.codemagic.io/builds/{build_id}",
    headers={"x-auth-token": token},
)
with urllib.request.urlopen(req, timeout=120) as r:
    build = json.load(r).get("build", {})

seen = set()
for art in build.get("artefacts") or []:
    name = art.get("name") or ""
    if not name.endswith(".apk") or "latest" in name:
        continue
    if name in seen:
        continue
    if "arm64-v8a" in name:
        out_name = f"FocuBili-v{version}-android-arm64-v8a.apk"
    elif "armeabi-v7a" in name:
        out_name = f"FocuBili-v{version}-android-armeabi-v7a.apk"
    elif "x86_64" in name:
        out_name = f"FocuBili-v{version}-android-x86_64.apk"
    else:
        continue
    seen.add(name)
    url = art["url"]
    print(f"fetch {name} -> {out_name}")
    req = urllib.request.Request(url, headers={"x-auth-token": token})
    with urllib.request.urlopen(req, timeout=600) as r:
        data = r.read()
    path = os.path.join(out_dir, out_name)
    with open(path, "wb") as f:
        f.write(data)
    print(f"  sha256 {hashlib.sha256(data).hexdigest()} size={len(data)}")

print("out:", out_dir)
for fn in sorted(os.listdir(out_dir)):
    print(" ", fn)
PY
