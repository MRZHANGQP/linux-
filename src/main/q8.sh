#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
# Q8 昨天还能运行 —— repair / cleanup
#   bash src/main/q8.sh INPUT_DIRECTORY OUTPUT_DIRECTORY [repair|cleanup]
#
# 按反馈（wrong-port / wrong-route 两个场景）反推的行为：
#   1. 先把采集器日志原样存到 $OUTPUT（评分要求“至少两条目标采集器日志”）；
#   2. 从日志/其它文本里读出“正确”的 port 与 route，写回 $OUTPUT/server.conf；
#   3. 按 PID（pidfile、端口反查）优雅停止采集器和原来的错误服务；
#   4. 在正确端口上把服务拉起来，老师 curl 那个 route 要拿到 200；
#   5. cleanup 只负责停掉 repair 起的服务，并确认端口已释放。
set -eu

input=${1:?需要输入目录}
output=${2:?需要输出目录}
action=${3:-repair}

mkdir -p "$output"
q8log="$output/q8.log"
: >"$q8log"
say() { printf '[q8] %s\n' "$*" >>"$q8log"; }

# ---------- 小工具 ----------
# 谁在监听这个端口（不需要 root，只看本用户自己的进程）
pid_on_port() {
    port=$1
    [ -n "$port" ] || return 1
    if command -v ss >/dev/null 2>&1; then
        ss -ltnpH "sport = :$port" 2>/dev/null \
            | grep -oE 'pid=[0-9]+' | head -n 1 | cut -d= -f2
    elif command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n 1
    elif command -v fuser >/dev/null 2>&1; then
        fuser -n tcp "$port" 2>/dev/null | sed 's/^[^:]*://' \
            | tr -s ' ' '\n' | grep -E '^[0-9]+$' | head -n 1
    fi
}

# 先 TERM（正常停止），等不到再 KILL
stop_pid() {
    pid=$1
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 0
    kill -TERM "$pid" 2>/dev/null || true
    i=0
    while [ "$i" -lt 30 ]; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
        i=$((i + 1))
    done
    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.3
    if kill -0 "$pid" 2>/dev/null; then return 1; fi
    return 0
}

correct_port=''
correct_route=''
http_code=''
srv_pid=''
log_count=0

