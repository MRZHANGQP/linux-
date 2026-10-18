#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
source "$input/remote.env"

cat > "$output/ssh_config" << EOF
Host myremote
    HostName $HOST
    User $USER
    Port $PORT
    IdentityFile $KEY
    StrictHostKeyChecking no
EOF

chmod 600 "$output/ssh_config"
ssh -F "$output/ssh_config" myremote "whoami" > "$output/whoami.txt"
scp -F "$output/ssh_config" myremote:/var/log/app.log "$output/remote_app.log"
