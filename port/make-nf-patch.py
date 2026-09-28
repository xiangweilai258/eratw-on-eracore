#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 NF（NoFocus）指令族的独立补丁。

对比基准：上游 main 分支归档 zip
产出：patches/nf-input-family.patch

★ 与 port/make-patch.py 的区别：
  那个产出「eraTW 兼容 + 插件修复」的全量移植补丁；
  这个只产出「NF 指令族」这一件事的增量补丁 —— 干净、可单独 apply / 单独评审。

用法：
    python3 make-nf-patch.py --zip /path/to/era-core-latest.zip --src /path/to/era-core-src
"""
import argparse
import difflib
import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)


def resolve_paths():
    ap = argparse.ArgumentParser(description="生成 NF（NoFocus）指令族的独立补丁")
    ap.add_argument(
        "--zip",
        default=os.environ.get("ERA_ZIP", os.path.join(REPO, "era-core-latest.zip")),
        help="上游 main 分支原版 zip（用于取「修改前」的基线）",
    )
    ap.add_argument(
        "--src",
        default=os.path.join(REPO, "era-core-src"),
        help="已打补丁的上游源码目录（用于取「修改后」的内容）",
    )
    ap.add_argument(
        "--out",
        default=os.path.join(REPO, "patches", "nf-input-family.patch"),
        help="补丁输出路径",
    )
    return ap.parse_args()


_ARGS = resolve_paths()
ZIP = _ARGS.zip
SRC = _ARGS.src
OUT = _ARGS.out
ROOT = "era-core-main/"   # 上游 zip 内的根目录名

# NF 指令族涉及的文件（相对 era-core-src 的路径 = 相对 zip 的路径）
TARGETS = [
    "EraCore.Core/EraCore.Core.csproj",                                     # 版本号 +1（作废 IR 缓存）
    "EraCore.Core/Shared/Runtime/InputRequest.cs",                          # 加 NoFocus 字段
    "EraCore.Core/Shared/Runtime/Script/Statements/BuiltInFunctionCode.cs", # 加 4 枚举
    "EraCore.Core/Shared/Runtime/Script/Statements/FunctionIdentifier.cs",  # 加 4 行登记
    "EraCore.Core/Shared/Runtime/Script/Statements/Instraction.Child.cs",   # 两构造加 noFocus
]

z = zipfile.ZipFile(ZIP)
out, stats = [], []
tot_a = tot_d = 0

# ★ 关键：补丁必须统一用 LF。上游仓库是 LF，而 Windows 侧源码经 git 检出可能是 CRLF，
#   若原样 diff 会产出 CRLF 补丁 → 在 LF 仓库上 `git apply` 直接失败
#   （本项目 MEMORY 记过同类坑：「Windows 会把 .sh 转 CRLF」）。
def read_lines(path):
    with open(path, "rb") as f:
        raw = f.read()
    # 统一 CRLF / CR → LF，再切行，确保新旧两侧行尾口径一致
    raw = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return raw.decode("utf-8").splitlines(keepends=True)


for rel in TARGETS:
    disk = os.path.join(SRC, rel)
    if not os.path.exists(disk):
        print("  ! 缺文件", rel)
        continue
    new = read_lines(disk)
    with z.open(ROOT + rel) as zf:
        old = zf.read().replace(b"\r\n", b"\n").replace(b"\r", b"\n").decode("utf-8").splitlines(keepends=True)

    a = d = 0
    buf = []
    for line in difflib.unified_diff(old, new, fromfile="a/" + rel, tofile="b/" + rel, lineterm=""):
        buf.append(line.rstrip("\n") + "\n")   # 强制 LF
        if line.startswith("+") and not line.startswith("+++"):
            a += 1
        elif line.startswith("-") and not line.startswith("---"):
            d += 1
    out.append("".join(buf))
    stats.append((rel, a, d))
    tot_a += a
    tot_d += d

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:   # newline="\n" 禁掉自动 CRLF
    f.write("".join(out))

print("=== NF 指令族补丁内容 ===")
for rel, a, d in stats:
    print(f"  {rel:72s} +{a:<4d}-{d}")
print("  " + "-" * 80)
print(f"  合计: +{tot_a} / -{tot_d}   （{len(stats)} 个文件）")
print()
print("写入:", OUT, f"({os.path.getsize(OUT)/1024:.1f} KB)")
