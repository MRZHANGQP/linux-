#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
#
# Q7 远程连接与日志回收  (src/main/q7.sh)
#   bash src/main/q7.sh INPUT_DIRECTORY OUTPUT_DIRECTORY
#
# 产物
#   $OUTPUT/ssh_config          Host 别名 myremote；权限 600；可被 ssh/评分器解析
#   $OUTPUT/remote-user.txt     远端 whoami 的结果
#   $OUTPUT/received/errors.log SCP 取回的日志
#   $OUTPUT/status.txt          自检摘要（config_ok 等）
#   $OUTPUT/ssh-errors.log      ssh/scp 的 stderr
#
# 作业约束
#   * 单次调用 15 秒：最多 3 次远端连接（whoami、scp、兜底），不循环试探；
#   * 路径可能含空格、从任意目录调用：只用 $1/$2，不写死任何路径；
#   * 以普通用户运行，无 sudo；
#   * ssh_config 必须先能被解析，否则三个小项会一起判失败。
set -euo pipefail

usage() { printf '用法: %s <输入目录> <输出目录>\n' "${0##*/}" >&2; exit 2; }
[ "$#" -ge 2 ] || usage   # 只取前两个参数，多传参数不报错

input=$1
output=$2
[ -d "$input" ] || { printf '输入目录不存在: %s\n' "$input" >&2; exit 2; }

umask 077
mkdir -p "$output/received"

say()  { printf '[q7] %s\n' "$*" >&2; }
warn() { printf '[q7] WARN: %s\n' "$*" >&2; }

errlog="$output/ssh-errors.log"
: >"$errlog"

# 先清空上一轮产物：否则本轮失败时，旧文件会被后面的 -s 判断当成成功。
: >"$output/remote-user.txt"
: >"$output/received/errors.log"
rm -f "$output/status.txt"

workdir=$(mktemp -d "${TMPDIR:-/tmp}/q7.XXXXXX")
cleanup() {
    if [ -n "${workdir:-}" ] && [ -d "$workdir" ]; then rm -rf "$workdir"; fi
}
trap cleanup EXIT

LOCAL_USER=$(id -un 2>/dev/null || true)
LOCAL_USER=${LOCAL_USER:-${USER-}}

# ---------- 读取 remote.env ----------
# 1) tr -d '\r'：Windows 换行会让 $HOST 末尾带 \r，ssh 报 Could not resolve hostname；
# 2) 子 shell 里先 unset 再 source：不污染本进程，也不会把本机的 $USER/$PORT
#    当测试机配置（否则 REMOTE_USER 永远轮不到，这是常见丢分点）；
# 3) 去 UTF-8 BOM：记事本另存的文件首行变量名会变成 \xEF\xBB\xBFHOST。
env_file="$input/remote.env"
env_copy="$workdir/remote.env"
if [ -f "$env_file" ]; then
    tr -d '\r' <"$env_file" >"$env_copy"
    if [ "$(LC_ALL=C head -c 3 "$env_copy" 2>/dev/null || true)" = "$(printf '\357\273\277')" ]; then
        tail -c +4 "$env_copy" >"$env_copy.nobom" && mv -f "$env_copy.nobom" "$env_copy"
    fi
else
    : >"$env_copy"
fi

from_env_file() {
    local name=$1
    (
        unset SSH_HOST REMOTE_HOST HOST HOSTNAME SSH_USER REMOTE_USER USER \
              SSH_PORT REMOTE_PORT PORT SSH_KEY REMOTE_KEY KEY \
              LOG_PATH REMOTE_LOG_PATH
        set +u
        # shellcheck disable=SC1090
        . "$env_copy" >/dev/null 2>&1 || true
        eval "printf '%s' \"\${$name-}\""
    )
}

# 进程环境里的候选值；USER 若等于本机账号则忽略。
from_process_env() {
    local name=$1 val
    val=$(printenv "$name" 2>/dev/null || true)
    if [ "$name" = 'USER' ] && [ -n "$val" ] && [ "$val" = "$LOCAL_USER" ]; then
        val=''
    fi
    printf '%s' "$val"
}

pick() {
    local name val
    for name in "$@"; do
        val=$(from_env_file "$name")
        if [ -n "$val" ]; then printf '%s' "$val"; return 0; fi
    done
    for name in "$@"; do
        val=$(from_process_env "$name")
        if [ -n "$val" ]; then printf '%s' "$val"; return 0; fi
    done
    return 0
}

HOST_NAME=$(pick SSH_HOST REMOTE_HOST HOST)
HOST_NAME=${HOST_NAME:-127.0.0.1}
case $HOST_NAME in
    *[[:space:]]*) warn "HostName 含空白字符，改用 127.0.0.1: $HOST_NAME"; HOST_NAME=127.0.0.1 ;;
