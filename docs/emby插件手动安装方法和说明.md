[English](/docs/emby插件手动安装方法和说明_en.md) | [中文](/docs/emby插件手动安装方法和说明.md)

# 美化插件

项目地址：
https://github.com/Nolovenodie/emby-crx

## 步骤说明

1. 进入docker或安装目录中的/system/dashboard-ui/目录
2. 输入以下代码
```
#!/bin/bash

# 创建emby-crx目录并下载所需文件
rm -rf emby-crx
mkdir -p emby-crx
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/common-utils.js -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/md5.min.js -P emby-crx/
wget https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/content/main.js -P emby-crx/

# 读取index.html文件内容
content=$(cat index.html)

# 检查index.html是否包含emby-crx
if grep -q "emby-crx" index.html; then
    echo "Index.html already contains emby-crx, skipping insertion."
else
    # 定义要插入的代码
    code='<link rel="stylesheet" id="theme-css" href="emby-crx/style.css" type="text/css" media="all" />\n<script src="emby-crx/common-utils.js"></script>\n<script src="emby-crx/jquery-3.6.0.min.js"></script>\n<script src="emby-crx/md5.min.js"></script>\n<script src="emby-crx/main.js"></script>'

    # 在</head>之前插入代码
    new_content=$(echo -e "${content/<\/head>/$code<\/head>}")

    # 将新内容写入index.html文件
    echo -e "$new_content" > index.html
fi
```
3. 完成安装，不用重启，刷新网页即可使用
4. 可能遇到的问题：wget下载脚本失败，可以手动进入项目地址：https://github.com/Nolovenodie/emby-crx下载对应文件（看下wget后面下载了哪些文件），然后放到刚才mkdir创建的emby-crx文件夹下，然后手动执行下载后的命令
5. 每次有更新可以完整手动执行前半部分脚本（删除原有插件文件，下载新的插件文件这部分）

# 弹幕插件

项目地址：
https://github.com/chen3861229/dd-danmaku

## 安装步骤

1. 同上，进入docker or 安装目录中的/system/dashboard-ui/目录
2. 输入以下代码
```
#!/bin/bash

# 创建dd-danmaku目录并下载ede.js
rm -rf dd-danmaku
mkdir -p dd-danmaku
wget https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/

# 读取index.html文件内容
content=$(cat index.html)

# 检查index.html是否包含dd-danmaku
if grep -q "dd-danmaku" index.html; then
    echo "index.html already contains dd-danmaku, skipping insertion."
else
    # 定义要插入的代码
    code='<script src="dd-danmaku/ede.js"></script>'

    # 在</head>之前插入代码
    new_content=$(echo "$content" | sed "s|</head>|$code</head>|")

    # 将新内容写入index.html文件
    echo "$new_content" > index.html

    echo "ede.js reference inserted successfully."
fi
```
3. 安装完成
4. 下载失败的处理方式同上

# 外部播放器插件 (MPV/Potplayer)

项目地址：
https://github.com/bpking1/embyExternalUrl
https://github.com/akiirui/mpv-handler
https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer

