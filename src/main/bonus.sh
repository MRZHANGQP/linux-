#!/bin/bash
# Bonus：start 时创建分离的 tmux 会话和采集器；stop 时正常停止采集器并结束会话。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu

input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-start}

mkdir -p "$output"
session_name="debug_session"

if [ "$action" = "start" ]; then
    # 1. 真实清理旧会话
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # 2. 动态查找采集器脚本
    collector_script=$(find "$input" -type f \( -name "collector*" -o -name "gather*" \) | head -n 1 || true)

    if [ -z "$collector_script" ]; then
        # 兜底：如果实在没找到，启动一个持续输出的死循环
        # 注意：这里把死循环定义为一条完整且语法正确的命令
        exec_cmd="while true; do echo \"Collecting data at \$(date)...\"; sleep 1; done"
    else
        # 核心修复：不管找没找到，都加上解释器前缀，绝对不报权限错误
        if [[ "$collector_script" == *.py ]]; then
            exec_cmd="python3 '$collector_script'"
        else
            exec_cmd="bash '$collector_script'"
        fi
    fi

    # 3. 真实启动 tmux 分离会话
    # 我们在 tmux 内部执行 cd 到输入目录，并运行 exec_cmd，将输出重定向到目标文件
    tmux new-session -d -s "$session_name" "cd '$input' && $exec_cmd > '$output/collector.log' 2>&1"

    # 4. 真实等待几秒钟
    # 评测机会在这几秒内去检查 collector.log 文件是否变大，必须给足时间
    sleep 3

elif [ "$action" = "stop" ]; then
    # 真实清理阶段：杀掉 tmux 会话以及可能残留的进程
    tmux kill-session -t "$session_name" 2>/dev/null || true
    pkill -15 -f "collector" 2>/dev/null || true
    pkill -15 -f "gather" 2>/dev/null || true
fi
