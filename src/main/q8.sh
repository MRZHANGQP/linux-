#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
# Q8 昨天还能运行  (src/main/q8.sh)
#   bash src/main/q8.sh INPUT_DIRECTORY OUTPUT_DIRECTORY [repair|cleanup]
#
# 评测会做这些事：
#   1. 进程识别：OUTPUT/process.txt 里 pid/user/state/command 四项要能对上采集器；
#   2. 正常停止：SIGTERM 掉 TARGET_PID，日志里要出现 "STOP <token>"；
#   3. 保留其他进程：另一个同款采集器（干扰项）不能被误杀；
#   4. 采集日志：OUTPUT/collector-sample.log 里至少两条 "TICK <token> "；
#   5. 修复配置：OUTPUT/server.conf 必须恰好是 bind=127.0.0.1 / port=<TARGET_PORT> / route=/status，
#      且原来的错误服务（SERVICE_PID）要停掉；
#   6. HTTP 恢复：服务要在 TARGET_PORT 上对 /status 返回 200 和 "SENTRY READY\n"，
#      并把状态码、响应体写进 http-status.txt / http-body.txt；
#   7. 服务清理：cleanup 之后端口不能再被监听。
set -eu

input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-repair}

mkdir -p "$output"

# 端口是否有监听（bash 自带 /dev/tcp，不依赖 ss/lsof）
port_open() {
    (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

# 等进程消失
wait_gone() {
    i=0
    while [ "$i" -lt "$2" ]; do
        kill -0 "$1" 2>/dev/null || return 0
        sleep 0.05
        i=$((i + 1))
    done
    return 1
}

# 等端口释放
wait_port_free() {
    i=0
    while [ "$i" -lt "${2:-60}" ]; do
        port_open "$1" || return 0
        sleep 0.05
        i=$((i + 1))
    done
    return 1
}

if [ "$action" = 'repair' ]; then
    set +u
    # shellcheck disable=SC1091
    . "$input/process.env"
    set -u

    : "${TARGET_PID:?process.env 缺少 TARGET_PID}"
    : "${TARGET_TOKEN:?process.env 缺少 TARGET_TOKEN}"
    : "${WORKER_LOG:?process.env 缺少 WORKER_LOG}"
    : "${SERVICE_PID:?process.env 缺少 SERVICE_PID}"
    : "${TARGET_PORT:?process.env 缺少 TARGET_PORT}"
    : "${START_TOOL:?process.env 缺少 START_TOOL}"

    # 1) 进程识别：趁进程还活着取 user/state/command
    {
        printf 'pid=%s\n' "$TARGET_PID"
        printf 'user=%s\n' "$(ps -ww -o user= -p "$TARGET_PID" | tr -d '[:space:]')"
        printf 'state=%s\n' "$(ps -ww -o state= -p "$TARGET_PID" | tr -d '[:space:]')"
        printf 'command=%s\n' "$(ps -ww -o args= -p "$TARGET_PID" | sed 's/^[[:space:]]*//')"
    } >"$output/process.txt"

    # 2) 正常停止采集器：SIGTERM，worker 收到后会补一行 STOP <token>
    kill -TERM "$TARGET_PID" 2>/dev/null || true
    wait_gone "$TARGET_PID" 60 || true

    # 3) 保存采集器日志（等 STOP 落盘后再复制）
    i=0
    while [ "$i" -lt 40 ]; do
        if grep -q "^STOP ${TARGET_TOKEN}$" "$WORKER_LOG" 2>/dev/null; then break; fi
        sleep 0.05
        i=$((i + 1))
    done
    cp -f "$WORKER_LOG" "$output/collector-sample.log"

    # 4) 停掉原来的错误服务，等端口真正释放
    kill -TERM "$SERVICE_PID" 2>/dev/null || true
    wait_gone "$SERVICE_PID" 60 || true
    wait_port_free "$TARGET_PORT" 60 || true

    # 5) 修复配置：三项固定内容
    printf 'bind=127.0.0.1\nport=%s\nroute=/status\n' "$TARGET_PORT" >"$output/server.conf"

    # 6) 用教师提供的脚本启动服务（pid 写到 OUTPUT/service/pid）
    bash "$START_TOOL" "$output/server.conf" "$output/service"

    # 7) 等就绪并记录 HTTP 结果
    code=''
    i=0
    while [ "$i" -lt 100 ]; do
        code=$(curl -s -o "$output/http-body.txt" -w '%{http_code}' \
            "http://127.0.0.1:${TARGET_PORT}/status" 2>/dev/null || true)
        if [ "$code" = '200' ]; then break; fi
        sleep 0.05
        i=$((i + 1))
    done
    printf '%s\n' "$code" >"$output/http-status.txt"

elif [ "$action" = 'cleanup' ]; then
    # 停掉 repair 启动的服务
    pid=''
    if [ -f "$output/service/pid" ]; then
        pid=$(tr -dc '0-9' <"$output/service/pid")
    fi
    if [ -n "$pid" ]; then
        kill -TERM "$pid" 2>/dev/null || true
        wait_gone "$pid" 60 || true
    fi

    # 确认端口已释放；还有残留就按端口再清一次
    port=''
    if [ -f "$output/server.conf" ]; then
        port=$(sed -n 's/^port=//p' "$output/server.conf" | head -n 1)
    fi
    if [ -n "$port" ]; then
        wait_port_free "$port" 60 || true
        if port_open "$port"; then
            p2=$(ss -ltnpH "sport = :$port" 2>/dev/null | grep -oE 'pid=[0-9]+' | head -n 1 | cut -d= -f2 || true)
            if [ -n "$p2" ]; then
                kill -TERM "$p2" 2>/dev/null || true
                wait_gone "$p2" 40 || true
                wait_port_free "$port" 40 || true
            fi
        fi
    fi
fi

exit 0
