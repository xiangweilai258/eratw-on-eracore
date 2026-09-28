# `pluginsAware` 软警告对齐（2026-09-28）

> **一句话**：把 `pluginsAware` 硬门禁（撞到就拒绝启动）改为上游 Emuera 现行的**软警告**方案。
>
> **为什么**：上游 `emuera.em` 已于 **2026-05-26（提交 `0abdff83`）** 废弃该门禁。
> EraCore 的 `main` fork 早于该日，所以还留着旧逻辑。本改动让 EraCore 与上游行为一致。

---

## 一、问题是什么

游戏目录的 `plugins/` 里有 DLL 插件，但**没有** `pluginsAware.txt` 时：

| 版本 | 行为 |
| ---- | ---- |
| EraCore（改前） | ✗ 抛 `ExeEE`，**拒绝启动** |
| 上游 emuera.em（2026-05-26 起） | ✓ 正常启动 + 打印一条警告 |
| gEmuera v1.0.8 | ✓ 正常（**根本没实现插件子系统**） |

**为什么会撞上**：eraTW 官方仓库**从不带** `pluginsAware.txt`，且**没有 Releases**（只能 clone）。
玩家用原版 Emuera 首次运行必撞；而我们的移植补丁把插件绑定修好了，反而让这道门禁开始真正生效。

---

## 二、改哪 6 个文件

全部在 `EraCore.Core/Shared/Runtime/` 下。

### 2.1 `Utils/PluginSystem/PluginManager.cs`

**改动 A** — 注释掉 `pluginsAware` 检测，并记录插件存在性：

```csharp
			string[] plugins = Directory.GetFiles(pluginRoot, "*.dll");
			// ★ 对齐上游 emuera.em 提交 0abdff83（2026-05-26）：
			// 上游已废弃 pluginsAware 硬门禁——注释掉该检测与下方的 throw，
			// 改为由宿主在 LoadPlugins 之后打印一条软警告（见 Process.cs + Config.PluginAvailableWarn）。
			// 旧逻辑：bool pluginsAware = File.Exists(Program.ExeDir + "pluginsAware.txt");
			ClearMethods();

			// 上游同款：记录本游戏是否带插件，供宿主决定是否打印警告。
			ExistPlugin = plugins.Length > 0;

			foreach (var pluginPath in plugins)
```

**改动 B** — 注释掉 `throw`：

```csharp
				var manifestType = dllTypes.Where((v) => v.Name == "PluginManifest").FirstOrDefault();
				if (manifestType == null)
				{
					// 不是 EE/EM 插件（例如纯辅助类库），跳过
					EmueraLog.Debug("plugins", $"非插件程序集，跳过：{Path.GetFileName(pluginPath)}");
					continue;
				}
				// ★ 对齐上游 0abdff83：pluginsAware 硬门禁已废弃。原代码为：
				//   if (!pluginsAware) { throw new ExeEE("This game comes prepackaged with plugins. ..."); }
				// 现改为不拦截，由宿主打印软警告（见 Process.cs）。
```

**改动 C** — 新增 `ExistPlugin` 属性（放在 `HasPlugins` 附近）：

```csharp
		internal bool HasPlugins => methods.Count > 0;

		/// <summary>
		/// 本次 <see cref="LoadPlugins"/> 是否在插件目录中发现了 DLL（不论是否成功登记方法）。
		/// ★ 对齐上游 emuera.em 提交 0abdff83：上游用同名标志（GlobalStatic.ExistPlugin）
		/// 决定是否在启动时打印「外部插件已启用」软警告。
		/// </summary>
		internal bool ExistPlugin { get; private set; }
```

### 2.2 `Config/ConfigCode.cs` — 加枚举

```csharp
	#region EE_CALLSHARP注意
	PluginAvailableWarn,
	#endregion
```

### 2.3 `Config/ConfigData.cs` — 注册配置项（默认 **true**，与上游一致）

