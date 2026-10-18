#!/bin/bash
# Q4：合并日志，按级别提取，保存首尾片段并统计错误行数。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
cat "$input/boot.log" "$input/run.log" > "$output/merged.log"
grep -E "^(ERROR|WARN)" "$output/merged.log" > "$output/filtered.log" || true
head -n 5 "$output/filtered.log" > "$output/head.txt"
tail -n 5 "$output/filtered.log" > "$output/tail.txt"
grep -c "^ERROR" "$output/merged.log" > "$output/error_count.txt" || true
