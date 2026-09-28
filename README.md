# EraRelay

> **eraTW on EraCore** —— 把 **eraTW（画蛇添足版）** 移植到
> **[LaoBro/era-core](https://github.com/LaoBro/era-core)** 引擎上运行，
> 并针对 Android 真机做了打包与内存验证。

**名字的意思**：eraTW 从旧引擎（Emuera）接力到新引擎（EraCore）—— 我们只做接力的那一棒。

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

| 项目     | 结果                                                             |
| ------ | -------------------------------------------------------------- |
| 补丁规模   | `+999 / -10`，9 个文件，41.6 KB                                     |
| ERB 加载 | 3931 个 ERB 全通过（`labels=112727`）                                |
| 启动     | `Process.Initialize OK` → `state=WaitInput`；热 IR 缓存后 **约 6 秒** |
| 真机     | 荣耀平板 ROD-W09 / Android 14 / 8 GB —— **完整可玩**                   |
| 内存     | 标题画面 **PSS 747 MB**，游玩 27+ 分钟未被系统回收                            |
| APK    | **255 MB**（arm64 + x86_64 双架构，见 Releases）                     |

### 内存对照

同设备、同游戏目录下与另一款 Android 端模拟器（gEmuera v1.0.8）的实测对照：

|          | EraCore（本仓库） | gEmuera v1.0.8 |
| -------- | ------------ | -------------- |
| 载入 eraTW | ✅            | ✅（部分版本）        |
| 标题画面 PSS | **747 MB**   | 2,555 MB       |
| 长时间游玩    | 27+ 分钟未被杀    | 6 分钟涨到 3.2 GB  |

内存占用约为对照实现的 **1/3 ~ 1/4**。

> ⚠️ **仅内存维度有数据。** 速度维度**没有量化对比**，主观感受不做结论。上表数据来自单台设备单次采样，  
> 环境差异（系统版本、后台负载、采样方式）都会影响结果，请自行复现。

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

需要 .NET 10 SDK、Android SDK、JDK 17+。上游详细的构建说明见其 README。

### 方式三：只在 PC 上跑（无头 / Web）

见仓库 `tools/` 下的脚本：

- `tools/eracore-probe.sh` —— 无头引擎加载探针（量化加载耗时、打印画面、发送输入）
- `tools/start-web.sh` —— 拉起 HTTP server，浏览器直接玩

---

## 仓库内容

```
port/
  eratw-EE56-compat.patch    ★ 核心补丁（+999/-10，9 文件）
  make-patch.py                补丁生成脚本（可复现）
patches/
  als-VarKeyAreadyDefined-fix.patch   一个独立的小修（上游 main 分支可用）
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
```

---

## 补丁做了什么

改动集中在 `EraCore.Core`，可归纳为四类：

1. **EEv56 兼容层** —— 新增 `Creator.Method.EE56.cs`，补齐 eraTW 依赖的扩展指令实现  
   （`GRAPH_DISTANCE` / `SQL_IMPORT_MAP_XML` / `TEXT_BGC` / `HTML_PRINTC` / `UNCHECKED_*` 等）
2. **指令注册** —— 在 `BuiltInFunctionCode.cs` / `FunctionIdentifier.cs` / `Instraction.Child.cs` 登记新指令
3. **SQL 运行时** —— 新增 `EESqlRuntime.cs`，提供 eraTW 需要的 SQL 层
4. **插件加载容错** —— `PluginManager.cs`：程序集重定向、`GetTypes` 容错、目录大小写

### 已知未实现

- **NF 指令族**（`TINPUTNF` / `TINPUTSNF` / `TONEINPUTNF` / `TONEINPUTSNF`）—— eraTW 的动态地图动画依赖它。  
  未实现时地图**不显示动画**；把地图类型切到「[2] 颜色地图」或「[3] 经典」可绕过（功能正常，仅无动画）。

---

## 授权与致谢

本项目**基于 [LaoBro/era-core](https://github.com/LaoBro/era-core)** 开发，后者又源自 **EvilMask 的  
[Emuera.EM](https://gitlab.com/EvilMask/emuera.em)**，并可追溯至 **MinorShift 的 Emuera**。

**本仓库不声称对上游代码的任何原创性。** 我们做的是移植与适配，所有改动均以补丁形式明示。

上游采用 MinorShift 的 Emuera 许可（允许自由使用、修改、再分发，含商用），要求：  
① 不得虚报出处 ② **修改过源码必须明示** ③ 不得删除许可声明。  
本仓库遵守上述三条，许可原文见 [`LICENSE-NOTICE.md`](LICENSE-NOTICE.md)。

**关于游戏本体**：eraTW 是独立同人作品，版权归其作者群体所有，**本仓库不包含、不分发任何游戏内容**。
