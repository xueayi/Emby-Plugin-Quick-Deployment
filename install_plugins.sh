#!/bin/sh

# ==============================================================================
# Emby 插件全功能安装脚本 (V2.2 - Bugfix 版)
# 修复：解决部分环境下 sed 注入破坏 index.html 结构及安装中断问题
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}      Emby 插件安装与管理程序 (V2.2)${NC}"
echo -e "${YELLOW}==============================================${NC}"

# 1. 环境校验
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "${RED}错误: 未找到 Emby UI 目录 ($UI_DIR)。${NC}"
    exit 1
fi

cd "$UI_DIR" || exit

# 2. 交互式主菜单
echo -e "请选择操作:"
echo -e "  ${GREEN}[1] 安装全部${NC}"
echo -e "  [2] 界面美化 (emby-crx)"
echo -e "  [3] 弹幕增强 (dd-danmaku)"
echo -e "  [4] 外部播放器 (PotPlayer/MPV)"
echo -e "  ${RED}[U] 卸载所有插件并还原环境${NC}"
echo -e "  [Q] 退出"
read -p "您的选择: " main_choice

# --- 卸载逻辑 (移动到这里以确保优先处理) ---
do_uninstall() {
    echo -e "${YELLOW}正在清理 index.html 注入内容...${NC}"
    # 精准移除相关行，不再依赖起始/结尾标签，防止误删核心内容
    sed -i '/emby-crx/d' index.html
    sed -i '/dd-danmaku/d' index.html
    sed -i '/externalPlayer.js/d' index.html
    sed -i '/Emby Plugins/d' index.html
    
    echo -e "${YELLOW}正在删除插件物理文件...${NC}"
    rm -rf emby-crx dd-danmaku
    rm -f externalPlayer.js
    
    echo -e "${GREEN}卸载完成！${NC}"
    echo -e "${YELLOW}提示：如果网页仍无法打开，请执行 'mv index.html.bak index.html' 还原备份。${NC}"
}

if [ "$main_choice" = "U" ] || [ "$main_choice" = "u" ]; then
    do_uninstall
    exit 0
fi

# 3. 处理安装选项
INSTALL_CRX=false; INSTALL_DANMAKU=false; INSTALL_PLAYER=false
[ "$main_choice" = "1" ] && { INSTALL_CRX=true; INSTALL_DANMAKU=true; INSTALL_PLAYER=true; }
echo "$main_choice" | grep -q "2" && INSTALL_CRX=true
echo "$main_choice" | grep -q "3" && INSTALL_DANMAKU=true
echo "$main_choice" | grep -q "4" && INSTALL_PLAYER=true

if [ "$INSTALL_CRX" = false ] && [ "$INSTALL_DANMAKU" = false ] && [ "$INSTALL_PLAYER" = false ]; then
    [ "$main_choice" != "Q" ] && [ "$main_choice" != "q" ] && echo -e "${RED}输入无效。${NC}"
    exit 0
fi

# 4. 备份处理 (增加 index.html 内容校验)
if [ ! -f "index.html" ]; then
    echo -e "${RED}严重错误：找不到 index.html。${NC}"
    exit 1
fi

if [ -f "index.html.bak" ]; then
    echo -e "${YELLOW}检测到备份文件 index.html.bak 已存在。${NC}"
    echo -e "  [O] Overwrite (覆盖备份 - 谨慎)"
    echo -e "  [C] Continue (直接运行 - 推荐)"
    read -p "您的选择 [O/C]: " back_opt
    [ "$back_opt" = "O" ] || [ "$back_opt" = "o" ] && cp index.html index.html.bak
else
    cp index.html index.html.bak
    echo "已创建初始备份。"
fi

# 5. 下载资源
echo -e "${GREEN}正在准备插件资源...${NC}"
if [ "$INSTALL_CRX" = true ]; then
    rm -rf emby-crx && mkdir -p emby-crx
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/common-utils.js -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/md5.min.js -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/content/main.js -P emby-crx/
fi

if [ "$INSTALL_DANMAKU" = true ]; then
    rm -rf dd-danmaku && mkdir -p dd-danmaku
    wget -q https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/
fi

if [ "$INSTALL_PLAYER" = true ]; then
    wget -q https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js
fi

# 6. 修改 index.html (采用分行安全注入)
echo -e "${GREEN}正在应用修改到 index.html...${NC}"

# 先清理所有旧注入，防止重复
sed -i '/emby-crx/d' index.html
sed -i '/dd-danmaku/d' index.html
sed -i '/externalPlayer.js/d' index.html
sed -i '/Emby Plugins/d' index.html

# 在 </head> 之前分步注入，不使用 \n 变量以提高兼容性
[ "$INSTALL_CRX" = true ] && {
    sed -i '/<\/head>/i <!-- Emby Plugins Start -->' index.html
    sed -i '/<\/head>/i <link rel="stylesheet" id="theme-css" href="emby-crx/style.css" type="text/css" media="all" />' index.html
    sed -i '/<\/head>/i <script src="emby-crx/common-utils.js"></script>' index.html
    sed -i '/<\/head>/i <script src="emby-crx/jquery-3.6.0.min.js"></script>' index.html
    sed -i '/<\/head>/i <script src="emby-crx/md5.min.js"></script>' index.html
    sed -i '/<\/head>/i <script src="emby-crx/main.js"></script>' index.html
}

[ "$INSTALL_DANMAKU" = true ] && {
    sed -i '/<\/head>/i <script src="dd-danmaku/ede.js"></script>' index.html
}

# 在 </body> 之前注入播放器和结束标签
if [ "$INSTALL_PLAYER" = true ]; then
    if grep -q "apploader.js" index.html; then
        sed -i '/apploader.js/a <script src="externalPlayer.js" defer></script>' index.html
    else
        sed -i '/<\/body>/i <script src="externalPlayer.js" defer></script>' index.html
    fi
fi
sed -i '/<\/body>/i <!-- Emby Plugins End -->' index.html

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}安装成功！请刷新网页查看。${NC}"
echo -e "${YELLOW}==============================================${NC}"
