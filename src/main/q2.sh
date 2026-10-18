#!/bin/bash
# Q2：创建 sentry_ws 四个子目录、两个空文件以及指定脚本和配置。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 创建所有要求的目录（包括 logs 和 TMP）
mkdir -p "$output/sentry_ws/src"
mkdir -p "$output/sentry_ws/config"
mkdir -p "$output/sentry_ws/scripts"
mkdir -p "$output/sentry_ws/logs"
mkdir -p "$output/sentry_ws/TMP"

# 2. 创建空文件（包括 .keep）
touch "$output/sentry_ws/src/main.cpp"
touch "$output/sentry_ws/logs/.keep"

# 3. 写入指定的 hello.sh，完全照抄期望输出
printf '#!/bin/bash\necho "你好，AIM Linux!"\n' > "$output/sentry_ws/scripts/hello.sh"
chmod +x "$output/sentry_ws/scripts/hello.sh"

# 4. 写入指定的配置文本 robot.conf
echo "param: value" > "$output/sentry_ws/config/robot.conf"
