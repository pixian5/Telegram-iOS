#!/bin/bash
set -e

OUTPUT_PATH="build/artifacts"
mkdir -p "$OUTPUT_PATH"

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
