#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-repair}

mkdir -p "$output"
if [ "$action" = "repair" ]; then
    pid=$(pgrep -f "collector" || true)
    if [ -n "$pid" ]; then kill -15 "$pid"; fi
    systemctl --user restart httpd
    curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 > "$output/curl_status.txt"
elif [ "$action" = "cleanup" ]; then
    systemctl --user stop httpd
    pkill -f "collector" || true
fi
