# ============================================================================
# Emby Plugin Manager (Windows PowerShell) v1.0.0
#
# Features: Selective install/uninstall plugins, backup/restore, China mirror
# Author: xueayi
# ============================================================================

param(
    [string]$UiDir,
    [switch]$Status,
    [switch]$InstallAll,
    [switch]$UninstallAll,
    [switch]$UseMirror,
    [switch]$Help,
    [switch]$ShowVersion
)

$VERSION = "1.0.0"

# ========================== Global Config ==========================

$script:UI_DIR = ""
$script:BACKUP_DIR = ""
$script:CURRENT_SOURCE = "github"
$script:MAX_BACKUPS = 5

# ========================== Plugin Definitions ==========================

$PLUGINS = @{
    "crx" = @{
        id="crx"
        name="Interface Theme (emby-crx)"
        desc="Modify Web UI skin"
        dir="emby-crx"
        base_path="Nolovenodie/emby-crx/master"
        files=@("static/css/style.css","static/js/common-utils.js","static/js/jquery-3.6.0.min.js","static/js/md5.min.js","content/main.js")
        marker="emby-crx"
    }
    "danmaku" = @{
        id="danmaku"
        name="Danmaku Plugin (dd-danmaku)"
        desc="Danmaku display"
        dir="dd-danmaku"
        base_path="chen3861229/dd-danmaku/refs/heads/main"
        files=@("ede.js")
        marker="dd-danmaku"
    }
    "player" = @{
        id="player"
        name="External Player (PotPlayer/MPV)"
        desc="Launch local player"
        dir=""
        base_path="bpking1/embyExternalUrl/refs/heads/main"
        files=@("embyWebAddExternalUrl/embyLaunchPotplayer.js")
        marker="externalPlayer.js"
    }
    "swiper" = @{
        id="swiper"
        name="Home Swiper (Emby Home Swiper)"
        desc="Full screen banner"
        dir=""
        base_path="sohag1192/Emby-Home-Swiper-UI/refs/heads/main"
        files=@("v1/home.js")
        marker="home.js"
    }
}
$PLUGIN_LIST = @("crx", "danmaku", "player", "swiper")

# ========================== Utility Functions ==========================

# Display Banner
function Show-Banner{
    Write-Host @"
  _____ __ _  ___  _  _   ___  __   _   _  ___  _  __  _ ___
 | ____||  V|| o )\ \/ / | o \| |  | | | |/ __|| ||  \| / __|
 | _|  | |\/|| o \ \  /  |  _/| |__| U | | (_ || || | ' \__ \
 |____||_|  ||___/  \/   |_|  |____|___|_|\___||_||_|\__|___/

"@ -ForegroundColor Cyan
    Write-Host "        Emby Plugin Management Script v$VERSION"
    Write-Host "        Author: xueayi"
    Write-Host "        Project: https://github.com/xueayi/Emby-Plugin-Quick-Deployment"
    Write-Host "======================================================================="
}

