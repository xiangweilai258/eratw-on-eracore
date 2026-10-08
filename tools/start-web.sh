#!/bin/bash
# EraCore Web 界面启动器 —— 用浏览器方式玩 eraTW
#
# ⚠ 必须前台运行（若由后台任务管理工具启动，请设为「前台 / 阻塞」模式）。
#    若用 `nohup ... &` 然后在脚本里返回，进程会在 Bash 任务结束时被清理掉。
#
# 用法：
#   bash tools/start-web.sh          # 默认 8080
#   bash tools/start-web.sh 9000     # 指定端口
#
# 启动后另开一个终端/调用加载游戏：
#   curl -X POST -H "Content-Type: application/json" \
#        -d "{\"gameDir\":\"$ROOT/eraTW\"}" \
#        http://localhost:8080/load-game
# ★ 2026-10-03 改：上面这行原**写死了本机绝对路径**（含 Windows 用户名）—— 与下面 ROOT 的
#   「不再写死绝对路径（2026-09-26 改）」是同一件事，当时**注释漏改了**。
#   ★ 旧值**不在注释里回抄**，避免用户名再次落盘（见 research/30 的 2026-10-03 更正）。
#
# 浏览器打开 http://localhost:8080/

set -e

# 项目根由脚本自身位置推出 —— 不再写死绝对路径（2026-09-26 改）
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTNET="$ROOT/tools/dotnet"
# ★ 2026-10-07：引擎已独立 fork 成 eracore-engine（可用 ERACORE_ENGINE 覆盖）
ENGINE_ROOT="${ERACORE_ENGINE:-$ROOT/../eracore-engine}"
BIN="$ENGINE_ROOT/EraCore.Cli/bin-aot/Release/net10.0"
PORT="${1:-8080}"

# dotnet 可执行：兼容 Windows(.exe) / macOS / Linux（2026-09-27 改）
if [ -x "$DOTNET/dotnet.exe" ]; then DOTNET_EXE="$DOTNET/dotnet.exe"
elif [ -x "$DOTNET/dotnet" ]; then DOTNET_EXE="$DOTNET/dotnet"
else DOTNET_EXE="$(command -v dotnet)" || { echo "❌ 找不到 dotnet"; exit 1; }
fi

if [ ! -d "$BIN/wwwroot" ]; then
  echo "❌ wwwroot 不存在（前端未构建）"
  echo "   修复：cd $ENGINE_ROOT && \\"
  echo "         PATH=\"$ROOT/tools/dotnet:$ROOT/tools/node/bin:\$PATH\" \\"
  echo "         $DOTNET_EXE build EraCore.Cli/EraCore.Cli.csproj -c Release"
  echo "   （不要传 -p:SkipVueBuild=true，否则前端不会被构建和复制）"
  exit 1
fi

export DOTNET_ROOT="$DOTNET"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export EMUERA_LOG_TERMINAL=info

echo "=============================================="
echo " EraCore server  →  http://localhost:$PORT/"
echo " 前端产物       →  $BIN/wwwroot"
echo " 游戏目录       →  $ROOT/eraTW"
echo "=============================================="
echo

exec "$DOTNET_EXE" "$BIN/EraCore.Cli.dll" -server -port "$PORT"
