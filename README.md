# Emby 插件快速安装指南

[English](/docs/README_EN.md) | [中文](/README.md)

本仓库提供了一套用于 Emby Server Web 端的插件集成一键安装方案，包括界面美化、弹幕支持以及外部播放器（PotPlayer/MPV）调用功能。这些功能实现来自于开源社区其他朋友的贡献，项目地址已附在下方对应位置。

![主界面](/image/main.png)

## 快速开始

### 1. 服务端部署
通过本仓库提供的 `install_plugins` 脚本，您可以一键完成所有插件的安装。

#### 安装步骤：
1. **Docker / Linux**:
- 如果使用docker部署的emby，推荐在进入emby的docker终端环境后在其根目录执行。如需设置其他路径下的安装，请在脚本启动后配置路径。

- 中文安装命令（Chinese installation command）
   ```bash
   wget -q https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins.sh -O install_plugins.sh && chmod +x install_plugins.sh && ./install_plugins.sh
   ```

- 英文安装命令（English installation command）
   ```bash
   wget -q https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins_en.sh -O install_plugins_en.sh && chmod +x install_plugins_en.sh && ./install_plugins_en.sh
   ```

2. **Windows (PowerShell)**:
- 如果您的Emby运行在Windows上，请确保Emby Server已停止运行后再运行此脚本，避免文件被锁定。如需设置其他路径下的安装，请在脚本启动后配置路径。

- 中文安装命令（Chinese installation command）
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins.ps1" -OutFile "install_plugins.ps1"
   powershell -ExecutionPolicy Bypass -File install_plugins.ps1
   ```

- 英文安装命令（English installation command）
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins_en.ps1" -OutFile "install_plugins_en.ps1"
   powershell -ExecutionPolicy Bypass -File install_plugins_en.ps1
   ```

- 安装后刷新 Emby 网页端即可看到效果。

1. 安装插件后刷新 Emby 网页端即可看到效果。
2. 如果您不想使用一键执行脚本安装，可以参考[emby插件手动安装方法和说明.md](/docs/emby插件手动安装方法和说明.md)进行手动安装

> [!WARNING]
> **插件互斥说明：**
> - **界面美化 (emby-crx)** 和 **首页轮播 (Emby Home Swiper)** 两个插件存在功能冲突
> - **建议只安装其中一个**，避免出现样式错乱或功能异常
> - Emby 4.8 及以下版本推荐使用 **界面美化 (emby-crx)**
> - Emby 4.9+ 版本推荐使用 **首页轮播 (Emby Home Swiper)**

> [!IMPORTANT]
> **外部播放器正常使用的三个核心条件：**
> 1. **后端（Server Side）**: emby服务器通过nginx的njs模块运行js脚本，在emby视频的外部链接处添加调用外部播放器链接，所有emby官方客户端可用。参考：[embyExternalUrl 原生部署方案](https://github.com/bpking1/embyExternalUrl/blob/main/README.zh-Hans.md)
> 2. **前端（Web UI）**: Emby 的 `index.html` 必须成功引入脚本并在前端渲染播放按钮。可以通过修改服务器的 `index.html` 文件或者客户端使用浏览器油猴脚本两种方式实现。参考：[embylaunchpotplayer 油猴文档](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)
> 3. **播放协议（Player Protocol）**: 本地电脑必须安装播放器及其对应的协议处理器（如 PotPlayer 或 mpv-handler）。参考：[mpv-handler 设置项目](https://github.com/akiirui/mpv-handler)

---

## 插件说明

### 1. 界面美化 (emby-crx)
*   **功能**: 修改 Web 端皮肤，优化视觉体验。
*   **项目地址**: [Nolovenodie/emby-crx](https://github.com/Nolovenodie/emby-crx)

### 2. 弹幕插件 (dd-danmaku)
*   **功能**: 为 Web 端播放器集成弹幕显示功能。
*   **项目地址**: [chen3861229/dd-danmaku](https://github.com/chen3861229/dd-danmaku)

### 3. 外部播放器调用 (PotPlayer/MPV)
*   **功能**: 通过协议调用本地播放器，实现从浏览器一键唤起本地的高性能播放器。
*   **项目地址**: [bpking1/embyExternalUrl](https://github.com/bpking1/embyExternalUrl)

### 4. 首页轮播（emby 4.9+ 版本推荐） (Emby Home Swiper)
*   **功能**: 现代化全屏轮播横幅组件，自动展示最新和热门媒体内容。
*   **项目地址**: [sohag1192/Emby-Home-Swiper-UI](https://github.com/sohag1192/Emby-Home-Swiper-UI)
*   **版本要求**: **Emby 4.9.1.80 和 Emby 4.8.11.0 已测试通过**
*   **注意事项**: 本插件安装后服务器的网页标题会被替换成`SN FTP SERVER`，若想改回原标题，需要手动注释安装到本地的`home.js`文件中的`Emby.Page.setTitle("SN FTP SERVER");`这两行代码。

#### 客户端环境配置（必须）：
要使网页端的“按钮”生效，您的本地电脑必须安装相应的关联程序：

1.  **MPV Player**:
    *   **设置项目**: 桌面端需要使用 [mpv-handler](https://github.com/akiirui/mpv-handler) 进行协议注册。
    *   按照该项目的 README 进行设置，确保 `mpv://` 协议已关联到您的播放器。

2.  **PotPlayer**:
    *   **推荐版本**: 请务必使用 **PotPlayer 官方最新版**。
    *   **字幕支持**: PotPlayer 可以完美调用外挂字幕。如果未在网页端选中特定外挂字幕，播放器默认会尝试加载同目录下的中文外挂字幕。
    *   **注册表关联**: 如果点击调用不生效，通常是注册表关联丢失。**解决方法**: 重新下载安装 PotPlayer 官方最新版安装包进行安装即可修复。

#### 注意事项：
*   **外部播放器使用说明**:请参考油猴脚本的详情页面 [embylaunchpotplayer](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)。
*   **解决中文乱码**: 由于目前 PotPlayer 官方版本的问题，影片标题中的中文可能会表现为乱码。这属于播放器本身对 URL 编码的处理问题，需要等待官方后续更新修复。
*   **配置多开**: 默认情况下 PotPlayer 可能是单实例运行。如果需要支持多开，请编辑服务端生成的 `externalPlayer.js` 文件，找到第 186 行左右的 `potplayer://` 启动参数部分，将 `/current` 字符串删除。

---

## 常见问题 (FAQ)

*   **Q: 界面美化和首页轮播可以同时安装吗？**
    *   A: **不建议同时安装**。这两个插件都会修改首页布局，同时使用可能导致样式冲突或功能异常。建议根据 Emby 版本选择：Emby 4.8 及以下使用界面美化，Emby 4.9+ 使用首页轮播。
*   **Q: 为什么点击播放器图标没反应？**
    *   A: 99% 的情况是本地没有安装对应的“协议处理器”。对于 MPV 请检查 mpv-handler ；对于 PotPlayer 请直接重置/重装官方最新版。
*   **Q: 安装后 index.html 报错或显示异常？**
    *   A: 脚本会自动备份。您可以重新运行脚本，进入 `3) 备份管理` -> `3) 恢复备份` 选择一个历史版本恢复；或从 UI 目录下的 `.plugin_backups/index.html.original` 手动恢复。
