# ============================================================================
# Emby 插件管理脚本 (Windows PowerShell 版) v1.0.0
#
# 功能: 选择性安装/卸载插件、备份恢复、国内加速源
# 作者: xueayi
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

# ========================== 全局配置 ==========================

$script:UI_DIR = ""
$script:BACKUP_DIR = ""
$script:CURRENT_SOURCE = "github"
$script:MAX_BACKUPS = 5

# ========================== 插件定义 ==========================

$PLUGINS = @{
    "crx" = @{
        id="crx"
        name="[CN]界面美化 (emby-crx)"
        desc="修改网页端皮肤"
        dir="emby-crx"
        base_path="Nolovenodie/emby-crx/master"
        files=@("static/css/style.css","static/js/common-utils.js","static/js/jquery-3.6.0.min.js","static/js/md5.min.js","content/main.js")
        marker="emby-crx"
    }
    "danmaku" = @{
        id="danmaku"
        name="[CN]弹幕插件 (dd-danmaku)"
        desc="播放器弹幕显示"
        dir="dd-danmaku"
        base_path="chen3861229/dd-danmaku/refs/heads/main"
        files=@("ede.js")
        marker="dd-danmaku"
    }
    "player" = @{
        id="player"
        name="[CN]外部播放器 (PotPlayer/MPV)"
        desc="调用本地播放器"
        dir=""
        base_path="bpking1/embyExternalUrl/refs/heads/main"
        files=@("embyWebAddExternalUrl/embyLaunchPotplayer.js")
        marker="externalPlayer.js"
    }
    "swiper" = @{
        id="swiper"
        name="[CN]首页轮播 (Emby Home Swiper)"
        desc="全屏轮播横幅"
        dir=""
        base_path="sohag1192/Emby-Home-Swiper-UI/refs/heads/main"
        files=@("v1/home.js")
        marker="home.js"
    }
}
$PLUGIN_LIST = @("crx", "danmaku", "player", "swiper")

# ========================== 工具函数 ==========================

# 显示 Banner
function Show-Banner{
    Write-Host @"
  _____ __ _  ___  _  _   ___  __   _   _  ___  _  __  _ ___
 | ____||  V|| o )\ \/ / | o \| |  | | | |/ __|| ||  \| / __|
 | _|  | |\/|| o \ \  /  |  _/| |__| U | | (_ || || | ' \__ \
 |____||_|  ||___/  \/   |_|  |____|___|_|\___||_||_|\__|___/

"@ -ForegroundColor Cyan
    Write-Host "        Emby 插件管理脚本 v$VERSION"
    Write-Host "        作者: xueayi"
    Write-Host "        项目: https://github.com/xueayi/Emby-Plugin-Quick-Deployment"
    Write-Host "======================================================================="
}

