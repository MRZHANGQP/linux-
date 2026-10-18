#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

mkdir -p "$output/sentry_ws/config"
mkdir -p "$output/sentry_ws/backup"
mkdir -p "$output/sentry_ws/tmp"

echo "robot=sentry" > "$output/sentry_ws/config/robot.conf"

cp "$output/sentry_ws/config/robot.conf" "$output/sentry_ws/backup/robot.conf"

rm -rf "$output/sentry_ws/tmp"

mkdir -p "$output/assets_copy"

hello_script=$(find "$input" -name "hello.sh" | head -n 1 || true)

if [ -n "$hello_script" ]; then
    cp "$hello_script" "$output/assets_copy/hello.sh"
    chmod 750 "$output/assets_copy/hello.sh"
    "$output/assets_copy/hello.sh" > "$output/hello_out.txt" || true
fi
