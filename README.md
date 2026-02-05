# Emby 插件快速安装指南

本仓库提供了一套用于 Emby Server 的插件集成一键安装方案，涵盖 **Web 端增强**（界面美化、弹幕支持、外部播放器调用）及 **服务端增强**（豆瓣削刮器、字幕下载、消息通知）。

如果您想开发此脚本，请参考[开发文档](DEVELOPMENT.md)。

## 插件概览

| 插件类型 | 插件名称 | 功能描述 | 项目地址 |
| :--- | :--- | :--- | :--- |
| **Web 端** | [界面美化 (emby-crx)](#1-界面美化-emby-crx) | 修改 Web 端皮肤，优化视觉体验 | [Github](https://github.com/Nolovenodie/emby-crx) |
| **Web 端** | [弹幕插件 (dd-danmaku)](#2-弹幕插件-dd-danmaku) | 为 Web 端播放器集成弹幕显示功能 | [Github](https://github.com/chen3861229/dd-danmaku) |
| **Web 端** | [外部播放器调用](#3-外部播放器调用-potplayermpv) | 通过协议调用本地 PotPlayer/MPV 播放器 | [Github](https://github.com/bpking1/embyExternalUrl) |
| **服务端** | [豆瓣削刮器 (Douban)](#4-豆瓣削刮器-douban) | 为 Emby 提供豆瓣元数据削刮功能 | [Github](https://github.com/AlifeLine/Emby.Plugins.Douban) |
| **服务端** | [字幕插件 (Meiam)](#5-字幕插件-meiamsubtitles) | 自动下载迅雷/射手网字幕 | [Github](https://github.com/91270/MeiamSubtitles) |
| **服务端** | [Telegram 通知](#6-telegram-通知-telegramnotification) | 将 Emby 通知推送至 Telegram Bot | [Github](https://github.com/bjoerns1983/Emby.Plugin.TelegramNotification) |

## 快速开始

### 1. 服务端部署
通过本仓库提供的 `install_plugins.sh` 脚本，您可以一键完成所有插件的安装。

#### 安装步骤：
1. **一键执行**:
   - 默认 Web UI 路径: `/system/dashboard-ui` (Emby Docker 默认)
   - 默认 DLL 插件路径: `/config/plugins` (Emby Docker 默认)
   - 安装 DLL 插件后 **必须重启 Emby 服务** 才能生效。

   ```bash
   wget -q https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins.sh -O install_plugins.sh && chmod +x install_plugins.sh && ./install_plugins.sh
   ```

2. **高级选项 (非交互式)**:
   - 指定路径: `./install_plugins.sh --ui-dir /path/to/ui --plugin-dir /path/to/plugins`
   - 国内加速: 使用 `--use-mirror` 参数。
   - 更多选项查看: `./install_plugins.sh --help`

3. 刷新 Emby 网页端（Web 插件）或重启服务（DLL 插件）即可看到效果。
3. 如果您不想使用一键执行脚本安装，可以参考[Emby Web 插件手动安装说明](emby_web_manual_install.md)进行手动安装。DLL插件的安装请参考插件作者仓库中的说明。

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

<<<<<<< Updated upstream
### 4. 豆瓣削刮器 (Douban)
*   **功能**: 为 Emby 提供豆瓣元数据削刮功能，解决电影/电视剧削刮难题。
*   **项目地址**: [AlifeLine/Emby.Plugins.Douban](https://github.com/AlifeLine/Emby.Plugins.Douban)

### 5. 字幕插件 (MeiamSubtitles)
*   **功能**: 自动下载迅雷/射手网字幕，支持多种语言。
*   **项目地址**: [91270/MeiamSubtitles](https://github.com/91270/MeiamSubtitles)

### 6. Telegram 通知 (TelegramNotification)
*   **功能**: 将 Emby 的通知（如新片上线、播放记录等）推送至 Telegram Bot。
*   **项目地址**: [bjoerns1983/Emby.Plugin.TelegramNotification](https://github.com/bjoerns1983/Emby.Plugin.TelegramNotification)
=======
### 4. 界面美化（emby 4.9+ 版本推荐） (Emby Home Swiper)
*   **功能**: 现代化全屏轮播横幅组件，自动展示最新和热门媒体内容。
*   **项目地址**: [sohag1192/Emby-Home-Swiper-UI](https://github.com/sohag1192/Emby-Home-Swiper-UI)
*   **版本要求**: **Emby 4.9.1.80 及以上版本**
>>>>>>> Stashed changes

#### 客户端环境配置（必须）：
要使网页端的“按钮”生效，您的本地电脑必须安装相应的关联程序：

1.  **MPV Player**:
    *   **设置项目**: 桌面端需要使用 [mpv-handler](https://github.com/akiirui/mpv-handler) 进行协议注册。
    *   按照该项目的 README 进行设置，确保 `mpv://` 协议已关联到您的播放器。

2.  **PotPlayer**:
    *   **推荐版本**: 请务必使用 **PotPlayer 官方最新版**。
    *   **字幕支持**: PotPlayer 可以完美调用外挂字幕。如果未在网页端选中特定外挂字幕，播放器默认会尝试加载同目录下的中文外挂字幕。
    *   **注册表关联**: 如果点击调用不生效，通常是注册表关联丢失。**解决方法**: 重新下载安装 PotPlayer 官方最新版安装包进行安装即可修复。

#### 进阶调整（摘自原作者文档）：
*   **外部播放器使用说明**:请参考油猴脚本的详情页面 [embylaunchpotplayer](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)。
*   **解决中文乱码**: 由于目前 PotPlayer 官方版本的问题，影片标题中的中文可能会表现为乱码。这属于播放器本身对 URL 编码的处理问题，需要等待官方后续更新修复。
*   **配置多开**: 默认情况下 PotPlayer 可能是单实例运行。如果需要支持多开，请编辑服务端生成的 `externalPlayer.js` 文件，找到第 186 行左右的 `potplayer://` 启动参数部分，将 `/current` 字符串删除。

---

## 常见问题 (FAQ)

*   **Q: 为什么点击播放器图标没反应？**
    *   A: 99% 的情况是本地没有安装对应的“协议处理器”。对于 MPV 请检查 mpv-handler ；对于 PotPlayer 请直接重置/重装官方最新版。
*   **Q: 安装后 index.html 报错或显示异常？**
    *   A: 脚本会自动备份。您可以重新运行脚本，进入 `3) 备份管理` -> `3) 恢复备份` 选择一个历史版本恢复；或从 UI 目录下的 `.plugin_backups/index.html.original` 手动恢复。
*   **Q: 插件安装后没有效果？**
    *   A: Web 插件（如美化、弹幕）需刷新浏览器页面；服务器端 DLL 插件（如豆瓣削刮、字幕）**必须重启 Emby 服务**。
