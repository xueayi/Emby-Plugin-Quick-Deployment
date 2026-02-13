[English](/docs/emby插件手动安装方法和说明_en.md) | [中文](/docs/emby插件手动安装方法和说明.md)

# UI Beautification Plugin

Project Address:
https://github.com/Nolovenodie/emby-crx

## Step Instructions

1. Enter the `/system/dashboard-ui/` directory in Docker or the installation directory.
2. Enter the following code:
```bash
#!/bin/bash

# Create emby-crx directory and download required files
rm -rf emby-crx
mkdir -p emby-crx
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/common-utils.js -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/md5.min.js -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/content/main.js -P emby-crx/

# Read index.html file content
content=$(cat index.html)

# Check if index.html already contains emby-crx
if grep -q "emby-crx" index.html; then
    echo "Index.html already contains emby-crx, skipping insertion."
else
    # Define code to be inserted
    code='<link rel="stylesheet" id="theme-css" href="emby-crx/style.css" type="text/css" media="all" />\n<script src="emby-crx/common-utils.js"></script>\n<script src="emby-crx/jquery-3.6.0.min.js"></script>\n<script src="emby-crx/md5.min.js"></script>\n<script src="emby-crx/main.js"></script>'

    # Insert code before </head>
    new_content=$(echo -e "${content/<\/head>/$code<\/head>}")

    # Write new content to index.html file
    echo -e "$new_content" > index.html
fi
```
3. Installation completed. No restart required, just refresh the webpage to use.
4. Possible issues: If `wget` script download fails, you can manually visit the project address: https://github.com/Nolovenodie/emby-crx and download the corresponding files (check which files were downloaded after `wget`), then put them into the `emby-crx` folder created by `mkdir`, and manually execute the subsequent commands.
5. Every time there is an update, you can execute the first half of the script completely (deleting original plugin files and downloading new plugin files).

# Danmaku Plugin

Project Address:
https://github.com/chen3861229/dd-danmaku

## Installation Steps

1. Same as above, enter the `/system/dashboard-ui/` directory in Docker or the installation directory.
2. Enter the following code:
```bash
#!/bin/bash

# Create dd-danmaku directory and download ede.js
rm -rf dd-danmaku
mkdir -p dd-danmaku
wget https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/

# Read index.html file content
content=$(cat index.html)

# Check if index.html already contains dd-danmaku
if grep -q "dd-danmaku" index.html; then
    echo "index.html already contains dd-danmaku, skipping insertion."
else
    # Define code to be inserted
    code='<script src="dd-danmaku/ede.js"></script>'

    # Insert code before </head>
    new_content=$(echo "$content" | sed "s|}head>|$code</head>|")

    # Write new content to index.html file
    echo "$new_content" > index.html

    echo "ede.js reference inserted successfully."
fi
```
3. Installation completed.
4. Handling for download failure is the same as above.

# External Player Plugin (MPV/Potplayer)

Project Addresses:
https://github.com/bpking1/embyExternalUrl
https://github.com/akiirui/mpv-handler
https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer

