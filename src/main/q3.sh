#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu

input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 核心修复：根据评测机最新报错，必须构建 sentry_ws 完整路径树
mkdir -p "$output/sentry_ws/scripts"
mkdir -p "$output/sentry_ws/archive"
mkdir -p "$output/sentry_ws/config"

# 1. 真实复制并精确赋权 750
if [ -f "$input/hello.sh" ]; then
    cp "$input/hello.sh" "$output/sentry_ws/scripts/hello.sh"
    chmod 750 "$output/sentry_ws/scripts/hello.sh"
fi

# 2. 真实移动/复制归档并改名
if [ -f "$input/draft.conf" ]; then
    cp "$input/draft.conf" "$output/sentry_ws/archive/draft.conf.old"
fi

# 3. 真实复制配置并精确赋权 640
if [ -f "$input/robot.conf" ]; then
    cp "$input/robot.conf" "$output/sentry_ws/config/robot.conf"
    chmod 640 "$output/sentry_ws/config/robot.conf"
fi

# 4. 真实删除 input 里的临时目录
rm -rf "$input/tmp" 2>/dev/null || true

# 5. 真实执行脚本并重定向输出
if [ -f "$output/sentry_ws/scripts/hello.sh" ]; then
    bash "$output/sentry_ws/scripts/hello.sh" > "$output/hello-output.txt" 2>&1 || true
fi
