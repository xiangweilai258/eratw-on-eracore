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

### `port/eratw-EE56-compat.patch`（+999 / -10，9 个文件）

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
- 本仓库中提到的其他模拟器（如 gEmuera、XEmuera）仅作为**性能对照参照物被提及**，  
  其代码与产物**不在本仓库中**。

---

## 六、免责

本仓库内容按「现状」提供，不附带任何担保。使用者需自行确认其所在地区对相关软件与内容的  
使用、分发规定。
