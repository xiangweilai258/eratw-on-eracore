#!/bin/bash
# EraCore headless 引擎 · eraTW 实跑探针
#
# 用法：
#   ./eracore-probe.sh load            # 只加载，报耗时与错误
#   ./eracore-probe.sh screen          # 加载后打印当前画面
#   ./eracore-probe.sh input 0 1 1     # 加载后依次发送这些输入并打印画面
#
# 已固化的接口知识（都是踩坑换来的）：
#   - CLI 产物在 EraCore.Cli/bin-aot/Release/net10.0/（不是 bin/）
#   - server 模式 **不会** 因 -exedir 自动加载，必须 POST /load-game {"gameDir":...}
#   - POST /input body = {"value":"<字符串>"}；传数字会报 Invalid JSON
#   - /state 里 state=WaitInput 即加载完成；inputType 会变（IntValue / EnterKey）
#   - EESqlRuntime 的异常会写 <产物目录>/sql-debug.log —— 这是 SQL 层的探针
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/era-core-src"
BIN="$SRC/EraCore.Cli/bin-aot/Release/net10.0"
GAME="${ERATW_DIR:-$ROOT/eraTW}"
PORT="${PORT:-8099}"

# dotnet 可执行：项目内优先，兼容 Windows(.exe) / macOS / Linux（2026-09-27 改）
D="$ROOT/tools/dotnet"
if [ -x "$D/dotnet.exe" ]; then DOTNET_EXE="$D/dotnet.exe"
elif [ -x "$D/dotnet" ]; then DOTNET_EXE="$D/dotnet"
else DOTNET_EXE="$(command -v dotnet)" || { echo "✗ 找不到 dotnet"; exit 1; }
fi

export DOTNET_ROOT="$D"; export PATH="$D:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1; export DOTNET_NOLOGO=1
PY="$(command -v python3 || command -v python)"

MODE="${1:-screen}"
shift || true

[ -f "$BIN/EraCore.Cli.dll" ] || { echo "✗ 未找到产物，先编译：cd era-core-src && dotnet build EraCore.Cli/EraCore.Cli.csproj -c Release"; exit 1; }
[ -d "$GAME" ] || { echo "✗ 游戏目录不存在：$GAME（可用 ERATW_DIR=... 覆盖）"; exit 1; }

rm -f "$BIN/sql-debug.log" "$BIN/als-debug.log"
LOG=/tmp/eracore-probe.log

"$DOTNET_EXE" "$BIN/EraCore.Cli.dll" -server -port "$PORT" > "$LOG" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null' EXIT
sleep 5

echo "→ POST /load-game  gameDir=$GAME"
curl -sS -m 30 -X POST -H "Content-Type: application/json" \
  -d "{\"gameDir\":\"$GAME\"}" "http://127.0.0.1:$PORT/load-game" | head -c 200; echo

echo "→ 等待 WaitInput"
for i in $(seq 1 40); do
  sleep 3
  ST=$(curl -sS -m 6 "http://127.0.0.1:$PORT/state" 2>/dev/null | $PY -c "import sys,json;print(json.load(sys.stdin).get('state'))" 2>/dev/null)
  if [ "$ST" = "WaitInput" ]; then echo "  ★ WaitInput（约 $((i*3)) 秒）"; break; fi
  [ -z "$ST" ] && { echo "  ✗ 服务无响应"; break; }
done

snap() {
  curl -sS -m 20 "http://127.0.0.1:$PORT/snapshot" -o /tmp/eracore-snap.json 2>/dev/null
  $PY "$ROOT/tools/snapshot-dump.py" /tmp/eracore-snap.json "${1:-34}"
}

case "$MODE" in
  load)
    echo "→ 加载统计"
    grep -E "noError|Process.Initialize|labels=|heapMB" "$LOG" | tail -8
    ;;
  screen)
    echo "→ 当前画面"; snap 34
    ;;
  input)
    echo "→ 初始画面"; snap 20
    for v in "$@"; do
      echo
      echo "→ 输入 \"$v\""
      curl -sS -m 15 -X POST -H "Content-Type: application/json" \
        -d "{\"value\":\"$v\"}" "http://127.0.0.1:$PORT/input" | head -c 120; echo
      sleep 6; snap 26
    done
    ;;
  *) echo "未知模式：$MODE"; exit 1 ;;
esac

echo
echo "→ SQL 探针"
if [ -f "$BIN/sql-debug.log" ]; then
  echo "  ⚠ 有 SQL 异常（$(wc -l < "$BIN/sql-debug.log") 行）："; head -30 "$BIN/sql-debug.log"
else
  echo "  ✓ 无 sql-debug.log —— EESqlRuntime 零异常"
fi
echo "→ 日志尾部"; tail -6 "$LOG"
