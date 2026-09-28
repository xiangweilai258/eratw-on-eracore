#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 EraRelay（eraTW-on-EraCore）的完整移植补丁。

对比基准：上游 main 分支原版 zip（默认 <仓库同级>/era-core-latest.zip）
产出：<本脚本所在目录>/eratw-EE56-compat.patch

用法：
    # 用默认路径（脚本同级目录下的 era-core-latest.zip 与 era-core-src/）
    python3 make-patch.py

    # 显式指定
    python3 make-patch.py --zip /path/to/era-core-latest.zip --src /path/to/era-core-src

    # 也可以走环境变量
    ERACORE_ZIP=/path/to/era-core-latest.zip ERACORE_SRC=/path/to/era-core-src python3 make-patch.py
"""
import argparse
import difflib
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))


def resolve_paths():
    ap = argparse.ArgumentParser(description="生成 EraRelay（eraTW-on-EraCore）移植补丁")
    ap.add_argument(
        "--zip",
        default=os.environ.get("ERACORE_ZIP", os.path.join(HERE, "era-core-latest.zip")),
        help="上游 main 分支原版 zip（用于取「修改前」的基线）",
    )
    ap.add_argument(
        "--src",
        default=os.environ.get("ERACORE_SRC", os.path.join(os.path.dirname(HERE), "era-core-src")),
        help="已打补丁的上游源码目录（用于取「修改后」的内容）",
    )
    ap.add_argument(
        "--out",
        default=os.path.join(HERE, "eratw-EE56-compat.patch"),
        help="补丁输出路径",
    )
    return ap.parse_args()


# 相对源码根的路径 → zip 内路径（None = 新增文件）
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


def main():
    args = resolve_paths()

    zip_path = os.path.abspath(args.zip).replace("\\", "/")
    src_root = os.path.abspath(args.src).replace("\\", "/")
    out_path = os.path.abspath(args.out)

    for label, p in (("zip", zip_path), ("src", src_root)):
        if not os.path.exists(p):
            print(f"[错误] {label} 路径不存在：{p}")
            print("       用 --zip / --src 显式指定，或设置 ERACORE_ZIP / ERACORE_SRC 环境变量。")
            return 1

    # zip 内根目录名（如 era-core-main/）——从第一个文件自动推导，避免硬编码
    with zipfile.ZipFile(zip_path) as z:
        names = z.namelist()
        if not names:
            print("[错误] zip 为空")
            return 1
        first = names[0]
        root = first if first.endswith("/") else first.split("/")[0] + "/"

        out, stats = [], []
        tot_a = tot_d = 0

        for rel, zpath in TARGETS.items():
            disk = os.path.join(src_root, rel.replace("/", os.sep))
            if not os.path.exists(disk):
                print("  ! 缺文件", rel)
                continue
            new = open(disk, encoding="utf-8").read().splitlines(keepends=True)
            if zpath is None:
                old, tag = [], "A"
            else:
                old = z.read(root + zpath).decode("utf-8").splitlines(keepends=True)
                tag = "M"

            a = d = 0
            buf = []
            for line in difflib.unified_diff(
                old, new, fromfile="a/" + rel, tofile="b/" + rel, lineterm="\n"
            ):
                buf.append(line)
                if line.startswith("+") and not line.startswith("+++"):
                    a += 1
                elif line.startswith("-") and not line.startswith("---"):
                    d += 1
            out.append("".join(buf))
            stats.append((tag, rel, a, d))
            tot_a += a
            tot_d += d

    open(out_path, "w", encoding="utf-8").write("".join(out))

    print("=== 补丁内容 ===")
    for tag, rel, a, d in stats:
        print(f"  [{tag}] {rel:74s} +{a:<4d}-{d}")
    print("  " + "-" * 76)
    print(f"  合计: +{tot_a} / -{tot_d}   （{len(stats)} 个文件）")
    print()
    print("写入:", out_path, f"({os.path.getsize(out_path)/1024:.1f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
