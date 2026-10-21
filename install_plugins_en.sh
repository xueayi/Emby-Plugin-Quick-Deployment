#!/bin/sh
# ============================================================================
# Emby Plugin Management Script v1.1.0
# Suitable for Emby Docker minimal terminal (BusyBox/Alpine sh)
# Also supports Emby installed natively from the fnOS app store (auto-detect, needs sudo)
#
# Features: Selective install/uninstall plugins, backup/restore, domestic mirror acceleration,
#           automatic fnOS native path detection
# Author: xueayi
# Project: https://github.com/xueayi/Emby-Plugin-Quick-Deployment
# ============================================================================

# ========================== Global Configuration ==========================

# Default paths
VERSION="1.1.0"
UI_DIR="/system/dashboard-ui"
BACKUP_DIR="/system/dashboard-ui/.plugin_backups"
MAX_BACKUPS=5
INDEX_FILE="index.html"
LOG_FILE="/tmp/emby_plugin_install.log"

# Path resolution state: UI_DIR_EXPLICIT=1 when the user passed --ui-dir
UI_DIR_EXPLICIT=0
IS_FNOS_NATIVE=0

# Download source configuration
GITHUB_RAW="https://raw.githubusercontent.com"
MIRROR_GHPROXY="https://ghproxy.net"
CURRENT_SOURCE="github"  # github or mirror

# Color codes (compatible with minimal terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No color

# ========================== Plugin Definitions ==========================
# Each plugin uses variable prefix to distinguish, format: PLUGIN_<ID>_<attribute>

# --- Plugin 1: UI Beautification (emby-crx) ---
PLUGIN_CRX_ID="crx"
PLUGIN_CRX_NAME="UI Beautification (emby-crx)"
PLUGIN_CRX_DESC="Modify web skin, optimize visual experience"
PLUGIN_CRX_DIR="emby-crx"
PLUGIN_CRX_PROJECT="https://github.com/Nolovenodie/emby-crx"
PLUGIN_CRX_FILES="static/css/style.css static/js/common-utils.js static/js/jquery-3.6.0.min.js static/js/md5.min.js content/main.js"
PLUGIN_CRX_BASE_PATH="Nolovenodie/emby-crx/master"
PLUGIN_CRX_INJECT_HEAD='<link rel="stylesheet" href="emby-crx/style.css" type="text/css" />\n<script src="emby-crx/jquery-3.6.0.min.js"></script>\n<script src="emby-crx/md5.min.js"></script>\n<script src="emby-crx/common-utils.js"></script>\n<script src="emby-crx/main.js"></script>'
PLUGIN_CRX_MARKER="emby-crx"

# --- Plugin 2: Danmaku plugin (dd-danmaku) ---
PLUGIN_DANMAKU_ID="danmaku"
PLUGIN_DANMAKU_NAME="Danmaku plugin (dd-danmaku)"
PLUGIN_DANMAKU_DESC="Integrate danmaku display function into web player"
PLUGIN_DANMAKU_DIR="dd-danmaku"
PLUGIN_DANMAKU_PROJECT="https://github.com/l429609201/dd-danmaku"
PLUGIN_DANMAKU_FILES="ede.js"
PLUGIN_DANMAKU_BASE_PATH="l429609201/dd-danmaku/refs/heads/main"
PLUGIN_DANMAKU_INJECT_HEAD='<script src="dd-danmaku/ede.js"></script>'
PLUGIN_DANMAKU_MARKER="dd-danmaku"

# --- Plugin 3: External Player (PotPlayer/MPV) ---
PLUGIN_PLAYER_ID="player"
PLUGIN_PLAYER_NAME="External Player (PotPlayer/MPV)"
PLUGIN_PLAYER_DESC="Call local player via protocol to play videos"
PLUGIN_PLAYER_DIR=""  # Single file, no directory
PLUGIN_PLAYER_PROJECT="https://github.com/bpking1/embyExternalUrl"
PLUGIN_PLAYER_FILES="embyWebAddExternalUrl/embyLaunchPotplayer.js"
PLUGIN_PLAYER_BASE_PATH="bpking1/embyExternalUrl/refs/heads/main"
PLUGIN_PLAYER_INJECT_BODY='<script src="externalPlayer.js" defer></script>'
PLUGIN_PLAYER_MARKER="externalPlayer.js"