```csharp
		// ★ 对齐上游 emuera.em 提交 0abdff83（2026-05-26）：pluginsAware 硬门禁废弃后，
		// 改为「检测到插件目录有 DLL 时打印一条软警告」，本项控制该警告是否显示。
		// 默认 true（与上游一致）；玩家可在设置里关闭。
		configArray.Add(new ConfigItem<bool>(ConfigCode.PluginAvailableWarn, "外部プラグインが有効時に警告を表示する", "If available pllugins, Show warning", true));
```

### 2.4 `Config/Config.cs` — 加属性

```csharp
	/// <summary>★ 对齐上游 0abdff83：检测到插件目录有 DLL 时是否打印软警告（默认 true）。</summary>
	public static bool PluginAvailableWarn => Current!._data.GetConfigValue<bool>(ConfigCode.PluginAvailableWarn);
```

### 2.5 `Utils/EvilMask/Lang.cs` — 加**中文**文案

```csharp
		// ★ 对齐上游 emuera.em 提交 0abdff83（2026-05-26）：pluginsAware 硬门禁废弃后的软警告。
		// 上游原文为「注意：外部プラグイン機能が有効になっています。...」。
		// 此处用中文表述，并补充「如何自行排查」，因为中文用户撞到此提示时更需要行动指引。
		[Managed] public static TranslatableString PluginAvailable { get; } = new TranslatableString("注意：检测到外部插件已启用。插件由第三方提供，由此产生的问题不在本引擎支持范围内；如非你本人安装，请检查游戏目录下的 plugins 文件夹");
```

### 2.6 `Script/Process.cs` — 打印软警告

找到 `LoadPlugins()` 调用处（`Process.Initialize` 内），在其后加：

```csharp
			PluginManager.GetInstance().SetParent(process, process.state, process.exm);
			PluginManager.GetInstance().LoadPlugins();
			// ★ 对齐上游 emuera.em 提交 0abdff83（2026-05-26）：pluginsAware 硬门禁已废弃，
			// 改为「有插件就提示一次」的软警告。仅当插件目录确实含 DLL（ExistPlugin）且
			// 配置未关闭（PluginAvailableWarn，默认开）时打印；不影响启动与插件加载。
			if (PluginManager.GetInstance().ExistPlugin && Config.PluginAvailableWarn)
			{
				console.PrintSystemLine(trsl.PluginAvailable.Text);
			}
```

---

## 三、验证方法

改动后用 `pluginsAware.txt` **删掉**的场景跑一次，应满足：

1. 游戏正常启动，不再抛 `ExeEE`
2. 到达 `WaitInput`（标题画面就绪）
3. **画面上**出现中文软警告 ← ★ 注意：这条走 `PrintSystemLine`，**进游戏画面、不进 stdout 日志**
4. 日志里**没有** `This game comes prepackaged with plugins` 字样
5. 插件功能正常（eraTW 画蛇添足版可测 `CALCULATE`）

> **实测结果（2026-09-28）**：上述 5 条在「删掉 `pluginsAware.txt`」与「保留」两种场景下**各 5/5 通过**。
> 启动数据：`LoadErbDir done: noError=True, labels=112724`；`Process.Initialize OK`；插件加载
> `[plugins] 已加载插件 Math Expansion Plugin v1.0（3 个方法）`。

---

## 四、上游对照原文（供核对）

上游提交 `0abdff83`（2026-05-26，作者 Enter）：

> `fix:pluuginsAwareを参照しなくなった代わりにDLLがあるとログに表示するように`
> （不再参照 pluginsAware，改为在有 DLL 时输出日志）

上游警告文案：

> 注意：外部プラグイン機能が有効になっています。この機能で生じた不具合等はEmueraのサポート対象外となります

上游仓库：<https://gitlab.com/EvilMask/emuera.em>（project id `9043712`）

---

## 五、为什么不直接给 .patch

本仓库的 `port/eratw-EE56-compat.patch` 已经把 `PluginManager.cs` 改了很多
（程序集重定向、目录大小写容错等）。在已打过该补丁的代码上再叠一个 patch，
hunk 会与既有改动交织，`git apply` 的成功率低且难读。

**本文件给出的是逐处代码片段**，配合 `port/eratw-EE56-compat.patch` 一起看即可完整复现。
如果你是从**未打移植补丁**的上游 main 开始，建议直接以本仓库的源码为准。