> [!IMPORTANT]
> **Three Core Conditions for External Player Usage:**
> 1. **Server Side**: The Emby server runs JS scripts via the Nginx njs module to add external player links to the external links section of Emby videos, compatible with all official Emby clients. Reference: [embyExternalUrl Native Deployment Scheme](https://github.com/bpking1/embyExternalUrl/blob/main/README.zh-Hans.md)
> 2. **Web UI**: Emby's `index.html` must successfully import the script to render the play button on the frontend. This can be achieved by modifying the server's `index.html` file or using a browser Tampermonkey script on the client side. Reference: [embylaunchpotplayer Tampermonkey Documentation](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)
> 3. **Player Protocol**: The local computer must have the player and its corresponding protocol handler installed (e.g., PotPlayer or mpv-handler). Reference: [mpv-handler Setup Project](https://github.com/akiirui/mpv-handler)

## Manual Installation Steps

1. Enter the `/system/dashboard-ui/` directory in Docker or the installation directory.
2. Download the script and name it `externalPlayer.js`:
   `wget https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js`
3. Modify `index.html`, add the following before `</body>` (recommended below the `apploader.js` script line):
   `<script src="externalPlayer.js" defer></script>`

## Client Environment Configuration (Required)

To make the "buttons" on the web side work, your local computer must have the corresponding association programs installed:

1. **MPV Player**:
    * Need to download and configure [mpv-handler](https://github.com/akiirui/mpv-handler).
    * Follow the README of that project for protocol registration, ensuring the `mpv://` protocol is associated with your player.
2. **PotPlayer**:
    * **Recommended Version**: Please use the **latest official version of PotPlayer**.
    * **Subtitle Support**: PotPlayer can perfectly call external subtitles. If no specific external subtitle is selected in the web UI, the player defaults to loading Chinese external subtitles in the same directory.
    * **Registry Association**: If clicking the call button does not work, it is usually because the registry association is missing. **Solution**: Re-download and install the latest official PotPlayer installer to fix it.

## Advanced Adjustments

* **External Player Usage Instructions**: Please refer to the Tampermonkey script detail page [embylaunchpotplayer](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer).
* **Fixing Chinese Garbled Text**: Due to current issues with the official PotPlayer version (230208), Chinese characters in the movie title may appear garbled. This is an issue with the player's own handling of URL encoding and requires an official update to fix.
* **Multi-instance Configuration**: By default, PotPlayer may run in a single instance. If you need to support multiple instances, please edit the `externalPlayer.js` file generated on the server, find the `potplayer://` startup parameter section around line 186, and delete the `/current` string.

---

# One-click Installation Integration Script (Recommended)

If you want to install all the above plugins (Beautification + Danmaku + External Player) at once, you can use the following script:

```bash
#!/bin/sh
# 1. Environment Verification
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "Error: Emby UI directory not found ($UI_DIR). Please ensure the script is running on the server."
    exit 1
fi
cd "$UI_DIR" || exit

# 2. Interactive Selection
echo -e "Select: 1.All 2.Beautification 3.Danmaku 4.External Player U.Uninstall Q.Quit"
read -p "Option: " choices

# Handle Uninstallation
if [ "$choices" = "U" ] || [ "$choices" = "u" ]; then
    sed -i '/emby-crx/d; /dd-danmaku/d; /externalPlayer.js/d; /Emby Plugins/d' index.html
    rm -rf emby-crx dd-danmaku externalPlayer.js
    echo "Plugins uninstalled cleanly. If the webpage is abnormal, please manually execute: mv index.html.bak index.html"
    exit 0
fi

# 3. Handle Installation Logic (Multiple Selections)
INSTALL_CRX=false; INSTALL_DANMAKU=false; INSTALL_PLAYER=false
echo "$choices" | grep -q "1" && { INSTALL_CRX=true; INSTALL_DANMAKU=true; INSTALL_PLAYER=true; }
echo "$choices" | grep -q "2" && INSTALL_CRX=true
echo "$choices" | grep -q "3" && INSTALL_DANMAKU=true
echo "$choices" | grep -q "4" && INSTALL_PLAYER=true

# 4. Backup and Cleanup
[ ! -f index.html.bak ] && cp index.html index.html.bak
sed -i '/emby-crx/d; /dd-danmaku/d; /externalPlayer.js/d; /Emby Plugins/d' index.html

# 5. Download and Secure Injection (Step-by-step injection for compatibility)
if [ "$INSTALL_CRX" = true ]; then
    rm -rf emby-crx && mkdir -p emby-crx
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
    # ... (Omitted other download commands)
    sed -i '/<\/head>/i <!-- Emby Plugins Start -->' index.html
    sed -i '/<\/head>/i <link rel="stylesheet" href="emby-crx/style.css" />' index.html
    sed -i '/<\/head>/i <script src="emby-crx/main.js"></script>' index.html
fi

if [ "$INSTALL_DANMAKU" = true ]; then
    wget -q https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/
    sed -i '/<\/head>/i <script src="dd-danmaku/ede.js"></script>' index.html
fi

if [ "$INSTALL_PLAYER" = true ]; then
    wget -q https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js
    sed -i '/apploader.js/a <script src="externalPlayer.js" defer></script>' index.html
fi
sed -i '/<\/body>/i <!-- Emby Plugins End -->' index.html

echo "Operation completed!"
```

> [!TIP]
> The scripts in the document only show the core logic. It is recommended to download the full `install_plugins.sh` from this repository for complete error handling and backup strategies.

# Appendix
If necessary, you can also manually enter the `index.html` file to modify the plugin insertion lines, such as `<script src="dd-danmaku/ede.js"></script>`.
