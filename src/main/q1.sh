#!/bin/bash
# Q1：定位 handover，读取隐藏编号和欢迎文本。输出 location.txt、robot-id.txt、welcome.txt。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 动态查找 handover 目录的位置（不管嵌套了几层）
found_dir=$(find "$input" -type d -name "handover" | head -n 1 || true)
if [ -n "$found_dir" ]; then
    base_dir="$found_dir"
else
    base_dir="$input"
fi

# 2. 记录真实绝对路径到 location.txt
(cd "$base_dir" && pwd) > "$output/location.txt"

# 3. 在整个输入目录下查找隐藏文件 .robot-id
robot_file=$(find "$input" -name ".robot-id" -type f | head -n 1 || true)
if [ -n "$robot_file" ]; then
    cat "$robot_file" > "$output/robot-id.txt"
fi

# 4. 在整个输入目录下查找名字包含 welcome 的文本文件（忽略大小写）
welcome_file=$(find "$input" -iname "*welcome*" -type f | head -n 1 || true)
if [ -n "$welcome_file" ]; then
    cat "$welcome_file" > "$output/welcome.txt"
fi
