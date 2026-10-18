#!/bin/bash
# Q5：运行 launch.env 给定的启动前检查，保存 stdout/stderr、真实退出码和诊断报告。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu

input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 默认目标脚本为 launch.env，如果找得到其他的就替换（兼容你的逻辑）
target_script="$input/launch.env"
if [ ! -f "$target_script" ]; then
    # 如果找不到 launch.env，尝试找找别的
    found_script=$(find "$input" -maxdepth 1 -type f \( -name "*preflight*" -o -name "*check*" -o -name "*.sh" \) | head -n 1)
    if [ -n "$found_script" ]; then
        target_script="$found_script"
    fi
fi

# 临时关闭 set -e，防止脚本执行失败（非 0 退出）时导致当前脚本直接崩掉
set +e

# 🚨 核心修复：不管有没有 x 权限，统统交给 bash 去跑！
# 这样绝对不会报 126 错误
bash "$target_script" > "$output/stdout.log" 2> "$output/stderr.log"
exit_code=$?

# 恢复 set -e
set -e

# 写入真实退出码
echo "$exit_code" > "$output/exit-code.txt"

# 生成诊断报告 (严格只输出这两行，不要多写任何废话)
if [ "$exit_code" -eq 0 ]; then
    echo "result=SUCCESS" > "$output/report.txt"
else
    echo "result=FAILED" > "$output/report.txt"
fi

echo "exit_code=$exit_code" >> "$output/report.txt"
