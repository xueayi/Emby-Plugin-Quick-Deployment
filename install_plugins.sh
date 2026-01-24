#!/bin/sh

# ==============================================================================
# Emby 插件全功能安装脚本 (V2.1)
# 功能：安装(组件化选择)、卸载、备份安全、幂等清理
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}      Emby 插件安装与管理程序 (V2.1)${NC}"
echo -e "${YELLOW}==============================================${NC}"

# 1. 环境校验
UI_DIR="/system/dashboard-ui"
if [ ! -d "$UI_DIR" ]; then
    echo -e "${RED}错误: 未找到 Emby UI 目录 ($UI_DIR)。${NC}"
    echo -e "请确认路径或参考手动安装指南。"
    exit 1
fi

cd "$UI_DIR" || exit

# 2. 交互式主菜单
echo -e "请选择操作:"
echo -e "  ${GREEN}[1] 安装全部 (美化 + 弹幕 + 外部播放器)${NC}"
echo -e "  [2] 界面美化插件 (emby-crx)"
echo -e "  [3] 弹幕增强插件 (dd-danmaku)"
echo -e "  [4] 外部播放器插件 (PotPlayer/MPV)"
echo -e "  ${RED}[U] 卸载所有插件并还原环境${NC}"
echo -e "  [Q] 退出"
read -p "您的选择: " main_choice

# 处理卸载逻辑
if [ "$main_choice" = "U" ] || [ "$main_choice" = "u" ]; then
    echo -e "${YELLOW}正在执行卸载程序...${NC}"
    
    # 清理 index.html 注入
    sed -i '/<!-- Emby Plugins Start -->/,/<!-- Emby Plugins End -->/d' index.html
    sed -i 's|<link[^>]*emby-crx/[^>]*>||g; s|<script[^>]*emby-crx/[^>]*></script>||g; s|<script[^>]*dd-danmaku/[^>]*></script>||g; s|<script[^>]*externalPlayer\.js[^>]*></script>||g' index.html
    
    # 删除插件物理文件
    rm -rf emby-crx
    rm -rf dd-danmaku
    rm -f externalPlayer.js
    
    echo -e "${GREEN}卸载完成！${NC} 插件文件已删除，index.html 已清理。"
    echo -e "${YELLOW}注意：备份文件 index.html.bak 未删除，您可以手动执行 'mv index.html.bak index.html' 完全还原状态。${NC}"
    exit 0
fi

# 处理安装选项
INSTALL_CRX=false; INSTALL_DANMAKU=false; INSTALL_PLAYER=false
for choice in $main_choice; do
    case $choice in
        1) INSTALL_CRX=true; INSTALL_DANMAKU=true; INSTALL_PLAYER=true ;;
        2) INSTALL_CRX=true ;;
        3) INSTALL_DANMAKU=true ;;
        4) INSTALL_PLAYER=true ;;
        [Qq]) echo "退出。"; exit 0 ;;
    esac
done

if [ "$INSTALL_CRX" = false ] && [ "$INSTALL_DANMAKU" = false ] && [ "$INSTALL_PLAYER" = false ]; then
    echo -e "${RED}输入无效，退出安装。${NC}"
    exit 1
fi

# 3. 备份 index.html
if [ -f "index.html.bak" ]; then
    echo -e "${YELLOW}检测到备份文件 index.html.bak 已存在。请选择：${NC}"
    echo -e "  [O] Overwrite (覆盖现有备份)"
    echo -e "  [C] Continue (保留现有备份继续)"
    echo -e "  [Q] Quit (退出)"
    read -p "选择 [O/C/Q]: " back_opt
    case $back_opt in
        [Oo]) cp index.html index.html.bak; echo "备份已更新。" ;;
        [Qq]) exit 0 ;;
    esac
else
    cp index.html index.html.bak
    echo "已创建 index.html 备份。"
fi

# 4. 下载资源
[ "$INSTALL_CRX" = true ] && { 
    echo -e "${GREEN}下载美化插件...${NC}"
    rm -rf emby-crx && mkdir -p emby-crx
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/css/style.css -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/common-utils.js -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/static/js/md5.min.js -P emby-crx/
    wget -q https://raw.githubusercontent.com/Nolovenodie/emby-crx/master/content/main.js -P emby-crx/
}

[ "$INSTALL_DANMAKU" = true ] && {
    echo -e "${GREEN}下载弹幕插件...${NC}"
    rm -rf dd-danmaku && mkdir -p dd-danmaku
    wget -q https://raw.githubusercontent.com/chen3861229/dd-danmaku/refs/heads/main/ede.js -P dd-danmaku/
}

[ "$INSTALL_PLAYER" = true ] && {
    echo -e "${GREEN}下载播放器脚本...${NC}"
    wget -q https://raw.githubusercontent.com/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js -O externalPlayer.js
}

# 5. 注入 index.html
echo -e "${GREEN}应用注入到 index.html...${NC}"

# 清理旧引用
sed -i '/<!-- Emby Plugins Start -->/,/<!-- Emby Plugins End -->/d' index.html
sed -i 's|<link[^>]*emby-crx/[^>]*>||g; s|<script[^>]*emby-crx/[^>]*></script>||g; s|<script[^>]*dd-danmaku/[^>]*></script>||g; s|<script[^>]*externalPlayer\.js[^>]*></script>||g' index.html

# 构建 HEAD 注入
H_CODE='<!-- Emby Plugins Start -->'
[ "$INSTALL_CRX" = true ] && H_CODE="${H_CODE}\n<link rel=\"stylesheet\" href=\"emby-crx/style.css\" />\n<script src=\"emby-crx/main.js\"></script>"
[ "$INSTALL_DANMAKU" = true ] && H_CODE="${H_CODE}\n<script src=\"dd-danmaku/ede.js\"></script>"
sed -i "s|</head>|$H_CODE\n</head>|" index.html

# 构建 BODY 注入
B_CODE=""
[ "$INSTALL_PLAYER" = true ] && B_CODE='<script src="externalPlayer.js" defer></script>'
B_CODE="${B_CODE}\n<!-- Emby Plugins End -->"

if grep -q "apploader.js" index.html; then
    sed -i "/apploader.js/a $B_CODE" index.html
else
    sed -i "s|</body>|$B_CODE\n</body>|" index.html
fi

echo -e "${GREEN}安装完成！${NC} 选定组件已生效。"