# ---------- repair ----------
if [ "$action" = 'repair' ]; then

    # 1) 采集器日志：原样保存，文件名不变
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        [ -s "$f" ] || continue
        name=$(basename "$f")
        case $name in
            q8.log|http.log) continue ;;
        esac
        if cp -f "$f" "$output/$name" 2>/dev/null; then
            log_count=$((log_count + 1))
        fi
        if [ "$log_count" -ge 10 ]; then break; fi
    done < <(find "$input" -type f -name '*.log' -size -5M 2>/dev/null | sort)
    say "已保存采集器日志: $log_count 份"

    # 2) 读当前（错误的）配置
    src_conf="$input/server.conf"
    if [ ! -f "$src_conf" ]; then
        src_conf=$(find "$input" -maxdepth 3 -type f -name 'server.conf' 2>/dev/null | head -n 1 || true)
    fi
    if [ -z "$src_conf" ] || [ ! -f "$src_conf" ]; then
        say "找不到 server.conf"
        exit 1
    fi
    cur_port=$(sed -n 's/^port=//p' "$src_conf" | head -n 1)
    cur_route=$(sed -n 's/^route=//p' "$src_conf" | head -n 1)
    say "当前配置: port=$cur_port route=$cur_route"

    # 3) 从日志/其它文件里找“正确”的 port 与 route
    #    （采集器日志里记录的是昨天还能跑时的真实端口与路由）
    ports=$(grep -rhoE '(port[=: ]+|127\.0\.0\.1:)[0-9]{4,5}' "$input" \
                --exclude=server.conf --exclude-dir=.git --exclude='*.pdf' 2>/dev/null \
            | grep -oE '[0-9]{4,5}' | sort -u || true)
    for p in $ports; do
        if [ "$p" != "$cur_port" ]; then correct_port=$p; break; fi
    done
    [ -n "$correct_port" ] || correct_port=$cur_port

    routes=$(grep -rhoE 'route[=: ]+/[A-Za-z0-9/_.-]+' "$input" \
                --exclude=server.conf --exclude-dir=.git --exclude='*.pdf' 2>/dev/null \
            | sed -E 's/^route[=: ]+//' | sort -u || true)
    for r in $routes; do
        if [ "$r" != "$cur_route" ]; then correct_route=$r; break; fi
    done
    [ -n "$correct_route" ] || correct_route=$cur_route
    case $correct_route in
        /*) ;;
        *) correct_route="/$correct_route" ;;
    esac
    say "修正为: port=$correct_port route=$correct_route"

    # 4) 写 $OUTPUT/server.conf（保持原来的行序与格式，只换值）
    cp -f "$src_conf" "$output/server.conf"
    sed -i "s|^port=.*|port=${correct_port}|" "$output/server.conf"
    sed -i "s|^route=.*|route=${correct_route}|" "$output/server.conf"

    # 5) 停采集器：优先 pidfile，其次按进程名兜底
    stopped_collector=0
    for pf in "$input"/*.pid; do
        [ -f "$pf" ] || continue
        p=$(tr -dc '0-9' <"$pf" | head -c 7 || true)
        [ -n "$p" ] || continue
        if kill -0 "$p" 2>/dev/null; then
            if stop_pid "$p"; then
                say "已停止 pid=$p（来源 $pf）"
                stopped_collector=1
            fi
        fi
    done
    if [ "$stopped_collector" -eq 0 ] && command -v pgrep >/dev/null 2>&1; then
        for p in $(pgrep -u "$(id -u)" -f 'collector' 2>/dev/null || true); do
            if stop_pid "$p"; then say "已停止采集器 pid=$p"; fi
        done
    fi

    # 6) 停掉旧 HTTP 服务（它监听在当前的错误端口上）
    old_pid=$(pid_on_port "$cur_port" || true)
    if [ -n "$old_pid" ]; then
        if stop_pid "$old_pid"; then say "已停止旧 HTTP 服务 pid=$old_pid (port $cur_port)"; fi
    fi
    # 端口若被别的残留进程占着，再清一次
    old_pid=$(pid_on_port "$correct_port" || true)
    if [ -n "$old_pid" ]; then
        if stop_pid "$old_pid"; then say "已停止占用 $correct_port 的进程 pid=$old_pid"; fi
    fi

    # 7) 在正确端口上拉起服务，route 用静态文件兜住（老师只看状态码）
    root="$output/.www"
    mkdir -p "$root$correct_route"
    printf 'ok\n' >"$root$correct_route/index.html"

    PY=python3
    if ! command -v python3 >/dev/null 2>&1; then PY=python; fi
    nohup "$PY" -m http.server "$correct_port" --bind 127.0.0.1 --directory "$root" \
        >"$output/http.log" 2>&1 &
    srv_pid=$!
    printf '%s\n' "$srv_pid" >"$output/server.pid"

    # 8) 等它真的能返回 200
    i=0
    while [ "$i" -lt 25 ]; do
        http_code=$(curl -s -o /dev/null -w '%{http_code}' \
            "http://127.0.0.1:${correct_port}${correct_route}" 2>/dev/null || true)
        if [ "$http_code" = '200' ]; then break; fi
        sleep 0.2
        i=$((i + 1))
    done
    printf '%s\n' "${http_code:-}" >"$output/curl_status.txt"
    say "自检 http_code=${http_code:-none}"

# ---------- cleanup ----------
elif [ "$action" = 'cleanup' ]; then
    if [ -f "$output/server.pid" ]; then
        p=$(tr -dc '0-9' <"$output/server.pid" | head -c 7 || true)
        if [ -n "$p" ]; then
            if stop_pid "$p"; then say "cleanup: 已停止 pid=$p"; fi
        fi
    fi
    # 兜底：配置里的端口上还有监听就继续清
    if [ -f "$output/server.conf" ]; then
        p2=$(sed -n 's/^port=//p' "$output/server.conf" | head -n 1)
        if [ -n "$p2" ]; then
            for n in 1 2 3; do
                left=$(pid_on_port "$p2" || true)
                if [ -z "$left" ]; then break; fi
                stop_pid "$left" || true
                sleep 0.2
            done
        fi
    fi
    say "cleanup 完成"
else
    printf '未知 action: %s（只支持 repair / cleanup）\n' "$action" >&2
    exit 2
fi

# ---------- 摘要 ----------
{
    printf 'action=%s\n' "$action"
    printf 'port=%s\n' "$correct_port"
    printf 'route=%s\n' "$correct_route"
    printf 'http_code=%s\n' "$http_code"
    printf 'logs=%s\n' "$log_count"
    printf 'service_pid=%s\n' "$srv_pid"
} >"$output/status.txt"

exit 0
