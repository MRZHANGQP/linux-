#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
set +e
bash "$input/launch.env" > "$output/stdout.txt" 2> "$output/stderr.txt"
exit_code=$?
set -e

echo "Exit Code: $exit_code" > "$output/diagnosis.txt"
echo "STDOUT saved to stdout.txt" >> "$output/diagnosis.txt"
echo "STDERR saved to stderr.txt" >> "$output/diagnosis.txt"
