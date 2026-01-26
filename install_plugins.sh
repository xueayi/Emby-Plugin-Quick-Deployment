#!/bin/sh
# ============================================================================
# Emby 插件管理脚本 v1.0.0
# 适用于 Emby Docker 精简终端 (BusyBox/Alpine sh)
# 
# 功能: 选择性安装/卸载插件、备份恢复、国内加速源
# 作者: xueayi
# 项目: https://github.com/xueayi/Emby-Plugin-Quick-Deployment
# ============================================================================

# ========================== 全局配置 ==========================

# 默认路径
VERSION="1.0.0"
UI_DIR="/system/dashboard-ui"
BACKUP_DIR="/system/dashboard-ui/.plugin_backups"
MAX_BACKUPS=5
INDEX_FILE="index.html"
LOG_FILE="/tmp/emby_plugin_install.log"

# 下载源配置
GITHUB_RAW="https://raw.githubusercontent.com"
MIRROR_GHPROXY="https://ghproxy.net"
CURRENT_SOURCE="github"  # github 或 mirror

# 颜色代码 (兼容精简终端)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # 无颜色

# ========================== 插件定义 ==========================
# 每个插件使用变量前缀区分，格式: PLUGIN_<ID>_<属性>

# --- 插件1: 界面美化 (emby-crx) ---
PLUGIN_CRX_ID="crx"
PLUGIN_CRX_NAME="界面美化 (emby-crx)"
PLUGIN_CRX_DESC="修改 Web 端皮肤，优化视觉体验"
PLUGIN_CRX_DIR="emby-crx"
PLUGIN_CRX_PROJECT="https://github.com/Nolovenodie/emby-crx"
PLUGIN_CRX_FILES="static/css/style.css static/js/common-utils.js static/js/jquery-3.6.0.min.js static/js/md5.min.js content/main.js"
PLUGIN_CRX_BASE_PATH="Nolovenodie/emby-crx/master"
PLUGIN_CRX_INJECT_HEAD='<link rel="stylesheet" href="emby-crx/style.css" type="text/css" />\n<script src="emby-crx/jquery-3.6.0.min.js"></script>\n<script src="emby-crx/md5.min.js"></script>\n<script src="emby-crx/common-utils.js"></script>\n<script src="emby-crx/main.js"></script>'
PLUGIN_CRX_MARKER="emby-crx"

# --- 插件2: 弹幕插件 (dd-danmaku) ---
PLUGIN_DANMAKU_ID="danmaku"
PLUGIN_DANMAKU_NAME="弹幕插件 (dd-danmaku)"
PLUGIN_DANMAKU_DESC="为 Web 端播放器集成弹幕显示功能"
PLUGIN_DANMAKU_DIR="dd-danmaku"
PLUGIN_DANMAKU_PROJECT="https://github.com/chen3861229/dd-danmaku"
PLUGIN_DANMAKU_FILES="ede.js"
PLUGIN_DANMAKU_BASE_PATH="chen3861229/dd-danmaku/refs/heads/main"
PLUGIN_DANMAKU_INJECT_HEAD='<script src="dd-danmaku/ede.js"></script>'
PLUGIN_DANMAKU_MARKER="dd-danmaku"

# --- 插件3: 外部播放器 (externalPlayer) ---
PLUGIN_PLAYER_ID="player"
PLUGIN_PLAYER_NAME="外部播放器 (PotPlayer/MPV)"
PLUGIN_PLAYER_DESC="通过协议调用本地播放器播放视频"
PLUGIN_PLAYER_DIR=""  # 单文件，无目录
PLUGIN_PLAYER_PROJECT="https://github.com/bpking1/embyExternalUrl"
PLUGIN_PLAYER_FILES="embyWebAddExternalUrl/embyLaunchPotplayer.js"
PLUGIN_PLAYER_BASE_PATH="bpking1/embyExternalUrl/refs/heads/main"
PLUGIN_PLAYER_INJECT_BODY='<script src="externalPlayer.js" defer></script>'
PLUGIN_PLAYER_MARKER="externalPlayer.js"

