#!/bin/bash
# Q6：将本地 Debian 包安装到 output/sysroot，运行安装后的工具。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output/sysroot"
dpkg --root="$output/sysroot" -i "$input/"*.deb
"$output/sysroot/usr/bin/tool" > "$output/tool_output.txt"
