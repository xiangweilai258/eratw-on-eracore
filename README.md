# EraRelay

> **eraTW on EraCore** —— 把 **eraTW（画蛇添足版）** 移植到  
> **[LaoBro/era-core](https://github.com/LaoBro/era-core)** 引擎上运行，  
> 并针对 Android 真机做了打包与内存验证。

**名字的意思**：eraTW 从旧引擎（Emuera）接力到新引擎（EraCore）—— 我们只做接力的那一棒。

> ★ **当前版本：v0.4.4**（2026-10-08）
> ★ 本版新增「**关于**」页（游戏内与主菜单的 **⋮** 里都能进：版本号、开源仓库、上游致谢、许可与免责），
> 并修正了主菜单里「疑难解答 / 关于」点击无反应的问题。
> ★ 全部版本与下载见 [**Releases**](https://github.com/xiangweilai258/eratw-on-eracore/releases)
> —— ★ 本应用**不做自动更新**，新版本请自行到这个页面取。

> **本仓库不包含任何游戏本体。** eraTW 是社区同人作品，请自行准备游戏目录。  
> 本仓库只提供：移植补丁、辅助脚本、以及我们自己编译的 Android APK。

---

## 这是什么

`era-core` 是 [Emuera](https://ja.wikipedia.org/wiki/Emuera) 的现代化重构版 —— 剥离了 WinForms、内核完全无头、  
可跨平台（Windows / Android / 浏览器）。但它**跑 eraTW 会崩**：eraTW 使用了「画蛇添足」这一支系魔改出的  
EEv56 扩展指令集，而 `era-core` 的 `main` 分支只实现了基础指令。

本仓库的 `port/eratw-EE56-compat.patch` 就是补上这块兼容层的补丁 —— **打完即可在 EraCore 上跑 eraTW**。

---

## 成果

| 项目     | 结果                                                                                                                            |
| ------ | ----------------------------------------------------------------------------------------------------------------------------- |
| 补丁规模   | `+946 / -10`，9 个文件，40.6 KB                                                                                                    |
| ERB 加载 | 3931 个 ERB 全通过（`labels=112727`）                                                                                               |
| 启动     | `Process.Initialize OK` → `state=WaitInput`；热 IR 缓存后 **约 6 秒**                                                                |
| 真机     | 荣耀平板 ROD-W09 / Android 14 / 8 GB —— **完整可玩**<br />ALLDOCUBE 掌玩 mini / Android 13 —— **可玩**（★ 该机需先关掉多进程 WebView，见「快速开始」里的白屏说明） |
| 内存     | 标题画面 **PSS 747 MB**，游玩 27+ 分钟未被系统回收                                                                                           |
| APK    | **37.9 MB**（**arm64-v8a 单架构精简包**，见 Releases）                                                                                  |

### 内存表现

标题画面 **PSS 747 MB**，游玩 27+ 分钟未被系统回收。

> ⚠️ 数据来自单台设备单次采样，环境差异（系统版本、后台负载、采样方式）都会影响结果，请自行复现。

### ★ AI 参与游玩（本项目的独特之处）

EraCore 的引擎内核是**完全无头**的，游戏会话跑在一个本地 HTTP + WebSocket 服务上，  
WebView 只是其中一个「客户端」。这意味着 —— **AI agent 可以像另一个玩家一样接进同一个会话**：

- 读画面：agent 订阅 turn 流，拿到与玩家屏幕上一致的文本 diff
- 下指令：agent 通过同一套输入协议发送操作，与真人操作等效

这不是设想，是**已经跑通的架构**（`EraCore.Core/Agent/` 下的 JSONL 协议 + `EraCore.Maui/BridgeHost.cs` 编排）。

> 这也是本仓库不同于社区其他 era 模拟器的地方：那些实现把「引擎 + 界面」焊死在一起，  
> 而这里界面是可拆换的，AI 只是换了一种接入方式。

---

## 快速开始

### 方式一：直接用 APK（推荐，最省事）

1. 到 [Releases](../../releases) 下载最新的 `EraRelay-v*.apk`
2. 安装到 Android 设备（支持 arm64 真机与 x86_64 模拟器）
3. 把 eraTW 游戏目录放到设备上，例如 `/sdcard/emuera/eraTW/`（目录内应有 `ERB/`、`CSV/` 等）
4. 打开应用，选择该目录

> **本 APK 不内置任何游戏内容**，请自行获取 eraTW 本体。

> ⚠️ **如果装上打开是一片白**：多半是**设备自带的 WebView 不完整**（Android 10 起 WebView 拆成  
> 「外壳 + Trichrome 核心库」，有些白牌 ROM 只装了外壳），**与本应用无关** —— 这类机器上  
> 任何 WebView 应用都会白屏。两个办法：① 把系统的 WebView 实现换成完整的 Chrome  
> （设置 → 开发者选项 → WebView 实现）；② 在电脑上执行 `adb shell settings put global webview_multiprocess 0`，  
> 退回单进程 WebView。★ 实测：一台白牌平板（Android 13）正是这种 ROM，用办法 ② 后白屏消失。

### 方式二：从源码构建

```bash
# 1. 取上游源码
git clone https://github.com/LaoBro/era-core.git
cd era-core && git checkout main

# 2. 打上移植补丁
git apply /path/to/port/eratw-EE56-compat.patch

# 3. 构建 Android APK（arm64）
dotnet publish EraCore.Maui/EraCore.Maui.csproj -f net10.0-android -c Release -r android-arm64
```

> ★ **推荐改用本仓库的 `tools/build-android.sh Release arm64`** —— 它把上面的命令包起来，  
> 并额外做四道自检 + **自动签名**。★ 注意：`dotnet build` 即便显示「0 错误 0 警告 生成成功」，  
> 产出的 `com.eracore.maui-Signed.apk` **实际没有签名**（那个名字是误导），装机会报  
> `INSTALL_PARSE_FAILED_NO_CERTIFICATES`。

需要 .NET 10 SDK、Android SDK、JDK 17+。上游详细的构建说明见其 README。

### 方式三：只在 PC 上跑（无头 / Web）

见仓库 `tools/` 下的脚本：

- `tools/eracore-probe.sh` —— 无头引擎加载探针（量化加载耗时、打印画面、发送输入）
- `tools/start-web.sh` —— 拉起 HTTP server，浏览器直接玩

---

## 仓库内容

```
port/
  eratw-EE56-compat.patch    ★ 核心补丁（+946/-10，9 文件）
  make-patch.py                补丁生成脚本（可复现）
  make-nf-patch.py             NF 指令族补丁生成脚本（可复现）
  make-pluginaware-patch.py    pluginsAware 软警告改动的补丁生成脚本（可复现）
patches/
  nf-input-family.patch         ★ NF 指令族补丁（+89/-4，5 文件，见下）
  als-VarKeyAreadyDefined-fix.patch   一个独立的小修（上游 main 分支可用）
  pluginsAware-soft-warning.md        插件门禁改软警告的逐处改动说明（见下）
tools/
  build-android.sh        Android 打包（含 Debug 打包的 .so 压缩坑的修复）
  deploy-android.sh       部署到真机 + 启动自检 + 内存采样
  bench-app.sh            跨架构启动/内存基准
  soak-memory.sh          长时内存采样（验稳定）
  soak-v2.sh              真实游玩资源占用记录（含 WebView 渲染进程）
  eracore-probe.sh        无头引擎探针
  start-web.sh            浏览器方式启动
  snapshot-dump.py        从 /snapshot 提取屏幕文本
  playthrough.py          自动通关驱动（跑 EEv56 路径）
  check-release.ps1       外发前自检（六类合规红线，FAIL / WARN / OK 分级）
  measure-win-fill.ps1    量 Windows 版游戏窗口的「铺满度」（可回归）
  web-layout-probe.ps1    前端布局探针：无头浏览器在指定分辨率下读真实 DOM 几何并出图
  web-layout-probe.mjs    同上，CDP 驱动部分（用 Node 内置 WebSocket，无第三方依赖）
```

> **关于 `pluginsAware`**：`era-core` 的 `main` 分支还留着**旧版硬门禁**——游戏目录带了 DLL 插件  
> 却没有 `pluginsAware.txt` 时，会**直接拒绝启动**。上游 Emuera 已于 2026-05-26 废弃该设计  
> （改为软警告），本仓库已对齐该行为，逐处改动见  
> [`patches/pluginsAware-soft-warning.md`](patches/pluginsAware-soft-warning.md)。  
> 用本仓库编译的 APK 无需关心这个文件；如需 `pluginsAware.txt` 模板，见  
> [`docs/pluginsAware.txt.template`](docs/pluginsAware.txt.template)。

---

## 补丁做了什么

改动集中在 `EraCore.Core`，可归纳为五类：

1. **EEv56 兼容层** —— 新增 `Creator.Method.EE56.cs`，补齐 eraTW 依赖的扩展指令实现  
   （`GRAPH_DISTANCE` / `SQL_IMPORT_MAP_XML` / `TEXT_BGC` / `HTML_PRINTC` / `UNCHECKED_*` 等）
2. **指令注册** —— 在 `BuiltInFunctionCode.cs` / `FunctionIdentifier.cs` / `Instraction.Child.cs` 登记新指令
3. **SQL 运行时** —— 新增 `EESqlRuntime.cs`，提供 eraTW 需要的 SQL 层
4. **插件加载容错** —— `PluginManager.cs`：程序集重定向、`GetTypes` 容错、目录大小写
5. **NF 指令族** —— `TINPUTNF` / `TINPUTSNF` / `TONEINPUTNF` / `TONEINPUTSNF`（见下）

### ★ NF 指令族（`patches/nf-input-family.patch`）

eraTW 的动态地图动画依赖一组「不夺窗口焦点」的输入指令 —— **NF（NoFocus）族**，  
由 eraTW 汉化整合版自行 fork 的解释器 v9 私有扩展，上游 `era-core` 没有。

本仓库已补齐（**+89 / -4，5 文件**）：

| 文件                       | 改动                              |
| ------------------------ | ------------------------------- |
| `EraCore.Core.csproj`    | 显式定义引擎版本号 `1.0.1`（作废旧 IR 缓存，见下） |
| `BuiltInFunctionCode.cs` | 新增 4 个枚举成员                      |
| `InputRequest.cs`        | 新增 `NoFocus` 字段                 |
| `Instraction.Child.cs`   | `TINPUT` / `TINPUTS` 两个构造加可选参   |
| `FunctionIdentifier.cs`  | 登记 4 个新指令                       |

> **为什么动版本号**：`EraCore.Core` 原本走 SDK 默认版本 `1.0.0.0`；新增指令后，  
> 已缓存过的 `era_ir.dat`（IR 缓存）可能用旧指令集合，需判废重建。引擎用  
> `Fnv1a64(AssemblyData.EmueraVersionText)` 作为 IR 缓存键 —— 版本号 +1 即可让老缓存自动失效，  
> 用户无需手动删 `_IRCache`。**注意：版本号只能增不能减。**

### 相对上游的行为调整

- **插件门禁改为软警告** —— 上游 `main` 分支在游戏自带 DLL 插件但缺 `pluginsAware.txt` 时**拒绝启动**；  
  本仓库对齐上游 Emuera 2026-05 的方案，改为**启动时提示一条，不拦截**。  
  详见 [`patches/pluginsAware-soft-warning.md`](patches/pluginsAware-soft-warning.md)。

---

## 授权与致谢

本项目**基于 [LaoBro/era-core](https://github.com/LaoBro/era-core)** 开发，后者又源自 **EvilMask 的  
[Emuera.EM](https://gitlab.com/EvilMask/emuera.em)**，并可追溯至 **MinorShift 的 Emuera**。

**本仓库不声称对上游代码的任何原创性。** 我们做的是移植与适配，所有改动均以补丁形式明示。

上游采用 MinorShift 的 Emuera 许可（允许自由使用、修改、再分发，含商用），要求：  
① 不得虚报出处 ② **修改过源码必须明示** ③ 不得删除许可声明。  
本仓库遵守上述三条，许可原文见 [`LICENSE-NOTICE.md`](LICENSE-NOTICE.md)。

**关于游戏本体**：eraTW 是独立同人作品，版权归其作者群体所有，**本仓库不包含、不分发任何游戏内容**。
