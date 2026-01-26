# Emby 插件管理脚本 - 开发文档

本文档介绍 `install_plugins.sh` 脚本的架构设计与扩展指南，帮助开发者理解代码结构并添加新插件。

---

## 项目结构

```
Emby-Plugin-Quick-Deployment/
├── install_plugins.sh          # 主安装脚本
├── README.md                   # 用户使用文档
├── DEVELOPMENT.md              # 开发者文档 (本文件)
└── emby插件手动安装方法和说明.md  # 手动安装参考
```

---

## 脚本架构

脚本采用**模块化设计**，主要分为以下几个区块：

```mermaid
graph TB
    subgraph 配置层
        A[全局配置] --> B[插件定义]
    end
    
    subgraph 核心层
        C[工具函数] --> D[环境检测]
        D --> E[备份系统]
        E --> F1[Web 下载引擎]
        E --> F2[DLL 下载引擎]
        F1 --> G1[Web 注入逻辑]
        F2 --> G2[DLL 部署逻辑]
    end
    
    subgraph 交互层
        H[主菜单] --> I[安装菜单]
        H --> J[卸载菜单]
        H --> K[备份菜单]
        H --> K2[路径配置]
    end
    
    subgraph 入口层
        L[命令行参数解析] --> M[main 函数]
    end
    
    配置层 --> 核心层
    核心层 --> 交互层
    
### 代码区块说明

| 区块 | 说明 |
|------|------|
| 全局配置 | 版本、路径、颜色代码、DLL 插件路径等 |
| 插件定义 | 各插件的配置变量，分为 `web` 和 `dll` 类型 |
| 工具函数 | 日志、输出、普通下载、**GitHub Release 链接解析**等 |
| 环境检测 | 检查 UI 目录、插件目录、权限、依赖 |
| 备份系统 | 创建、列出、恢复 Web UI 备份 |
| 插件操作 | **分发器逻辑**，分别处理 Web 注入和 DLL 部署 |
| 交互菜单 | 用户界面与输入处理，包含路径实时配置 |
| 命令行参数 | 非交互式选项支持，新增针对 DLL 的参数 |

---

## 🔌 添加新插件

### 步骤 1: 定义插件变量

根据插件类型选择对应的模板：

#### A. Web 端插件 (修改 index.html)
```sh
PLUGIN_NAME_ID="id"
PLUGIN_NAME_TYPE="web"
PLUGIN_NAME_NAME="显示名称"
PLUGIN_NAME_DESC="描述"
PLUGIN_NAME_DIR="dir-name"
PLUGIN_NAME_FILES="file.js"
PLUGIN_NAME_BASE_PATH="owner/repo/branch"
PLUGIN_NAME_MARKER="marker-string"
```

#### B. 服务器端插件 (DLL)
```sh
PLUGIN_NAME_ID="id"
PLUGIN_NAME_TYPE="dll"
PLUGIN_NAME_NAME="显示名称"
PLUGIN_NAME_DESC="描述"
PLUGIN_NAME_RELEASE_API="owner/repo"        # 用于检测最新 Release
PLUGIN_NAME_DLL_PATTERN="match-string.dll"   # 下载链接中 DLL 文件的匹配词
PLUGIN_NAME_MARKER="match-string"            # 用于安装检测的关键词
```

### 步骤 2: 注册到插件列表

修改 `PLUGIN_LIST` 及分类列表：

```sh
PLUGIN_LIST="... newplugin"
WEB_PLUGIN_LIST="..."        # 如果是 web 类型
DLL_PLUGIN_LIST="..."        # 如果是 dll 类型
```

### 步骤 3: 更新菜单选项

修改 `install_menu()` 和 `uninstall_menu()` 函数：

```sh
install_menu() {
    # ... 添加新选项
    echo "  5) 新插件名称"
    
    # ... 添加解析逻辑
    case "$choices" in *5*) install_newplugin=1 ;; esac
    
    # ... 添加安装调用
    [ "$install_newplugin" -eq 1 ] && install_plugin "newplugin"
}
```

### 步骤 4: 测试

```bash
# 语法检查
sh -n install_plugins.sh

# 功能测试
./install_plugins.sh --status
./install_plugins.sh  # 交互式测试
```

---

## 配置参考

### 插件变量命名规范

```
PLUGIN_<ID>_<属性>

ID: 插件唯一标识 (大写)
属性:
  - ID        : 小写标识符
  - TYPE      : 插件类型 (`web` 或 `dll`)
  - NAME      : 显示名称
  - DESC      : 功能描述
  - DIR       : [Web] 存放目录
  - PROJECT   : 项目地址
  - FILES     : [Web] 需下载的文件列表
  - BASE_PATH : [Web] GitHub 文件根路径
  - INJECT_*  : [Web] 注入代码
  - RELEASE_API: [DLL] GitHub 仓库标识 (owner/repo)
  - DLL_PATTERN: [DLL] 文件名匹配模式
  - MARKER    : 环境检测用的关键词
```

### 下载源切换

```sh
# 全局变量
GITHUB_RAW="https://raw.githubusercontent.com"      # GitHub 直连
MIRROR_GHPROXY="https://mirror.ghproxy.com"         # 国内镜像

# 下载函数会自动拼接
download_file() {
    if [ "$CURRENT_SOURCE" = "mirror" ]; then
        url="${MIRROR_GHPROXY}/${url}"
    fi
    ...
}
```

### 备份策略配置

```sh
MAX_BACKUPS=5                # 保留的最大备份数量
BACKUP_DIR="./system/dashboard-ui/.plugin_backups"  # 备份存放目录
```

---

## 调试指南

### 启用调试输出

```bash
# 在脚本开头添加
set -x  # 显示执行的每条命令
```

### 查看日志

```bash
cat /tmp/emby_plugin_install.log
```

### 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 下载失败 | 网络问题 / URL 错误 | 使用 `--use-mirror` 或检查 `BASE_PATH` |
| 注入无效 | sed 语法问题 | 检查 `INJECT_*` 中的特殊字符转义 |
| 插件不生效 | 浏览器缓存 | 清除缓存或使用无痕模式 |

---

## Shell 兼容性说明

脚本设计为 **POSIX sh 兼容**，避免使用 Bash 特有语法：

| 避免 | 使用 |
|---------|---------|
| `$((array[@]))` | 空格分隔的字符串 |
| `[[ ... ]]` | `[ ... ]` |
| `function name()` | `name()` |
| `${var,,}` | `echo "$var" \| tr '[:upper:]' '[:lower:]'` |
| `$'...'` | `printf '...'` |

---

## 版本更新

修改版本号时更新以下位置：

1. 脚本顶部注释: `# Emby 插件管理脚本 v1.x.x`
2. `VERSION` 变量: `VERSION="1.x.x"`

---

## 联系与贡献

- **项目地址**: https://github.com/xueayi/Emby-Plugin-Quick-Deployment
- **问题反馈**: [GitHub Issues](https://github.com/xueayi/Emby-Plugin-Quick-Deployment/issues)
- **贡献代码**: Fork → Modify → Pull Request
