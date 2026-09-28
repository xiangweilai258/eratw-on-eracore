#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EraCore /snapshot 屏幕内容提取器。

用法：  python3 snapshot-dump.py <snapshot.json> [末尾行数]

注意（踩过的坑）：/snapshot 的 lines 元素是**多层嵌套**结构，
形如 {"entries":[{"segments":[{"text":"..."}]}]} —— text 藏得很深。
必须递归收集，直接取 e["segments"] 会全部拿到空字符串。
"""
import json
import sys


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


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    tail_n = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    d = json.load(open(sys.argv[1], encoding="utf-8"))

    print(
        f"state={d.get('state')} inputType={d.get('inputType')} "
        f"needValue={d.get('needValue')} gen={d.get('generation')} "
        f"protocolVersion={d.get('protocolVersion')}"
    )

    lines = d.get("lines") or []
    rows = []
    for i, e in enumerate(lines):
        buf = []
        collect(e, buf)
        rows.append((i, "".join(buf)))

    non = [(i, t) for i, t in rows if t.strip()]
    print(f"lines {len(lines)} 行，非空 {len(non)} 行；显示最后 {tail_n} 行：")
    for i, t in non[-tail_n:]:
        print(f"  {i:5d}| {t[:140]}")


if __name__ == "__main__":
    main()
