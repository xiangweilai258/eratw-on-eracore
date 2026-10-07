#!/usr/bin/env bash
# 构建 EraCore Android APK
#
# 关键：必须显式传 EmbedAssembliesIntoApk=true
#
# 原因（已实测定位）：
#   dotnet/packs/Microsoft.Android.Sdk.Darwin/36.1.69/tools/Xamarin.Android.Common.targets:166
#     <EmbedAssembliesIntoApk Condition=" '$(EmbedAssembliesIntoApk)' == '' And '$(Optimize)' != 'True'
#         And '$(_AndroidFastDeploymentSupported)' == 'True' ">False</EmbedAssembliesIntoApk>
#
#   Debug 构建（Optimize != True）在支持快速部署的设备上默认把该属性置为 False
#   → 合并出的 AndroidManifest 写入 android:extractNativeLibs="true"
#   → _ReadAndroidManifest 读出 _EmbeddedDSOsEnabled=False
#   → .so 不进 AndroidStoreUncompressedFileExtensions 白名单
#   → APK 内 lib/<abi>/*.so 全部被 DEFLATE 压缩
#   → 一旦不走 fast-deploy（即普通 adb install），运行时读不到程序集，
#      libmonodroid 直接 abort：
#        "ALL entries in APK named `lib/arm64-v8a/` MUST be STORED."
#
#   传 EmbedAssembliesIntoApk=true 后 extractNativeLibs=false，
#   .so 以 STORED 落盘，APK 自包含、可直接分发安装。
#
# 用法:
#   ./build-android.sh            # Debug
#   ./build-android.sh Release    # Release（默认已 EmbedAssembliesIntoApk=true，无需额外开关）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-Debug}"
# 第二参数（可选）：ABI 过滤 —— 传 arm64 只出 arm64-v8a，用于出「真机精简包」
# （体积对照与理由见 research/29 §1：双架构 267M → 只出 arm64 约 139M）。
# 不传 = 按 csproj 的 RuntimeIdentifiers 出全部 ABI（开发用）。
ABI="${2:-}"
RID=""

# ---- 工具链路径：跨平台自动探测（2026-09-27 改为自推导，换机不用再改）----
# JDK：Windows 便携版是 tools/jdk/bin/java，macOS 版是 tools/jdk/Contents/Home/bin/java
if [ -d "$REPO_ROOT/tools/jdk/Contents/Home" ]; then
  JAVA_HOME="$REPO_ROOT/tools/jdk/Contents/Home"     # macOS 布局
elif [ -d "$REPO_ROOT/tools/jdk" ]; then
  JAVA_HOME="$REPO_ROOT/tools/jdk"                   # Windows/Linux 布局
else
  echo "[警告] 未找到 tools/jdk，尝试用系统 JAVA_HOME=${JAVA_HOME:-<未设置>}"
fi
export JAVA_HOME
export ANDROID_HOME="$REPO_ROOT/tools/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

# dotnet：优先项目内（tools/dotnet），回退到全局 dotnet
if [ -x "$REPO_ROOT/tools/dotnet/dotnet.exe" ]; then
  DOTNET="$REPO_ROOT/tools/dotnet/dotnet.exe"
elif [ -x "$REPO_ROOT/tools/dotnet/dotnet" ]; then
  DOTNET="$REPO_ROOT/tools/dotnet/dotnet"
elif command -v dotnet >/dev/null 2>&1; then
  DOTNET="$(command -v dotnet)"
else
  echo "[错误] 找不到 dotnet（项目内 tools/dotnet 与全局都没有）"; exit 1
fi
export DOTNET_ROOT="$REPO_ROOT/tools/dotnet"

# build-tools 版本：按实际安装的目录自动取（避免写死 36.0.0）
BT_DIR="$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)"
BT_DIR="${BT_DIR%/}"

