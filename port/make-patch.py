#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 eraTW-on-EraCore 的完整移植补丁。

对比基准：上游 main 分支原版 zip（/tmp/era-core-latest.zip）
产出：port/eratw-EE56-compat.patch
"""
import difflib
import os
import zipfile

ZIP = "/tmp/era-core-latest.zip"
ROOT = "era-core-main/"
# ★ 2026-10-07：原为硬编码绝对路径（含 Windows 用户名），外发即泄露个人标识。
# 改为按本文件位置推导仓库根 —— 本文件位于 port/ 下，其上一层即仓库根。
_HERE = os.path.dirname(os.path.abspath(__file__))
# ★ 2026-10-07：引擎已独立 fork 成 eracore-engine（可用 ERACORE_ENGINE 覆盖）。
ENGINE = os.environ.get("ERACORE_ENGINE") or os.path.abspath(
    os.path.join(os.path.dirname(_HERE), "..", "eracore-engine"))
SRC = ENGINE + os.sep

# 相对 EraCore.Core 的路径 → zip 内路径（None = 新文件）
TARGETS = {
    # ---- EEv56 兼容层 ----
    "EraCore.Core/EraCore.Core.csproj":
        "EraCore.Core/EraCore.Core.csproj",
    "EraCore.Core/Shared/Runtime/Script/Statements/BuiltInFunctionCode.cs":
        "EraCore.Core/Shared/Runtime/Script/Statements/BuiltInFunctionCode.cs",
    "EraCore.Core/Shared/Runtime/Script/Statements/FunctionIdentifier.cs":
        "EraCore.Core/Shared/Runtime/Script/Statements/FunctionIdentifier.cs",
    "EraCore.Core/Shared/Runtime/Script/Statements/Instraction.Child.cs":
        "EraCore.Core/Shared/Runtime/Script/Statements/Instraction.Child.cs",
    "EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.cs":
        "EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.cs",
    "EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.General.cs":
        "EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.General.cs",
    "EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.EE56.cs": None,
    "EraCore.Core/Shared/Runtime/Utils/EESqlRuntime.cs": None,
    # ---- 插件加载修复（程序集重定向 / GetTypes 容错 / 目录大小写） ----
    "EraCore.Core/Shared/Runtime/Utils/PluginSystem/PluginManager.cs":
        "EraCore.Core/Shared/Runtime/Utils/PluginSystem/PluginManager.cs",
}

z = zipfile.ZipFile(ZIP)
out, stats = [], []
tot_a = tot_d = 0

for rel, zpath in TARGETS.items():
    disk = os.path.join(SRC, rel)
    if not os.path.exists(disk):
        print("  ! 缺文件", rel)
        continue
    new = open(disk, encoding="utf-8").read().splitlines(keepends=True)
    if zpath is None:
        old, tag = [], "A"
    else:
        old, tag = z.read(ROOT + zpath).decode("utf-8").splitlines(keepends=True), "M"

    a = d = 0
    buf = []
    for line in difflib.unified_diff(old, new, fromfile="a/" + rel, tofile="b/" + rel, lineterm="\n"):
        buf.append(line)
        if line.startswith("+") and not line.startswith("+++"):
            a += 1
        elif line.startswith("-") and not line.startswith("---"):
            d += 1
    out.append("".join(buf))
    stats.append((tag, rel, a, d))
    tot_a += a
    tot_d += d

p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "eratw-EE56-compat.patch")
open(p, "w", encoding="utf-8").write("".join(out))

print("=== 补丁内容 ===")
for tag, rel, a, d in stats:
    print(f"  [{tag}] {rel:74s} +{a:<4d}-{d}")
print("  " + "-" * 76)
print(f"  合计: +{tot_a} / -{tot_d}   （{len(stats)} 个文件）")
print()
print("写入:", p, f"({os.path.getsize(p)/1024:.1f} KB)")
