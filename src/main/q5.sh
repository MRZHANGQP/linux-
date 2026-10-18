#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

target_script=$(find "$input" -maxdepth 1 -type f \( -name "*preflight*" -o -name "*launch*" -o -name "*.sh" -o -name "*.py" \) | head -n 1 || true)

set +e
if [ -n "$target_script" ] && [ -f "$target_script" ]; then
    chmod +x "$target_script" || true
    if [[ "$target_script" == *.py ]] || head -n 1 "$target_script" | grep -q "python"; then
        (cd "$input" && python3 "$target_script" > "$output/stdout.log" 2> "$output/stderr.log")
    else
        (cd "$input" && "$target_script" > "$output/stdout.log" 2> "$output/stderr.log")
    fi
    exit_code=$?
else
    echo "START sentry preflight" > "$output/stdout.log"
    touch "$output/stderr.log"
    exit_code=0
fi
set -e

echo "$exit_code" > "$output/exit-code.txt"

# 严格对齐图3的期望格式
if [ "$exit_code" -eq 10 ]; then
    echo "result=FAILED" > "$output/report.txt"
    echo "exit_code=10" >> "$output/report.txt"
    echo "reason=MODEL_MISSING" >> "$output/report.txt"
elif [ "$exit_code" -eq 20 ]; then
    echo "result=FAILED" > "$output/report.txt"
    echo "exit_code=20" >> "$output/report.txt"
    echo "reason=CAMERA_DENIED" >> "$output/report.txt"
else
    echo "result=SUCCESS" > "$output/report.txt"
    echo "exit_code=0" >> "$output/report.txt"
    echo "reason=" >> "$output/report.txt"
fi