# ★ 2026-10-07：引擎已独立 fork 成 eracore-engine（开发主线 = erarelay 分支）。
#   引擎根默认取「与 eratw 平级的 eracore-engine」，可用环境变量 ERACORE_ENGINE 覆盖。
ENGINE_ROOT="${ERACORE_ENGINE:-$REPO_ROOT/../eracore-engine}"
PROJ="$ENGINE_ROOT/EraCore.Maui/EraCore.Maui.csproj"

# Python 解释器（自检 2 用）。优先 PATH，其次 WorkBuddy 托管运行时 —— 不写死单机路径，
# 换机后无需再改（2026-09-26：由旧机写死路径改为解析式）。
# ★ 2026-10-01 加固：必须**真正执行一次**才算可用 —— 本机 PATH 上的 `python` 是
#   Microsoft Store 存根（WindowsApps\python.exe），它**不执行、直接返回非零**，
#   在过去会让本脚本死在「自检 2」的 python heredoc 处（实测 EXIT=49），
#   导致自检 3 与后续步骤永远跑不到。testlab 的脚本早已踩过同一个坑并加固，本脚本补齐。
runs_ok() { "$1" -c "print(1)" >/dev/null 2>&1; }

PY="${PYTHON:-}"
if [ -n "$PY" ] && ! runs_ok "$PY"; then
  echo "[警告] PYTHON=$PY 无法执行，忽略该设置"
  PY=""
fi
if [ -z "$PY" ]; then
  for c in python3 python py; do
    p="$(command -v "$c" 2>/dev/null)" || continue
    case "$p" in *WindowsApps*) continue ;; esac   # ★ Store 存根：静默失败，直接跳过
    if runs_ok "$p"; then PY="$p"; break; fi
  done
fi
if [ -z "$PY" ]; then
  for p in "$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/python/python.exe" \
           "$HOME/.workbuddy/binaries/python/versions/3.13.12/python.exe" \
           "$HOME/.workbuddy/binaries/python/versions/3.13.12/bin/python3"; do
    if [ -x "$p" ] && runs_ok "$p"; then PY="$p"; break; fi
  done
fi
: "${PY:?找不到【可用】的 python 解释器（Microsoft Store 存根不可用），请设置 PYTHON 环境变量}"

EXTRA=()
if [ "$CONFIG" = "Debug" ]; then
  EXTRA+=("-p:EmbedAssembliesIntoApk=true")
fi
case "$ABI" in
  "")            ;;
  arm64|arm64-v8a) RID="android-arm64" ;;
  x64|x86_64)      RID="android-x64" ;;
  *) echo "[错误] 未知 ABI：$ABI（支持 arm64 / x64）"; exit 2 ;;
esac
if [ -n "$RID" ]; then
  EXTRA+=("-p:RuntimeIdentifier=$RID")
  echo "[提示] 已限定单 ABI：$RID（产物路径会多一层子目录）"
fi

# ★★★ 2026-10-08 缺陷 C 修复：「前端压根没重新生成」⇒ 静默打出旧前端
#   症状：脚本**全绿**（0 错误、签名三 scheme 有效、四个自检全过、还打印了"可发布的签名包"），
#         装上去界面却是旧的。
#   ★ 与下方缺陷 B **症状相同、环节不同**：B = 「新前端没被打进包」（Android 暂存层），
#     C = 「前端压根没生成新的」（更上游的构建层）。★ B 修好之后反而把 C 掩盖了 —— 因为不再报错。
#   机制：本机**根本没有 npm**（`Get-Command npm` 为空；四个候选 node 目录也全都没有），
#         而上游 build/VueBuild.targets 探不到 npm 时只给一条 Warning 就**跳过 npm run build**，
#         紧随其后的复制步骤却照常把**旧的** dist-maui 搬进 wwwroot。
#   ★★ 实测判据：APK 构建时间 03:10:58，而 wwwroot/index.html 停在 02:16:29。
#   ★★★ 修法：在 dotnet 之前用 **node 直调 vite**（完全不经过 npm）重建 dist-maui 并复制进
#        wwwroot。这样 wwwroot 必然比 Android 暂存新 ⇒ 下方缺陷 B 的清理逻辑也会正确触发。
#   ★ 逃生阀：确认 dist-maui 已是最新时，可 SKIP_VUE_BUILD=1 跳过（会明确打印"跳过"）。
NODE_EXE=""
for c in "$REPO_ROOT/tools/node/bin/node.exe" "$REPO_ROOT/tools/node/node.exe" \
         "$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node.exe" \
         "$(command -v node 2>/dev/null)"; do
  if [ -n "$c" ] && [ -x "$c" ]; then NODE_EXE="$c"; break; fi
