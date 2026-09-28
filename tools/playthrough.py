#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EraCore eraTW 自动通关驱动（看屏幕做决策）。

用途：真正玩进游戏内，把「注册了但从未执行过」的 EEv56 路径跑一遍
（GRAPH_DISTANCE 寻路 / SQL_IMPORT_MAP_XML / TEXT_BGC / HTML_PRINTC / UNCHECKED_* …）。

用法：
    python3 playthrough.py [最大步数] [--base http://127.0.0.1:8099] [--bin <CLI 产物目录>]
前置： 引擎已以 --server 启动并已 POST /load-game

--bin 用于定位 sql-connect.log（EESqlRuntime 的 SQL 探针输出目录）。
不传时取 <仓库根>/era-core-src/EraCore.Cli/bin-aot/Release/net10.0，
也可用环境变量 ERACORE_BIN 指定。
"""
import argparse
import json
import os
import sys
import time
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_ap = argparse.ArgumentParser(description="EraCore eraTW 自动通关驱动")
_ap.add_argument("steps", nargs="?", type=int, default=28, help="最大步数（默认 28）")
_ap.add_argument("--base", default=os.environ.get("ERACORE_BASE", "http://127.0.0.1:8099"),
                 help="引擎 server 地址")
_ap.add_argument("--bin", default=os.environ.get(
                     "ERACORE_BIN",
                     os.path.join(REPO_ROOT, "era-core-src", "EraCore.Cli", "bin-aot", "Release", "net10.0")),
                 help="CLI 产物目录（用于定位 sql-connect.log）")
_args = _ap.parse_args()

BASE = _args.base.rstrip("/")
BIN = _args.bin
SQL_LOG = os.path.join(BIN, "sql-connect.log")
MAX_STEPS = _args.steps


def http_get(path):
    try:
        with urllib.request.urlopen(BASE + path, timeout=60) as r:
            return json.load(r)
    except Exception as e:
        return {"error": str(e)}


def http_post(path, obj=None):
    data = json.dumps(obj if obj is not None else {}).encode("utf-8")
    req = urllib.request.Request(
        BASE + path, data=data, method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return json.load(r)
    except Exception as e:
        return {"error": str(e)}


def collect(o, out):
    if isinstance(o, dict):
        t = o.get("text")
        if isinstance(t, str):
            out.append(t)
        for k, v in o.items():
            if k != "text":
                collect(v, out)
    elif isinstance(o, list):
        for v in o:
            collect(v, out)


def screen():
    """返回 (纯文本屏幕, snapshot 原对象)"""
    d = http_get("/snapshot")
    if "error" in d:
        return "", d
    rows = []
    for e in (d.get("lines") or []):
        buf = []
        collect(e, buf)
        rows.append("".join(buf))
    return "\n".join(rows), d


def log_tail(path, seen):
    """返回 sql 日志里新增的行"""
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", errors="ignore") as f:
        lines = f.read().splitlines()
    new = lines[seen:]
    return new


def decide(txt):
    """
    两级决策：先看**最底部 6 行**（真正的当前提示），再看 16 行宽窗口。

    ⚠ 教训一：/snapshot 的 lines 是**完整历史日志** —— 对全文匹配会命中滚上去的旧菜单。
    ⚠ 教训二：即便只看尾部，上一屏的内容仍可能留在窗口里（例如「[9999] 设定完毕」
       下面的确认提示「[0] 是 / [1] 否」）。所以必须**优先匹配最底部的那一条**。
    """
    lines = [l for l in txt.splitlines() if l.strip()]
    if not lines:
        return "1", "空屏，推进"
    zone = "\n".join(lines[-6:])     # 当前提示区
    wide = "\n".join(lines[-16:])    # 宽窗口兜底

    # ── 优先：最底部提示区 ──
    if "是" in zone and "否" in zone:
        return "0", "确认 → 是"
    if "变更" in zone and ("名字" in zone or "称呼" in zone):
        return "民", "输入名字"
    if "设定完毕" in zone:
        return "9999", "角色设定 → 设定完毕"
    if "开始游戏" in zone and "继续游戏" in zone:
        return "0", "标题 → 开始游戏"
    if "请选择游戏模式" in zone:
        return "0", "模式菜单 → START"
    if "要变成谁" in zone:
        return "1", "角色选择 → 第 1 位"

    # ── 兜底：宽窗口 ──
    if "是" in wide and "否" in wide:
        return "0", "宽窗口：确认 → 是"
    if "设定完毕" in wide:
        return "9999", "宽窗口：设定完毕"
    if "变更" in wide and ("名字" in wide or "称呼" in wide):
        return "民", "宽窗口：输入名字"
    if "开始游戏" in wide and "继续游戏" in wide:
        return "0", "宽窗口：标题"
    if "请选择游戏模式" in wide:
        return "0", "宽窗口：模式菜单"
    if "要变成谁" in wide:
        return "1", "宽窗口：角色选择"

    # ── 最后手段：最小普通可选项 ──
    import re
    opts = sorted({int(m) for m in re.findall(r"\[\s*(\d+)\s*\]", wide)})
    for o in opts:
        if o not in (9999, 1000, 2000, 3000, 4000):
            return str(o), f"兜底最小项 [{o}]"
    if opts:
        return str(opts[0]), f"兜底 [{opts[0]}]"
    return "1", "无菜单，推进"


def main():
    seen = 0
    print("=" * 78)
    print("EraCore eraTW 自动通关驱动")
    print("=" * 78)

    for step in range(1, MAX_STEPS + 1):
        st = http_get("/state")
        state = st.get("state")
        txt, snap = screen()

        non = [l for l in txt.splitlines() if l.strip()]
        # 决策依据：屏幕尾部 20 行（decide 内部再切 6/16 两级）
        decision_window = "\n".join(non[-20:])
        print(f"\n──────────── 第 {step} 步 | state={state} "
              f"inputType={snap.get('inputType')} gen={snap.get('generation')} ────────────")
        for l in non[-12:]:
            print("  |", l[:130])

        # SQL 探针增量
        new = log_tail(SQL_LOG, seen)
        if new:
            seen += len(new)
            for l in new:
                print("  ★SQL★", l[:150])

        if state not in ("WaitInput",):
            print(f"  (state={state}，非 WaitInput，等待 3s)")
            time.sleep(3)
            continue

        val, why = decide(decision_window)
        print(f"  → 输入 \"{val}\"   （{why}）")
        r = http_post("/input", {"value": val})
        if "received" not in r:
            print("  ! 输入被拒绝:", str(r)[:160])
        time.sleep(4)

    print("\n" + "=" * 78)
    print("驱动结束")
    print("=" * 78)


if __name__ == "__main__":
    main()
