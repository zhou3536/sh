#!/bin/bash

# 1. 检测系统架构
echo "Checking system architecture..."
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_SUFFIX="amd64"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="arm64"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH. Only amd64 (x86_64) and arm64 (aarch64) are supported."
        exit 1
        ;;
esac
echo "Detected architecture: $ARCH ($ARCH_SUFFIX)"

# 2. 创建 /app/openlist 文件夹
echo "Creating directory /app/openlist..."
mkdir -p /app/openlist
if [ $? -ne 0 ]; then
    echo "Error: Failed to create directory /app/openlist. Please check permissions."
    exit 1
fi
echo "Directory /app/openlist created successfully."

# 3. 下载并解压 OpenList
echo "Downloading and extracting OpenList..."
DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-${ARCH_SUFFIX}.tar.gz"
ARCHIVE_NAME="openlist-linux-${ARCH_SUFFIX}.tar.gz"
EXTRACT_DIR="/app/openlist"

# 下载文件
echo "Downloading from: $DOWNLOAD_URL"
wget -qO "$ARCHIVE_NAME" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download OpenList. Please check your internet connection and the URL."
    exit 1
fi
echo "Download complete."

# 解压文件
echo "Extracting $ARCHIVE_NAME to $EXTRACT_DIR..."
tar -xzf "$ARCHIVE_NAME" -C "$EXTRACT_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract OpenList archive. Make sure the archive is valid."
    rm -f "$ARCHIVE_NAME" # 清理下载的文件
    exit 1
fi
echo "Extraction complete."

# 清理下载的压缩包
rm -f "$ARCHIVE_NAME"

# 确保解压出的可执行文件具有执行权限
OPENLIST_EXECUTABLE="$EXTRACT_DIR/openlist"
if [ -f "$OPENLIST_EXECUTABLE" ]; then
    chmod +x "$OPENLIST_EXECUTABLE"
    echo "Set execute permission for $OPENLIST_EXECUTABLE."
else
    echo "Warning: OpenList executable not found at $OPENLIST_EXECUTABLE after extraction. Please check the archive contents."
fi

# 4. 创建 systemctl 服务
SERVICE_FILE="/etc/systemd/system/openlist.service"
echo "Creating systemctl service file: $SERVICE_FILE"

# 使用 cat << EOF 来创建文件内容
bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=OpenList Service
After=network.target

[Service]
ExecStart=/app/openlist/openlist server
WorkingDirectory=/app/openlist
Restart=on-failure
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to create systemctl service file $SERVICE_FILE. Please check permissions."
    exit 1
fi
echo "Systemctl service file created."

# 重新加载 systemd 管理器配置
echo "Reloading systemd manager configuration..."
systemctl daemon-reload
if [ $? -ne 0 ]; then
    echo "Error: Failed to reload systemd daemon. Please check systemd status."
    exit 1
fi
echo "Systemd daemon reloaded."

# 启用并启动 OpenList 服务
echo "Enabling and starting OpenList service..."
systemctl enable openlist
if [ $? -ne 0 ]; then
    echo "Error: Failed to enable OpenList service. Please check systemd status."
    exit 1
fi

systemctl restart openlist
if [ $? -ne 0 ]; then
    echo "Error: Failed to start OpenList service. Please check systemd status."
    exit 1
fi
echo "OpenList service enabled and started."

# 检查服务状态
echo "Checking OpenList service status..."
systemctl status openlist --no-pager

echo "Script finished."
