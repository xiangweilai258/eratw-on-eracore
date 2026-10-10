# 授权说明 / License Notice

本文件说明本仓库与上游项目的授权关系，并列出来源许可（License）原文。

---

## 一、来源与层级

本仓库（`eratw-on-eracore`，项目名 **EraRelay**）**不是原创项目**，而是一个**移植适配层**。依赖链路为：

```
MinorShift 的 Emuera  (Copyright (C) 2008-, 原始实现)
        ↓ fork
EvilMask 的 Emuera.EM  (https://gitlab.com/EvilMask/emuera.em)
        ↓ fork
LaoBro/era-core        (https://github.com/LaoBro/era-core —— 本仓库直接基于此)
        ↓ 本仓库提供补丁
eratw-on-eracore       （本仓库 / EraRelay：EEv56 兼容层补丁 + 构建/测试脚本）
```

**本仓库不声称对上游代码的任何原创性。** 我们的贡献限于：让 eraTW 能在 EraCore 上运行的兼容性补丁，  
以及配套的构建、部署、内存采样脚本。

---

## 二、本仓库对上游做的修改（明示）

依来源许可第 2 条「修改源码必须明示」，此处列出全部改动。改动以补丁形式提供，**不重分发完整源码**：

### ★ `patches/complete-changes.patch`（完整改动，**139 个文件**，+11142 / −2195）

**这是本仓库对上游改动的完整集合** —— 应用这一个补丁，即可把上游源码变成与本仓库构建 APK 时使用的源码一致。

| 范围 | 主要内容 |
| --- | -- |
| `EraCore.Core/` | EEv56 兼容层、图形画布链路、配置与排版逻辑画布、控制服务器、存储访问 |
| `EraCore.Maui/` | 界面宿主、WebView 桥、平台层（Android / Windows）、崩溃日志 |
| `EraCore.Cli/`、`EraCore.Server/` | 无头入口、HTTP / WebSocket 会话宿主 |
| `EraCore.Web/` | 前端（终端渲染、输入栏、设置页等） |
| `EraCore.Tests/`、`tests/`、`eracore_agent/` | 单元测试与自动化客户端 |
| `build/` | 构建目标 |

★ **基线**：`5ebd38ad`（上游 2026-09-15 的提交，也是本分支与上游的**分叉点**）。

★ **与下方分项补丁的关系**：分项补丁按功能拆分，便于逐项查阅；**若要做完整还原，只用本补丁**。
★ **不要与分项补丁同时应用** —— 两者基准不同，会冲突。

★ 本补丁为**补记**：此前分项补丁只覆盖了改动的一小部分（**42 / 139** 个文件），
而本节却声称「列出全部改动」；现已补齐，该声明与实际一致。

★ **本数字的更正留痕**：该数曾写作 `59 / 139`（v0.5.3 首次发布时），**2026-10-10 更正为 42** ——
错因是测量时把一份**从未发布**的临时补丁计入了"已覆盖"。
★ 同一次核对还纠正了另一版误算（`80 / 139`）：**"改动数 − 补丁并集数"不是未披露数** ——
补丁并集里有文件根本不在改动集内，**必须做集合相交，不能做减法**。

### `port/eratw-EE56-compat.patch`（+946 / -10，9 个文件）

| 文件                                                                                 | 类型 | 说明                                   |
| ---------------------------------------------------------------------------------- | -- | ------------------------------------ |
| `EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.EE56.cs`    | 新增 | EEv56 扩展指令实现（主体）                     |
| `EraCore.Core/Shared/Runtime/Utils/EESqlRuntime.cs`                                | 新增 | SQL 运行时                              |
| `EraCore.Core/Shared/Runtime/Script/Statements/BuiltInFunctionCode.cs`             | 修改 | 登记新指令                                |
| `EraCore.Core/Shared/Runtime/Script/Statements/FunctionIdentifier.cs`              | 修改 | 登记新指令标识符                             |
| `EraCore.Core/Shared/Runtime/Script/Statements/Instraction.Child.cs`               | 修改 | 登记新指令处理                              |
| `EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.cs`                | 修改 | 接入兼容层入口                              |
| `EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.General.cs` | 修改 | 适配 `argumentTypeArrayEx` 等 API 变更    |
| `EraCore.Core/Shared/Runtime/Utils/PluginSystem/PluginManager.cs`                  | 修改 | 插件加载容错（程序集重定向 / GetTypes 容错 / 目录大小写） |
| `EraCore.Core/EraCore.Core.csproj`                                                 | 修改 | 纳入新文件                                |

### `patches/nf-input-family.patch`（+89 / -4，5 个文件）

补齐 eraTW **动态地图动画**依赖的 NF（不夺窗口焦点）输入指令族 ——
`TINPUTNF` / `TINPUTSNF` / `TONEINPUTNF` / `TONEINPUTSNF`。
该族是 eraTW 汉化整合版自带解释器 v9 的私有扩展，上游 `era-core` 未实现。

### `patches/pluginsAware-soft-warning.md`（改动说明，非补丁文件）

`pluginsAware` 门禁由「**硬拒绝启动**」改为「**软警告**」，与上游 Emuera 2026-05-26 的行为对齐；
具体代码改动并入上方 `port/eratw-EE56-compat.patch` 的 `PluginManager.cs` 一处。

### `patches/cbg-graphics-layer.patch`（+827 / -45，33 个文件）

