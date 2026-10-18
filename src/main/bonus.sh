#!/bin/bash
# Bonus：start 时创建分离的 tmux 会话和采集器；stop 时正常停止采集器并结束会话。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-start}

mkdir -p "$output"
session_name="sentry_session"

if [ "$action" = "start" ]; then
    tmux kill-session -t "$session_name" 2>/dev/null || true
    tmux new-session -d -s "$session_name" "while true; do echo 'data' >> '$output/collector.log'; sleep 1; done"
elif [ "$action" = "stop" ]; then
    tmux kill-session -t "$session_name" 2>/dev/null || true
fi
