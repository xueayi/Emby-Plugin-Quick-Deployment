# Emby Plugin Quick Installation Guide

[English](/docs/README_EN.md) | [中文](/README.md)

This repository provides a one-click installation solution for integrating plugins into the Emby Server Web UI, including UI beautification, danmaku support, and external player (PotPlayer/MPV) calling features. These implementations are based on contributions from the open-source community, and the project addresses are listed in their respective sections below.

![Main Interface](/image/main.png)

## Quick Start

### 1. Server-side Deployment
Using the `install_plugins_en` script provided in this repository, you can complete the installation of all plugins with a single click.

#### Installation Steps:
1. **Docker / Linux**:
- If you are using Docker to deploy Emby, it is recommended to execute the script in the root directory after entering the Emby Docker terminal environment. If you need to set up installation in other paths, please configure the path after the script starts.

- English installation command
   ```bash
   wget -q https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins_en.sh -O install_plugins_en.sh && chmod +x install_plugins_en.sh && ./install_plugins_en.sh
   ```

- Chinese installation command
   ```bash
   wget -q https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins.sh -O install_plugins.sh && chmod +x install_plugins.sh && ./install_plugins.sh
   ```


2. **Windows (PowerShell)**:
- If your Emby is running on Windows, please stop Emby Server before running this script to avoid file locking. If you need to set up installation in other paths, please configure the path after the script starts.

- English installation command
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins_en.ps1" -OutFile "install_plugins_en.ps1"
   powershell -ExecutionPolicy Bypass -File install_plugins_en.ps1
   ```

- Chinese installation command
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xueayi/Emby-Plugin-Quick-Deployment/refs/heads/master/install_plugins.ps1" -OutFile "install_plugins.ps1"
   powershell -ExecutionPolicy Bypass -File install_plugins.ps1
   ```

- Refresh the Emby web UI after installation to see the effects.

1. Refresh the Emby web UI after installation to see the effects.
2. If you do not want to use the one-click script, you can refer to [emby插件手动安装方法和说明_en.md](/docs/emby插件手动安装方法和说明_en.md) for manual installation instructions.

> [!WARNING]
> **Plugin Mutual Exclusion Notice:**
> - **UI Beautification (emby-crx)** and **Home Swiper (Emby Home Swiper)** have functional conflicts.
> - **It is recommended to install only one of them** to avoid style issues or functional abnormalities.
> - For Emby 4.8 and below, **UI Beautification (emby-crx)** is recommended.
> - For Emby 4.9+ versions, **Home Swiper (Emby Home Swiper)** is recommended.

> [!IMPORTANT]
> **Two Core Conditions for External Player Usage:**
> 1. **Web UI**: Emby's `index.html` must successfully import the script to render the play button on the frontend. This can be achieved by modifying the server's `index.html` file or using a browser Tampermonkey script on the client side. Reference: [embylaunchpotplayer Tampermonkey Documentation](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)
> 2. **Player Protocol**: The local computer must have the player and its corresponding protocol handler installed (e.g., PotPlayer or mpv-handler). Reference: [mpv-handler Setup Project](https://github.com/akiirui/mpv-handler)

---

## Plugin Descriptions

### 1. UI Beautification (emby-crx)
*   **Feature**: Modifies the Web UI skin to optimize the visual experience.
*   **Project Address**: [Nolovenodie/emby-crx](https://github.com/Nolovenodie/emby-crx)

### 2. Danmaku Plugin (dd-danmaku)
*   **Feature**: Integrates danmaku display functionality into the Web player.
*   **Project Address**: [chen3861229/dd-danmaku](https://github.com/chen3861229/dd-danmaku)

### 3. External Player Integration (PotPlayer/MPV)
*   **Feature**: Calls local players via protocol to awaken high-performance local players from the browser with one click.
*   **Project Address**: [bpking1/embyExternalUrl](https://github.com/bpking1/embyExternalUrl)

### 4. Home Swiper (Recommended for Emby 4.9+) (Emby Home Swiper)
*   **Feature**: A modern full-screen carousel banner component that automatically displays latest and popular media content.
*   **Project Address**: [sohag1192/Emby-Home-Swiper-UI](https://github.com/sohag1192/Emby-Home-Swiper-UI)
*   **Version Requirements**: **Tested successfully on Emby 4.9.1.80 and Emby 4.8.11.0** (this script now installs the V2 build by default; empirically verified working on Emby 4.9.0.42 as well)
*   **Note**: Older builds of `home.js` hardcoded the server webpage title to `SN FTP SERVER`. This has been fixed upstream via a [PR](https://github.com/sohag1192/Emby-Home-Swiper-UI/pulls?q=is%3Apr+title+respect+server+name) (current upstream v1/v2 files no longer replace the title), so the latest files pulled by this script are not affected — no manual code commenting needed.

#### Client Environment Configuration (Required):
To make the "buttons" on the web side work, your local computer must have the corresponding association programs installed:

1.  **MPV Player**:
    *   **Setup Project**: Desktop systems need to use [mpv-handler](https://github.com/akiirui/mpv-handler) for protocol registration.
    *   Follow the README of that project to set it up, ensuring the `mpv://` protocol is associated with your player.

2.  **PotPlayer**:
    *   **Recommended Version**: Please use the **latest official version of PotPlayer**.
    *   **Subtitle Support**: PotPlayer can perfectly call external subtitles. If no specific external subtitle is selected in the web UI, the player defaults to loading Chinese external subtitles in the same directory.
    *   **Registry Association**: If clicking the call button does not work, it is usually because the registry association is missing. **Solution**: Re-download and install the latest official PotPlayer installer to fix it.

#### Notes:
*   **External Player Usage Instructions**: Please refer to the Tampermonkey script detail page [embylaunchpotplayer](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer).
*   **Fixing Chinese Garbled Text**: Due to current issues with the official PotPlayer version, Chinese characters in the movie title may appear garbled. This is an issue with the player's own handling of URL encoding and requires an official update to fix.
*   **Multi-instance Configuration**: By default, PotPlayer may run in a single instance. If you need to support multiple instances, please edit the `externalPlayer.js` file generated on the server, find the `potplayer://` startup parameter section around line 186, and delete the `/current` string.

---

## FAQ

*   **Q: Can UI Beautification and Home Swiper be installed at the same time?**
    *   A: **Not recommended**. Both plugins modify the homepage layout, and using them together may lead to style conflicts or functional abnormalities. It is recommended to choose based on your Emby version: UI Beautification for Emby 4.8 and below, Home Swiper for Emby 4.9+.
*   **Q: Why is there no response when clicking the player icon?**
    *   A: In 99% of cases, it's because the "protocol handler" is not installed locally. For MPV, please check mpv-handler; for PotPlayer, please reset/reinstall the latest official version.
*   **Q: index.html error or display abnormality after installation?**
    *   A: The script automatically creates backups. You can rerun the script, enter `3) Backup Management` -> `3) Restore Backup` and select a historical version to restore; or manually restore from `.plugin_backups/index.html.original` in the UI directory.