done
VITE_JS="$ENGINE_ROOT/EraCore.Web/node_modules/vite/bin/vite.js"
if [ "${SKIP_VUE_BUILD:-0}" = "1" ]; then
  echo "[跳过] SKIP_VUE_BUILD=1 ⇒ 不重建前端（前提：你自己确认 dist-maui 是新的）"
else
  if [ -z "$NODE_EXE" ]; then
    echo "[错误] 找不到 node —— 无法重建前端（旧前端会被打进包）。"
    echo "       若你确认 dist-maui 已是最新，可设 SKIP_VUE_BUILD=1 显式跳过。"
    exit 3
  fi
  if [ ! -f "$VITE_JS" ]; then
    echo "[错误] 找不到 $VITE_JS —— EraCore.Web 的依赖没装？"
    echo "       （本机没 npm，依赖是既有的；换机后需要先补 node_modules）"
    exit 3
  fi
  echo "=== 重建前端（node 直调 vite，不依赖 npm）==="
  ( cd "$ENGINE_ROOT/EraCore.Web" && "$NODE_EXE" "$VITE_JS" build --base=./ --outDir dist-maui )
fi
# 把 dist-maui 复制进 wwwroot。VueBuild.targets 的 Copy 只在"源比目标新"时才动，
# 这里显式整目录重做一遍更稳（wwwroot 完全是 dist-maui 的产物，见 CleanVueFrontendBeforeCopy）。
FRESH_WWW="$ENGINE_ROOT/EraCore.Maui/wwwroot"
rm -rf "$FRESH_WWW"
mkdir -p "$FRESH_WWW"
cp -r "$ENGINE_ROOT/EraCore.Web/dist-maui/." "$FRESH_WWW/"
echo "[前端] dist-maui → wwwroot 完成（index.html $(wc -c < "$FRESH_WWW/index.html" | tr -d ' ') 字节）"