# 插件列表 (空格分隔的ID)
PLUGIN_LIST="crx danmaku player"

# ========================== 工具函数 ==========================

# 日志函数
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# 彩色输出
print_color() {
    local color="$1"
    local msg="$2"
    printf "${color}%s${NC}\n" "$msg"
}

print_info()    { print_color "$CYAN"   "ℹ $1"; }
print_success() { print_color "$GREEN"  "✓ $1"; }
print_warning() { print_color "$YELLOW" "⚠ $1"; }
print_error()   { print_color "$RED"    "✗ $1"; }

# 检查命令是否存在
check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# 获取下载工具
get_download_cmd() {
    if check_cmd wget; then
        echo "wget"
    elif check_cmd curl; then
        echo "curl"
    else
        echo ""
    fi
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local dl_cmd=$(get_download_cmd)
    
    # 应用镜像源
    if [ "$CURRENT_SOURCE" = "mirror" ]; then
        url="${MIRROR_GHPROXY}/${url}"
    fi
    
    log "INFO" "下载: $url -> $output"
    
    case "$dl_cmd" in
        wget)
            wget -q --timeout=30 "$url" -O "$output" 2>/dev/null
            ;;
        curl)
            curl -sL --connect-timeout 30 "$url" -o "$output" 2>/dev/null
            ;;
        *)
            print_error "未找到 wget 或 curl，无法下载文件"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ] && [ -s "$output" ]; then
        return 0
    else
        rm -f "$output" 2>/dev/null
        return 1
    fi
}

# ========================== 环境检测 ==========================

# 配置自定义路径
configure_custom_path() {
    echo ""
    print_info "当前 UI 目录: $UI_DIR"
    printf "\n是否使用自定义路径? (y/N): "
    read use_custom
    
    if [ "$use_custom" = "y" ] || [ "$use_custom" = "Y" ]; then
        printf "请输入 index.html 所在目录的绝对路径: "
        read custom_path
        
        if [ -n "$custom_path" ]; then
            UI_DIR="$custom_path"
            BACKUP_DIR="${custom_path}/.plugin_backups"
            print_success "已设置自定义路径: $UI_DIR"
        fi
    fi
}

check_environment() {
    print_info "检测运行环境..."
    
    # 检查 UI 目录
    if [ ! -d "$UI_DIR" ]; then
        print_error "未找到 Emby UI 目录: $UI_DIR"
        print_info "请确保在 Emby Docker 容器根目录运行此脚本"
        print_info "或使用 --ui-dir 参数指定路径"
        return 1
    fi
    
    # 检查 index.html
    if [ ! -f "$UI_DIR/$INDEX_FILE" ]; then
        print_error "未找到 index.html: $UI_DIR/$INDEX_FILE"
        return 1
    fi
    
    # 检查写入权限
    if [ ! -w "$UI_DIR" ]; then
        print_error "无写入权限: $UI_DIR"
        return 1
    fi
    
    # 检查下载工具
    if [ -z "$(get_download_cmd)" ]; then
        print_error "未找到 wget 或 curl，无法下载插件"
        return 1
    fi
    
    print_success "环境检测通过"
    print_info "UI 目录: $UI_DIR"
    return 0
}

# ========================== 备份系统 ==========================

# 创建备份目录
ensure_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "INFO" "创建备份目录: $BACKUP_DIR"
    fi
}

# 创建原始备份 (仅首次)
create_original_backup() {
    local original_backup="$BACKUP_DIR/index.html.original"
    if [ ! -f "$original_backup" ]; then
        cp "$UI_DIR/$INDEX_FILE" "$original_backup"
        print_info "已创建原始备份: index.html.original"
        log "INFO" "创建原始备份"
    fi
}

