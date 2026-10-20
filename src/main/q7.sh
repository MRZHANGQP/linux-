#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
# Q7 远程连接与日志回收  (src/main/q7.sh)
#   bash src/main/q7.sh INPUT_DIRECTORY OUTPUT_DIRECTORY
#
# 评测会做这些事：
#   1. ssh -G -F OUTPUT/ssh_config aim-sentry 必须解析成功；
#   2. 配置里要有 Host aim-sentry、StrictHostKeyChecking yes、IdentitiesOnly yes、
#      UserKnownHostsFile 指向输入里的 known_hosts、IdentityFile 指向输入里的 client_key；
#      文件权限必须是 600；
#   3. 用这份配置 ssh 到远端执行 whoami，结果写 remote-user.txt；
#   4. 用 scp 把远端日志取回 received/errors.log（服务端要看到 sftp/scp 会话）。
#
# 注意：测试路径里带空格（"Q7 normal/input materials"），ssh_config 的路径必须加引号，
# 否则 ssh 报 "keyword identityfile extra arguments at end of line"，整份配置作废，
# 也就是之前那句“无法解析输出的 ssh_config”。
set -eu

input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output/received"

# 教师生成的连接参数：HOST / PORT / REMOTE_USER / KEY_PATH / KNOWN_HOSTS / REMOTE_LOG
set +u
# shellcheck disable=SC1091
. "$input/remote.env"
set -u

: "${HOST:?remote.env 缺少 HOST}"
: "${PORT:?remote.env 缺少 PORT}"
: "${REMOTE_USER:?remote.env 缺少 REMOTE_USER}"
: "${KEY_PATH:?remote.env 缺少 KEY_PATH}"
: "${KNOWN_HOSTS:?remote.env 缺少 KNOWN_HOSTS}"
: "${REMOTE_LOG:?remote.env 缺少 REMOTE_LOG}"

# 教师给的私钥是 root:学生组 0440，ssh 会以“权限过宽”为由忽略它；
# 复制一份自己拥有的 0600 私钥来用，同时原路径也留在配置里。
cp -f "$KEY_PATH" "$output/client_key"
chmod 600 "$output/client_key"

cfg="$output/ssh_config"
{
    printf 'Host aim-sentry\n'
    printf '    HostName %s\n' "$HOST"
    printf '    User %s\n' "$REMOTE_USER"
    printf '    Port %s\n' "$PORT"
    printf '    IdentityFile "%s"\n' "$output/client_key"
    printf '    IdentityFile "%s"\n' "$KEY_PATH"
    printf '    IdentitiesOnly yes\n'
    printf '    UserKnownHostsFile "%s"\n' "$KNOWN_HOSTS"
    printf '    StrictHostKeyChecking yes\n'
} >"$cfg"
chmod 600 "$cfg"

# 远程命令
ssh -F "$cfg" -o BatchMode=yes -o ConnectTimeout=5 aim-sentry whoami >"$output/remote-user.txt"

# SCP 取日志（服务端会记录 sftp 子系统会话）
scp -F "$cfg" -o BatchMode=yes -o ConnectTimeout=5 -q "aim-sentry:$REMOTE_LOG" "$output/received/errors.log"

exit 0
