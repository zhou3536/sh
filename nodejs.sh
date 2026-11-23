#!/bin/bash

# 检查是否以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本需要 root 权限运行。"
   echo "请尝试：sudo bash nodejs.sh"
   exit 1
fi
if command -v node >/dev/null 2>&1 && [[ $(node -v) =~ ^v22\. ]]; then
   echo "Node.js LTS (v22.x) 已安装，版本: $(node -v)"
   exit 0 # 已安装
fi

echo "正在安装 Node.js 最新 LTS 版本 (Node.js 22.x)..."

# 1. 更新包列表
echo "正在更新包列表..."
apt-get update -y

# 2. 安装必要的依赖项
echo "正在安装必要的依赖项 (curl, gnupg)..."
apt-get install -y curl gnupg

# 3. 添加 NodeSource 22.x 仓库（修改了这里）
echo "正在添加 NodeSource 22.x LTS 仓库..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

# 4. 安装/升级 Node.js
echo "正在安装/升级 Node.js..."
apt-get install -y nodejs

# 5. 验证安装（修改了这里）
echo "正在验证安装..."
node_version=$(node -v)
npm_version=$(npm -v)

if [[ "$node_version" =~ ^v22\. ]]; then
    echo "🎉 Node.js 22 安装成功！"
    echo "Node.js 版本: $node_version"
    echo "npm 版本: $npm_version"
    exit 0
else
    echo "❌ 错误：Node.js 版本不匹配或安装失败。"
    echo "检测到的 Node.js 版本: $node_version"
    exit 1
fi
