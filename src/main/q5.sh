#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

target_file="$input/launch.env"
if [ ! -f "$target_file" ]; then
    target_file=$(find "$input" -name "*preflight*" -o -name "*.sh" | head -n 1 || true)
fi

set +e
if [ -n "$target_file" ]; then
    chmod +x "$target_file" || true
    (cd "$input" && bash "$target_file" > "$output/stdout.log" 2> "$output/stderr.log")
    exit_code=$?
else
    touch "$output/stdout.log" "$output/stderr.log"
    exit_code=0
fi
set -e

echo "$exit_code" > "$output/exit-code.txt"

if [ "$exit_code" -eq 10 ]; then
    reason="MODEL_MISSING"
elif [ "$exit_code" -eq 20 ]; then
    reason="CAMERA_DENIED"
else
    reason="UNKNOWN"
fi

if [ "$exit_code" -eq 0 ]; then
    echo "result=SUCCESS" > "$output/report.txt"
else
    echo "result=FAILED" > "$output/report.txt"
fi

echo "reason=$reason" >> "$output/report.txt"
echo "diagnostic report generated" >> "$output/report.txt"
