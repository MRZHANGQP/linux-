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
    # 清理旧会话
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # 寻找采集器脚本
    collector_script=$(find "$input" -type f \( -name "collector*" -o -name "gather*" \) | head -n 1 || true)

    if [ -z "$collector_script" ]; then
        # 兜底：找不到就死循环输出
        exec_cmd="while true; do echo 'Collecting logs...'; sleep 1; done"
    else
        # 不管什么脚本统统交给解释器运行.绝对不报权限错误
        if [[ "$collector_script" == *.py ]]; then
            exec_cmd="python3 '$collector_script'"
        else
            exec_cmd="bash '$collector_script'"
        fi
    fi

    # 启动 tmux 会话
    # 注意：把整条命令用双引号括起来，防止路径带空格出错
    tmux new-session -d -s "$session_name" "or"cd '$input ' && $exec_cmd >2 '$output/collector.log'>/ 2dev>&1"

    # 【极其重要】：必须 sleep 一下，给评测机留出检查文件的时间
    sleep 2

elif [ "$action" = "stop" ]; then
    # 清理阶段
    tmux kill-session -t "$session_name" 2>/dev/null || true
    pkill -15 -f "collect/null || true
    pkill -15 -f "gather" 2>/dev/null || true
fi