# --- Plugin 4: Home Swiper (Emby Home Swiper UI) ---
PLUGIN_SWIPER_ID="swiper"
PLUGIN_SWIPER_NAME="Home Swiper (Emby Home Swiper)"
PLUGIN_SWIPER_DESC="Modern full-screen carousel banner, display latest media (Recommended for Emby 4.9+)"
PLUGIN_SWIPER_DIR=""
PLUGIN_SWIPER_PROJECT="https://github.com/sohag1192/Emby-Home-Swiper-UI"
# Upstream v2 path (v1/home.js was moved upstream and returns 404); v2 requires defer
PLUGIN_SWIPER_FILES="home-swiper-v2/home-swiper.js"
PLUGIN_SWIPER_BASE_PATH="sohag1192/Emby-Home-Swiper-UI/refs/heads/main"
PLUGIN_SWIPER_INJECT_HEAD='<script src="home.js" defer></script>'
PLUGIN_SWIPER_MARKER="home.js"

# Plugin list (space separated IDs)
PLUGIN_LIST="crx danmaku player swiper"

# ========================== Utility Functions ==========================

# Logging function
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# Colored output
print_color() {
    local color="$1"
    local msg="$2"
    printf "${color}%s${NC}\n" "$msg"
}

print_info()    { print_color "$CYAN"   "ℹ $1"; }
print_success() { print_color "$GREEN"  "✓ $1"; }
print_warning() { print_color "$YELLOW" "⚠ $1"; }
print_error()   { print_color "$RED"    "✗ $1"; }

# Check if command exists
check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Get download tool
get_download_cmd() {
    if check_cmd wget; then
        echo "wget"
    elif check_cmd curl; then
        echo "curl"
    else
        echo ""
    fi
}

# Download file
download_file() {
    local url="$1"
    local output="$2"
    local dl_cmd=$(get_download_cmd)
    
    # Apply mirror
    if [ "$CURRENT_SOURCE" = "mirror" ]; then
        url="${MIRROR_GHPROXY}/${url}"
    fi
    
    log "INFO" "Download: $url -> $output"
    
    case "$dl_cmd" in
        wget)
            wget -q --timeout=30 "$url" -O "$output" 2>/dev/null
            ;;
        curl)
            curl -sL --connect-timeout 30 "$url" -o "$output" 2>/dev/null
            ;;
        *)
            print_error "wget or curl not found, cannot download file"
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

# ========================== Environment Check ==========================