# 创建时间戳备份
create_timestamped_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/index.html.$timestamp"
    cp "$UI_DIR/$INDEX_FILE" "$backup_file"
    print_info "已创建备份: index.html.$timestamp"
    log "INFO" "创建备份: $backup_file"
    
    # 清理旧备份
    cleanup_old_backups
}

# 清理旧备份 (保留最新 N 个)
cleanup_old_backups() {
    ensure_backup_dir
    local count=$(ls -1 "$BACKUP_DIR"/index.html.2* 2>/dev/null | wc -l)
    if [ "$count" -gt "$MAX_BACKUPS" ]; then
        local to_delete=$((count - MAX_BACKUPS))
        ls -1t "$BACKUP_DIR"/index.html.2* | tail -n "$to_delete" | while read f; do
            rm -f "$f"
            log "INFO" "清理旧备份: $f"
        done
        print_info "已清理 $to_delete 个旧备份"
    fi
}

# 列出所有备份
list_backups() {
    ensure_backup_dir
    echo ""
    print_info "可用备份列表:"
    echo "----------------------------------------"
    
    local idx=1
    # 原始备份
    if [ -f "$BACKUP_DIR/index.html.original" ]; then
        local size=$(ls -lh "$BACKUP_DIR/index.html.original" | awk '{print $5}')
        printf "  ${GREEN}0${NC}) [原始] index.html.original ($size)\n"
    fi
    
    # 时间戳备份
    for f in $(ls -1t "$BACKUP_DIR"/index.html.2* 2>/dev/null); do
        local name=$(basename "$f")
        local size=$(ls -lh "$f" | awk '{print $5}')
        printf "  ${CYAN}%d${NC}) %s (%s)\n" "$idx" "$name" "$size"
        idx=$((idx + 1))
    done
    
    if [ "$idx" -eq 1 ] && [ ! -f "$BACKUP_DIR/index.html.original" ]; then
        print_warning "暂无备份"
    fi
    echo "----------------------------------------"
}

# 恢复备份
restore_backup() {
    list_backups
    
    printf "\n请输入要恢复的备份编号 (0=原始, q=取消): "
    read choice
    
    case "$choice" in
        q|Q) return 0 ;;
        0)
            if [ -f "$BACKUP_DIR/index.html.original" ]; then
                cp "$BACKUP_DIR/index.html.original" "$UI_DIR/$INDEX_FILE"
                print_success "已恢复原始备份"
                log "INFO" "恢复原始备份"
            else
                print_error "原始备份不存在"
            fi
            ;;
        [1-9]*)
            local file=$(ls -1t "$BACKUP_DIR"/index.html.2* 2>/dev/null | sed -n "${choice}p")
            if [ -n "$file" ] && [ -f "$file" ]; then
                cp "$file" "$UI_DIR/$INDEX_FILE"
                print_success "已恢复备份: $(basename "$file")"
                log "INFO" "恢复备份: $file"
            else
                print_error "无效的备份编号"
            fi
            ;;
        *)
            print_error "无效输入"
            ;;
    esac
}

# ========================== 插件操作 ==========================

# 获取插件属性
get_plugin_attr() {
    local plugin_id="$1"
    local attr="$2"
    local var_name="PLUGIN_$(echo "$plugin_id" | tr '[:lower:]' '[:upper:]')_$attr"
    eval echo "\$$var_name"
}

# 检查插件是否已安装
is_plugin_installed() {
    local plugin_id="$1"
    local marker=$(get_plugin_attr "$plugin_id" "MARKER")
    grep -q "$marker" "$UI_DIR/$INDEX_FILE" 2>/dev/null
}

# 显示插件状态
show_plugin_status() {
    echo ""
    print_info "插件状态:"
    echo "----------------------------------------"
    for id in $PLUGIN_LIST; do
        local name=$(get_plugin_attr "$id" "NAME")
        if is_plugin_installed "$id"; then
            printf "  ${GREEN}[已安装]${NC} %s\n" "$name"
        else
            printf "  ${YELLOW}[未安装]${NC} %s\n" "$name"
        fi
    done
    echo "----------------------------------------"
}

