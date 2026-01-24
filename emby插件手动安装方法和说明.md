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

## 安装步骤

1. 进入docker或安装目录中的/system/dashboard-ui/目录
2. 下载脚本并命名为 `externalPlayer.js`：
   `wget https://update.greasyfork.org/scripts/514529/embyLaunchPotplayer.user.js -O externalPlayer.js`
3. 修改 `index.html`，在 `</body>` 之前（推荐在 `apploader.js` 脚本行下方）添加：
   `<script src="externalPlayer.js" defer></script>`

---

# 一键安装集成脚本 (推荐)

如果你想一次性安装以上所有插件（美化+弹幕+外部播放器），可以使用以下脚本：

```bash
#!/bin/bash
# 1. 环境校验
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "错误: 未找到 Emby UI 目录 ($UI_DIR)。请确保脚本在 Emby 服务器上运行或检查路径配置是否正确。"
    exit 1
fi

cd "$UI_DIR" || exit

# 2. 下载并解压/创建插件文件
# 美化插件
rm -rf emby-crx && mkdir -p emby-crx
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/common-utils.js -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/md5.min.js -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/content/main.js -P emby-crx/

# 弹幕插件
rm -rf dd-danmaku && mkdir -p dd-danmaku
wget -q https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/

# 外部播放器
wget -q https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js

# 2. 修改 index.html
# 备份
if [ -f "index.html.bak" ]; then
    echo -e "检测到备份文件 index.html.bak 已存在。请选择操作："
    echo -e "  [O] Overwrite (覆盖备份)"
    echo -e "  [C] Continue (直接运行)"
    echo -e "  [Q] Quit (退出)"
    read -p "您的选择 [O/C/Q]: " action
    case $action in
        [Oo] ) cp index.html index.html.bak ;;
        [Cc] ) ;;
        [Qq] ) exit 0 ;;
        * ) exit 1 ;;
    esac
else
    cp index.html index.html.bak
fi

# 移除旧的注入，确保幂等性
# 1. 移除带注释标记的区块
sed -i '/<!-- Emby Plugins Start -->/,/<!-- Emby Plugins End -->/d' index.html
# 2. 移除可能存在的“裸”标签 (兼容旧脚本或手动注入)
sed -i 's|<link[^>]*emby-crx/[^>]*>||g' index.html
sed -i 's|<script[^>]*emby-crx/[^>]*></script>||g' index.html
sed -i 's|<script[^>]*dd-danmaku/[^>]*></script>||g' index.html
sed -i 's|<script[^>]*externalPlayer\.js[^>]*></script>||g' index.html

HEAD_CODE='<!-- Emby Plugins Start -->\n<link rel="stylesheet" id="theme-css" href="emby-crx/style.css" type="text/css" media="all" />\n<script src="emby-crx/common-utils.js"></script>\n<script src="emby-crx/jquery-3.6.0.min.js"></script>\n<script src="emby-crx/md5.min.js"></script>\n<script src="emby-crx/main.js"></script>\n<script src="dd-danmaku/ede.js"></script>'
sed -i "s|</head>|$HEAD_CODE\n</head>|" index.html

BODY_CODE='<script src="externalPlayer.js" defer></script>\n<!-- Emby Plugins End -->'
if grep -q "apploader.js" index.html; then
    sed -i "/apploader.js/a $BODY_CODE" index.html
else
    sed -i "s|</body>|$BODY_CODE\n</body>|" index.html
fi

echo "所有插件安装完成！"
```

# 附
必要的时候也可以手动进入index.html文件修改插入插件行，如<script src="dd-danmaku/ede.js"></script>这种脚本内容