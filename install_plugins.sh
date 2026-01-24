#!/bin/bash

# ==============================================================================
# Emby 插件一键安装脚本 (V1.0)
# 功能：集成美化插件、弹幕插件、MPV/Potplayer 调用插件
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}开始安装 Emby 插件...${NC}"

# 1. 环境校验
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "${RED}错误: 未找到 Emby UI 目录 ($UI_DIR)。请确保脚本在 Emby 服务器上运行或检查路径配置是否正确。${NC}"
    exit 1
fi

cd "$UI_DIR" || exit

# 2. 安装美化插件 (emby-crx)
echo -e "${GREEN}正在安装美化插件 (emby-crx)...${NC}"
rm -rf emby-crx
mkdir -p emby-crx
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/common-utils.js -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/md5.min.js -P emby-crx/
wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/content/main.js -P emby-crx/

# 3. 安装弹幕插件 (dd-danmaku)
echo -e "${GREEN}正在安装弹幕插件 (dd-danmaku)...${NC}"
rm -rf dd-danmaku
mkdir -p dd-danmaku
wget -q https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/

# 4. 安装外部播放器插件 (MPV/Potplayer)
echo -e "${GREEN}正在配置外部播放器插件 (externalPlayer)...${NC}"
# 直接下载脚本文件
wget -q https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js

# 5. 修改 index.html (注入代码)
echo -e "${GREEN}正在修改 index.html...${NC}"

# 检查 index.html 备份
if [ -f "index.html.bak" ]; then
    echo -e "${YELLOW}检测到备份文件 index.html.bak 已存在。请选择操作：${NC}"
    echo -e "  [O] Overwrite (覆盖备份)"
    echo -e "  [C] Continue (不覆盖备份，仅执行安装)"
    echo -e "  [Q] Quit (退出脚本)"
    read -p "您的选择 [O/C/Q]: " action
    case $action in
        [Oo] ) 
            cp index.html index.html.bak
            echo "已覆盖现有备份。" ;;
        [Cc] ) 
            echo "正在使用现有备份继续安装..." ;;
        [Qq] ) 
            echo "退出安装。"
            exit 0 ;;
        * ) 
            echo -e "${RED}无效输入，退出安装。${NC}"
            exit 1 ;;
    esac
else
    cp index.html index.html.bak
    echo "已创建 index.html 备份。"
fi

# 移除旧的注入，确保幂等性
# 1. 移除带注释标记的区块 (推荐方式)
sed -i '/<!-- Emby Plugins Start -->/,/<!-- Emby Plugins End -->/d' index.html
# 2. 移除可能存在的“裸”标签 (兼容旧脚本或手动注入)
sed -i 's|<link[^>]*emby-crx/[^>]*>||g' index.html
sed -i 's|<script[^>]*emby-crx/[^>]*></script>||g' index.html
sed -i 's|<script[^>]*dd-danmaku/[^>]*></script>||g' index.html
sed -i 's|<script[^>]*externalPlayer\.js[^>]*></script>||g' index.html

# 定义头部注入
HEAD_CODE='<!-- Emby Plugins Start -->\n<link rel="stylesheet" id="theme-css" href="emby-crx/style.css" type="text/css" media="all" />\n<script src="emby-crx/common-utils.js"></script>\n<script src="emby-crx/jquery-3.6.0.min.js"></script>\n<script src="emby-crx/md5.min.js"></script>\n<script src="emby-crx/main.js"></script>\n<script src="dd-danmaku/ede.js"></script>'

# 插入到 </head> 之前
sed -i "s|</head>|$HEAD_CODE\n</head>|" index.html

# 定义尾部注入 (在 apploader.js 之后)
BODY_CODE='<script src="externalPlayer.js" defer></script>\n<!-- Emby Plugins End -->'

# 检查是否存在 apploader.js 标签，在其下方插入；否则在 </body> 前插入
if grep -q "apploader.js" index.html; then
    sed -i "/apploader.js/a $BODY_CODE" index.html
else
    sed -i "s|</body>|$BODY_CODE\n</body>|" index.html
fi

echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${YELLOW}请刷新 Emby 网页端查看效果。${NC}"
echo -e "${YELLOW}==============================================${NC}"
