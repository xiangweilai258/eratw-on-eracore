#!/usr/bin/env bash
# 跨架构启动/内存基准
#
# 为什么要额外量「系统可用内存变化」：
#   不同实现把开销放在不同的进程里——
#     EraCore：主进程 + 独立的 WebView 渲染进程（com.huawei.webview:sandboxed_process*）
#     另有实现会另起引擎 / 渲染子进程；只量主进程的 PSS 会漏算。
#   只量自己那个包的 PSS 会漏算，跨架构比较就不公平。
#   因此除单进程 PSS 外，同步记录 /proc/meminfo 的 MemAvailable 变化。
#
# 用法: ./bench-app.sh <包名> <Activity组件> [采样秒数] [输出前缀]
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="$REPO_ROOT/tools/android-sdk/platform-tools/adb"

PKG="${1:?需要包名}"
ACT="${2:?需要 Activity（pkg/activity 或绝对组件名）}"
DURATION="${3:-60}"
LABEL="${4:-$(echo "$PKG" | tr '.' '_')}"

OUT_DIR="$REPO_ROOT/bench"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/bench-$LABEL.csv"

echo "==============================================="
echo " 基准：$PKG"
echo " Activity: $ACT"
echo " 时长: ${DURATION}s"
echo " 输出: $OUT"
echo "==============================================="

# ---- 归零 ----
"$ADB" shell am force-stop "$PKG" >/dev/null 2>&1
sleep 6

mem() { "$ADB" shell cat /proc/meminfo 2>/dev/null | awk -v k="$1" '$1==k":"{print $2; exit}'; }
TOTAL=$(mem MemTotal); AVAIL=$(mem MemAvailable)
echo "基线：MemTotal=$TOTAL kB   MemAvailable=$AVAIL kB   已用=$(( (TOTAL-AVAIL)/1024 )) MB"

# ---- 冷启动计时 ----
T0=$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')
START_OUT=$("$ADB" shell am start -W -n "$ACT" 2>&1)
T1=$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')
WALL_MS=$(( (T1 - T0) / 1000000 ))

AM_TOTAL=$(echo "$START_OUT" | awk -F': ' '/TotalTime/{print $2}' | tr -d '\r')
AM_WAIT=$(echo  "$START_OUT"  | awk -F': ' '/WaitTime/{print $2}'  | tr -d '\r')
echo
echo "冷启动：am 报 TotalTime=${AM_TOTAL:-?} ms  WaitTime=${AM_WAIT:-?} ms   实测墙钟=${WALL_MS} ms"
echo

echo "时间,秒,PSS_MB,MemAvailable_MB,系统已用_MB,相对基线_MB,进程存活" > "$OUT"

for ((t=0; t<=DURATION; t+=3)); do
  PID="$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')"
  if [ -z "$PID" ]; then
    echo "$(date +%H:%M:%S),$t,,,,,$("$ADB" shell cat /proc/meminfo 2>/dev/null | awk '/MemAvailable/{print int($2/1024)}'),0" >> "$OUT"
    echo "t=${t}s  *** 进程已退出 ***"
    break
  fi
  PSS=$("$ADB" shell dumpsys meminfo "$PID" 2>/dev/null | awk '/TOTAL PSS/{print $3; exit}')
  A=$(mem MemAvailable)
  echo "$(date +%H:%M:%S),$t,$(( ${PSS:-0} / 1024 )),$(( A / 1024 )),$(( (TOTAL-A)/1024 )),$(( (AVAIL-A)/1024 )),1" >> "$OUT"
  printf "t=%3ds  PSS=%5s MB   系统已用=%5s MB   相对基线=%+5s MB\n" \
    "$t" "$(( ${PSS:-0} / 1024 ))" "$(( (TOTAL-A)/1024 ))" "$(( (AVAIL-A)/1024 ))"
  sleep 3
done

echo
echo "=== 采样结束：$OUT ==="
