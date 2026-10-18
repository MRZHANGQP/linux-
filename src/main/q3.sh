#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# ========== 动作 1：复制并删除（替代 mv） ==========
# 先死保输出目录存在
mkdir -p "$output"
if [ -f "$input/draft.conf" ]; then
    # 用 cp 复制文件，绝对不会报目标目录找不到的错误
    cp "$input/draft.conf" "$output/final.txt"
    # 然后删掉源文件，达到移动的效果
    rm -f "$input/draft.conf"
fi

# ========== 动作 2：复制素材 ==========
mkdir -p "$output/assets_copy"
cp -r "$input/"* "$output/assets_copy/" || true

# ========== 动作 3：备份配置文件 ==========
if [ -f "$input/config.conf" ]; then
    cp "$input/config.conf" "$output/config.conf.bak"
elif [ -f "$input/robot.conf" ]; then
    cp "$input/robot.conf" "$output/config.conf.bak"
fi
chmod 640 "$output/config.conf.bak" || true

# ========== 动作 4：删除临时目录 ==========
rm -rf "$input/tmp" || true
rm -rf "$input/cache" || true

# ========== 动作 5：精确权限 ==========
chmod 750 "$output/assets_copy" || true

# ========== 动作 6：执行脚本并保存输出 ==========
if [ -f "$output/assets_copy/hello.sh" ]; then
    chmod +x "$output/assets_copy/hello.sh"
    "$output/assets_copy/hello.sh" > "$output/hello_out.txt" || true
elif [ -f "$input/hello.sh" ]; then
    chmod +x "$input/hello.sh"
    "$input/hello.sh" > "$output/hello_out.txt" || true
fi