# 安装单个插件
install_plugin() {
    local plugin_id="$1"
    local name=$(get_plugin_attr "$plugin_id" "NAME")
    local dir=$(get_plugin_attr "$plugin_id" "DIR")
    local files=$(get_plugin_attr "$plugin_id" "FILES")
    local base_path=$(get_plugin_attr "$plugin_id" "BASE_PATH")
    local inject_head=$(get_plugin_attr "$plugin_id" "INJECT_HEAD")
    local inject_body=$(get_plugin_attr "$plugin_id" "INJECT_BODY")
    local marker=$(get_plugin_attr "$plugin_id" "MARKER")
    
    print_info "正在安装: $name"
    log "DEBUG" "开始安装插件: $plugin_id"
    log "DEBUG" "inject_head: $inject_head"
    log "DEBUG" "inject_body: $inject_body"
    
    # 检查是否已安装
    if is_plugin_installed "$plugin_id"; then
        print_warning "插件已安装，将重新安装"
        uninstall_plugin "$plugin_id" "quiet"
    fi
    
    # 创建目录
    if [ -n "$dir" ]; then
        rm -rf "$UI_DIR/$dir" 2>/dev/null
        mkdir -p "$UI_DIR/$dir"
        log "DEBUG" "创建目录: $UI_DIR/$dir"
    fi
    
    # 下载文件
    local download_failed=0
    for file in $files; do
        local filename=$(basename "$file")
        local url="${GITHUB_RAW}/${base_path}/${file}"
        local output
        
        if [ -n "$dir" ]; then
            output="$UI_DIR/$dir/$filename"
        else
            # 特殊处理: 外部播放器重命名
            if [ "$plugin_id" = "player" ]; then
                output="$UI_DIR/externalPlayer.js"
            else
                output="$UI_DIR/$filename"
            fi
        fi
        
        printf "  下载 $filename ... "
        if download_file "$url" "$output"; then
            printf "${GREEN}成功${NC}\n"
            log "DEBUG" "下载成功: $output"
        else
            printf "${RED}失败${NC}\n"
            log "ERROR" "下载失败: $url"
            download_failed=1
        fi
    done
    
    if [ "$download_failed" -eq 1 ]; then
        print_error "部分文件下载失败，请检查网络或尝试使用国内加速源"
        return 1
    fi
    
    # 注入代码到 index.html
    # 根据不同插件使用专用的注入逻辑
    local index_path="$UI_DIR/$INDEX_FILE"
    
    # 先备份当前状态以防失败
    cp "$index_path" "${index_path}.inject_backup"
    
    case "$plugin_id" in
        crx)
            # 界面美化插件 - 注入到 </style> 后 (Emby 的 index.html 没有 </head> 标签)
            log "DEBUG" "注入 emby-crx 代码..."
            if grep -q "</head>" "$index_path"; then
                sed -i 's|</head>|<!-- emby-crx start --><link rel="stylesheet" href="emby-crx/style.css" type="text/css" /><script src="emby-crx/jquery-3.6.0.min.js"></script><script src="emby-crx/md5.min.js"></script><script src="emby-crx/common-utils.js"></script><script src="emby-crx/main.js"></script><!-- emby-crx end --></head>|' "$index_path"
            else
                # Emby 特殊处理：在最后一个 </style> 后插入
                sed -i '/<\/style>/,/<body/{s/<body/<!-- emby-crx start --><link rel="stylesheet" href="emby-crx\/style.css" type="text\/css" \/><script src="emby-crx\/jquery-3.6.0.min.js"><\/script><script src="emby-crx\/md5.min.js"><\/script><script src="emby-crx\/common-utils.js"><\/script><script src="emby-crx\/main.js"><\/script><!-- emby-crx end -->\n<body/}' "$index_path"
            fi
            ;;
        danmaku)
            # 弹幕插件 - 同上
            log "DEBUG" "注入 dd-danmaku 代码..."
            if grep -q "</head>" "$index_path"; then
                sed -i 's|</head>|<!-- dd-danmaku start --><script src="dd-danmaku/ede.js"></script><!-- dd-danmaku end --></head>|' "$index_path"
            else
                # Emby 特殊处理：在 <body 前插入
                sed -i 's|<body|<!-- dd-danmaku start --><script src="dd-danmaku/ede.js"></script><!-- dd-danmaku end -->\n<body|' "$index_path"
            fi
            ;;
        player)
            # 外部播放器 - 注入到 apploader.js 后或 </body> 前
            log "DEBUG" "注入 externalPlayer 代码..."
            if grep -q "apploader.js" "$index_path"; then
                # 在包含 apploader.js 的行后添加
                sed -i '/apploader.js/a <!-- externalPlayer.js start --><script src="externalPlayer.js" defer></script><!-- externalPlayer.js end -->' "$index_path"
            else
                # 在 </body> 前添加
                sed -i 's|</body>|<!-- externalPlayer.js start --><script src="externalPlayer.js" defer></script><!-- externalPlayer.js end --></body>|' "$index_path"
            fi
            ;;
        *)
            log "ERROR" "未知插件ID: $plugin_id"
            rm -f "${index_path}.inject_backup"
            return 1
            ;;
    esac
    
    # 验证注入结果
    if grep -q "$marker" "$index_path"; then
        print_success "$name 安装完成"
        log "INFO" "安装插件成功: $name"
        rm -f "${index_path}.inject_backup"
    else
        print_error "$name 安装失败，正在恢复..."
        mv "${index_path}.inject_backup" "$index_path"
        log "ERROR" "安装验证失败: $name - 未找到标记 $marker，已恢复"
    fi
    
    return 0
}

