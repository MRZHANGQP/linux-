#!/bin/bash
# Q4：合并日志，按级别提取，保存首尾片段并统计错误行数。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 合并 boot 和 run 的日志到 all.log
# 使用 find 动态找包含 boot 或 run 的 .log 文件并合并
find "$input" -type f -name "*boot*.log" -exec cat {} + > "$output/all.log" || true
find "$input" -type f -name "*run*.log" -exec cat {} + >> "$output/all.log" || true

# 2. 提取 ERROR 到 errors.log（行首必须严格是 ERROR）
grep "^ERROR" "$output/all.log" > "$output/errors.log" || true

# 3. 提取 WARN 到 attention.log（行首必须严格是 WARN）
grep "^WARN" "$output/all.log" > "$output/attention.log" || true

# 4. 提取末尾日志（这里假设取最后 5 行，如果题目有具体数字请替换 5）
tail -n 5 "$output/all.log" > "$output/recent.log" || true

# 5. 提取首条错误（从 errors.log 取第一行）
head -n 1 "$output/errors.log" > "$output/first-errors.log" || true

# 6. 计算错误计数并写入 error-count.txt
grep -c "^ERROR" "$output/all.log" > "$output/error-count.txt" || true
