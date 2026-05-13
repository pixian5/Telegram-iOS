#!/bin/bash
set -e

OUTPUT_PATH="build/artifacts"
mkdir -p "$OUTPUT_PATH"

# 检查并初始化未拉取的关键 submodule
echo "检查 submodule 状态..."
while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $2}')
    echo "初始化 submodule: $path"
    rm -rf "$path"
    git submodule update --init "$path"
done < <(git submodule status | grep "^-")

echo "开始构建并导出IPA..."

python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    --cacheDir="$HOME/telegram-bazel-cache" \
    build \
    --configurationPath=build-system/appstore-configuration.json \
    --codesigningInformationPath=build-system/fake-codesigning \
    --buildNumber=1 \
    --configuration=release_arm64 \
    --outputBuildArtifactsPath="$OUTPUT_PATH"

echo "构建完成！IPA及DSYM文件保存在: $OUTPUT_PATH"
open "$OUTPUT_PATH"
