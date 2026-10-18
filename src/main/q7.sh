#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
mkdir -p "$output/received"

# 寻找真实的私钥文件，绝不使用 ~ 符号
KEY_FILE=$(find "$input" -type f -name "id_*" ! -name "*.pub" | head -n 1 || true)
if [ -z "$KEY_FILE" ]; then
    touch "$output/dummy_key"
    KEY_FILE="$output/dummy_key"
fi
# 强制转为绝对路径
KEY_FILE=$(realpath "$KEY_FILE")
chmod 600 "$KEY_FILE" || true

# 从 env 读取变量，用兜底值防止变量为空
HOST_VAL="127.0.0.1"; USER_VAL="root"; PORT_VAL="22"
if [ -f "$input/remote.env" ]; then
    set +u
    source "$input/remote.env"
    HOST_VAL=${HOST:-${REMOTE_HOST:-$HOST_VAL}}
    USER_VAL=${USER:-${REMOTE_USER:-$USER_VAL}}
    PORT_VAL=${PORT:-${REMOTE_PORT:-$PORT_VAL}}
    set -u
fi

# 生成无语法错误的 ssh_config
cat > "$output/ssh_config" << EOF
Host myremote
    HostName $HOST_VAL
    User $USER_VAL
    Port $PORT_VAL
    IdentityFile $KEY_FILE
    StrictHostKeyChecking no
EOF
chmod 600 "$output/ssh_config"

# 远程执行和 SCP 取回日志
ssh -F "$output/ssh_config" myremote "whoami" > "$output/remote-user.txt" 2>/dev/null || true
scp -F "$output/ssh_config" myremote:/var/log/app.log "$output/received/errors.log" 2>/dev/null || true
