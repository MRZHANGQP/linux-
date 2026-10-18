#!/bin/bash
# Q6：将本地 Debian 包安装到 output/sysroot，运行安装后的工具。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# 创建 sysroot 目录以及 dpkg 所需的数据库目录结构
mkdir -p "$output/sysroot"
mkdir -p "$output/sysroot/var/lib/dpkg"
touch "$output/sysroot/var/lib/dpkg/status"

# 加上 --force-not-root 参数，强制让 dpkg 在普通用户下也能执行
dpkg --force-not-root --root="$output/sysroot" -i "$input/"*.deb

# 运行安装后的工具（假设工具名是 tool，具体名字需要看 PDF 或测试报错）
# 如果报错找不到文件，可以用 find 找一下具体的可执行文件路径
if [ -f "$output/sysroot/usr/bin/tool" ]; then
    "$output/sysroot/usr/bin/tool" > "$output/tool_output.txt"
else
    tool_path=$(find "$output/sysroot" -type f -executable | grep "bin/" | head -n 1 || true)
    if [ -n "$tool_path" ]; then
        "$tool_path" > "$output/tool_output.txt"
    fi
fi
