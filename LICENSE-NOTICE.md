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

依来源许可第 2 条，修改必须明示。当前完整修改以 `patches/complete-changes.patch` 披露，不重分发游戏内容。

### 当前完整补丁：v0.5.6 公开源码快照

- 基线：`5ebd38ad`；覆盖 **174 文件 / +20064 / −2998**。
- APK 构建内容锚点：`3f0d5ae9b3f23e90b44ac26d2a19cab696def953`；构建 tree：`3fbedb2b79db1ea210f28dd8b121249f6656b200`。
- 公开快照提交：`e42528bf2fcce2f28ecedc3e85038ef4a762620b`；公开 tree：`d8c671d14068e344257d5435ba222d8205d2bb0f`。
- **公开 tree 与构建 tree 不同**。为保护隐私，仅将 20 个源码/测试文件中 88 行非运行注释的用户称谓与审阅记录中性化（沿用 v0.5.5 的同一组中性化改动，相关文件本版无代码变化），未改变运行语句，不修改开发历史。
- 本次实测：在隔离 `GIT_INDEX_FILE` 内 `read-tree 5ebd38ad` → `git apply --cached` → `git write-tree`，结果 **`d8c671d14068e344257d5435ba222d8205d2bb0f`**，等于公开快照 tree。
- **不宣称补丁还原未经脱敏的原始构建树，不承诺 APK 位级可复现**。公开的是源码修改完整集合，不是私有协作历史。
- 当前完整补丁范围包含引擎、MAUI/CLI/Server 宿主、Web 前端、tests 与相关构建/技术说明。分项补丁仅作历史功能参考，**不要与完整补丁叠加**。
- 上游许可与署名原文保留。更详细的证据边界见 `docs/05-v0.5.6版本说明.md`。
- **披露与发布状态**：上述源码公开快照与补丁随本仓库公开；v0.5.6 安装包已随 [v0.5.6 Release](https://github.com/xiangweilai258/eratw-on-eracore/releases/tag/v0.5.6) 发布，安装包核验数据为构建验证包实测值。

### 历史披露沿革（非当前补丁判据）

v0.5.3 首次补齐完整集合时的分项覆盖口径为 42/139（可 apply 补丁计），若计入说明代码片段为 43/139。v0.5.4 完整补丁为 141 文件 / +11611 / −2196，锚点 `2ce25e0a`，tree `cbcb35bd86b0e19b780d6dd77bab13d34356077b`。v0.5.5 完整补丁为 171 文件 / +19237 / −2997，锚点 `edf0afff`，公开快照 `b0a56dd8`（tree `4ee4d920b428352a1fa42265c0b9229252cd3056`）。这些数值仅属于历史版本；当前补丁以上述 v0.5.6 公开快照为准。

### `port/eratw-EE56-compat.patch`（+999 / -10，9 个文件）

> ★★ **2026-10-10 更正 + 留痕**：此处**原写 `+946 / -10`** —— ★ 那是 **v0.5.2 时代旧版补丁**留下的旧数，
> 不是本版补丁的规模。**实测（本版）= `+999 / -10`**（★ 旧值 `946` 保留在此行留痕，不静默抹掉）。
> 判据：数补丁文本里以 `+` 开头（**排除 `+++`**）的行数 = **999**、以 `-` 开头（**排除 `---`**）的行数 = **10**，
> 与 `git apply --numstat` 逐文件累加的结果（`+999 / -10`）一致。

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

### `patches/nf-input-family.patch`（+108 / -4，5 个文件）

> ★★ **2026-10-10 更正 + 留痕**：此处**原写 `+89 / -4`** —— ★ 那是 **v0.5.2 时代旧版补丁**留下的旧数。
> **实测（本版）= `+108 / -4`**（★ 旧值 `89` 保留在此行留痕，不静默抹掉）。
> 判据同上：数 `+` 行（排除 `+++`）= **108**、`-` 行（排除 `---`）= **4**，与 `git apply --numstat` 一致。

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

★ **主要改动**（★ 完整清单见补丁本身，共 **33** 个文件）：

> ★ **本数字的更正留痕**：此处原写「共 **45** 个文件」—— **45 是补丁的删除行数（`-45`），不是文件数**。
> 2026-10-10 由独立审查指出，实测补丁内 `diff --git` 段 = **33**（与本节标题一致）。

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
| ② 修改必须明示   | 改动以完整补丁披露，公开快照非运行注释脱敏，见第二节                    |
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
