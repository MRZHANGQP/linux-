#!/bin/bash
# Q2：创建 sentry_ws 四个子目录、两个空文件以及指定脚本和配置。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 创建目录（把 TMP 改成小写 tmp）
mkdir -p "$output/sentry_ws/src"
mkdir -p "$output/sentry_ws/config"
mkdir -p "$output/sentry_ws/scripts"
mkdir -p "$output/sentry_ws/logs"
mkdir -p "$output/sentry_ws/tmp"

# 2. 创建空文件（增加 scratch.txt）
touch "$output/sentry_ws/src/main.cpp"
touch "$output/sentry_ws/logs/.keep"
touch "$output/sentry_ws/tmp/scratch.txt"

# 3. 写入指定的 hello.sh（完全照抄测试器期望的英文内容）
printf '#!/bin/bash\necho "Hello, AIM Linux!"\n' > "$output/sentry_ws/scripts/hello.sh"
chmod +x "$output/sentry_ws/scripts/hello.sh"

cat > "$output/sentry_ws/config/robot.conf" << EOF
robot=sentry
mode=training
version=1.0.0
EOF