# fnOS native app detection: when no explicit path is set and running on the
# fnOS host, find /var/apps/*/target/system/dashboard-ui automatically.
detect_ui_dir() {
    if [ "$UI_DIR_EXPLICIT" = "1" ]; then
        return 0
    fi
    if [ -d "/var/apps" ] && [ -d "/usr/trim" ]; then
        for d in /var/apps/*/target/system/dashboard-ui; do
            if [ -f "$d/$INDEX_FILE" ]; then
                UI_DIR="$d"
                BACKUP_DIR="$d/.plugin_backups"
                IS_FNOS_NATIVE=1
                return 0
            fi
        done
    fi
    return 1
}

# Configure custom path
configure_custom_path() {
    echo ""
    print_info "Current UI directory: $UI_DIR"
    printf "\nUse custom path? (y/N): "
    read use_custom
    
    if [ "$use_custom" = "y" ] || [ "$use_custom" = "Y" ]; then
        printf "Enter absolute path of index.html directory: "
        read custom_path
        
        if [ -n "$custom_path" ]; then
            UI_DIR="$custom_path"
            BACKUP_DIR="${custom_path}/.plugin_backups"
            UI_DIR_EXPLICIT=1
            IS_FNOS_NATIVE=0
            print_success "Custom path set: $UI_DIR"
        fi
    fi
}

check_environment() {
    print_info "Checking environment..."

    # Auto-detect the fnOS native path
    if detect_ui_dir; then
        if [ "$IS_FNOS_NATIVE" = "1" ]; then
            print_success "Detected fnOS native Emby application"
        fi
    fi
    
    # Check UI directory
    if [ ! -d "$UI_DIR" ]; then
        print_error "Emby UI directory not found: $UI_DIR"
        print_info "Please run this script in the root directory of Emby Docker container"
        print_info "Or specify path with --ui-dir parameter"
        return 1
    fi
    
    # Check index.html
    if [ ! -f "$UI_DIR/$INDEX_FILE" ]; then
        print_error "index.html not found: $UI_DIR/$INDEX_FILE"
        return 1
    fi
    
    # Check write permission
    if [ ! -w "$UI_DIR" ]; then
        print_error "No write permission: $UI_DIR"
        if [ "$IS_FNOS_NATIVE" = "1" ]; then
            print_info "The fnOS native application directory requires root; run this script with sudo"
        fi
        return 1
    fi
    
    # Check download tool
    if [ -z "$(get_download_cmd)" ]; then
        print_error "wget or curl not found, cannot download plugins"
        return 1
    fi
    
    print_success "Environment check passed"
    print_info "UI directory: $UI_DIR"
    return 0
}

# ========================== Backup System ==========================

# Ensure backup directory
ensure_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "INFO" "Create backup directory: $BACKUP_DIR"
    fi
}

# Create original backup (only first time)
create_original_backup() {
    local original_backup="$BACKUP_DIR/index.html.original"
    if [ ! -f "$original_backup" ]; then
        cp "$UI_DIR/$INDEX_FILE" "$original_backup"
        print_info "Original backup created: index.html.original"
        log "INFO" "Create original backup"
    fi
}

# Create timestamped backup
create_timestamped_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/index.html.$timestamp"
    cp "$UI_DIR/$INDEX_FILE" "$backup_file"
    print_info "Backup created: index.html.$timestamp"
    log "INFO" "Create backup: $backup_file"
    
    # Clean old backups
    cleanup_old_backups
}

# Clean old backups (keep latest N)
cleanup_old_backups() {
    ensure_backup_dir
    local count=$(ls -1 "$BACKUP_DIR"/index.html.2* 2>/dev/null | wc -l)
    if [ "$count" -gt "$MAX_BACKUPS" ]; then
        local to_delete=$((count - MAX_BACKUPS))
        ls -1t "$BACKUP_DIR"/index.html.2* | tail -n "$to_delete" | while read f; do
            rm -f "$f"
            log "INFO" "Clean old backup: $f"
        done
        print_info "Cleaned $to_delete old backups"
    fi
}

# List all backups
list_backups() {
    ensure_backup_dir
    echo ""
    print_info "Available backups:"
    echo "----------------------------------------"
    
    local idx=1
    # Original backup
    if [ -f "$BACKUP_DIR/index.html.original" ]; then
        local size=$(ls -lh "$BACKUP_DIR/index.html.original" | awk '{print $5}')
        printf "  ${GREEN}0${NC}) [Original] index.html.original ($size)\n"
    fi
    
    # Timestamp backups
    for f in $(ls -1t "$BACKUP_DIR"/index.html.2* 2>/dev/null); do
        local name=$(basename "$f")
        local size=$(ls -lh "$f" | awk '{print $5}')
        printf "  ${CYAN}%d${NC}) %s (%s)\n" "$idx" "$name" "$size"
        idx=$((idx + 1))
    done
    
    if [ "$idx" -eq 1 ] && [ ! -f "$BACKUP_DIR/index.html.original" ]; then
        print_warning "No backups yet"
    fi
    echo "----------------------------------------"
}

# Restore backup
restore_backup() {
    list_backups
    
    printf "\nEnter backup number to restore (0=original, q=cancel): "
    read choice
    
    case "$choice" in
        q|Q) return 0 ;;
        0)
            if [ -f "$BACKUP_DIR/index.html.original" ]; then
                cp "$BACKUP_DIR/index.html.original" "$UI_DIR/$INDEX_FILE"
                print_success "Restored original backup"
                log "INFO" "Restore original backup"
            else
                print_error "Original backup does not exist"
            fi
            ;;
        [1-9]*)
            local file=$(ls -1t "$BACKUP_DIR"/index.html.2* 2>/dev/null | sed -n "${choice}p")
            if [ -n "$file" ] && [ -f "$file" ]; then
                cp "$file" "$UI_DIR/$INDEX_FILE"
                print_success "Restored backup: $(basename "$file")"
                log "INFO" "Restore backup: $file"
            else
                print_error "Invalid backup number"
            fi
            ;;
        *)
            print_error "Invalid input"
            ;;
    esac
}

# ========================== Plugin Operations ==========================

# fnOS native note: app upgrades reset the target directory, so plugins must be reinstalled
print_fnos_upgrade_note() {
    if [ "$IS_FNOS_NATIVE" = "1" ]; then
        echo ""
        print_warning "fnOS note: upgrading Emby in App Center resets the program directory; rerun this script afterward"
    fi
}

# Validate plugin IDs and normalize comma/space-separated input to a space-separated list
normalize_plugin_ids() {
    local raw="$1"
    local id out=""
    for id in $(echo "$raw" | tr ',' ' '); do
        local ok=0
        for known in $PLUGIN_LIST; do
            [ "$id" = "$known" ] && ok=1 && break
        done
        if [ "$ok" = "1" ]; then
            out="$out $id"
        else
            print_error "Unknown plugin ID: $id (available: $PLUGIN_LIST)" >&2
            return 1
        fi
    done
    echo "$out"
}

# Non-interactive install of selected plugins
install_selected() {
    local ids
    ids=$(normalize_plugin_ids "$1") || return 1
    [ -z "$ids" ] && return 1
    if ! check_environment; then exit 1; fi
    cd "$UI_DIR" || exit 1
    ensure_backup_dir
    create_original_backup
    create_timestamped_backup
    for id in $ids; do
        install_plugin "$id" || return 1
    done
    print_success "Selected plugins installed! Refresh the Emby web page to apply."
    print_fnos_upgrade_note
}

# Non-interactive uninstall of selected plugins
uninstall_selected() {
    local ids
    ids=$(normalize_plugin_ids "$1") || return 1
    [ -z "$ids" ] && return 1
    if ! check_environment; then exit 1; fi
    cd "$UI_DIR" || exit 1
    ensure_backup_dir
    create_timestamped_backup
    for id in $ids; do
        uninstall_plugin "$id" || return 1
    done
    print_success "Selected plugins uninstalled! Refresh the Emby web page to apply."
    print_fnos_upgrade_note
}

# Get plugin attribute
get_plugin_attr() {
    local plugin_id="$1"
    local attr="$2"
    local var_name="PLUGIN_$(echo "$plugin_id" | tr '[:lower:]' '[:upper:]')_$attr"
    eval echo "\$$var_name"
}

# Check if plugin is installed
is_plugin_installed() {
    local plugin_id="$1"
    local marker=$(get_plugin_attr "$plugin_id" "MARKER")
    grep -q "$marker" "$UI_DIR/$INDEX_FILE" 2>/dev/null
}

# Display plugin status
show_plugin_status() {
    echo ""
    print_info "Plugin status:"
    echo "----------------------------------------"
    for id in $PLUGIN_LIST; do
        local name=$(get_plugin_attr "$id" "NAME")
        if is_plugin_installed "$id"; then
            printf "  ${GREEN}[Installed]${NC} %s\n" "$name"
        else
            printf "  ${YELLOW}[Not installed]${NC} %s\n" "$name"
        fi
    done
    echo "----------------------------------------"
}

# Install single plugin
install_plugin() {
    local plugin_id="$1"
    local name=$(get_plugin_attr "$plugin_id" "NAME")
    local dir=$(get_plugin_attr "$plugin_id" "DIR")
    local files=$(get_plugin_attr "$plugin_id" "FILES")
    local base_path=$(get_plugin_attr "$plugin_id" "BASE_PATH")
    local inject_head=$(get_plugin_attr "$plugin_id" "INJECT_HEAD")
    local inject_body=$(get_plugin_attr "$plugin_id" "INJECT_BODY")
    local marker=$(get_plugin_attr "$plugin_id" "MARKER")
    
    print_info "Installing: $name"
    log "DEBUG" "Start installing plugin: $plugin_id"
    log "DEBUG" "inject_head: $inject_head"
    log "DEBUG" "inject_body: $inject_body"
    
    # Check if already installed
    if is_plugin_installed "$plugin_id"; then
        print_warning "Plugin already installed, will reinstall"
        uninstall_plugin "$plugin_id" "quiet"
    fi
    
    # Create directory
    if [ -n "$dir" ]; then
        rm -rf "$UI_DIR/$dir" 2>/dev/null
        mkdir -p "$UI_DIR/$dir"
        log "DEBUG" "Create directory: $UI_DIR/$dir"
    fi
    
    # Download files
    local download_failed=0
    for file in $files; do
        local filename=$(basename "$file")
        local url="${GITHUB_RAW}/${base_path}/${file}"
        local output
        
        if [ -n "$dir" ]; then
            output="$UI_DIR/$dir/$filename"
        else
            # Special handling: rename external player
            if [ "$plugin_id" = "player" ]; then
                output="$UI_DIR/externalPlayer.js"
            elif [ "$plugin_id" = "swiper" ]; then
                # Swiper v2 is injected under the fixed home.js name
                output="$UI_DIR/home.js"
            else
                output="$UI_DIR/$filename"
            fi
        fi
        
        printf "  Download $filename ... "
        if download_file "$url" "$output"; then
            printf "${GREEN}Success${NC}\n"
            log "DEBUG" "Download successful: $output"
        else
            printf "${RED}Failed${NC}\n"
            log "ERROR" "Download failed: $url"
            download_failed=1
        fi
    done
    
    if [ "$download_failed" -eq 1 ]; then
        print_error "Some files failed to download, please check network or try using domestic mirror"
        return 1
    fi
    
    # Inject code into index.html
    # Use dedicated injection logic for different plugins
    local index_path="$UI_DIR/$INDEX_FILE"
    
    # Backup current state to prevent failure
    cp "$index_path" "${index_path}.inject_backup"
    
    case "$plugin_id" in
        crx)
            # UI Beautification plugin - inject after </style> (Emby's index.html does not have </head> tag)
            log "DEBUG" "Inject emby-crx code..."
            if grep -q "</head>" "$index_path"; then
                sed -i 's|</head>|<!-- emby-crx start --><link rel="stylesheet" href="emby-crx/style.css" type="text/css" /><script src="emby-crx/jquery-3.6.0.min.js"></script><script src="emby-crx/md5.min.js"></script><script src="emby-crx/common-utils.js"></script><script src="emby-crx/main.js"></script><!-- emby-crx end --></head>|' "$index_path"
            else
                # Emby special handling: insert after last </style>
                sed -i '/<\/style>/,/<body/{s/<body/<!-- emby-crx start --><link rel="stylesheet" href="emby-crx\/style.css" type="text\/css" \/><script src="emby-crx\/jquery-3.6.0.min.js"><\/script><script src="emby-crx\/md5.min.js"><\/script><script src="emby-crx\/common-utils.js"><\/script><script src="emby-crx\/main.js"><\/script><!-- emby-crx end -->\n<body/}' "$index_path"
            fi
            ;;
        danmaku)
            # Danmaku plugin - same as above
            log "DEBUG" "Inject dd-danmaku code..."
            if grep -q "</head>" "$index_path"; then
                sed -i 's|</head>|<!-- dd-danmaku start --><script src="dd-danmaku/ede.js"></script><!-- dd-danmaku end --></head>|' "$index_path"
            else
                # Emby special handling: insert before <body
                sed -i 's|<body|<!-- dd-danmaku start --><script src="dd-danmaku/ede.js"></script><!-- dd-danmaku end -->\n<body|' "$index_path"
            fi
            ;;
        player)
            # External player - inject after apploader.js or before </body>
            log "DEBUG" "Inject externalPlayer code..."
            if grep -q "apploader.js" "$index_path"; then
                # Add after line containing apploader.js
                sed -i '/apploader.js/a <!-- externalPlayer.js start --><script src="externalPlayer.js" defer></script><!-- externalPlayer.js end -->' "$index_path"
            else
                # Add before </body>
                sed -i 's|</body>|<!-- externalPlayer.js start --><script src="externalPlayer.js" defer></script><!-- externalPlayer.js end --></body>|' "$index_path"
            fi
            ;;
        swiper)
            # Home swiper plugin - inject before </head> or before <body
            log "DEBUG" "Inject home.js code..."
            if grep -q "</head>" "$index_path"; then
                sed -i 's|</head>|<!-- home.js start --><script src="home.js" defer></script><!-- home.js end --></head>|' "$index_path"
            else
                sed -i 's|<body|<!-- home.js start --><script src="home.js" defer></script><!-- home.js end -->\n<body|' "$index_path"
            fi
            ;;
        *)
            log "ERROR" "Unknown plugin ID: $plugin_id"
            rm -f "${index_path}.inject_backup"
            return 1
            ;;
    esac
    
    # Verify injection result
    if grep -q "$marker" "$index_path"; then
        print_success "$name installation completed"
        log "INFO" "Plugin installed successfully: $name"
        rm -f "${index_path}.inject_backup"
    else
        print_error "$name installation failed, restoring..."
        mv "${index_path}.inject_backup" "$index_path"
        log "ERROR" "Installation verification failed: $name - marker $marker not found, restored"
        return 1
    fi
    
    return 0
}

# Uninstall single plugin
uninstall_plugin() {
    local plugin_id="$1"
    local quiet="$2"
    local name=$(get_plugin_attr "$plugin_id" "NAME")
    local dir=$(get_plugin_attr "$plugin_id" "DIR")
    local marker=$(get_plugin_attr "$plugin_id" "MARKER")
    
    if [ "$quiet" != "quiet" ]; then
        print_info "Uninstalling: $name"
    fi
    
    # Delete files/directory
    if [ -n "$dir" ]; then
        rm -rf "$UI_DIR/$dir" 2>/dev/null
    else
        # External player
        if [ "$plugin_id" = "player" ]; then
            rm -f "$UI_DIR/externalPlayer.js" 2>/dev/null
        fi
        # Swiper v2 is injected under the fixed home.js name
        if [ "$plugin_id" = "swiper" ]; then
            rm -f "$UI_DIR/home.js" 2>/dev/null
        fi
    fi
    
    # Remove injected code from index.html
    local marker_pattern=$(printf '%s' "$marker" | sed 's/[.]/\\./g')
    sed -i "s|<!-- $marker_pattern start -->[^!]*<!-- $marker_pattern end -->||g;s|<!-- $marker_pattern -->||g" "$UI_DIR/$INDEX_FILE"
    
    if [ "$quiet" != "quiet" ]; then
        print_success "$name uninstalled"
        log "INFO" "Plugin uninstalled: $name"
    fi
}

# ========================== Interactive Menu ==========================

# Select download source
select_source() {
    echo ""
    print_info "Select download source:"
    echo "  1) GitHub direct (Recommended for overseas users)"
    echo "  2) Domestic mirror (ghproxy.net mirror)"
    printf "\nPlease select [1-2] (default 1): "
    read choice
    
    case "$choice" in
        2)
            CURRENT_SOURCE="mirror"
            print_success "Switched to domestic mirror"
            ;;
        *)
            CURRENT_SOURCE="github"
            print_success "Using GitHub direct"
            ;;
    esac
}

# Install menu
install_menu() {
    echo ""
    print_info "Select plugins to install:"
    echo "  1) Install all (except option 2)"
    echo "  2) UI Beautification (emby-crx)【Emby 4.8 compatible】"
    echo "  3) Danmaku plugin (dd-danmaku)"
    echo "  4) External Player (PotPlayer/MPV)"
    echo "  5) Home Swiper (Emby Home Swiper)【Emby 4.9+ compatible】【Emby 4.8 compatible】"
    echo ""
    print_warning "Note: Options 2 and 5 are mutually exclusive, it is recommended to install only one"
    echo "  q) Return to main menu"
    printf "\nPlease select (multiple choices allowed, e.g. 234): "
    read choices
    
    [ "$choices" = "q" ] || [ "$choices" = "Q" ] && return
    
    # Select download source
    select_source
    
    # Backup
    ensure_backup_dir
    create_original_backup
    create_timestamped_backup
    
    # Parse selections
    local install_crx=0
    local install_danmaku=0
    local install_player=0
    local install_swiper=0
    
    case "$choices" in
        *1*) install_crx=0; install_danmaku=1; install_player=1; install_swiper=1 ;;
    esac
    case "$choices" in *2*) install_crx=1 ;; esac
    case "$choices" in *3*) install_danmaku=1 ;; esac
    case "$choices" in *4*) install_player=1 ;; esac
    case "$choices" in *5*) install_swiper=1 ;; esac
    
    # Check mutually exclusive plugins
    if [ "$install_crx" -eq 1 ] && [ "$install_swiper" -eq 1 ]; then
        echo ""
        print_warning "Both【UI Beautification】and【Home Swiper】are selected"
        print_warning "These plugins both modify the home layout, installing both may cause conflicts"
        printf "\nContinue installation? (y/N): "
        read confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "Installation canceled"
            return
        fi
    fi
    
    # Execute installation
    echo ""
    [ "$install_crx" -eq 1 ] && install_plugin "crx"
    [ "$install_danmaku" -eq 1 ] && install_plugin "danmaku"
    [ "$install_player" -eq 1 ] && install_plugin "player"
    [ "$install_swiper" -eq 1 ] && install_plugin "swiper"
    
    echo ""
    print_success "Installation completed! Refresh Emby web page to take effect."
    print_fnos_upgrade_note
}

# Uninstall menu
uninstall_menu() {
    echo ""
    print_info "Select plugins to uninstall:"
    echo "  1) Uninstall all"
    echo "  2) UI Beautification (emby-crx)"
    echo "  3) Danmaku plugin (dd-danmaku)"
    echo "  4) External Player (PotPlayer/MPV)"
    echo "  5) Home Swiper (Emby Home Swiper)"
    echo "  q) Return to main menu"
    printf "\nPlease select (multiple choices allowed, e.g. 234): "
    read choices
    
    [ "$choices" = "q" ] || [ "$choices" = "Q" ] && return
    
    # Backup
    ensure_backup_dir
    create_timestamped_backup
    
    # Parse selections
    local uninstall_crx=0
    local uninstall_danmaku=0
    local uninstall_player=0
    local uninstall_swiper=0
    
    case "$choices" in
        *1*) uninstall_crx=1; uninstall_danmaku=1; uninstall_player=1; uninstall_swiper=1 ;;
    esac
    case "$choices" in *2*) uninstall_crx=1 ;; esac
    case "$choices" in *3*) uninstall_danmaku=1 ;; esac
    case "$choices" in *4*) uninstall_player=1 ;; esac
    case "$choices" in *5*) uninstall_swiper=1 ;; esac
    
    # Execute uninstallation
    echo ""
    [ "$uninstall_crx" -eq 1 ] && uninstall_plugin "crx"
    [ "$uninstall_danmaku" -eq 1 ] && uninstall_plugin "danmaku"
    [ "$uninstall_player" -eq 1 ] && uninstall_plugin "player"
    [ "$uninstall_swiper" -eq 1 ] && uninstall_plugin "swiper"
    
    echo ""
    print_success "Uninstallation completed! Refresh Emby web page to take effect."
    print_fnos_upgrade_note
}

# Backup management menu
backup_menu() {
    echo ""
    print_info "Backup management:"
    echo "  1) List backups"
    echo "  2) Create new backup"
    echo "  3) Restore backup"
    echo "  4) Clean old backups"
    echo "  q) Return to main menu"
    printf "\nPlease select [1-4]: "
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
            print_success "Backup cleanup completed"
            ;;
        q|Q) return ;;
        *) print_error "Invalid option" ;;
    esac
}

# Display help
show_help() {
    echo ""
    print_info "Script usage instructions:"
    echo "----------------------------------------"
    echo "This script is used to manage the installation and uninstallation of Emby web plugins."
    echo ""
    echo "Plugin descriptions:"
    for id in $PLUGIN_LIST; do
        local name=$(get_plugin_attr "$id" "NAME")
        local desc=$(get_plugin_attr "$id" "DESC")
        local project=$(get_plugin_attr "$id" "PROJECT")
        echo "  • $name"
        echo "    $desc"
        echo "    Project: $project"
        echo ""
    done
    echo "Notes:"
    echo "  • index.html will be automatically backed up before installation"
    echo "  • You can restore to previous state at any time via backup"
    echo "  • UI Beautification and Home Swiper plugins are mutually exclusive, it is recommended to install only one"
    echo "  • External Player requires protocol handler installed on the client side"
    echo "----------------------------------------"
}

# Display Banner
show_banner() {
    printf "${CYAN}"
    cat << 'EOF'
  _____ __ _  ___  _  _   ___  __   _   _  ___  _  __  _ ___
 | ____||  V|| o )\ \/ / | o \| |  | | | |/ __|| ||  \| / __|
 | _|  | |\/|| o \ \  /  |  _/| |__| U | | (_ || || | ' \__ \
 |____||_|  ||___/  \/   |_|  |____|___|_|\___||_||_|\__|___/

EOF
    printf "${NC}"
    echo "        Emby Plugin Management Script v${VERSION}"
    echo "        Author:xueayi"
    echo "        Project:https://github.com/xueayi/Emby-Plugin-Quick-Deployment"
    echo "======================================================================="
}

# Main menu
main_menu() {
    while true; do
        echo ""
        show_plugin_status
        echo ""
        print_info "Select operation:"
        echo "  1) Install plugins"
        echo "  2) Uninstall plugins"
        echo "  3) Backup management"
        echo "  4) Set path"
        echo "  5) Help"
        echo "  q) Quit"
        printf "\nPlease select [1-5/q]: "
        read choice
        
        case "$choice" in
            1) install_menu ;;
            2) uninstall_menu ;;
            3) backup_menu ;;
            4) 
                configure_custom_path
                if ! check_environment; then
                    print_error "Invalid path configuration, restored to default"
                    UI_DIR="/system/dashboard-ui"
                    BACKUP_DIR="/system/dashboard-ui/.plugin_backups"
                    UI_DIR_EXPLICIT=0
                    IS_FNOS_NATIVE=0
                    detect_ui_dir
                fi
                ;;
            5) show_help ;;
            q|Q) 
                echo ""
                print_info "Thank you for using, goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option, please select again"
                ;;
        esac
    done
}

# ========================== Command Line Arguments ==========================

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Display help information"
    echo "  -v, --version        Display version information"
    echo "  -s, --status         Display plugin status"
    echo "  --ui-dir <path>      Specify absolute path of index.html directory"
    echo "  --install <ids>      Non-interactively install plugins (comma-separated, e.g. danmaku,player)"
    echo "  --uninstall <ids>    Non-interactively uninstall plugins"
    echo "  --install-all        Non-interactive install all plugins"
    echo "  --uninstall-all      Non-interactive uninstall all plugins"
    echo "  --use-mirror         Use domestic mirror"
    echo ""
    echo "Plugin IDs: $PLUGIN_LIST"
    echo "fnOS native: automatically detects /var/apps/*/target/system/dashboard-ui on the fnOS host;"
    echo "             run with sudo. App upgrades reset plugins; rerun this script afterward."
    echo ""
    echo "Interactive mode: $0"
}