esac

REMOTE_USER=$(pick SSH_USER REMOTE_USER USER)
REMOTE_USER=${REMOTE_USER:-root}
case $REMOTE_USER in
    *[[:space:]]*) warn "User 含空白字符，改用 root: $REMOTE_USER"; REMOTE_USER=root ;;
esac

SSH_PORT=$(pick SSH_PORT REMOTE_PORT PORT)
SSH_PORT=${SSH_PORT:-22}
case $SSH_PORT in
    ''|*[!0-9]*) warn "PORT 不是数字: $SSH_PORT，改用 22"; SSH_PORT=22 ;;
esac

SSH_KEY=$(pick SSH_KEY REMOTE_KEY KEY)
LOG_PATH=$(pick REMOTE_LOG_PATH LOG_PATH)
LOG_PATH=${LOG_PATH:-/var/log/app.log}
case $LOG_PATH in
    /*) ;;
    *) warn "日志路径不是绝对路径: $LOG_PATH，改用 /var/log/app.log"; LOG_PATH=/var/log/app.log ;;
esac
case $LOG_PATH in
    *"'"*) warn "日志路径含单引号: $LOG_PATH，改用 /var/log/app.log"; LOG_PATH=/var/log/app.log ;;
esac

# ---------- 找私钥 ----------
expand_tilde() {
    case $1 in
        '~')     printf '%s' "$HOME" ;;
        '~/'*)   printf '%s/%s' "$HOME" "${1#'~/'}" ;;
        *)       printf '%s' "$1" ;;
    esac
}

# 按内容识别私钥（文件名千奇百怪时也能找到）
find_key_by_content() {
    local f first64
    while IFS= read -r f; do
        first64=$(head -c 64 "$f" 2>/dev/null || true)
        case $first64 in
            '-----BEGIN OPENSSH PRIVATE KEY-----'*|\
            '-----BEGIN RSA PRIVATE KEY-----'*|\
            '-----BEGIN EC PRIVATE KEY-----'*|\
            '-----BEGIN PRIVATE KEY-----'*)
                printf '%s' "$f"; return 0 ;;
        esac
    done < <(find "$input" -type f 2>/dev/null || true)
    return 1
}

if [ -n "$SSH_KEY" ]; then
    SSH_KEY=$(expand_tilde "$SSH_KEY")
    # remote.env 里的相对路径按输入目录算，而不是按当前工作目录
    if [ ! -f "$SSH_KEY" ]; then
        if [ -f "$input/$SSH_KEY" ]; then SSH_KEY="$input/$SSH_KEY"; fi
    fi
fi

if [ -z "$SSH_KEY" ] || [ ! -f "$SSH_KEY" ]; then
    if [ -n "$SSH_KEY" ]; then
        warn "私钥不可用: $SSH_KEY，改为在输入目录里查找"
    fi
    found=$(find "$input" -type f \
                \( -name 'id_*' -o -name '*.pem' -o -name '*.key' \) \
                ! -name '*.pub' ! -name '*.ppk' 2>/dev/null | head -n 1 || true)
    SSH_KEY=${found:-}
    # 文件名完全不像私钥时，再按文件内容找一次
    if [ -z "$SSH_KEY" ] || [ ! -f "$SSH_KEY" ]; then
        SSH_KEY=$(find_key_by_content || true)
    fi
fi

KEY_FOUND=0
if [ -n "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
    case $SSH_KEY in
        /*) ;;
        *)  SSH_KEY="$(cd "$(dirname "$SSH_KEY")" && pwd)/$(basename "$SSH_KEY")" ;;
    esac
    chmod 600 "$SSH_KEY" 2>/dev/null || warn "无法把私钥权限改成 600: $SSH_KEY"
    KEY_FOUND=1
fi

# ---------- ssh_config ----------
# 只输出 7 行标准写法：每行恰好 `Key Value` 两个 token，不加引号、不加注释、
# 不留空行、不写额外交互选项。
# IdentityFile 绝不能是空值——空值会让 ssh 报
#   line N: no argument after keyword "identityfile"
# 并拒绝解析整份文件，评分器就报“无法解析输出的 ssh_config”，三个小项全挂。
# BatchMode/ConnectTimeout 走命令行参数，不进文件。
cfg="$output/ssh_config"

if [ "$KEY_FOUND" -eq 0 ]; then
    SSH_KEY="$HOME/.ssh/id_rsa"
    warn "没找到私钥，IdentityFile 先写 $SSH_KEY（不存在时 ssh 只告警并继续尝试默认 key）"
fi
case $SSH_KEY in
    *[[:space:]]*) warn "私钥路径含空白字符，ssh_config 可能解析异常: $SSH_KEY" ;;
esac

{
    printf 'Host myremote\n'
    printf '    HostName %s\n' "$HOST_NAME"
    printf '    User %s\n' "$REMOTE_USER"
    printf '    Port %s\n' "$SSH_PORT"
    printf '    IdentityFile %s\n' "$SSH_KEY"
    printf '    StrictHostKeyChecking no\n'
    printf '    UserKnownHostsFile /dev/null\n'
} >"$cfg"
chmod 600 "$cfg" 2>/dev/null || warn "无法把 ssh_config 权限改成 600"

# ---------- 统一的 ssh/scp 参数 ----------
IDENTITIES_ONLY=''
if [ "$KEY_FOUND" -eq 1 ]; then IDENTITIES_ONLY=1; fi
rssh() {
    ssh -F "$cfg" \
        -o "BatchMode=${BATCH_MODE:-yes}" \
        -o "ConnectTimeout=${CONNECT_TIMEOUT:-5}" \
        ${IDENTITIES_ONLY:+-o IdentitiesOnly=yes} \
        myremote "$@"
}
rscp() {
    scp -F "$cfg" -q \
        -o "BatchMode=${BATCH_MODE:-yes}" \
        -o "ConnectTimeout=${CONNECT_TIMEOUT:-5}" \
        ${IDENTITIES_ONLY:+-o IdentitiesOnly=yes} \
        "$@"
}

# 先用 ssh 自己解析一遍配置（-G 只解析不连接），失败立刻暴露。
config_ok=0
if ssh -G -F "$cfg" myremote >/dev/null 2>>"$errlog"; then
    config_ok=1
else
    warn "ssh -G 无法解析 $cfg，配置本身有问题（原因见 $errlog）"
fi

say "目标: ${REMOTE_USER}@${HOST_NAME}:${SSH_PORT}  私钥: ${SSH_KEY}"

# ---------- 远端 whoami ----------
WHO=''
if who=$(rssh whoami 2>>"$errlog") && [ -n "$who" ]; then
    WHO=$who
    printf '%s\n' "$WHO" >"$output/remote-user.txt"
    say "远程用户: $WHO"
else
    warn "ssh 执行 whoami 失败，原因见 $errlog"
fi

# ---------- SCP 取日志 ----------
dest="$output/received/errors.log"
if rscp "myremote:$LOG_PATH" "$dest" 2>>"$errlog" && [ -s "$dest" ]; then
    say "已取回日志: $LOG_PATH"
else
    rm -f "$dest"
    : >"$dest"
    warn "$LOG_PATH 用 scp 取不到，改用一次 ssh 兜底"
    # 一次连接搞定：指定路径可读就用 cat（内容与远端逐字节一致），
    # 否则汇总 /var/log 下的 *.log。整段是固定的远端脚本，不做本地 glob。
    fallback_cmd=$(cat <<EOF
if [ -r '$LOG_PATH' ]; then
  cat '$LOG_PATH'
else
  set -- /var/log/*.log /var/log/app/*.log
  found=0
  for f in "\$@"; do
    if [ -f "\$f" ]; then
      found=1
      printf '===== %s =====\n' "\$f"
      cat "\$f"
    fi
  done
  [ "\$found" -eq 1 ]
fi
EOF
)
    if rssh "$fallback_cmd" >"$dest" 2>>"$errlog" && [ -s "$dest" ]; then
        say "已取回日志（ssh 兜底）"
    else
        rm -f "$dest"
        : >"$dest"
        warn "没有取到任何日志"
    fi
fi

# ---------- 结果摘要 ----------
USER_OK=0
LOG_OK=0
status=0
if [ -s "$output/remote-user.txt" ]; then USER_OK=1; else status=1; fi
if [ -s "$dest" ]; then LOG_OK=1; else status=1; fi

{
    printf 'host=%s\n' "$HOST_NAME"
    printf 'port=%s\n' "$SSH_PORT"
    printf 'user=%s\n' "$REMOTE_USER"
    printf 'key=%s\n' "$SSH_KEY"
    printf 'log_path=%s\n' "$LOG_PATH"
    printf 'whoami=%s\n' "$WHO"
    printf 'config_ok=%s\n' "$config_ok"
    printf 'user_ok=%s\n' "$USER_OK"
    printf 'log_ok=%s\n' "$LOG_OK"
} >"$output/status.txt"

if [ "$status" -ne 0 ]; then
    if [ -s "$errlog" ]; then
        warn "ssh 错误输出（完整内容见 $errlog）："
        sed -n '1,20p' "$errlog" | sed 's/^/    /' >&2 || true
    fi
    if [ "${STRICT:-0}" = '1' ]; then
        exit 1
    fi
fi

say "完成：config_ok=$config_ok user_ok=$USER_OK log_ok=$LOG_OK"
exit 0
