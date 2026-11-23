#!/bin/bash

# 脚本名: create_service.sh
# 功能: 创建Systemd服务，并在此之前检查和安装Node.js LTS版本 (Node.js 22.x)

# --- Node.js LTS 安装函数 ---
install_nodejs_lts() {
    # 检查是否以root权限运行，Node.js安装需要root权限
    if [[ $EUID -ne 0 ]]; then
       echo "Node.js 安装需要 root 权限。"
       return 1 # 返回错误码
    fi

    echo "正在检查 Node.js LTS (22.x) 是否已安装..."
    # 尝试获取node版本，匹配 v22. 开头
    if command -v node >/dev/null 2>&1 && [[ $(node -v) =~ ^v22\. ]]; then
        echo "Node.js LTS (v22.x) 已安装，版本: $(node -v)"
        return 0 # 已安装，返回成功码
    else
        echo "Node.js LTS (v22.x) 未检测到或版本不匹配，开始安装..."
        # --- Node.js LTS 安装逻辑 ---
        # 1. 更新包列表
        echo "正在更新包列表..."
        apt-get update -y || { echo "apt-get update 失败"; return 1; }

        # 2. 安装必要的依赖项
        echo "正在安装必要的依赖项 (curl, gnupg)..."
        apt-get install -y curl gnupg || { echo "安装依赖项失败"; return 1; }

        # 3. 添加 NodeSource LTS 仓库 (Node.js 22.x)
        echo "正在添加 NodeSource 22.x LTS 仓库..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - || { echo "添加 NodeSource 仓库失败"; return 1; }

        # 4. 安装 Node.js
        echo "正在安装 Node.js..."
        apt-get install -y nodejs || { echo "安装 Node.js 失败"; return 1; }

        # 5. 验证安装
        echo "正在验证 Node.js 安装..."
        if command -v node >/dev/null 2>&1 && [[ $(node -v) =~ ^v22\. ]]; then
            echo "Node.js LTS (v22.x) 安装成功！版本: $(node -v)"
            return 0 # 安装成功
        else
            echo "错误：Node.js LTS (v22.x) 安装后版本不匹配或安装失败。"
            echo "检测到的 Node.js 版本: $(node -v 2>/dev/null || echo '未检测到')"
            return 1 # 安装失败
        fi
    fi
}

# --- 主脚本逻辑 ---

# 检查是否以root用户运行 (这是创建Systemd服务必须的)
if [ "$(id -u)" -ne 0 ]; then
  echo "此脚本需要root权限才能运行。请使用 sudo ./create_service.sh"
  exit 1
fi

# --- Node.js 安装部分 ---
echo "--- Node.js 环境检查与安装 ---"
# 调用 Node.js 安装函数
if ! install_nodejs_lts; then
    echo "Node.js LTS 安装失败，脚本将退出。"
    exit 1
fi
echo "--- Node.js 环境准备完毕 ---"
echo "" # 添加空行分隔

# --- Systemd 服务创建部分 ---
echo "--- Systemd 服务创建 ---"

# 1. 获取当前所在的文件夹名字和路径
CURRENT_DIR_FULL_PATH=$(pwd)
CURRENT_DIR_NAME=$(basename "$CURRENT_DIR_FULL_PATH")

echo "当前路径: $CURRENT_DIR_FULL_PATH"
echo "当前文件夹: $CURRENT_DIR_NAME"
echo "将创建服务: ${CURRENT_DIR_NAME}.service"
# 定义服务文件名称
SERVICE_NAME="${CURRENT_DIR_NAME}.service"
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"

# 2. 执行 npm install
echo "进入目录: $CURRENT_DIR_FULL_PATH 并运行 'npm install'..."
if ! (cd "$CURRENT_DIR_FULL_PATH" && /usr/bin/npm install); then
  echo "错误: npm install 执行失败。请检查您的项目依赖或npm配置。"
  echo "请确保 Node.js (v22.x) 已正确安装，并且 '/usr/bin/npm' 命令可用。"
  exit 1
fi

echo "npm install 执行成功。"

# 3. 创建Systemd服务文件
cat <<EOF > "$SERVICE_FILE_PATH"
[Unit]
Description=Service for application in $CURRENT_DIR_NAME
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CURRENT_DIR_FULL_PATH
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$CURRENT_DIR_NAME

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
  echo "错误: 无法创建服务文件 $SERVICE_FILE_PATH"
  exit 1
fi

echo "创建服务文件成功: $SERVICE_FILE_PATH"

# 4. 重新加载systemd配置
echo "重新加载 systemctl daemon-reload..."
systemctl daemon-reload
if [ $? -ne 0 ]; then
  echo "错误: systemctl daemon-reload 失败。"
  exit 1
fi

# 5. 启动新创建的服务
echo "启动服务 $SERVICE_NAME ..."
systemctl start "$SERVICE_NAME"
if [ $? -ne 0 ]; then
  echo "错误: 启动服务 $SERVICE_NAME 失败。请检查应用程序或服务配置。"
  echo "可以通过 'journalctl -u $SERVICE_NAME' 查看详细日志。"
  exit 1
fi

# 6. 设置服务开机自启动
echo "开机启动 $SERVICE_NAME ..."
systemctl enable "$SERVICE_NAME"
if [ $? -ne 0 ]; then
  echo "错误: 设置服务 $SERVICE_NAME 开机启动失败。"
  exit 1
fi

echo "服务已成功创建、并设置开机启动！"
echo "你可以使用以下命令管理服务:"
echo "--查看状态       systemctl status $SERVICE_NAME"
echo "--重启服务       systemctl restart $SERVICE_NAME"
echo "--停止服务       systemctl stop $SERVICE_NAME"
echo "--开机启动       systemctl enable $SERVICE_NAME"
echo "--禁用启动       systemctl disable $SERVICE_NAME"

exit 0
