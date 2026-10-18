#!/bin/bash
# Q3：复制素材、备份配置、移动草稿、删除 tmp、设定权限并直接运行 hello.sh。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

mkdir -p "$output"

# 1. 动态查找需要复制的源文件夹（找名字里带 asset, material, resource 的目录）
# 假设我们要复制的目录里有 hello.sh，所以可以先搜 hello.sh 在哪
script_path=$(find "$input" -name "hello.sh" -type f | head -n 1 || true)
if [ -n "$script_path" ]; then
    src_dir=$(dirname "$script_path")
    # 复制整个目录并重命名
    cp -r "$src_dir" "$output/assets_copy"
fi

# 2. 动态查找配置文件并备份（找名字里带 .conf 的文件）
conf_file=$(find "$input" -name "*.conf" -type f | head -n 1 || true)
if [ -n "$conf_file" ]; then
    cp "$conf_file" "$output/config.conf.bak"
    chmod 640 "$output/config.conf.bak"
fi

# 3. 动态查找草稿文件并移动改名（找名字里带 draft 的文件）
draft_file=$(find "$input" -iname "*draft*" -type f | head -n 1 || true)
if [ -n "$draft_file" ]; then
    mv "$draft_file" "$output/final.txt"
fi

# 4. 动态查找并删除缓存目录（找名字叫 tmp, temp, cache 的目录）
for dir_name in "tmp" "temp" "cache"; do
    target_dir=$(find "$input" -type d -name "$dir_name" | head -n 1 || true)
    if [ -n "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
done

# 5. 设定精确权限（如果刚才复制了文件夹，这里设置权限）
if [ -d "$output/assets_copy" ]; then
    chmod 750 "$output/assets_copy"
    # 如果里面有脚本，给执行权限并运行
    if [ -f "$output/assets_copy/hello.sh" ]; then
        chmod +x "$output/assets_copy/hello.sh"
        "$output/assets_copy/hello.sh" > "$output/hello_out.txt"
    fi
fi
