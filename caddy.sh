#!/bin/bash

# ----------------------------------------------------------------------------
# Linux 脚本：安装 Caddy Web 服务器
#
# 功能：
# 1. 检查 /app/caddy/caddy 是否已存在，存在则提示退出或覆盖安装（回车默认退出）。
# 2. 创建 /app/caddy 目录。
# 3. 根据 CPU 架构从指定 URL 下载 caddy 压缩包并解压到 /app/caddy。
# 4. 生成 Caddyfile 和 1.conf 配置文件。
# 5. 创建 systemd 服务文件，并启用、启动 Caddy。
# ----------------------------------------------------------------------------

# 变量定义
INSTALL_DIR="/app/caddy"
SERVICE_FILE="/etc/systemd/system/caddy.service"
SERVICE_NAME="caddy"

# 检查 /app/caddy/caddy 是否存在
if [ -f "$INSTALL_DIR/caddy" ]; then
    echo ">>> 检测到 $INSTALL_DIR/caddy 已存在。"
    read -r -p "是否覆盖安装？输入 y 覆盖安装，直接回车退出 [y/N]: " choice < /dev/tty
    case "$choice" in
        [yY]|[yY][eE][sS])
            echo ">>> 选择覆盖安装，继续执行..."
            if systemctl is-active --quiet "$SERVICE_NAME.service"; then
                echo ">>> 正在停止运行中的 $SERVICE_NAME 服务..."
                systemctl stop "$SERVICE_NAME.service"
            fi
            ;;
        *)
            echo ">>> 已退出安装。"
            exit 0
            ;;
    esac
fi

# 根据 CPU 架构选择下载链接
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        DOWNLOAD_URL="https://github.com/caddyserver/caddy/releases/download/v2.11.9/caddy_2.11.9_linux_amd64.tar.gz"
        ;;
    aarch64|arm64)
        DOWNLOAD_URL="https://github.com/caddyserver/caddy/releases/download/v2.11.9/caddy_2.11.9_linux_arm64.tar.gz"
        ;;
    *)
        echo "!!! 错误：不支持的 CPU 架构: $ARCH"
        exit 1
        ;;
esac

ARCHIVE_FILE=$(basename "$DOWNLOAD_URL")

echo ">>> 脚本开始执行 (检测到架构: $ARCH)..."

# 1. 创建安装目录
echo ">>> 正在创建目录: $INSTALL_DIR"
if ! mkdir -p "$INSTALL_DIR"; then
    echo "!!! 错误：无法创建目录 $INSTALL_DIR。请检查权限。"
    exit 1
fi
echo ">>> 目录 $INSTALL_DIR 创建成功。"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "!!! 错误：无法切换到目录 $INSTALL_DIR。"; exit 1; }

# 2. 下载并解包 Caddy
echo ">>> 正在下载 Caddy: $DOWNLOAD_URL"
if ! wget -O "$ARCHIVE_FILE" "$DOWNLOAD_URL"; then
    echo "!!! 错误：下载文件失败。请检查 URL 或网络连接。"
    exit 1
fi
echo ">>> 文件下载完成。"

echo ">>> 正在解包 Caddy 文件..."
if ! tar -zxf "$ARCHIVE_FILE" -C "$INSTALL_DIR"; then
    echo "!!! 错误：解压文件 $ARCHIVE_FILE 失败。"
    exit 1
fi
rm -f "$ARCHIVE_FILE"
chmod +x "$INSTALL_DIR/caddy"
echo ">>> Caddy 文件解包成功。"

# 检查 caddy 可执行文件是否存在并授权
if [ ! -x "$INSTALL_DIR/caddy" ]; then
    echo "!!! 错误：在 $INSTALL_DIR 中未找到可执行的 Caddy 二进制文件。"
    echo "!!! 请确保下载的文件包含 caddy 可执行文件。"
    exit 1
fi
echo ">>> Caddy 可执行文件找到。"

# 3. 创建 Caddyfile 和 1.conf
echo ">>> 正在生成配置文件: $INSTALL_DIR/Caddyfile"
cat << 'EOF' > "$INSTALL_DIR/Caddyfile"
:80 {
    redir https://{host}{uri}
}
import ./*.conf
EOF

echo ">>> 正在生成配置文件: $INSTALL_DIR/1.conf"
cat << 'EOF' > "$INSTALL_DIR/1.conf"
#www.abc.com {
#    reverse_proxy 127.0.0.1:3000
#}
EOF

# 4. 创建 systemd 服务文件
echo ">>> 正在创建 systemd 服务文件: $SERVICE_FILE"
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Caddy Server
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR/
ExecStart=$INSTALL_DIR/caddy run
ExecReload=$INSTALL_DIR/caddy reload --config $INSTALL_DIR/Caddyfile
ExecStop=$INSTALL_DIR/caddy stop
Restart=on-failure
RestartSec=10
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_RESOURCE

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
    echo "!!! 错误：创建服务文件 $SERVICE_FILE 失败。"
    exit 1
fi
echo ">>> 服务文件 $SERVICE_FILE 创建成功。"

# 重新加载 systemd 配置
echo ">>> 重新加载 systemd 配置..."
if ! systemctl daemon-reload; then
    echo "!!! 错误：systemd daemon-reload 失败。"
    exit 1
fi
echo ">>> systemd 配置重新加载完成。"

# 启用 Caddy 服务 (开机自启)
echo ">>> 正在启用 Caddy 服务 (开机自启)..."
if ! systemctl enable "$SERVICE_NAME.service"; then
    echo "!!! 错误：启用 Caddy 服务失败。"
    exit 1
fi
echo ">>> Caddy 服务已启用。"

# 启动/重启 Caddy 服务
echo ">>> 正在启动 Caddy 服务..."
if ! systemctl restart "$SERVICE_NAME.service"; then
    echo "!!! 错误：启动 Caddy 服务失败。"
    echo ">>> 尝试显示服务状态以帮助诊断问题："
    systemctl status "$SERVICE_NAME.service" --no-pager
    exit 1
fi
echo ">>> Caddy 服务启动成功。"

# 显示服务状态
echo ">>> 正在显示 Caddy 服务状态："
systemctl status "$SERVICE_NAME.service" --no-pager

echo ">>> 脚本执行完毕！"
echo ">>> Caddy 已安装并运行。"
echo ">>> 配置文件位于 $INSTALL_DIR/"
exit 0