让 era 类游戏使用的**图形画布**族指令（`GCREATE` / `GDRAWSPRITE` / `CBGSETG` 等）在无头构建下真正生效，
并补齐围绕它的图形能力（背景图的颜色处理、运行时合成图的登记与取图等）。
上游在无头化改造时移除了这条链路（源码中保留了说明其被移除的注释），本次将其接回，
并把绘制结果经由显示协议送到前端渲染。

★ **主要改动**（★ 完整清单见补丁本身，共 **45** 个文件）：

| 文件                                                                        | 类型    | 说明                                     |
| ------------------------------------------------------------------------- | ----- | -------------------------------------- |
| `EraCore.Core/Shared/UI/Game/Image/GraphicsImage.cs`                      | 修改    | 无头分支：画布由空实现改为**记录绘制内容与来源**             |
| `EraCore.Core/Shared/UI/Game/Image/AppContents.cs`                        | 修改    | 画布→命名图的登记与查询；合成名可回溯到来源                 |
| `EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.Cbg.cs` | 修改    | 接回 `CBG_SetGraphics`（设置图形图层）与 `CBG_Clear`（清除） |
| `EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.Sprite.cs` | 修改    | 记录所绘资源与目标矩形；颜色矩阵解析                     |
| `EraCore.Core/Shared/Runtime/Script/Statements/Function/Creator.Method.Io.cs` | 修改    | 「从文件建画布」在无头下的实现（记录尺寸与来源）               |
| `EraCore.Core/UI/Game/Console/ConsolePrintManager.cs`                     | 修改    | 图形图层出口：把画布内容转为背景图层并下发                  |
| `EraCore.Core/Assets/AssetChannel.cs`                                     | 修改    | 取图回退：合成名可落到它的来源文件                      |
| `EraCore.Core/Agent/TurnRecord.cs`                                        | 修改    | 背景图层状态新增可空字段；显示协议版本 11 → 13            |
| `EraCore.Web/src/`（3 个文件）                                                | 修改    | 前端类型、解析与背景图渲染同步                        |
| `EraCore.Tests/`、`tests/emuera_server.py`                                 | 修改／新增 | 单元测试与测试夹具同步（含 4 个新增测试文件）                |

★ 说明：本补丁**包含图形画布链路本身，以及围绕它的图形能力改动**（背景图的颜色处理、运行时合成图的登记与取图等）。
★ 本节的规模与范围**以本节为准**（此前的版本说明只涵盖绘制链路，范围更窄）。

### `patches/als-VarKeyAreadyDefined-fix.patch`（独立小修，906 B）

针对上游 `main` 分支的一处独立修复，可用 `git apply` 单独应用。

---

## 三、来源许可原文（不得删改）

以下为上游 `LaoBro/era-core` 采用的许可文件 **`Readme/License/Emuera.LICENSE.txt`** 的完整原文，  
按来源许可第 3 条要求**照录不改**：

```
Copyright (C) 2008- MinorShift, 妊）|дﾟ)の中の人

本ソフトウェアは「現状のまま」で、明示であるか暗黙であるかを問わず、何らの保証もなく提供されます。 本ソフトウェアの使用によって生じるいかなる損害についても、作者は一切の責任を負わないものとします。 

以下の制限に従う限り、商用アプリケーションを含めて、本ソフトウェアを任意の目的に使用し、自由に改変して再頒布することをすべての人に許可します。 

1.本ソフトウェアの出自について虚偽の表示をしてはなりません。あなたがオリジナルのソフトウェアを作成したと主張してはなりません。 あなたが本ソフトウェアを製品内で使用する場合、製品の文書に謝辞を入れていただければ幸いですが、必須ではありません。 
2.ソースを変更した場合は、そのことを明示しなければなりません。オリジナルのソフトウェアであるという虚偽の表示をしてはなりません。 
3.ソースの頒布物から、この表示を削除したり、表示の内容を変更したりしてはなりません。
```

### 中文参考译文（仅供参考，非正式文本，以上方日文原文为准）

> 版权所有 (C) 2008- MinorShift, 妊）|дﾟ)の中の人
>
> 本软件按「现状」提供，无论明示或默示，均不附带任何担保。因使用本软件而产生的任何损害，作者概不负责。
>
> 只要遵守以下限制，**允许所有人将本软件用于任何目的、自由修改并再分发，包括用于商业应用**。
>
> 1. 不得对本软件的出处作虚假表示。不得声称你创作了原始软件。若你在产品中使用本软件，虽然希望在产品的文档中加入致谢，但并非强制。
> 2. **修改源码时，必须明示这一点。**&#x4E0D;得作出「这是原始软件」的虚假表示。
> 3. 不得从源码分发物中删除本声明，或更改其内容。

---

## 四、本仓库的遵守情况

| 许可要求       | 本仓库做法                                        |
| ---------- | -------------------------------------------- |
| ① 不得虚报出处   | README 首段即声明基于 `LaoBro/era-core`；本文件列出完整依赖链路 |
| ② 修改必须明示   | 改动**全部以补丁形式**提供，逐文件列表见第二节                    |
| ③ 不得删改许可声明 | 上方许可原文**完整照录**，未作任何改动                        |

---

## 五、游戏本体的版权（重要）

**本仓库不包含、不分发任何游戏内容。**

- **eraTW（画蛇添足版）** 是独立的社区同人作品，其版权归原作者群体所有。  
  其开发仓库为 <https://gitgud.io/era-games-zh/touhou/eratw-sub-modding>。
- 本仓库提供的 APK **不内置任何游戏文件**，使用者需自行获取游戏本体。

---

## 六、免责

本仓库内容按「现状」提供，不附带任何担保。使用者需自行确认其所在地区对相关软件与内容的  
使用、分发规定。