# 卸载单个插件
uninstall_plugin() {
    local plugin_id="$1"
    local quiet="$2"
    local name=$(get_plugin_attr "$plugin_id" "NAME")
    local dir=$(get_plugin_attr "$plugin_id" "DIR")
    local marker=$(get_plugin_attr "$plugin_id" "MARKER")
    
    if [ "$quiet" != "quiet" ]; then
        print_info "正在卸载: $name"
    fi
    
    # 删除文件/目录
    if [ -n "$dir" ]; then
        rm -rf "$UI_DIR/$dir" 2>/dev/null
    else
        # 外部播放器
        if [ "$plugin_id" = "player" ]; then
            rm -f "$UI_DIR/externalPlayer.js" 2>/dev/null
        fi
    fi
    
    # 移除 index.html 中的注入代码
    sed -i "/$marker/d" "$UI_DIR/$INDEX_FILE"
    
    if [ "$quiet" != "quiet" ]; then
        print_success "$name 已卸载"
        log "INFO" "卸载插件: $name"
    fi
}

# ========================== 交互菜单 ==========================

# 选择下载源
select_source() {
    echo ""
    print_info "选择下载源:"
    echo "  1) GitHub 直连 (海外用户推荐)"
    echo "  2) 国内加速 (ghproxy.net 镜像)"
    printf "\n请选择 [1-2] (默认1): "
    read choice
    
    case "$choice" in
        2)
            CURRENT_SOURCE="mirror"
            print_success "已切换到国内加速源"
            ;;
        *)
            CURRENT_SOURCE="github"
            print_success "使用 GitHub 直连"
            ;;
    esac
}