> [!IMPORTANT]
> **外部播放器正常使用的三个核心条件：**
> 1. **后端（Server Side）**: emby服务器通过nginx的njs模块运行js脚本，在emby视频的外部链接处添加调用外部播放器链接，所有emby官方客户端可用。参考：[embyExternalUrl 原生部署方案](https://github.com/bpking1/embyExternalUrl/blob/main/README.zh-Hans.md)
> 2. **前端（Web UI）**: Emby 的 `index.html` 必须成功引入脚本并在前端渲染播放按钮。可以通过修改服务器的 `index.html` 文件或者客户端使用浏览器油猴脚本两种方式实现。参考：[embylaunchpotplayer 油猴文档](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)
> 3. **播放协议（Player Protocol）**: 本地电脑必须安装播放器及其对应的协议处理器（如 PotPlayer 或 mpv-handler）。参考：[mpv-handler 设置项目](https://github.com/akiirui/mpv-handler)

## 手动安装步骤

1. 进入docker或安装目录中的/system/dashboard-ui/目录
2. 下载脚本并命名为 `externalPlayer.js`：
   `wget https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js`
3. 修改 `index.html`，在 `</body>` 之前（推荐在 `apploader.js` 脚本行下方）添加：
   `<script src="externalPlayer.js" defer></script>`

## 客户端环境配置 (必须)

要使网页端的“按钮”生效，您的本地电脑必须安装相应的关联程序：

1. **MPV Player**:
    * 需要下载并配置 [mpv-handler](https://github.com/akiirui/mpv-handler)。
    * 按照该项目的 README 进行协议注册，确保 `mpv://` 协议已关联到您的播放器。
2. **PotPlayer**:
    * **推荐版本**: 请务必使用 **PotPlayer 官方最新版**。
    * **字幕支持**: PotPlayer 可以完美调用外挂字幕。如果未在网页端选中特定外挂字幕，播放器默认会尝试加载同目录下的中文外挂字幕。
    * **注册表关联**: 如果点击调用不生效，通常是注册表关联丢失。**解决方法**: 重新下载安装 PotPlayer 官方最新版安装包进行安装即可修复。

## 进阶调整

* **外部播放器使用说明**: 请参考油猴脚本的详情页面 [embylaunchpotplayer](https://greasyfork.org/zh-CN/scripts/514529-embylaunchpotplayer)。
* **解决中文乱码**: 由于目前 PotPlayer 官方版本（230208）的问题，影片标题中的中文可能会表现为乱码。这属于播放器本身对 URL 编码的处理问题，需要等待官方后续更新修复。
* **配置多开**: 默认情况下 PotPlayer 可能是单实例运行。如果需要支持多开，请编辑服务端生成的 `externalPlayer.js` 文件，找到第 186 行左右的 `potplayer://` 启动参数部分，将 `/current` 字符串删除。

---

# 一键安装集成脚本 (推荐)

如果你想一次性安装以上所有插件（美化+弹幕+外部播放器），可以使用以下脚本：

```bash
# 一键安装集成脚本 (推荐)

如果你想通过菜单选择性安装插件（美化、弹幕、外部播放器），可以使用以下脚本：

```bash
#!/bin/sh
# 1. 环境校验
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "错误: 未找到 Emby UI 目录 ($UI_DIR)。请确保脚本在服务器上运行。"
    exit 1
fi
cd "$UI_DIR" || exit

# 一键安装集成脚本 (推荐)

如果你想通过菜单选择性安装插件（美化、弹幕、外部播放器），可以使用以下脚本（V2.2 稳定版）：

```bash
#!/bin/sh
# 1. 环境校验
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "错误: 未找到 Emby UI 目录 ($UI_DIR)。"
    exit 1
fi
cd "$UI_DIR" || exit

# 2. 交互选择
echo -e "选择: 1.全部 2.美化 3.弹幕 4.外部播放器 U.卸载 Q.退出"
read -p "选项: " choices

# 处理卸载
if [ "$choices" = "U" ] || [ "$choices" = "u" ]; then
    sed -i '/emby-crx/d; /dd-danmaku/d; /externalPlayer.js/d; /Emby Plugins/d' index.html
    rm -rf emby-crx dd-danmaku externalPlayer.js
    echo "插件已干净卸载。如网页异常，请手动执行 mv index.html.bak index.html"
    exit 0
fi

# 3. 处理安装逻辑 (多项选择)
INSTALL_CRX=false; INSTALL_DANMAKU=false; INSTALL_PLAYER=false
echo "$choices" | grep -q "1" && { INSTALL_CRX=true; INSTALL_DANMAKU=true; INSTALL_PLAYER=true; }
echo "$choices" | grep -q "2" && INSTALL_CRX=true
echo "$choices" | grep -q "3" && INSTALL_DANMAKU=true
echo "$choices" | grep -q "4" && INSTALL_PLAYER=true

# 4. 备份与清理
[ ! -f index.html.bak ] && cp index.html index.html.bak
sed -i '/emby-crx/d; /dd-danmaku/d; /externalPlayer.js/d; /Emby Plugins/d' index.html

# 5. 下载并安全注入 (分步注入以提高兼容性)
if [ "$INSTALL_CRX" = true ]; then
    rm -rf emby-crx && mkdir -p emby-crx
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
    # ... (省略其他下载命令)
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

echo "操作完成！"
```
```

> [!TIP]
> 文档中的脚本仅展示核心逻辑，建议直接下载本仓库完整的 `install_plugins.sh` 以获得完整的错误处理和备份策略。
```

# 附
必要的时候也可以手动进入index.html文件修改插入插件行，如<script src="dd-danmaku/ede.js"></script>这种脚本内容