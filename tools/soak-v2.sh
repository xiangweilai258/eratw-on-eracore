#!/usr/bin/env bash
# 真实游玩期间的资源占用记录（v2：把 WebView 渲染进程也算进来）
#
# 背景：EraCore 的界面跑在 WebView 里，渲染在独立进程
#       com.huawei.webview:sandboxed_process* 中，`dumpsys meminfo <包名>` 不含它。
#       只记主进程会低估真实占用（实测渲染进程 RSS ~180 MB）。
#       因此本脚本同时记录：主进程 PSS/RSS + 全部 WebView 渲染进程 PSS 合计 + 系统可用内存。
#
# 用法: ./soak-v2.sh [分钟数] [采样间隔秒]
# 输出: research/soakv2-<时间戳>.csv
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="$REPO_ROOT/tools/android-sdk/platform-tools/adb"
PKG="${3:-com.eracore.maui}"

MINUTES="${1:-180}"
INTERVAL="${2:-30}"
OUT_DIR="$REPO_ROOT/research"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/soakv2-$(echo "$PKG" | tr '.' '_')-$(date +%Y%m%d-%H%M).csv"

echo "时间,序号,主进程PSS_MB,主进程RSS_MB,WebView渲染进程PSS_MB,合计PSS_MB,系统可用_MB,进程存活" > "$OUT"
echo "开始记录 → $OUT   （每 ${INTERVAL}s，共 ${MINUTES} 分钟）"

TOTAL=$(( MINUTES * 60 / INTERVAL ))
for i in $(seq 1 "$TOTAL"); do
  TS="$(date +%H:%M:%S)"
  APP_PID="$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')"

  if [ -z "$APP_PID" ]; then
    A=$("$ADB" shell cat /proc/meminfo 2>/dev/null | awk '/MemAvailable/{print int($2/1024)}')
    echo "$TS,$i,,,,,${A:-},0" >> "$OUT"
    echo "[$TS] *** 主进程已退出（第 $i 次采样）—— 记录终止 ***"
    break
  fi

  INFO="$("$ADB" shell dumpsys meminfo "$APP_PID" 2>/dev/null)"
  APSS=$(echo "$INFO" | awk '/TOTAL PSS/{print int($3/1024); exit}')
  ARSS=$(echo "$INFO" | awk '/TOTAL RSS/{print int($4/1024); exit}')

  # WebView 渲染进程（可能多个，求和）
  WV=0
  for WPID in $("$ADB" shell ps -A -o PID,NAME 2>/dev/null | grep 'sandboxed_process' | awk '{print $1}' | tr -d '\r'); do
    [ -z "$WPID" ] && continue
    W=$("$ADB" shell dumpsys meminfo "$WPID" 2>/dev/null | awk '/TOTAL PSS/{print $3; exit}' | tr -d '\r')
    WV=$(( WV + ${W:-0} / 1024 ))
  done

  A=$("$ADB" shell cat /proc/meminfo 2>/dev/null | awk '/MemAvailable/{print int($2/1024)}')
  SUM=$(( ${APSS:-0} + WV ))
  echo "$TS,$i,${APSS:-},${ARSS:-},$WV,$SUM,${A:-},1" >> "$OUT"
  printf "[%s] %3d  主=%5s MB  WebView=%4s MB  合计=%5s MB  系统可用=%5s MB\n" \
    "$TS" "$i" "${APSS:-?}" "$WV" "$SUM" "${A:-?}"
  sleep "$INTERVAL"
done

echo
echo "=== 记录结束：$OUT ==="
awk -F, 'NR>1 && $3!="" {if($7>m)m=$7; if(f=="")f=$7; l=$7} END{printf "合计PSS：首 %s MB → 末 %s MB，峰值 %s MB\n", f, l, m}' "$OUT"
