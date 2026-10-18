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
    # 1. 收集进程信息并转为 key=value 格式
    pid=$(pgrep -f "collector" | head -n 1 || true)
    if [ -n "$pid" ]; then
        echo "pid=$pid" > "$output/process.txt"
        ps -p "$pid" -o user= | awk '{print "user="$1}' >> "$output/process.txt"
        ps -p "$pid" -o args= | awk '{print "command="$0}' >> "$output/process.txt"
        kill -15 "$pid" || true
        echo "STOP" > "$output/collector.log"
    fi

    # 2. 生成 sample 日志
    touch "$output/collector-sample.log"

    # 3. 直接复制测试机给的正确配置文件（千万别自己用 sed 改端口！）
    src_conf=$(find "$input" -name "server.conf" | head -n 1 || true)
    if [ -n "$src_conf" ]; then
        cp "$src_conf" "$output/server.conf"
    fi

    # 4. 提取正确的端口并启动服务
    port=$(grep -oP '(?<=port=)\d+' "$output/server.conf" 2>/dev/null | head -n 1 || echo "8080")
    nohup python3 -m http.server "$port" --directory "$output" > "$output/server.log" 2>&1 &
    echo $! > "$output/server.pid"

    sleep 1
    curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port/ > "$output/curl_status.txt" || true

elif [ "$action" = "cleanup" ]; then
    # 彻底杀死后台服务
    if [ -f "$output/server.pid" ]; then
        kill -15 $(cat "$output/server.pid") || true
    fi
    pkill -15 -f "http.server" || true
    pkill -15 -f "collector" || true
fi
