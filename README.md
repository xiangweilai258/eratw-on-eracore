# EraRelay

**在手机或平板上玩 eraTW（蛇版）。**

EraRelay 是一款基于 [era-core](https://github.com/LaoBro/era-core) 开发的 era 游戏运行工具。目前主要适配 Android 上的 eraTW 画蛇添足版，提供触屏操作、画面显示和游戏目录选择。

应用不附带游戏，请自行准备游戏文件。

**[下载安装包](https://github.com/xiangweilai258/eratw-on-eracore/releases/latest)** · [使用说明](https://github.com/xiangweilai258/eratw-on-eracore/blob/main/docs/02-使用说明.md) · [反馈问题](https://github.com/xiangweilai258/eratw-on-eracore/issues)

## 开始游玩

1. 下载并安装 Android 安装包，目前提供 arm64 版本。
2. 将游戏完整解压到设备上，保留原有目录结构。可以按下面的方式摆放，`emuera` 只是示例名称：

   ```text
   emuera/              ← 在应用中选择这一层
   └─ 你的游戏/
      ├─ ERB/
      └─ CSV/
   ```

3. 打开 EraRelay，跟随应用内引导完成目录访问设置，选择装着游戏文件夹的父目录并扫描。
4. 在游戏列表中点选游戏，开始游玩。

**更新应用或尝试新游戏前，建议先备份重要存档。**

## 用起来有什么不同

- **直接在触屏上操作**：通过画面选项与输入栏推进游戏，无需连接实体键盘。
- **适合横屏游玩**：支持方向锁定，方便在手机和平板上阅读游戏画面。
- **不容易漏掉选项**：为部分深色背景上的暗色选项增加提示底衬，让触屏操作时更容易找到可点的位置。
- **保留蛇版的画面内容**：已适配背景图片及部分扩展显示与输入指令，兼容效果以实际游戏版本为准。

## 目前适合谁

目前主要围绕 **eraTW 画蛇添足版（蛇版）** 进行适配与测试。想在 Android 手机上或平板上玩蛇版，可以先从这里开始尝试。

其他 era 游戏尚未充分验证，不能保证都能运行。项目仍在持续完善，遇到画面、输入或兼容问题，欢迎反馈。

找不到游戏或无法启动时，请先查看应用内引导与疑难解答；如果界面未能加载，请按屏幕上的提示处理。仍有问题，可以通过下方渠道反馈。

## 版本更新

当前正式版：**v0.5.7**。修复连续「点任意处 / 按回车继续」等画面输入完成后仍可能额外等待约 30 秒的问题（0.5.5 / 0.5.6 受影响，建议更新）；改善部分资源文件名 Unicode 写法不一致导致的图片无法读取。遇问题欢迎反馈。

[查看当前版本与更新说明](https://github.com/xiangweilai258/eratw-on-eracore/releases/latest)

## 后续方向

除了继续改善游玩体验，我们也希望探索 **AI 辅助游玩**，让 AI 能够理解游戏画面，并协助玩家操作。

目前仍处于底层能力探索阶段，**尚未提供开箱即用的 AI 陪玩功能**。

## 反馈问题

请在 [Issues](https://github.com/xiangweilai258/eratw-on-eracore/issues) 中反馈（需要 GitHub 账号），说明：

- 使用的应用版本、设备型号和 Android 版本；
- 游戏名称与版本，以及遇到问题前做了什么；
- 实际出现的情况，方便的话附一张截图。

提交前请遮盖截图或日志中的私人信息。不要公开上传存档、完整游戏文件、账户信息或密钥。

## 来源与致谢

EraRelay 基于 [LaoBro/era-core](https://github.com/LaoBro/era-core) 开发，源自 Emuera 的开源传承。我们做的是移植、兼容适配与游玩体验改进，感谢上游作者及社区的工作。

本项目不包含、不分发游戏内容。游戏版权归各自作者所有。

[授权与致谢](https://github.com/xiangweilai258/eratw-on-eracore/blob/main/LICENSE-NOTICE.md) · [技术与构建文档](https://github.com/xiangweilai258/eratw-on-eracore/tree/main/docs)

## 特别致谢

特别感谢我的姐姐 Crystal。她未必理解 ERA 游戏意味着什么，也从未问过 WebView 到底渲染了什么，但她始终相信我在做的这件事有意义。开源在上一代人眼中或许是“赚钱”的反面；而在她眼里，那不过是我需要支持时，她恰好站在我身边的理由。若你在某个深夜享受着新引擎驱动的 eraTW，请记得，这引擎背后，还有一位姐姐无私的信任。

Thanks to my sister, for always being there.
