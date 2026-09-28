#!/usr/bin/env bash
# 把 EraCore APK 部署到已连接的 Android 设备，并做启动自检 + 内存采样
#
# 用法:
#   ./deploy-android.sh [apk路径]
# 不传 apk 则用 Debug 构建产物。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="$REPO_ROOT/tools/android-sdk/platform-tools/adb"
PKG="com.eracore.maui"
ACTIVITY="$PKG/crc64a4e4bc3d698d8bd7.MainActivity"
GAME_DIR="/sdcard/emuera/eraTW"

APK="${1:-$REPO_ROOT/era-core-src/EraCore.Maui/bin/Debug/net10.0-android/$PKG-Signed.apk}"

echo "=== 设备 ==="
"$ADB" devices -l | tail -n +2
if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "[失败] 无设备。检查 USB 调试是否开启、是否已授权。"; exit 1
fi

echo
echo "=== 安装 ==="
"$ADB" install -r "$APK" 2>&1 | tail -3

echo
echo "=== 授权「所有文件访问」 ==="
"$ADB" shell appops set "$PKG" MANAGE_EXTERNAL_STORAGE allow
"$ADB" shell appops get "$PKG" MANAGE_EXTERNAL_STORAGE

echo
echo "=== 游戏目录 ==="
"$ADB" shell ls -d "$GAME_DIR" 2>&1

echo
echo "=== 启动并采样内存 ==="
"$ADB" shell am force-stop "$PKG"
"$ADB" shell am start -n "$ACTIVITY" >/dev/null 2>&1

for t in 3 6 10 15 25 40; do
  sleep $((t - ${prev:-0})); prev=$t
  PID="$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')"
  if [ -z "$PID" ]; then
    echo "t=${t}s  进程已退出 —— 崩溃"
    break
  fi
  PSS="$("$ADB" shell dumpsys meminfo "$PKG" 2>/dev/null | awk '/TOTAL PSS/ {print $3; exit} /TOTAL:/ {print $2; exit}')"
  echo "t=${t}s  pid=$PID  TOTAL PSS ≈ ${PSS:-?} kB"
done

echo
echo "=== 最近崩溃记录（若上一步显示退出） ==="
"$ADB" shell "dumpsys activity exit-info $PKG" 2>/dev/null | grep -E "timestamp|reason|description" | head -6
