#!/usr/bin/env bash
# 长时内存采样：验证 EraCore 在真实游玩中是否稳定，对照 XEmuera 的 5.3 GB 失控增长。
#
# 用法:
#   ./soak-memory.sh [分钟数] [采样间隔秒]
#   默认 60 分钟 / 60 秒一次
#
# 输出: research/soak-<时间戳>.csv
#   列: 时间, 采样序号, TOTAL_PSS_kB, TOTAL_RSS_kB, SWAP_PSS_kB,
#       Native_Heap_kB, Dalvik_Heap_kB, 系统可用内存_kB, 进程存活
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB="$REPO_ROOT/tools/android-sdk/platform-tools/adb"
PKG="com.eracore.maui"

MINUTES="${1:-60}"
INTERVAL="${2:-60}"
OUT_DIR="$REPO_ROOT/research"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/soak-$(date +%Y%m%d-%H%M).csv"

echo "时间,序号,TOTAL_PSS_kB,TOTAL_RSS_kB,SWAP_PSS_kB,Native_Heap_kB,Dalvik_Heap_kB,系统可用内存_kB,进程存活" > "$OUT"
echo "开始采样 → $OUT  (每 ${INTERVAL}s，共 ${MINUTES} 分钟)"

TOTAL=$(( MINUTES * 60 / INTERVAL ))
for i in $(seq 1 "$TOTAL"); do
  TS="$(date +%H:%M:%S)"
  INFO="$("$ADB" shell dumpsys meminfo "$PKG" 2>/dev/null)"
  ALIVE="$("$ADB" shell pidof "$PKG" 2>/dev/null | tr -d '\r')"

  # 字段位置（dumpsys meminfo 的一行内）：
  #   TOTAL PSS:  a   TOTAL RSS:  b   TOTAL SWAP PSS:  c
  #   $1=TOTAL $2=PSS: $3=a $4=TOTAL $5=RSS: $6=b $7=TOTAL $8=SWAP $9=PSS: $10=c
  PSS=$(echo "$INFO"  | awk '/TOTAL PSS/{print $3; exit}')
  RSS=$(echo "$INFO"  | awk '/TOTAL RSS/{print $6; exit}')
  SWAP=$(echo "$INFO" | awk '/TOTAL SWAP PSS/{print $10; exit}')
  NAT=$(echo "$INFO"  | awk '/Native Heap/{print $3; exit}')
  DAL=$(echo "$INFO"  | awk '/Dalvik Heap/{print $3; exit}')
  AVAIL="$("$ADB" shell cat /proc/meminfo 2>/dev/null | awk '/MemAvailable/{print $2; exit}')"

  if [ -n "$ALIVE" ]; then
    echo "$TS,$i,${PSS:-},${RSS:-},${SWAP:-},${NAT:-},${DAL:-},${AVAIL:-},1" >> "$OUT"
    printf "[%s] %3d/%d  PSS=%s kB  可用=%s kB\n" "$TS" "$i" "$TOTAL" "${PSS:-?}" "${AVAIL:-?}"
  else
    echo "$TS,$i,,,,,,${AVAIL:-},0" >> "$OUT"
    echo "[$TS] *** 进程已退出（第 $i 次采样）—— 采样终止 ***"
    break
  fi
  sleep "$INTERVAL"
done

echo
echo "=== 采样结束 ==="
echo "原始数据: $OUT"
echo
echo "--- PSS 变化（首 → 末，MB）---"
awk -F, 'NR==2{f=$3} END{if(NR>1) printf "  首 %.0f MB → 末 %.0f MB  (净变化 %+.0f MB)\n", f/1024, $3/1024, ($3-f)/1024}' "$OUT"
echo "--- 峰值 PSS（MB）---"
awk -F, 'NR>1 && $3!="" {if($3>m) m=$3} END{printf "  %.0f MB\n", m/1024}' "$OUT"
