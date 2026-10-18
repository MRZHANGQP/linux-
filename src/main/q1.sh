#!/bin/bash
# Q1：定位 handover，读取隐藏编号和欢迎文本。输出 location.txt、robot-id.txt、welcome.txt。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
if [ -d "$input/handover" ]; then base_dir="$input/handover"; else base_dir="$input"; fi
(cd "$base_dir" && pwd) > "$output/location.txt"
cat "$base_dir/.robot-id" > "$output/robot-id.txt"
cat "$base_dir/welcome.txt" > "$output/welcome.txt"
