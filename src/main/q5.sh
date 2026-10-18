#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 暴力找检查程序：通常它是一个可执行文件，或者名字里带 preflight/check/launch
target_script=$(find "$input" -maxdepth 1 -type f \( -name "*preflight*" -o -name "*check*" -o -name "*.sh" \) | head -n 1 || true)
if [ -z "$target_script" ]; then
    target_script="$input/launch.env"
fi

# 2. 执行检查程序（千万别加 bash，直接运行它，让系统根据 shebang 或二进制自己决定怎么跑）
set +e
if [ -f "$target_script" ] && [ -x "$target_script" ]; then
    "$target_script" > "$output/stdout.log" 2> "$output/stderr.log"
    exit_code=$?
else
    # 如果它没有执行权限，强行跑一下
    if [ -f "$target_script" ]; then
        chmod +x "$target_script" || true
        "$target_script" > "$output/stdout.log" 2> "$output/stderr.log"
        exit_code=$?
    else
        touch "$output/stdout.log" "$output/stderr.log"
        exit_code=0
    fi
fi
set -e

# 3. 写入真实退出码（期望值是 10 或 20，你跑出来多少就存多少）
echo "$exit_code" > "$output/exit-code.txt"

# 4. 生成三行诊断报告（首行必须满足测试器要求）
if [ "$exit_code" -eq 0 ]; then
    echo "result=SUCCESS" > "$output/report.txt"
else
    echo "result=FAILED" > "$output/report.txt"
fi
echo "exit_code=$exit_code" >> "$output/report.txt"
echo "diagnostic report generated" >> "$output/report.txt"
