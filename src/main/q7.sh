#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
mkdir -p "$output/received"

env_file=$(find "$input" -name "remote.env" -type f | head -n 1 || true)

if [ -n "$env_file" ]; then
    set +u
    source "$env_file"
    set -u
fi

set +u
HOST=${HOST:-127.0.0.1}
USER=${USER:-root}
PORT=${PORT:-22}
if [ -z "${KEY:-}" ]; then
    KEY=$(find "$input" -type f -name "id_*" ! -name "*.pub" | head -n 1 || true)
    KEY=${KEY:-"~/.ssh/id_rsa"}
fi
set -u

cat > "$output/ssh_config" << EOF
Host myremote
    HostName $HOST
    User $USER
    Port $PORT
    IdentityFile $KEY
    StrictHostKeyChecking no
EOF

chmod 600 "$output/ssh_config"

ssh -F "$output/ssh_config" myremote "whoami" > "$output/remote-user.txt" || true
scp -F "$output/ssh_config" myremote:/var/log/app.log "$output/received/errors.log" || true
scp -F "$output/ssh_config" myremote:/*.log "$output/received/" 2>/dev/null || true
