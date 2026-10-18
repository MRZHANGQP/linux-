#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
#!/bin/bash
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
mkdir -p "$output/sentry_ws/config"
mkdir -p "$output/sentry_ws/scripts"
mkdir -p "$output/sentry_ws/archive"

# 复制或生成 hello.sh 并赋权 750
hello_src=$(find "$input" -name "hello.sh" | head -n 1 || true)
if [ -n "$hello_src" ]; then
    cp "$hello_src" "$output/sentry_ws/scripts/hello.sh"
else
    printf '#!/bin/bash\necho "Hello"\n' > "$output/sentry_ws/scripts/hello.sh"
fi
chmod 750 "$output/sentry_ws/scripts/hello.sh"

# 复制或生成 robot.conf 并赋权 640
robot_src=$(find "$input" -name "robot.conf" | head -n 1 || true)
if [ -n "$robot_src" ]; then
    cp "$robot_src" "$output/sentry_ws/config/robot.conf"
else
    echo "robot=sentry" > "$output/sentry_ws/config/robot.conf"
fi
chmod 640 "$output/sentry_ws/config/robot.conf"

# 移动并重命名 draft.conf 到 archive
draft_src=$(find "$input" -name "draft.conf" | head -n 1 || true)
if [ -n "$draft_src" ]; then
    cp "$draft_src" "$output/sentry_ws/archive/draft.conf.old"
    rm -f "$draft_src" || true
fi

# 执行脚本，输出文件叫 hello-output.txt
if [ -f "$output/sentry_ws/scripts/hello.sh" ]; then
    "$output/sentry_ws/scripts/hello.sh" > "$output/hello-output.txt" 2>&1 || true
fi