# ========================== Main Entry ==========================

main() {
    # Initialize log
    : > "$LOG_FILE"
    log "INFO" "Script started v$VERSION"
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "Emby Plugin Management Script v$VERSION"
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
                    UI_DIR_EXPLICIT=1
                    print_info "Using custom path: $UI_DIR"
                else
                    print_error "--ui-dir requires a path argument"
                    exit 1
                fi
                shift
                ;;
            --install)
                shift
                if [ -n "$1" ]; then
                    install_selected "$1"
                    exit $?
                else
                    print_error "--install requires plugin IDs (e.g. danmaku,player)"
                    exit 1
                fi
                exit 0
                ;;
            --uninstall)
                shift
                if [ -n "$1" ]; then
                    uninstall_selected "$1"
                    exit $?
                else
                    print_error "--uninstall requires plugin IDs"
                    exit 1
                fi
                exit 0
                ;;
            --use-mirror)
                CURRENT_SOURCE="mirror"
                print_info "Using domestic mirror"
                shift
                ;;
            --install-all)
                install_selected "$PLUGIN_LIST"
                exit $?
                ;;
            --uninstall-all)
                uninstall_selected "$PLUGIN_LIST"
                exit $?
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Environment check
    if ! check_environment; then
        exit 1
    fi

    # Warn when fnOS native mode is not running as root
    if [ "$IS_FNOS_NATIVE" = "1" ] && [ "$(id -u)" != "0" ]; then
        print_warning "Not running as root: fnOS native app files may not be writable, rerun with sudo"
    fi
    
    # Switch to UI directory
    cd "$UI_DIR" || exit 1
    
    # Display banner and enter main menu
    clear
    show_banner
    main_menu
}

# Run main program
main "$@"
