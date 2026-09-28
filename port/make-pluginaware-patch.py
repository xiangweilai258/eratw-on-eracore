#!/usr/bin/env python3
"""生成 pluginsAware 软警告补丁。

背景：上游 LaoBro/era-core 的 main 分支 fork 自 emuera.em 的旧快照，
      自带 pluginsAware 硬门禁（插件目录有 DLL 但无 pluginsAware.txt → 抛异常）。
      上游 emuera.em 已于 2026-05-26（提交 0abdff83）废弃该门禁，改为软警告。
      本补丁把 EraCore 对齐到上游行为。

用法：
    python make-pluginaware-patch.py <原始文件目录> <改后文件目录> <输出patch>

说明：
    "原始文件目录" 指从上游 main 拉下来的那 6 个文件（未含本补丁）。
    脚本只输出**本轮改动**对应的 hunk，不掺杂其他既有移植改动。
"""
import difflib
import os
import sys

# 文件清单：(仓库内路径, 原始文件名, 改后文件相对路径)
FILES = [
    ("EraCore.Core/Shared/Runtime/Utils/PluginSystem/PluginManager.cs",
     "PluginManager.cs",
     "EraCore.Core/Shared/Runtime/Utils/PluginSystem/PluginManager.cs"),
    ("EraCore.Core/Shared/Runtime/Config/ConfigCode.cs",
     "ConfigCode.cs",
     "EraCore.Core/Shared/Runtime/Config/ConfigCode.cs"),
    ("EraCore.Core/Shared/Runtime/Config/ConfigData.cs",
     "ConfigData.cs",
     "EraCore.Core/Shared/Runtime/Config/ConfigData.cs"),
    ("EraCore.Core/Shared/Runtime/Config/Config.cs",
     "Config.cs",
     "EraCore.Core/Shared/Runtime/Config/Config.cs"),
    ("EraCore.Core/Shared/Runtime/Utils/EvilMask/Lang.cs",
     "Lang.cs",
     "EraCore.Core/Shared/Runtime/Utils/EvilMask/Lang.cs"),
    ("EraCore.Core/Shared/Runtime/Script/Process.cs",
     "Process.cs",
     "EraCore.Core/Shared/Runtime/Script/Process.cs"),
]

# 只保留含这些关键字的 hunk（= 本轮改动），过滤掉其他既有移植差异。
KEYWORDS = ("ExistPlugin", "PluginAvailableWarn", "PluginAvailable", "pluginsAware", "0abdff83")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.readlines()


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2

    orig_dir, new_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    out_lines = []
    total_hunks = 0

    for repo_path, orig_name, new_rel in FILES:
        orig_file = os.path.join(orig_dir, orig_name)
        new_file = os.path.join(new_dir, new_rel)
        if not os.path.exists(orig_file):
            print(f"跳过（缺原始文件）：{orig_file}", file=sys.stderr)
            continue
        if not os.path.exists(new_file):
            print(f"跳过（缺改后文件）：{new_file}", file=sys.stderr)
            continue

        a = read(orig_file)
        b = read(new_file)

        # 用统一的 diff 生成器
        diff = list(difflib.unified_diff(
            a, b,
            fromfile=f"a/{repo_path}",
            tofile=f"b/{repo_path}",
            n=3,
        ))

        # 按 hunk 分组，只保留含关键字的
        header = []
        hunks = []
        cur = None
        for line in diff:
            if line.startswith("--- ") or line.startswith("+++ "):
                header.append(line)
                continue
            if line.startswith("@@"):
                if cur is not None:
                    hunks.append(cur)
                cur = [line]
            elif cur is not None:
                cur.append(line)
        if cur is not None:
            hunks.append(cur)

        kept = [h for h in hunks if any(k in "".join(h) for k in KEYWORDS)]
        if not kept:
            continue

        out_lines.extend(header)
        for h in kept:
            out_lines.extend(h)
        total_hunks += len(kept)

    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(out_lines)

    print(f"✓ 已写 {out_path}：{len(out_lines)} 行，{total_hunks} 个 hunk")
    return 0


if __name__ == "__main__":
    sys.exit(main())
