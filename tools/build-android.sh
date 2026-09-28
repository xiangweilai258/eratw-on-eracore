#!/usr/bin/env bash
# 构建 EraCore Android APK
#
# 关键：必须显式传 EmbedAssembliesIntoApk=true
#
# 原因（已实测定位）：
#   dotnet/packs/Microsoft.Android.Sdk.Darwin/36.1.69/tools/Xamarin.Android.Common.targets:166
#     <EmbedAssembliesIntoApk Condition=" '$(EmbedAssembliesIntoApk)' == '' And '$(Optimize)' != 'True'
#         And '$(_AndroidFastDeploymentSupported)' == 'True' ">False</EmbedAssembliesIntoApk>
#
#   Debug 构建（Optimize != True）在支持快速部署的设备上默认把该属性置为 False
#   → 合并出的 AndroidManifest 写入 android:extractNativeLibs="true"
#   → _ReadAndroidManifest 读出 _EmbeddedDSOsEnabled=False
#   → .so 不进 AndroidStoreUncompressedFileExtensions 白名单
#   → APK 内 lib/<abi>/*.so 全部被 DEFLATE 压缩
#   → 一旦不走 fast-deploy（即普通 adb install），运行时读不到程序集，
#      libmonodroid 直接 abort：
#        "ALL entries in APK named `lib/arm64-v8a/` MUST be STORED."
#
#   传 EmbedAssembliesIntoApk=true 后 extractNativeLibs=false，
#   .so 以 STORED 落盘，APK 自包含、可直接分发安装。
#
# 用法:
#   ./build-android.sh            # Debug
#   ./build-android.sh Release    # Release（默认已 EmbedAssembliesIntoApk=true，无需额外开关）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-Debug}"

# ---- 工具链路径：跨平台自动探测（2026-09-27 改为自推导，换机不用再改）----
# JDK：Windows 便携版是 tools/jdk/bin/java，macOS 版是 tools/jdk/Contents/Home/bin/java
if [ -d "$REPO_ROOT/tools/jdk/Contents/Home" ]; then
  JAVA_HOME="$REPO_ROOT/tools/jdk/Contents/Home"     # macOS 布局
elif [ -d "$REPO_ROOT/tools/jdk" ]; then
  JAVA_HOME="$REPO_ROOT/tools/jdk"                   # Windows/Linux 布局
else
  echo "[警告] 未找到 tools/jdk，尝试用系统 JAVA_HOME=${JAVA_HOME:-<未设置>}"
fi
export JAVA_HOME
export ANDROID_HOME="$REPO_ROOT/tools/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

# dotnet：优先项目内（tools/dotnet），回退到全局 dotnet
if [ -x "$REPO_ROOT/tools/dotnet/dotnet.exe" ]; then
  DOTNET="$REPO_ROOT/tools/dotnet/dotnet.exe"
elif [ -x "$REPO_ROOT/tools/dotnet/dotnet" ]; then
  DOTNET="$REPO_ROOT/tools/dotnet/dotnet"
elif command -v dotnet >/dev/null 2>&1; then
  DOTNET="$(command -v dotnet)"
else
  echo "[错误] 找不到 dotnet（项目内 tools/dotnet 与全局都没有）"; exit 1
fi
export DOTNET_ROOT="$REPO_ROOT/tools/dotnet"

# build-tools 版本：按实际安装的目录自动取（避免写死 36.0.0）
BT_DIR="$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)"
BT_DIR="${BT_DIR%/}"

PROJ="$REPO_ROOT/era-core-src/EraCore.Maui/EraCore.Maui.csproj"

# Python 解释器（自检 2 用）。优先 PATH，其次常见托管运行时位置 —— 不写死单机路径，
# 换机后无需再改（2026-09-26：由旧机写死路径改为解析式）。
PY="${PYTHON:-}"
if [ -z "$PY" ]; then
  for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
  done
fi
if [ -z "$PY" ]; then
  for p in "$HOME/.local/bin/python3" /usr/local/bin/python3 /opt/homebrew/bin/python3; do
    if [ -x "$p" ]; then PY="$p"; break; fi
  done
fi
: "${PY:?找不到 python 解释器，请设置 PYTHON 环境变量}"

EXTRA=()
if [ "$CONFIG" = "Debug" ]; then
  EXTRA+=("-p:EmbedAssembliesIntoApk=true")
fi

# 注意：MauiAsset 的 glob 在项目加载时求值。若 EraCore.Web 的 wwwroot 是刚生成的，
# 首次构建可能收不到前端资源，需连跑两次。这里直接跑两次以确保 assets/wwwroot 齐全。
for pass in 1 2; do
  echo "=== [$CONFIG] 构建 pass $pass/2 ==="
  "$DOTNET" build "$PROJ" \
    -f net10.0-android \
    -c "$CONFIG" \
    -p:AndroidPackageFormats=apk \
    "${EXTRA[@]}"
done

OUT="$REPO_ROOT/era-core-src/EraCore.Maui/bin/$CONFIG/net10.0-android"
echo
echo "=== 产物 ==="
ls -lh "$OUT"/*.apk

APK="$OUT/com.eracore.maui-Signed.apk"
[ -f "$APK" ] || APK="$OUT/com.eracore.maui.apk"

# ---- 自检 1：清单里的 extractNativeLibs 必须是 false ----
echo
echo "=== 自检 1：extractNativeLibs ==="
AAPT2="$BT_DIR/aapt2"
if [ ! -x "$AAPT2" ] && [ -x "$AAPT2.exe" ]; then AAPT2="$AAPT2.exe"; fi
ENL=$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" 2>/dev/null \
      | grep -o 'extractNativeLibs(0x010104ea)=[a-z]*' | head -1)
echo "APK 清单: ${ENL:-<未设置>}"
if [ "${ENL##*=}" != "false" ]; then
  echo "[警告] extractNativeLibs 不为 false —— lib/ 下的 .so 很可能被压缩，装到设备上会 abort。"
fi

# ---- 自检 2：lib/ 下的 .so 必须 STORED ----
echo
echo "=== 自检 2：原生库压缩状态 ==="
"$PY" - "$APK" <<'PY'
import sys, zipfile
apk = sys.argv[1]
z = zipfile.ZipFile(apk)
libs = [i for i in z.infolist() if i.filename.startswith("lib/") and i.filename.endswith(".so")]
compressed = [i for i in libs if i.compress_type != 0]
print(f"{len(libs)} 个 .so，其中压缩的 {len(compressed)} 个")
for i in compressed[:5]:
    print(f"   !! DEFLATED: {i.filename}")
if compressed:
    print("\n[失败] 存在被压缩的 .so —— 装到设备上会触发 libmonodroid abort。")
    sys.exit(1)
print("[通过] 全部 .so 均为 STORED。")
PY

# ---- 自检 3：页对齐（extractNativeLibs=false 的前提） ----
echo
echo "=== 自检 3：lib/ 页对齐 ==="
ZIPALIGN="$BT_DIR/zipalign"
if [ ! -x "$ZIPALIGN" ] && [ -x "$ZIPALIGN.exe" ]; then ZIPALIGN="$ZIPALIGN.exe"; fi
if "$ZIPALIGN" -c -p -v 4 "$APK" >/tmp/zipalign-check.txt 2>&1; then
  echo "[通过] 已按 4 字节页对齐。"
else
  echo "[警告] 未按页对齐，需执行: zipalign -p -f 4 <in> <out> 后重新签名。"
  tail -3 /tmp/zipalign-check.txt
fi