# 安装菜单
install_menu() {
    echo ""
    print_info "选择要安装的插件:"
    echo "  1) 全部安装"
    echo "  2) 界面美化 (emby-crx)"
    echo "  3) 弹幕插件 (dd-danmaku)"
    echo "  4) 外部播放器 (PotPlayer/MPV)"
    echo "  q) 返回主菜单"
    printf "\n请选择 (可多选，如 234): "
    read choices
    
    [ "$choices" = "q" ] || [ "$choices" = "Q" ] && return
    
    # 选择下载源
    select_source
    
    # 备份
    ensure_backup_dir
    create_original_backup
    create_timestamped_backup
    
    # 解析选择
    local install_crx=0
    local install_danmaku=0
    local install_player=0
    
    case "$choices" in
        *1*) install_crx=1; install_danmaku=1; install_player=1 ;;
    esac
    case "$choices" in *2*) install_crx=1 ;; esac
    case "$choices" in *3*) install_danmaku=1 ;; esac
    case "$choices" in *4*) install_player=1 ;; esac
    
    # 执行安装
    echo ""
    [ "$install_crx" -eq 1 ] && install_plugin "crx"
    [ "$install_danmaku" -eq 1 ] && install_plugin "danmaku"
    [ "$install_player" -eq 1 ] && install_plugin "player"
    
    echo ""
    print_success "安装操作完成！刷新 Emby 网页即可生效。"
}

# 卸载菜单
uninstall_menu() {
    echo ""
    print_info "选择要卸载的插件:"
    echo "  1) 全部卸载"
    echo "  2) 界面美化 (emby-crx)"
    echo "  3) 弹幕插件 (dd-danmaku)"
    echo "  4) 外部播放器 (PotPlayer/MPV)"
    echo "  q) 返回主菜单"
    printf "\n请选择 (可多选，如 234): "
    read choices
    
    [ "$choices" = "q" ] || [ "$choices" = "Q" ] && return
    
    # 备份
    ensure_backup_dir
    create_timestamped_backup
    
    # 解析选择
    local uninstall_crx=0
    local uninstall_danmaku=0
    local uninstall_player=0
    
    case "$choices" in
        *1*) uninstall_crx=1; uninstall_danmaku=1; uninstall_player=1 ;;
    esac
    case "$choices" in *2*) uninstall_crx=1 ;; esac
    case "$choices" in *3*) uninstall_danmaku=1 ;; esac
    case "$choices" in *4*) uninstall_player=1 ;; esac
    
    # 执行卸载
    echo ""
    [ "$uninstall_crx" -eq 1 ] && uninstall_plugin "crx"
    [ "$uninstall_danmaku" -eq 1 ] && uninstall_plugin "danmaku"
    [ "$uninstall_player" -eq 1 ] && uninstall_plugin "player"
    
    echo ""
    print_success "卸载操作完成！刷新 Emby 网页即可生效。"
}

# 备份管理菜单
backup_menu() {
    echo ""
    print_info "备份管理:"
    echo "  1) 查看备份列表"
    echo "  2) 创建新备份"
    echo "  3) 恢复备份"
    echo "  4) 清理旧备份"
    echo "  q) 返回主菜单"
    printf "\n请选择 [1-4]: "
    read choice
    
    case "$choice" in
        1) list_backups ;;
        2) 
            ensure_backup_dir
            create_timestamped_backup
            ;;
        3) restore_backup ;;
        4) 
            cleanup_old_backups
            print_success "备份清理完成"
            ;;
        q|Q) return ;;
        *) print_error "无效选项" ;;
    esac
}

# 显示帮助
show_help() {
    echo ""
    print_info "脚本使用说明:"
    echo "----------------------------------------"
    echo "本脚本用于管理 Emby Web 端插件的安装与卸载。"
    echo ""
    echo "插件说明:"
    for id in $PLUGIN_LIST; do
        local name=$(get_plugin_attr "$id" "NAME")
        local desc=$(get_plugin_attr "$id" "DESC")
        local project=$(get_plugin_attr "$id" "PROJECT")
        echo "  • $name"
        echo "    $desc"
        echo "    项目: $project"
        echo ""
    done
    echo "注意事项:"
    echo "  • 安装前会自动备份 index.html"
    echo "  • 可随时通过备份恢复到之前状态"
    echo "  • 外部播放器需客户端安装协议处理器"
    echo "----------------------------------------"
}

