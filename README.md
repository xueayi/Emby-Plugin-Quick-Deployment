# Emby 插件快速安装指南

本仓库提供了一套用于 Emby Server Web 端的插件集成一键安装方案，包括界面美化、弹幕支持以及外部播放器（PotPlayer/MPV）调用功能。这些功能实现来自于开源社区其他朋友的贡献，项目地址已附在下方对应位置。

## 快速开始

### 1. 服务端部署
通过本仓库提供的 `install_plugins.sh` 脚本，您可以一键完成所有插件的安装。

#### 安装步骤：
1. **一键执行**:
- 默认在emby docker根目录路径下执行（默认index.html在docker中的绝对路径是`/system/dashboard-ui`），如需设置其他路径下的安装，请参考下方手动部署进行安装。
- 安装后刷新 Emby 网页端即可看到效果。

   ```bash
   wget -q https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins.sh -O install_plugins.sh && chmod +x install_plugins.sh && ./install_plugins.sh
   ```

1. **更改脚本执行目录**:
   * 将 `install_plugins.sh` 上传到 Emby 服务器。
   * 修改脚本中的 `UI_DIR` 路径（默认index.html的路径为 `/system/dashboard-ui`）。
   * 执行脚本：`chmod +x install_plugins.sh && ./install_plugins.sh`
2. 刷新 Emby 网页端即可看到效果。
3. 如果您不想使用一键执行脚本安装，可以参考[emby插件手动安装方法和说明.md](emby插件手动安装方法和说明.md)进行手动安装

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

#### 客户端环境配置（必须）：
要使网页端的“按钮”生效，您的本地电脑必须安装相应的关联程序：

1.  **MPV Player**:
    *   **设置项目**: 桌面端需要使用 [mpv-handler](https://github.com/akiirui/mpv-handler) 进行协议注册。
    *   按照该项目的 README 进行设置，确保 `mpv://` 协议已关联到您的播放器。

2.  **PotPlayer**:
    *   **推荐版本**: 请务必使用 **PotPlayer 官方最新版**。
    *   **字幕支持**: PotPlayer 可以完美调用外挂字幕。如果未在网页端选中特定外挂字幕，播放器默认会尝试加载同目录下的中文外挂字幕。
    *   **注册表关联**: 如果点击调用不生效，通常是注册表关联丢失。**解决方法**: 重新下载安装 PotPlayer 官方最新版安装包进行安装即可修复。

#### 进阶调整：
*   **外部播放器使用说明**:请参考油猴脚本的详情页面 [embylaunchpotplayer](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)。
*   **解决中文乱码**: 由于目前 PotPlayer 官方版本（230208）的问题，影片标题中的中文可能会表现为乱码。这属于播放器本身对 URL 编码的处理问题，需要等待官方后续更新修复。
*   **配置多开**: 默认情况下 PotPlayer 可能是单实例运行。如果需要支持多开，请编辑服务端生成的 `externalPlayer.js` 文件，找到第 186 行左右的 `potplayer://` 启动参数部分，将 `/current` 字符串删除。

---

## 常见问题 (FAQ)

*   **Q: 为什么点击播放器图标没反应？**
    *   A: 99% 的情况是本地没有安装对应的“协议处理器”。对于 MPV 请检查 mpv-handler ；对于 PotPlayer 请直接重置/重装官方最新版。
*   **Q: 安装后 index.html 报错或显示异常？**
    *   A: 脚本在修改前已创建 `index.html.bak`。您可以执行 `mv index.html.bak index.html` 恢复初始状态。
