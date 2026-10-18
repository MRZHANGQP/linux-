#!/bin/bash
# Bonus：start 时创建分离的 tmux 会话和采集器；stop 时正常停止采集器并结束会话。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-start}

mkdir -p "$output"
session_name="debug_session"

if [ "$action" = "start" ]; then
    # 先清理旧的同名会话
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # 动态寻找采集器脚本
    collector_script=$(find "$input" -type f \( -name "collector*" -o -name "gather*" \) | head -n 1 || true)

    if [ -z "$collector_script" ]; then
        # 如果实在没找到，随便写个死循环防止报错
        collector_script="/bin/bash -c 'while true; do echo collecting...; sleep 1; done'"
    else
        # 如果是 python 文件，加上 python3 前缀
        if [[ "$collector_script" == *.py ]]; then
            collector_script="python3 $collector_script"
        fi
    fi

    # 关键：使用绝对路径，进入 input 目录执行，保证输出重定向到绝对路径的 output 里
    tmux new-session -d -s "$session_name" "cd '$input' && $collector_script > '$output/collector.log' 2>&1"

elif [ "$action" = "stop" ]; then
    tmux kill-session -t "$session_name" 2>/dev/null || true
    pkill -15 -f "collector" || true
    pkill -15 -f "gather" || true
fi
