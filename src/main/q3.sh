#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"
cp -r "$input/assets" "$output/assets_copy"
cp "$input/config.conf" "$output/config.conf.bak"
mv "$input/draft.txt" "$output/final.txt"
rm -rf "$input/tmp"

chmod 750 "$output/assets_copy"
chmod 640 "$output/config.conf.bak"
chmod +x "$output/assets_copy/hello.sh"
"$output/assets_copy/hello.sh" > "$output/hello_out.txt"
