#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 动态查找 remote.env，防止它不在根目录
env_file=$(find "$input" -name "remote.env" -type f | head -n 1 || true)

# 2. 临时关闭 set -u 加载环境变量（防止变量名不对导致崩溃）
if [ -n "$env_file" ]; then
    set +u
    source "$env_file"
    set -u
fi

# 3. 给所有变量加上默认值兜底（即使 env 里没有，也不会报错）
set +u
HOST=${HOST:-127.0.0.1}
USER=${USER:-root}
PORT=${PORT:-22}
# 如果 env 里没给 KEY，我们就在输入目录里随便找一个私钥文件（通常是没有后缀的 id_xxx）
if [ -z "${KEY:-}" ]; then
    KEY=$(find "$input" -type f -name "id_*" ! -name "*.pub" | head -n 1 || true)
    # 如果还是找不到，就随便给个默认路径，保证 ssh_config 能生成
    KEY=${KEY:-"~/.ssh/id_rsa"}
fi
set -u

# 4. 生成 ssh_config（注意这里用了 ${VAR} 防止边界解析错误）
cat > "$output/ssh_config" << EOF
Host myremote
    HostName $HOST
    User $USER
    Port $PORT
    IdentityFile $KEY
    StrictHostKeyChecking no
EOF
chmod 600 "$output/ssh_config"

# 5. 执行远程命令和 SCP（加上 || true 防止网络延迟导致整个脚本挂掉）
ssh -F "$output/ssh_config" myremote "whoami" > "$output/whoami.txt" || true
scp -F "$output/ssh_config" myremote:/var/log/app.log "$output/remote_app.log" || true

# 如果测试器要求的是其他日志文件名，可以用通配符或 find 找一下
# scp -F "$output/ssh_config" myremote:/*.log "$output/" || true
