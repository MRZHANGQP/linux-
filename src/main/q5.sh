#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 临时关闭 set -e，防止子程序失败导致脚本直接退出
set +e
# 运行检查程序（用 bash 执行），分离 stdout 和 stderr
bash "$input/launch.env" > "$output/stdout.log" 2> "$output/stderr.log"
# 立刻捕获退出码
exit_code=$?
set -e

# 写入真实退出码
echo "$exit_code" > "$output/exit-code.txt"

# 生成三行诊断报告
echo "Exit Code: $exit_code" > "$output/report.txt"
echo "STDOUT saved to stdout.log" >> "$output/report.txt"
echo "STDERR saved to stderr.log" >> "$output/report.txt"
