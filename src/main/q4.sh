#!/bin/bash
# Q4：合并日志，按级别提取，保存首尾片段并统计错误行数。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 合并日志
find "$input" -type f -name "*boot*.log" -exec cat {} + > "$output/all.log" || true
find "$input" -type f -name "*run*.log" -exec cat {} + >> "$output/all.log" || true

# 2. 提取纯 ERROR 到 errors.log
grep "^ERROR" "$output/all.log" > "$output/errors.log" || true

# 3. 提取 ERROR 和 WARN 到 attention.log (根据报错纠正)
grep -E "^(ERROR|WARN)" "$output/all.log" > "$output/attention.log" || true

# 4. 提取末尾日志（最后 5 行）
tail -n 5 "$output/all.log" > "$output/recent.log" || true

# 5. 提取首条错误（前 3 行）
head -n 3 "$output/errors.log" > "$output/first-errors.log" || true

# 6. 计算错误计数
grep -c "^ERROR" "$output/all.log" > "$output/error-count.txt" || true
