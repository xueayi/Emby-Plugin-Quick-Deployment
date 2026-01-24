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
    # 卸载前创建安全备份
    echo -e "${YELLOW}正在创建卸载前备份 (index.html.uninstall_bak)...${NC}"
    cp index.html index.html.uninstall_bak
    
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
    echo -e "${YELLOW}提示：如果网页仍无法打开，请执行以下命令还原：${NC}"
    echo -e "  ${GREEN}mv index.html.uninstall_bak index.html${NC} (恢复到卸载前)"
    echo -e "  ${GREEN}mv index.html.bak index.html${NC} (恢复到首次安装前)"
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

# 3.1 选择下载镜像源
echo -e "\n${YELLOW}请选择下载源 (国内用户建议选择镜像):${NC}"
echo -e "  [1] GitHub 直连 (海外/代理用户)"
echo -e "  [2] ghproxy.net 镜像 ${GREEN}(推荐)${NC}"
echo -e "  [3] mirror.ghproxy.com 镜像"
read -p "您的选择 [1/2/3] (默认 2): " mirror_choice

case "$mirror_choice" in
    1)
        GITHUB_RAW="https://raw.githubusercontent.com"
        echo -e "${GREEN}已选择: GitHub 直连${NC}"
        ;;
    3)
        GITHUB_RAW="https://mirror.ghproxy.com/https://raw.githubusercontent.com"
        echo -e "${GREEN}已选择: mirror.ghproxy.com 镜像${NC}"
        ;;
    *)
        GITHUB_RAW="https://ghproxy.net/https://raw.githubusercontent.com"
        echo -e "${GREEN}已选择: ghproxy.net 镜像 (默认)${NC}"
        ;;
esac

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
echo -e "${GREEN}正在准备插件资源 (使用 $GITHUB_RAW)...${NC}"
if [ "$INSTALL_CRX" = true ]; then
    rm -rf emby-crx && mkdir -p emby-crx
    wget -q "${GITHUB_RAW}/Nolovenodie/emby-crx/master/static/css/style.css" -P emby-crx/
    wget -q "${GITHUB_RAW}/Nolovenodie/emby-crx/master/static/js/common-utils.js" -P emby-crx/
    wget -q "${GITHUB_RAW}/Nolovenodie/emby-crx/master/static/js/jquery-3.6.0.min.js" -P emby-crx/
    wget -q "${GITHUB_RAW}/Nolovenodie/emby-crx/master/static/js/md5.min.js" -P emby-crx/
    wget -q "${GITHUB_RAW}/Nolovenodie/emby-crx/master/content/main.js" -P emby-crx/
fi

if [ "$INSTALL_DANMAKU" = true ]; then
    rm -rf dd-danmaku && mkdir -p dd-danmaku
    wget -q "${GITHUB_RAW}/chen3861229/dd-danmaku/refs/heads/main/ede.js" -P dd-danmaku/
fi

if [ "$INSTALL_PLAYER" = true ]; then
    wget -q "${GITHUB_RAW}/bpking1/embyExternalUrl/refs/heads/main/embyWebAddExternalUrl/embyLaunchPotplayer.js" -O externalPlayer.js
fi

# 6. 修改 index.html (BusyBox/Alpine 兼容注入方式)
echo -e "${GREEN}正在应用修改到 index.html...${NC}"

# 先清理所有旧注入，防止重复
sed -i '/emby-crx/d' index.html
sed -i '/dd-danmaku/d' index.html
sed -i '/externalPlayer.js/d' index.html
sed -i '/Emby Plugins/d' index.html

# 构建 </head> 前需要注入的内容（写入临时文件）
HEAD_INJECT_FILE=$(mktemp)
echo '<!-- Emby Plugins Start -->' > "$HEAD_INJECT_FILE"

if [ "$INSTALL_CRX" = true ]; then
    cat >> "$HEAD_INJECT_FILE" << 'EOF'
<link rel="stylesheet" id="theme-css" href="emby-crx/style.css" type="text/css" media="all" />
<script src="emby-crx/common-utils.js"></script>
<script src="emby-crx/jquery-3.6.0.min.js"></script>
<script src="emby-crx/md5.min.js"></script>
<script src="emby-crx/main.js"></script>
EOF
fi

if [ "$INSTALL_DANMAKU" = true ]; then
    echo '<script src="dd-danmaku/ede.js"></script>' >> "$HEAD_INJECT_FILE"
fi

# 构建 </body> 前需要注入的内容（写入临时文件）
BODY_INJECT_FILE=$(mktemp)

if [ "$INSTALL_PLAYER" = true ]; then
    echo '<script src="externalPlayer.js" defer></script>' >> "$BODY_INJECT_FILE"
fi
echo '<!-- Emby Plugins End -->' >> "$BODY_INJECT_FILE"

# 使用 awk 进行注入（BusyBox/Alpine 完全兼容）
# 在 </head> 前插入 HEAD_INJECT_FILE 的内容
awk -v injectfile="$HEAD_INJECT_FILE" '
    /<\/head>/ {
        while ((getline line < injectfile) > 0) print line
        close(injectfile)
    }
    { print }
' index.html > index.html.tmp && mv index.html.tmp index.html

# 在 </body> 前插入 BODY_INJECT_FILE 的内容
awk -v injectfile="$BODY_INJECT_FILE" '
    /<\/body>/ {
        while ((getline line < injectfile) > 0) print line
        close(injectfile)
    }
    { print }
' index.html > index.html.tmp && mv index.html.tmp index.html

# 清理临时文件
rm -f "$HEAD_INJECT_FILE" "$BODY_INJECT_FILE"

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}安装成功！请刷新网页查看。${NC}"
echo -e "${YELLOW}==============================================${NC}"