# 显示 Banner
show_banner() {
    printf "${CYAN}"
    cat << 'EOF'
  _____ __ _  ___  _  _   ___  __   _   _  ___  _  __  _ ___
 | ____||  V|| o )\ \/ / | o \| |  | | | |/ __|| ||  \| / __|
 | _|  | |\/|| o \ \  /  |  _/| |__| U | | (_ || || | ' \__ \
 |____||_|  ||___/  \/   |_|  |____|___|_|\___||_||_|\__|___/

EOF
    printf "${NC}"
    echo "        Emby 插件管理脚本 v${VERSION}"
    echo "        作者:xueayi"
    echo "        项目地址:https://github.com/xueayi/Emby-Plugin-Quick-Deployment"
    echo "======================================================================="
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        show_plugin_status
        echo ""
        print_info "请选择操作:"
        echo "  1) 安装插件"
        echo "  2) 卸载插件"
        echo "  3) 备份管理"
        echo "  4) 设置路径"
        echo "  5) 帮助说明"
        echo "  q) 退出"
        printf "\n请选择 [1-5/q]: "
        read choice
        
        case "$choice" in
            1) install_menu ;;
            2) uninstall_menu ;;
            3) backup_menu ;;
            4) 
                configure_custom_path
                if ! check_environment; then
                    print_error "路径配置无效，已恢复默认设置"
                    UI_DIR="/system/dashboard-ui"
                    BACKUP_DIR="/system/dashboard-ui/.plugin_backups"
                fi
                ;;
            5) show_help ;;
            q|Q) 
                echo ""
                print_info "感谢使用，再见！"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                ;;
        esac
    done
}

# ========================== 命令行参数 ==========================

show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示帮助信息"
    echo "  -v, --version        显示版本信息"
    echo "  -s, --status         显示插件状态"
    echo "  --ui-dir <路径>      指定 index.html 所在目录的绝对路径"
    echo "  --install-all        非交互式安装全部插件"
    echo "  --uninstall-all      非交互式卸载全部插件"
    echo "  --use-mirror         使用国内加速源"
    echo ""
    echo "交互式运行: $0"
}

# ========================== 主入口 ==========================

main() {
    # 初始化日志
    : > "$LOG_FILE"
    log "INFO" "脚本启动 v$VERSION"
    
    # 解析命令行参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "Emby 插件管理脚本 v$VERSION"
                exit 0
                ;;
            -s|--status)
                check_environment || exit 1
                cd "$UI_DIR" || exit 1
                show_plugin_status
                exit 0
                ;;
            --ui-dir)
                shift
                if [ -n "$1" ]; then
                    UI_DIR="$1"
                    BACKUP_DIR="${1}/.plugin_backups"
                    print_info "使用自定义路径: $UI_DIR"
                else
                    print_error "--ui-dir 需要指定路径参数"
                    exit 1
                fi
                shift
                ;;
            --use-mirror)
                CURRENT_SOURCE="mirror"
                print_info "使用国内加速源"
                shift
                ;;
            --install-all)
                check_environment || exit 1
                cd "$UI_DIR" || exit 1
                ensure_backup_dir
                create_original_backup
                create_timestamped_backup
                for id in $PLUGIN_LIST; do
                    install_plugin "$id"
                done
                print_success "全部插件安装完成"
                exit 0
                ;;
            --uninstall-all)
                check_environment || exit 1
                cd "$UI_DIR" || exit 1
                ensure_backup_dir
                create_timestamped_backup
                for id in $PLUGIN_LIST; do
                    uninstall_plugin "$id"
                done
                print_success "全部插件已卸载"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 环境检测
    if ! check_environment; then
        exit 1
    fi
    
    # 切换到 UI 目录
    cd "$UI_DIR" || exit 1
    
    # 显示 Banner 并进入主菜单
    clear
    show_banner
    main_menu
}

# 运行主程序
main "$@"
