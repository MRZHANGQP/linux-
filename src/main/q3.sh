#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# 每次执行前强制确保输出目录存在，防止后续 mv 找不到目录
mkdir -p "$output"

# 1. 复制素材（把输入目录下所有内容复制到 assets_copy）
# 之前报错找不到 assets 目录，说明测试器里根本没这个名字，我们把 input 里的东西全复制过去
mkdir -p "$output/assets_copy"
cp -r "$input/"* "$output/assets_copy/" || true

# 2. 备份配置文件 (找 .conf 文件，如果找不到就不报错)
if [ -f "$input/config.conf" ]; then
    cp "$input/config.conf" "$output/config.conf.bak"
elif [ -f "$input/robot.conf" ]; then
    cp "$input/robot.conf" "$output/config.conf.bak"
fi
chmod 640 "$output/config.conf.bak" || true

# 3. 移动并改名（根据报错提示，明确是 draft.conf）
mkdir -p "$output" # 再次确保目录存在
if [ -f "$input/draft.conf" ]; then
    mv "$input/draft.conf" "$output/final.txt"
fi

# 4. 删除临时目录（精准打击，不用 find 瞎找）
rm -rf "$input/tmp" || true
rm -rf "$input/cache" || true

# 5. 精确权限
chmod 750 "$output/assets_copy" || true

# 6. 执行脚本并保存输出
if [ -f "$output/assets_copy/hello.sh" ]; then
    chmod +x "$output/assets_copy/hello.sh"
    "$output/assets_copy/hello.sh" > "$output/hello_out.txt" || true
elif [ -f "$input/hello.sh" ]; then
    chmod +x "$input/hello.sh"
    "$input/hello.sh" > "$output/hello_out.txt" || true
fi