function Print-Info{ param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Print-Success{ param([string]$Message) Write-Host "[ OK ] $Message" -ForegroundColor Green }
function Print-Warning{ param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Print-ErrorMsg{ param([string]$Message) Write-Host "[ERR ] $Message" -ForegroundColor Red }

# Auto-detect Emby dashboard-ui directory
function Get-UI-Dir{
    $paths = @(
        "$env:APPDATA\Emby-Server\system\dashboard-ui",
        "$env:ProgramData\Emby-Server\system\dashboard-ui",
        "C:\Emby\system\dashboard-ui"
    )
    foreach($p in $paths){
        if(Test-Path(Join-Path $p "index.html")){return $p}
    }
    return $null
}

# Detect available download tool (curl/wget/WebClient)
function Get-DownloadTool{
    # Check for real curl/wget (not PowerShell aliases)
    $curl = (Get-Command curl -ErrorAction SilentlyContinue).Source
    $wget = (Get-Command wget -ErrorAction SilentlyContinue).Source
    if($curl -and $curl -notlike "*PowerShell*"){return "curl"}
    if($wget){return "wget"}
    return "webclient"
}

# Download file to specified path
function Download-File([string]$url, [string]$out){
    $finalUrl = $url
    if($script:CURRENT_SOURCE -eq "mirror"){$finalUrl="https://ghproxy.net/$url"}
    $dl = Get-DownloadTool
    
    try{
        if($dl -eq "curl"){
            Start-Process -FilePath "curl" -ArgumentList "-sL","--connect-timeout","30","-o",$out,$finalUrl -Wait -NoNewWindow
        }elseif($dl -eq "wget"){
            Start-Process -FilePath "wget" -ArgumentList "-q","--timeout=30","-O",$out,$finalUrl -Wait -NoNewWindow
        }else{
            # Use WebClient
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($finalUrl, $out)
            $wc.Dispose()
        }
        return (Test-Path $out)
    }catch{
        return $false
    }
}

# ========================== Environment Check ==========================

# Check if environment is ready
function Test-Environment{
    Print-Info "Checking environment..."
    if(!(Test-Path $script:UI_DIR)){Print-ErrorMsg "UI directory not found: $script:UI_DIR";return $false}
    if(!(Test-Path(Join-Path $script:UI_DIR "index.html"))){Print-ErrorMsg "index.html not found";return $false}
    Print-Success "Environment check passed"
    Print-Info "UI directory: $script:UI_DIR"
    return $true
}

# ========================== Backup System ==========================

# Ensure backup directory exists
function Ensure-BackupDir{
    if(!(Test-Path $script:BACKUP_DIR)){New-Item -ItemType Directory -Path $script:BACKUP_DIR -Force|Out-Null}
}

# Create original backup (first backup)
function Create-OriginalBackup{
    $orig = Join-Path $script:BACKUP_DIR "index.html.original"
    if(!(Test-Path $orig)){
        Copy-Item(Join-Path $script:UI_DIR "index.html")$orig -Force
        Print-Info "Created original backup"
    }
}

# Create timestamped backup
function Create-TimestampedBackup{
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $bf = Join-Path $script:BACKUP_DIR "index.html.$ts"
    Copy-Item(Join-Path $script:UI_DIR "index.html")$bf -Force
    Print-Info "Created backup: index.html.$ts"
}

# Get list of backups
function Get-BackupList{
    Ensure-BackupDir
    Write-Host ""
    Print-Info "Available backups:"
    Write-Host "----------------------------------------"
    $idx = 1
    $backupFiles = @()
    
    $orig = Join-Path $script:BACKUP_DIR "index.html.original"
    if(Test-Path $orig){
        $sz = [math]::Round((Get-Item $orig).Length/1KB,2)
        Write-Host "  0) [Original] index.html.original ($sz KB)"
        $backupFiles += @{num=0;path=$orig;n="index.html.original"}
    }
    
    $tsbks = Get-ChildItem -Path $script:BACKUP_DIR -Filter "index.html.2*"|Sort-Object LastWriteTime -Descending
    foreach($f in $tsbks){
        $sz = [math]::Round($f.Length/1KB,2)
        Write-Host "  $idx) $($f.Name) ($sz KB)"
        $backupFiles += @{num=$idx;path=$f.FullName;n=$f.Name}
        $idx++
    }
    
    if($backupFiles.Count -eq 0){Print-Warning "No backups"}
    Write-Host "----------------------------------------"
    return $backupFiles
}

# Restore from backup
function Restore-Backup{
    $bs = Get-BackupList
    if($bs.Count -eq 0){return}
    $ch = Read-Host "`nEnter backup number to restore (0=original, q=cancel)"
    if($ch -eq "q" -or $ch -eq "Q"){return}
    $sel = $bs | Where-Object {$_.num -eq [int]$ch}
    if($sel){
        Copy-Item $sel.path (Join-Path $script:UI_DIR "index.html") -Force
        Print-Success "Restored: $($sel.n)"
    }else{
        Print-ErrorMsg "Invalid number"
    }
}

# Cleanup old backups (keep max 5)
function Cleanup-OldBackups{
    Ensure-BackupDir
    $bs = Get-ChildItem -Path $script:BACKUP_DIR -Filter "index.html.2*"|Sort-Object LastWriteTime -Descending
    $c = $bs.Count
    if($c -gt $script:MAX_BACKUPS){
        $td = $c - $script:MAX_BACKUPS
        for($i=$td;$i -lt $c;$i++){Remove-Item $bs[$i].FullName -Force}
        Print-Info "Cleaned $td old backups"
    }
}

# ========================== Plugin Status ==========================

# Show plugin installation status
function Show-PluginStatus{
    Write-Host ""
    Print-Info "Plugin Status:"
    foreach($i in $PLUGIN_LIST){
        $m = $PLUGINS[$i].marker
        if((Get-Content(Join-Path $script:UI_DIR "index.html")-Raw) -match [regex]::Escape($m)){
            Write-Host "  [Installed] $($PLUGINS[$i].name)" -ForegroundColor Green
        }else{
            Write-Host "  [Not Installed] $($PLUGINS[$i].name)" -ForegroundColor DarkGray
        }
    }
}

# ========================== Core Engine ==========================

# Install plugin
function Install-Plugin([string]$id){
    $p = $PLUGINS[$id]
    Print-Info "Installing: $($p.name)"
    $target = $script:UI_DIR
    
    if($p.dir){
        $dir = Join-Path $script:UI_DIR $p.dir
        if(Test-Path $dir){Remove-Item $dir -Recurse -Force}
        New-Item -ItemType Directory -Path $dir -Force|Out-Null
        $target = $dir
    }
    
    foreach($f in $p.files){
        $name = [System.IO.Path]::GetFileName($f)
        if($id -eq "player"){$name = "externalPlayer.js"}
        elseif($id -eq "swiper"){$name = "home.js"}
        
        $outPath = Join-Path $target $name
        $url = "https://raw.githubusercontent.com/$($p.base_path)/$f"
        Write-Host "  Downloading $name... " -NoNewline -ForegroundColor Cyan
        
        if(Download-File $url $outPath){
            Write-Host "OK" -ForegroundColor Green
        }else{
            Write-Host "FAILED" -ForegroundColor Red
        }
    }
    
    $c = Get-Content(Join-Path $script:UI_DIR "index.html")-Raw
    $mk = $p.marker
    
    if($id -eq "player"){
        $inj = '<script src="externalPlayer.js" defer></script>'
        if($c -match "apploader"){
            $c = $c -replace "(apploader.*)", "`$1`n<!-- $mk --> $inj <!-- $mk -->"
        }else{
            $c = $c -replace "</body>", "<!-- $mk --> $inj <!-- $mk --></body>"
        }
    }else{
        if($id -eq "crx"){
            $inj = '<link rel="stylesheet" href="emby-crx/style.css" type="text/css"/><script src="emby-crx/jquery-3.6.0.min.js"></script><script src="emby-crx/md5.min.js"></script><script src="emby-crx/common-utils.js"></script><script src="emby-crx/main.js"></script>'
        }elseif($id -eq "danmaku"){
            $inj = '<script src="dd-danmaku/ede.js"></script>'
        }elseif($id -eq "swiper"){
            $inj = '<script src="home.js"></script>'
        }
        
        if($c -match "</head>"){
            $c = $c -replace "</head>", "<!-- $mk --> $inj</head>"
        }else{
            $c = $c -replace "<body", "<!-- $mk --> $inj`n<body"
        }
    }
    
    $c|Out-File(Join-Path $script:UI_DIR "index.html") -Encoding UTF8
    Print-Success "$($p.name) installation completed"
}

# Uninstall plugin
function Uninstall-Plugin([string]$id){
    $p = $PLUGINS[$id]
    Print-Info "Uninstalling: $($p.name)"
    
    if($p.dir){
        $dirPath = Join-Path $script:UI_DIR $p.dir
        if(Test-Path $dirPath){
            Remove-Item $dirPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }else{
        if($id -eq "player"){
            $fPath = Join-Path $script:UI_DIR "externalPlayer.js"
            if(Test-Path $fPath){Remove-Item $fPath -Force -ErrorAction SilentlyContinue}
        }elseif($id -eq "swiper"){
            $fPath = Join-Path $script:UI_DIR "home.js"
            if(Test-Path $fPath){Remove-Item $fPath -Force -ErrorAction SilentlyContinue}
        }
    }
    
    $c = Get-Content(Join-Path $script:UI_DIR "index.html")|Where-Object{$_ -notmatch $p.marker}
    $c|Out-File(Join-Path $script:UI_DIR "index.html") -Encoding UTF8
    Print-Success "$($p.name) uninstalled"
}

# ========================== Help & Menu ==========================

# Show help information
function Show-Help{
    Write-Host ""
    Write-Host "Emby Plugin Manager v$VERSION" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Print-Info "Plugin Description:"
    foreach($i in $PLUGIN_LIST){
        $p = $PLUGINS[$i]
        Write-Host "  * $($p.name)"
        Write-Host "    $($p.desc)"
    }
    Write-Host ""
    Print-Warning "Notes:"
    Write-Host "  - Backup will be created automatically before install"
    Write-Host "  - Can restore from backup anytime"
    Write-Host "  - Interface Theme and Home Swiper are conflicting"
    Write-Host ""
    Print-Info "Options:"
    Write-Host "  -UiDir <path>     Specify Emby dashboard-ui directory"
    Write-Host "  -Status           Show plugin status"
    Write-Host "  -InstallAll       Install all plugins"
    Write-Host "  -UninstallAll     Uninstall all plugins"
    Write-Host "  -UseMirror        Use China mirror (ghproxy.net)"
    Write-Host "  -Help             Show this help"
    Write-Host "  -Version          Show version"
    Write-Host ""
    Write-Host "Interactive: Run script without parameters"
    Write-Host ""
}

# Install plugin menu
function Install-Menu{
    while($true){
        Write-Host ""
        Write-Host "Select plugins to install:"
        Write-Host "  1) Install ALL (not include 2)"
        Write-Host "  2) Interface Theme (emby-crx) [Emby 4.8]"
        Write-Host "  3) Danmaku Plugin (dd-danmaku)"
        Write-Host "  4) External Player (PotPlayer/MPV)"
        Write-Host "  5) Home Swiper (Emby Home Swiper) [Emby 4.9+]"
        Write-Host ""
        Print-Warning "Note: Options 2 and 5 are conflicting, recommend choose one"
        Write-Host "  q) Return to main menu"
        
        $choices = Read-Host "`nSelect (multi-select, e.g. 234)"
        
        if($choices -eq "q" -or $choices -eq "Q"){return}
        
        # Select source
        Write-Host ""
        Write-Host "Select download source:"
        Write-Host "  1) GitHub Direct (Recommended for overseas)"
        Write-Host "  2) China Mirror (ghproxy.net)"
        $src = Read-Host "`nSelect [1-2] (default: 1)"
        if($src -eq "2"){$script:CURRENT_SOURCE = "mirror";Print-Success "Using China mirror"}else{$script:CURRENT_SOURCE = "github";Print-Success "Using GitHub"}
        
        # Backup
        Ensure-BackupDir
        Create-OriginalBackup
        Create-TimestampedBackup
        
        # Parse choice
        $todo = @()
        if($choices -match "1"){$todo += @("danmaku","player","swiper")}
        if($choices -match "2"){$todo += "crx"}
        if($choices -match "3"){$todo += "danmaku"}
        if($choices -match "4"){$todo += "player"}
        if($choices -match "5"){$todo += "swiper"}
        
        # Check conflict
        if($todo -contains "crx" -and $todo -contains "swiper"){
            Write-Host ""
            Print-Warning "Both Interface Theme and Home Swiper selected!"
            Print-Warning "These two plugins modify homepage layout, may cause conflicts"
            $confirm = Read-Host "Continue anyway? (y/N)"
            if($confirm -ne "y" -and $confirm -ne "Y"){Print-Info "Cancelled";return}
        }
        
        # Install
        Write-Host ""
        foreach($pluginId in $todo){Install-Plugin $pluginId}
        
        Write-Host ""
        Print-Success "Installation complete! Refresh Emby web to see changes."
        Read-Host "Press Enter to continue..."
        return
    }
}

# Uninstall plugin menu
function Uninstall-Menu{
    while($true){
        Write-Host ""
        Write-Host "Select plugins to uninstall:"
        Write-Host "  1) Uninstall ALL"
        Write-Host "  2) Interface Theme (emby-crx)"
        Write-Host "  3) Danmaku Plugin (dd-danmaku)"
        Write-Host "  4) External Player (PotPlayer/MPV)"
        Write-Host "  5) Home Swiper (Emby Home Swiper)"
        Write-Host "  q) Return to main menu"
        
        $choices = Read-Host "`nSelect (multi-select, e.g. 234)"
        
        if($choices -eq "q" -or $choices -eq "Q"){return}
        
        # Backup
        Ensure-BackupDir
        Create-TimestampedBackup
        
        # Parse choice
        $todo = @()
        if($choices -match "1"){$todo += @("crx","danmaku","player","swiper")}
        if($choices -match "2"){$todo += "crx"}
        if($choices -match "3"){$todo += "danmaku"}
        if($choices -match "4"){$todo += "player"}
        if($choices -match "5"){$todo += "swiper"}
        
        # Uninstall
        Write-Host ""
        foreach($pluginId in $todo){Uninstall-Plugin $pluginId}
        
        Write-Host ""
        Print-Success "Uninstallation complete! Refresh Emby web to see changes."
        Read-Host "Press Enter to continue..."
        return
    }
}

# Backup management menu
function Backup-Menu{
    while($true){
        Write-Host ""
        Write-Host "Backup Management:"
        Write-Host "  1) List backups"
        Write-Host "  2) Create new backup"
        Write-Host "  3) Restore backup"
        Write-Host "  4) Clean old backups"
        Write-Host "  q) Return to main menu"
        
        $choice = Read-Host "`nSelect [1-4]"
        
        switch($choice){
            "1"{
                Get-BackupList | Out-Null
                Read-Host "Press Enter to continue..."
            }
            "2"{
                Ensure-BackupDir
                Create-TimestampedBackup
                Print-Success "Backup created"
                Read-Host "Press Enter to continue..."
            }
            "3"{
                Restore-Backup
                Read-Host "Press Enter to continue..."
            }
            "4"{
                Cleanup-OldBackups
                Print-Success "Cleanup complete"
                Read-Host "Press Enter to continue..."
            }
            {"q","Q"}{return}
            default{Print-ErrorMsg "Invalid option";Start-Sleep 1}
        }
    }
}

# ========================== Main Program ==========================

# Main function
function Main{
    if($Help){Show-Help;exit}
    if($ShowVersion){Print-Info "Emby Plugin Manager v$VERSION";exit}
    
    if($UiDir){
        $script:UI_DIR = $UiDir
    }else{
        $script:UI_DIR = Get-UI-Dir
    }
    
    if(!$script:UI_DIR){
        $script:UI_DIR = Read-Host "Enter Emby dashboard-ui directory path:"
    }
    
    $script:BACKUP_DIR = Join-Path $script:UI_DIR ".plugin_backups"
    
    if(!(Test-Environment)){exit}
    
    if($UseMirror){$script:CURRENT_SOURCE = "mirror";Print-Info "Using China mirror"}
    
    if($Status){
        Show-PluginStatus
        exit
    }
    
    if($InstallAll){
        Ensure-BackupDir
        Create-OriginalBackup
        Create-TimestampedBackup
        foreach($i in $PLUGIN_LIST){Install-Plugin $i}
        Print-Success "All plugins installed"
        exit
    }
    
    if($UninstallAll){
        foreach($i in $PLUGIN_LIST){Uninstall-Plugin $i}
        Print-Success "All plugins uninstalled"
        exit
    }
    
    while($true){
        Clear-Host
        Show-Banner
        Write-Host ""
        Show-PluginStatus
        Write-Host ""
        Print-Info "Select operation:"
        Write-Host "  1) Install plugins"
        Write-Host "  2) Uninstall plugins"
        Write-Host "  3) Backup Management"
        Write-Host "  4) Help"
        Write-Host "  q) Quit"
        
        $ch = Read-Host "`nSelect [1-4/q]"
        
        switch($ch){
            "1"{ Install-Menu }
            "2"{ Uninstall-Menu }
            "3"{ Backup-Menu }
            "4"{ Show-Help; Read-Host "Press Enter to continue..." }
            {"q","Q"}{
                Print-Info "Goodbye!"
                exit
            }
            default{
                Print-ErrorMsg "Invalid option"
                Start-Sleep 1
            }
        }
    }
}

Main
