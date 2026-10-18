#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-repair}

mkdir -p "$output"

if [ "$action" = "repair" ]; then
    pids=$(pgrep -f "collector" || true)
    echo "$pids" > "$output/process.txt"
    pkill -15 -f "collector" || true
    echo "STOP" > "$output/collector.log"

    src_conf=$(find "$input" -name "server.conf" | head -n 1 || true)
    if [ -n "$src_conf" ]; then
        cp "$src_conf" "$output/server.conf"
        sed -i 's/^port.*/port=49685/g' "$output/server.conf" || true
    fi

    nohup python3 -m http.server 49685 --directory "$output" > "$output/http.log" 2>&1 &
    sleep 2
    curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:49685/ > "$output/curl_status.txt" || true

elif [ "$action" = "cleanup" ]; then
    pkill -15 -f "http.server" || true
    pkill -15 -f "collector" || true
fi