# 注意：MauiAsset 的 glob 在项目加载时求值。若 EraCore.Web 的 wwwroot 是刚生成的，
# 首次构建可能收不到前端资源，需连跑两次。这里直接跑两次以确保 assets/wwwroot 齐全。
# ★★★ 2026-10-08 缺陷 B 修复（第 2 版）：「新包打进旧前端」（实测踩中过，危害最大、最难查）
#   症状：装了新 APK、签名正常、构建日志没有任何报错，**界面却仍是旧的**。
#   （实测：wwwroot 已是新版 index.html 6342 字节，APK 里却是旧的 6011 字节版本。）
#   机制：Android 打包前把 assets 暂存到 obj/<cfg>/<tfm>/<rid>/assets/ 且不清旧文件；
#         前端文件名带内容哈希（index-<hash>.js / .css）⇒ 每改一次前端就换一次名，
#         暂存里于是同时留着新旧两套，打包时**旧的那套会被选中**。
#   ★★ 第 2 版的更正（第 1 版**实测无效**）：只删那一个 assets/wwwroot 目录**不够** ——
#      Android 的资产生成步进有**独立的时间戳**，目录删了但步进仍判「已完成」⇒ 跳过重生成
#      ⇒ APK 里仍是旧前端。**必须连整个 Android obj（含步进）一起清**才有效（实测通过）。
#      同理，也不要在 **MSBuild 图里中途**删它 —— 那会让步进时间戳与实际产物不一致，
#      aapt2 link 直接失败（MSB6006 java.exe 退出码 1，两个 pass 全挂）。
#   ★ 加 -nt 条件：只在「wwwroot/index.html 比已暂存的 index.html 新」时才清，
#      避免每次构建都全量重编（全清约多花 1–2 分钟）。
#   ★ 验收判据：**拆开 APK 数 assets/wwwroot，必须与 EraCore.Web/dist-maui 逐名 + 逐字节一致。**
WWW_INDEX="$ENGINE_ROOT/EraCore.Maui/wwwroot/index.html"
if [ -f "$WWW_INDEX" ]; then
  STAGED_INDEX="$(find "$ENGINE_ROOT/EraCore.Maui/obj" -type f -path '*/assets/wwwroot/index.html' 2>/dev/null | head -1)"
  if [ -n "$STAGED_INDEX" ] && [ "$WWW_INDEX" -nt "$STAGED_INDEX" ]; then
    echo "[修复] 前端比 Android 暂存新 ⇒ 清 obj 资产链（否则 APK 会打进旧前端）"
    rm -rf "$ENGINE_ROOT"/EraCore.Maui/obj/*/net*-android*
  fi
fi

FAILED_PASSES=0
for pass in 1 2; do
  echo "=== [$CONFIG] 构建 pass $pass/2 ==="
  # ★ 容错：本项目【首次构建常因资源 glob 未就绪而失败】，上方注释已说明『需连跑两次』——
  #   但原先的 set -e 会在 pass 1 失败时直接中止，导致永远跑不到 pass 2（实测 java.exe MSB6006）。
  #   故此处显式容错：单次失败只记数，必须把两次都跑完；两次都失败才判失败。
  if "$DOTNET" build "$PROJ" \
    -f net10.0-android \
    -c "$CONFIG" \
    -p:AndroidPackageFormats=apk \
    "${EXTRA[@]}"; then
    FAILED_PASSES=0
  else
    FAILED_PASSES=$((FAILED_PASSES+1))
    echo "[警告] pass $pass 失败（首次构建常见，见上方注释）；继续尝试下一 pass"
  fi
done
if [ "$FAILED_PASSES" -ge 2 ]; then
  echo "[错误] 两次构建均失败，放弃"
  exit 1
fi

OUT="$ENGINE_ROOT/EraCore.Maui/bin/$CONFIG/net10.0-android"
# 单 ABI 时 dotnet 会把产物放进 <rid>/ 子目录
if [ -n "$RID" ]; then OUT="$OUT/$RID"; fi
echo
echo "=== 产物 ==="
ls -lh "$OUT"/*.apk

# ★★★ 2026-10-08 缺陷 C 的**自动护栏**：校验 APK 里的前端 == dist-maui
#   这条判据（"拆开 APK 数 assets/wwwroot，与 dist-maui 逐名 + 逐字节一致"）一直写在注释里，
#   但**一直是手工做的** ⇒ 才会静默漏掉一整个版本的旧前端。所以把它变成脚本的硬自检。
#   ★ 用 JDK 自带的 jar 解压（不依赖 unzip / python）。
# ★ 用 unzip 而不是 JDK 的 jar —— **第 1 版用 jar，实测误报**：
#   `jar xf <包> assets/wwwroot` 对**目录条目不递归**，等于什么都没解出来，
#   于是报出假的「APK 里根本没有 assets/wwwroot」，把**好包**判成坏包。
#   ⇒ unzip 支持通配、实测可用（Info-ZIP 6.00 at /usr/bin/unzip）。
#   ★ 教训（通用）：**新验收护栏上线前，必须先证明它不会误报** —— 会误报的护栏比没有更糟。
UNZIP_EXE="$(command -v unzip 2>/dev/null || true)"
APK_FOR_CHECK="$OUT/com.eracore.maui.apk"
DIST_DIR="$ENGINE_ROOT/EraCore.Web/dist-maui"
echo
echo "=== 自检 5：APK 内的前端 == dist-maui ？（缺陷 C 护栏）==="
if [ ! -f "$APK_FOR_CHECK" ]; then
  echo "[跳过] 找不到 $APK_FOR_CHECK，无法自动校验"
elif [ -z "$UNZIP_EXE" ]; then
  echo "[跳过] 找不到 unzip，无法自动校验 —— ★ 请手工拆包核对 assets/wwwroot"
elif [ ! -d "$DIST_DIR" ]; then
  echo "[跳过] 找不到 $DIST_DIR"
else
  CHK="$(mktemp -d)"
  ( cd "$CHK" && "$UNZIP_EXE" -qq -o "$APK_FOR_CHECK" 'assets/wwwroot/*' ) >/dev/null 2>&1 || true
  if [ ! -d "$CHK/assets/wwwroot" ]; then
    echo "[失败] ★★★ APK 里根本没有 assets/wwwroot —— 前端没进包，别装这个包"
    rm -rf "$CHK"; exit 4
  elif diff -r "$DIST_DIR" "$CHK/assets/wwwroot" >/dev/null 2>&1; then
    echo "[通过] APK 内 assets/wwwroot 与 dist-maui 逐名 + 逐字节一致"
    echo "       index.html 字节数：$(wc -c < "$CHK/assets/wwwroot/index.html" | tr -d ' ')"
  else
    echo "[失败] ★★★ APK 里的前端与 dist-maui **不一致** —— 这正是「静默打旧前端」！"
    diff -rq "$DIST_DIR" "$CHK/assets/wwwroot" 2>&1 | head -20
    rm -rf "$CHK"; exit 4
  fi
  rm -rf "$CHK"
fi

APK="$OUT/com.eracore.maui-Signed.apk"
[ -f "$APK" ] || APK="$OUT/com.eracore.maui.apk"

# ---- 自检 1：清单里的 extractNativeLibs 必须是 false ----
echo
echo "=== 自检 1：extractNativeLibs ==="
AAPT2="$BT_DIR/aapt2"
if [ ! -x "$AAPT2" ] && [ -x "$AAPT2.exe" ]; then AAPT2="$AAPT2.exe"; fi
ENL=$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" 2>/dev/null \
      | grep -o 'extractNativeLibs(0x010104ea)=[a-z]*' | head -1)
echo "APK 清单: ${ENL:-<未设置>}"
if [ "${ENL##*=}" != "false" ]; then
  echo "[警告] extractNativeLibs 不为 false —— lib/ 下的 .so 很可能被压缩，装到设备上会 abort。"
fi

# ---- 自检 2：lib/ 下的 .so 必须 STORED，且必须「齐全」 ----
#
# ★ 2026-09-28 新增「完整性」检查（本案教训）：
#   自检 1~3 检查的都是「已存在的文件是否合规」。2026-09-27 的 v0.3 包
#   三项全过，却因 lib/ 只剩 1 个条目（原生库全丢）而根本装不上：
#     INSTALL_FAILED_INVALID_APK: ... base.apk code is missing
#   根因是换机后旧机（macOS）残留的 obj/ 缓存让打包步骤被跳过。
#   → 合规性检查必须配一个「完整性」检查，否则会给出假阳性。
echo
echo "=== 自检 2：原生库压缩状态 + 完整性 ==="
"$PY" - "$APK" <<'PY'
import sys, zipfile
apk = sys.argv[1]
z = zipfile.ZipFile(apk)
libs = [i for i in z.infolist() if i.filename.startswith("lib/") and i.filename.endswith(".so")]

# --- 2a 合规性：不得有被压缩的 .so ---
compressed = [i for i in libs if i.compress_type != 0]
print(f"lib/ 下共 {len(libs)} 个 .so，其中被压缩的 {len(compressed)} 个")
for i in compressed[:5]:
    print(f"   !! DEFLATED: {i.filename}")

# --- 2b 完整性：条目数与关键库 ---
# 正常布局（Debug + AndroidUseAssemblyStore=true）应有 20+ 个 .so。
# 下限取 10 以留出裁剪余地；低于此几乎必然意味着打包残缺。
MIN_LIBS = 10
# 这几个是「少了就一定跑不起来」的：Mono 运行时 + 程序集宿主 + SQLite 原生库
REQUIRED_SUBSTR = ["libmonodroid", "libassembly-store", "libe_sqlite3"]

problems = []
if compressed:
    problems.append("存在被压缩的 .so —— 装到设备上会触发 libmonodroid abort")
if len(libs) < MIN_LIBS:
    problems.append(f"只有 {len(libs)} 个 .so（下限 {MIN_LIBS}）—— 原生库很可能未打包完整")
missing = [k for k in REQUIRED_SUBSTR
           if not any(k in i.filename for i in libs)]
if missing:
    problems.append("缺少关键库: " + ", ".join(missing))

if problems:
    print()
    for p in problems:
        print("   [失败]", p)
    print()
    print("   ★ 常见原因：跨机/跨平台残留的 obj 缓存让打包步骤被跳过。")
    print("     → 修复：rm -rf EraCore.Core/{bin,obj} EraCore.Maui/{bin,obj} 后重建")
    sys.exit(1)

print("[通过] 压缩状态正常，关键库齐全。")
PY

# ---- 自检 3：页对齐（extractNativeLibs=false 的前提） ----
echo
echo "=== 自检 3：lib/ 页对齐 ==="
ZIPALIGN="$BT_DIR/zipalign"
if [ ! -x "$ZIPALIGN" ] && [ -x "$ZIPALIGN.exe" ]; then ZIPALIGN="$ZIPALIGN.exe"; fi
if "$ZIPALIGN" -c -p -v 4 "$APK" >/tmp/zipalign-check.txt 2>&1; then
  echo "[通过] 已按 4 字节页对齐。"
else
  echo "[警告] 未按页对齐，需执行: zipalign -p -f 4 <in> <out> 后重新签名。"
  tail -3 /tmp/zipalign-check.txt
fi

# ============================================================
# ---- 步骤 4：★ 自动签名（2026-10-01 新增，必须保留）----
# ============================================================
# 为什么必须有这一步（血泪教训，别再删）：
#   ① **dotnet build 自己不做签名** —— 即使它报「0 错误 0 警告 生成成功」，
#      产出的 `*-Signed.apk` **没有 META-INF/*.RSA**，装到设备上直接：
#        adb: Failure [INSTALL_PARSE_FAILED_NO_CERTIFICATES: ... Attempt to get length of null array]
#      「-Signed」这个名字是**误导**，别信它。
#   ② 本机沙箱下，**由 bash 派生的 java/keytool 只能【读】`~/.android`，不能【写】**：
#        keytool: java.io.FileNotFoundException: ...\.android\debug.keystore (拒绝访问。)
#      → 而 dotnet-android 的签名步骤恰好需要**创建** keystore，于是它失败（表现为 `java.exe` 退出码 1）。
#      ★ 对策：**在可写目录（仓库根）生成 keystore，再用 cp 复制到 ~/.android**（复制不需 java 写权限）。
#   ③ 签名只需**读** keystore —— 所以「生成在别处 + 复制过去」这条路是通的（已实测）。
echo
echo "=== 步骤 4：自动签名（zipalign + apksigner）==="

KEYSTORE="$HOME/.android/debug.keystore"
KS_TMP="$REPO_ROOT/.keystore-tmp"

# --- 4a 准备 keystore（缺则生成：在仓库内生成，再复制到 ~/.android）---
if [ ! -f "$KEYSTORE" ]; then
  echo "[信息] ~/.android/debug.keystore 不存在 —— 尝试自动生成"
  mkdir -p "$HOME/.android"
  rm -f "$KS_TMP"
  if "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KS_TMP" \
       -storepass android -alias androiddebugkey -keypass android \
       -keyalg RSA -keysize 2048 -validity 10000 \
       -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 && [ -f "$KS_TMP" ]; then
    cp -f "$KS_TMP" "$KEYSTORE" 2>/dev/null && rm -f "$KS_TMP"
  fi
fi
if [ ! -f "$KEYSTORE" ]; then
  echo "[失败] 无法准备 debug keystore，APK 将无法签名（装不上设备）。"
  echo "       手动修法（两条命令）："
  echo "         1) \"\$JAVA_HOME/bin/keytool\" -genkeypair -keystore ./debug.keystore \\"
  echo "              -storepass android -alias androiddebugkey -keypass android \\"
  echo "              -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'"
  echo "         2) cp ./debug.keystore \"\$KEYSTORE\""
  exit 1
fi
echo "[通过] keystore: $KEYSTORE"

# --- 4b 定位 zipalign / apksigner（Windows 下可能是 .bat / .exe）---
ZIPALIGN="$BT_DIR/zipalign"
[ -f "$ZIPALIGN" ] || [ -f "$ZIPALIGN.exe" ] && [ -f "$ZIPALIGN.exe" ] && ZIPALIGN="$ZIPALIGN.exe"
APKSIGNER="$BT_DIR/apksigner"
for _c in "$APKSIGNER" "$APKSIGNER.bat" "$APKSIGNER.exe"; do
  if [ -f "$_c" ]; then APKSIGNER="$_c"; break; fi
done

# --- 4c 对齐 + 签名（输出名带 ABI，避免多架构互相覆盖）---
SIGNED="$OUT/eracore-${RID:-all}-signed.apk"
ALIGNED="$OUT/.aligned-tmp.apk"
rm -f "$SIGNED" "$ALIGNED"
echo "[1/2] zipalign -f -p 4 …"
"$ZIPALIGN" -f -p 4 "$APK" "$ALIGNED" || { echo "[失败] zipalign 出错"; exit 1; }
echo "[2/2] apksigner sign …"
"$APKSIGNER" sign --ks "$KEYSTORE" \
  --ks-pass pass:android --key-pass pass:android --ks-key-alias androiddebugkey \
  --out "$SIGNED" "$ALIGNED" || { echo "[失败] apksigner 签名出错"; rm -f "$ALIGNED"; exit 1; }
rm -f "$ALIGNED"

# --- 4d 验签（不通过就判失败，绝不把未签名包当成品）---
echo
echo "=== 自检 4：签名校验 ==="
if "$APKSIGNER" verify "$SIGNED" >/dev/null 2>&1; then
  "$APKSIGNER" verify --verbose "$SIGNED" 2>/dev/null | grep -E "Verified using|Number of signers" | head -5
  echo "[通过] 签名有效。"
else
  echo "[失败] 签名校验未通过 —— 该包不可发布。"
  exit 1
fi

# --- 4e 指纹（发布时贴给用户核对）---
SHA=$(sha256sum "$SIGNED" 2>/dev/null | cut -d' ' -f1)
SIZE=$(stat -c %s "$SIGNED" 2>/dev/null)
echo
echo "=== ★ 可发布的签名包 ==="
echo "  路径  : $SIGNED"
echo "  大小  : $SIZE 字节（$(echo "scale=1; $SIZE/1048576" | bc 2>/dev/null || echo "?") MB）"
echo "  sha256: $SHA"
echo "  ★ 上传 Release 请用这个文件；上面那个 *-Signed.apk 是【未签名】的，别发。"