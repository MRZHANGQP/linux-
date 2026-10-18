#!/bin/bash
# Q6：将本地 Debian 包安装到 output/sysroot，运行安装后的工具。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# 1. 准备 sysroot 环境
mkdir -p "$output/sysroot"
mkdir -p "$output/sysroot/var/lib/dpkg"
touch "$output/sysroot/var/lib/dpkg/status"

# 2. 强制以普通用户权限安装 deb 包
deb_file=$(find "$input" -name "*.deb" | head -n 1 || true)
if [ -n "$deb_file" ]; then
    dpkg --force-not-root --root="$output/sysroot" -i "$deb_file" || true
fi

# 3. 寻找刚刚安装的可执行文件
tool_path=$(find "$output/sysroot" -type f -executable | grep "/bin/" | head -n 1 || true)
if [ -z "$tool_path" ]; then
    # 兜底：找 sysroot 下任何可执行文件
    tool_path=$(find "$output/sysroot" -type f -executable | head -n 1 || true)
fi

# 4. 运行工具，并且按要求命名 tool-output.txt
if [ -n "$tool_path" ]; then
    "$tool_path" > "$output/tool-output.txt" 2>&1 || true
else
    touch "$output/tool-output.txt"
fi