function Print-Info{ param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Print-Success{ param([string]$Message) Write-Host "[ OK ] $Message" -ForegroundColor Green }
function Print-Warning{ param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Print-ErrorMsg{ param([string]$Message) Write-Host "[ERR ] $Message" -ForegroundColor Red }

# 自动检测 Emby dashboard-ui 目录
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

# 检测可用的下载工具 (curl/wget/WebClient)
function Get-DownloadTool{
    # Check for real curl/wget (not PowerShell aliases)
    $curl = (Get-Command curl -ErrorAction SilentlyContinue).Source
    $wget = (Get-Command wget -ErrorAction SilentlyContinue).Source
    if($curl -and $curl -notlike "*PowerShell*"){return "curl"}
    if($wget){return "wget"}
    return "webclient"
}

# 下载文件到指定路径
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

# ========================== 环境检测 ==========================

# 检测运行环境是否正常
function Test-Environment{
    Print-Info "检测运行环境..."
    if(!(Test-Path $script:UI_DIR)){Print-ErrorMsg "未找到Emby UI目录: $script:UI_DIR";return $false}
    if(!(Test-Path(Join-Path $script:UI_DIR "index.html"))){Print-ErrorMsg "未找到index.html";return $false}
    Print-Success "环境检测通过"
    Print-Info "UI目录: $script:UI_DIR"
    return $true
}

# ========================== 备份系统 ==========================

# 确保备份目录存在
function Ensure-BackupDir{
    if(!(Test-Path $script:BACKUP_DIR)){New-Item -ItemType Directory -Path $script:BACKUP_DIR -Force|Out-Null}
}

# 创建原始备份 (首次备份)
function Create-OriginalBackup{
    $orig = Join-Path $script:BACKUP_DIR "index.html.original"
    if(!(Test-Path $orig)){
        Copy-Item(Join-Path $script:UI_DIR "index.html")$orig -Force
        Print-Info "已创建原始备份"
    }
}

# 创建时间戳备份
function Create-TimestampedBackup{
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $bf = Join-Path $script:BACKUP_DIR "index.html.$ts"
    Copy-Item(Join-Path $script:UI_DIR "index.html")$bf -Force
    Print-Info "已创建备份: index.html.$ts"
}

# 获取备份列表
function Get-BackupList{
    Ensure-BackupDir
    Write-Host ""
    Print-Info "可用备份列表:"
    Write-Host "----------------------------------------"
    $idx = 1
    $backupFiles = @()
    
    $orig = Join-Path $script:BACKUP_DIR "index.html.original"
    if(Test-Path $orig){
        $sz = [math]::Round((Get-Item $orig).Length/1KB,2)
        Write-Host "  0) [原始] index.html.original ($sz KB)"
        $backupFiles += @{num=0;path=$orig;n="index.html.original"}
    }
    
    $tsbks = Get-ChildItem -Path $script:BACKUP_DIR -Filter "index.html.2*"|Sort-Object LastWriteTime -Descending
    foreach($f in $tsbks){
        $sz = [math]::Round($f.Length/1KB,2)
        Write-Host "  $idx) $($f.Name) ($sz KB)"
        $backupFiles += @{num=$idx;path=$f.FullName;n=$f.Name}
        $idx++
    }
    
    if($backupFiles.Count -eq 0){Print-Warning "暂无备份"}
    Write-Host "----------------------------------------"
    return $backupFiles
}

# 恢复备份
function Restore-Backup{
    $bs = Get-BackupList
    if($bs.Count -eq 0){return}
    $ch = Read-Host "`n请输入要恢复的备份编号 (0=原始, q=取消)"
    if($ch -eq "q" -or $ch -eq "Q"){return}
    $sel = $bs | Where-Object {$_.num -eq [int]$ch}
    if($sel){
        Copy-Item $sel.path (Join-Path $script:UI_DIR "index.html") -Force
        Print-Success "已恢复: $($sel.n)"
    }else{
        Print-ErrorMsg "无效的编号"
    }
}

# 清理旧备份 (保留最多5个)
function Cleanup-OldBackups{
    Ensure-BackupDir
    $bs = Get-ChildItem -Path $script:BACKUP_DIR -Filter "index.html.2*"|Sort-Object LastWriteTime -Descending
    $c = $bs.Count
    if($c -gt $script:MAX_BACKUPS){
        $td = $c - $script:MAX_BACKUPS
        for($i=$td;$i -lt $c;$i++){Remove-Item $bs[$i].FullName -Force}
        Print-Info "已清理 $td 个旧备份"
    }
}

# ========================== 插件状态 ==========================

# 显示插件安装状态
function Show-PluginStatus{
    Write-Host ""
    Print-Info "插件状态:"
    foreach($i in $PLUGIN_LIST){
        $m = $PLUGINS[$i].marker
        if((Get-Content(Join-Path $script:UI_DIR "index.html")-Raw) -match [regex]::Escape($m)){
            Write-Host "  [已安装] $($PLUGINS[$i].name)" -ForegroundColor Green
        }else{
            Write-Host "  [未安装] $($PLUGINS[$i].name)" -ForegroundColor DarkGray
        }
    }
}

# ========================== 核心引擎 ==========================

# 安装插件
function Install-Plugin([string]$id){
    $p = $PLUGINS[$id]
    Print-Info "正在安装: $($p.name)"
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
        Write-Host "  正在下载 $name... " -NoNewline -ForegroundColor Cyan
        
        if(Download-File $url $outPath){
            Write-Host "成功" -ForegroundColor Green
        }else{
            Write-Host "失败" -ForegroundColor Red
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
    Print-Success "$($p.name) 安装完成"
}

# 卸载插件
function Uninstall-Plugin([string]$id){
    $p = $PLUGINS[$id]
    Print-Info "正在卸载: $($p.name)"
    
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
    Print-Success "$($p.name) 已卸载"
}

# ========================== 帮助与菜单 ==========================

# 显示帮助信息
function Show-Help{
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Emby 插件管理脚本 v$VERSION" -ForegroundColor Cyan
    Write-Host "  作者: xueayi" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Print-Info "插件说明:"
    foreach($i in $PLUGIN_LIST){
        $p = $PLUGINS[$i]
        Write-Host "  * $($p.name)"
        Write-Host "    $($p.desc)"
    }
    Write-Host ""
    Print-Warning "注意事项:"
    Write-Host "  - 安装前会会自动备份index.html"
    Write-Host "  - 可随时通过备份恢复到之前状态"
    Write-Host "  - 界面美化和首页轮播插件互斥"
    Write-Host ""
    Print-Info "命令行选项:"
    Write-Host "  -UiDir <路径>     指定Emby dashboard-ui目录"
    Write-Host "  -Status           显示插件状态"
    Write-Host "  -InstallAll       安装所有插件"
    Write-Host "  -UninstallAll     卸载所有插件"
    Write-Host "  -UseMirror        使用国内加速源(ghproxy.net)"
    Write-Host "  -Help             显示帮助"
    Write-Host "  -Version          显示版本"
    Write-Host ""
    Write-Host "交互式运行: 执行脚本"
    Write-Host ""
}

# 安装插件菜单
function Install-Menu{
    while($true){
        Write-Host ""
        Write-Host "选择要安装的插件:"
        Write-Host "  1) 全部安装(不包括2)"
        Write-Host "  2) 界面美化 (emby-crx) [Emby 4.8]"
        Write-Host "  3) 弹幕插件 (dd-danmaku)"
        Write-Host "  4) 外部播放器 (PotPlayer/MPV)"
        Write-Host "  5) 首页轮播 (Emby Home Swiper) [Emby 4.9+]"
        Write-Host ""
        Print-Warning "注意: 选项2和5互斥,建议只安装其中一个"
        Write-Host "  q) 返回主菜单"
        
        $choices = Read-Host "`n请选择 (可多选, 如 234)"
        
        if($choices -eq "q" -or $choices -eq "Q"){return}
        
        # Select source
        Write-Host ""
        Write-Host "选择下载源:"
        Write-Host "  1) GitHub直连 (海外用户推荐)"
        Write-Host "  2) 国内加速 (ghproxy.net)"
        $src = Read-Host "`n请选择 [1-2] (默认 1)"
        if($src -eq "2"){$script:CURRENT_SOURCE = "mirror";Print-Success "使用国内加速源"}else{$script:CURRENT_SOURCE = "github";Print-Success "使用GitHub直连"}
        
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
            Print-Warning "同时选择了【界面美化】和【首页轮播】"
            Print-Warning "这两个插件会修改首页布局,可能导致冲突"
            $confirm = Read-Host "是否继续? (y/N)"
            if($confirm -ne "y" -and $confirm -ne "Y"){Print-Info "已取消";return}
        }
        
        # Install
        Write-Host ""
        foreach($pluginId in $todo){Install-Plugin $pluginId}
        
        Write-Host ""
        Print-Success "安装完成! 刷新Emby网页即可生效."
        Read-Host "按回车键继续..."
        return
    }
}

# 卸载插件菜单
function Uninstall-Menu{
    while($true){
        Write-Host ""
        Write-Host "选择要卸载的插件:"
        Write-Host "  1) 全部卸载"
        Write-Host "  2) 界面美化 (emby-crx)"
        Write-Host "  3) 弹幕插件 (dd-danmaku)"
        Write-Host "  4) 外部播放器 (PotPlayer/MPV)"
        Write-Host "  5) 首页轮播 (Emby Home Swiper)"
        Write-Host "  q) 返回主菜单"
        
        $choices = Read-Host "`n请选择 (可多选, 如 234)"
        
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
        Print-Success "卸载完成! 刷新Emby网页即可生效."
        Read-Host "按回车键继续..."
        return
    }
}

# 备份管理菜单
function Backup-Menu{
    while($true){
        Write-Host ""
        Write-Host "备份管理:"
        Write-Host "  1) 查看备份列表"
        Write-Host "  2) 创建新备份"
        Write-Host "  3) 恢复备份"
        Write-Host "  4) 清理旧备份"
        Write-Host "  q) 返回主菜单"
        
        $choice = Read-Host "`n请选择 [1-4]"
        
        switch($choice){
            "1"{
                Get-BackupList | Out-Null
                Read-Host "按回车键继续..."
            }
            "2"{
                Ensure-BackupDir
                Create-TimestampedBackup
                Print-Success "备份已创建"
                Read-Host "按回车键继续..."
            }
            "3"{
                Restore-Backup
                Read-Host "按回车键继续..."
            }
            "4"{
                Cleanup-OldBackups
                Print-Success "清理完成"
                Read-Host "按回车键继续..."
            }
            {"q","Q"}{return}
            default{Print-ErrorMsg "无效选项";Start-Sleep 1}
        }
    }
}

# ========================== 主程序 ==========================

# 主函数
function Main{
    if($Help){Show-Help;exit}
    if($ShowVersion){Print-Info "Emby 插件管理脚本 v$VERSION";exit}
    
    if($UiDir){
        $script:UI_DIR = $UiDir
    }else{
        $script:UI_DIR = Get-UI-Dir
    }
    
    if(!$script:UI_DIR){
        $script:UI_DIR = Read-Host "请输入Emby dashboard-ui目录路径:"
    }
    
    $script:BACKUP_DIR = Join-Path $script:UI_DIR ".plugin_backups"
    
    if(!(Test-Environment)){exit}
    
    if($UseMirror){$script:CURRENT_SOURCE = "mirror";Print-Info "使用国内加速源"}
    
    if($Status){
        Show-PluginStatus
        exit
    }
    
    if($InstallAll){
        Ensure-BackupDir
        Create-OriginalBackup
        Create-TimestampedBackup
        foreach($i in $PLUGIN_LIST){Install-Plugin $i}
        Print-Success "所有插件已安装"
        exit
    }
    
    if($UninstallAll){
        foreach($i in $PLUGIN_LIST){Uninstall-Plugin $i}
        Print-Success "所有插件已卸载"
        exit
    }
    
    while($true){
        Clear-Host
        Show-Banner
        Write-Host ""
        Show-PluginStatus
        Write-Host ""
        Print-Info "请选择操作:"
        Write-Host "  1) 安装插件"
        Write-Host "  2) 卸载插件"
        Write-Host "  3) 备份管理"
        Write-Host "  4) 帮助说明"
        Write-Host "  q) 退出"
        
        $ch = Read-Host "`n请选择 [1-4/q]"
        
        switch($ch){
            "1"{ Install-Menu }
            "2"{ Uninstall-Menu }
            "3"{ Backup-Menu }
            "4"{ Show-Help; Read-Host "按回车键继续..." }
            {"q","Q"}{
                Print-Info "感谢使用,再见!"
                exit
            }
            default{
                Print-ErrorMsg "无效选项"
                Start-Sleep 1
            }
        }
    }
}

Main
