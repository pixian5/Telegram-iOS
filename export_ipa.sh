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

# ===== 创建临时钥匙串并导入假证书（免交互弹窗） =====
CERTS_PATH="build-system/fake-codesigning/certs"
MY_KEYCHAIN="telegram-build-temp.keychain"
MY_KEYCHAIN_PASSWORD="secret"

echo "配置临时钥匙串..."
# 清理已有的同名钥匙串
security delete-keychain "$MY_KEYCHAIN" 2>/dev/null || true
# 创建新的临时钥匙串
security create-keychain -p "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"
# 将临时钥匙串加入搜索列表
security list-keychains -d user -s "$MY_KEYCHAIN" $(security list-keychains -d user | sed s/\"//g)
security set-keychain-settings "$MY_KEYCHAIN"
security unlock-keychain -p "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"

# 导入所有证书（忽略已存在的错误）
for f in "$CERTS_PATH"/*.p12; do
    [ -f "$f" ] && security import "$f" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security || true
done
for f in "$CERTS_PATH"/*.cer; do
    [ -f "$f" ] && security import "$f" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security || true
done
# 导入 Apple WWDR 中间证书
security import "build-system/AppleWWDRCAG3.cer" -k "$MY_KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security || true
# 设置分区列表（允许 codesign 免提示访问）
security set-key-partition-list -S apple-tool:,apple: -k "$MY_KEYCHAIN_PASSWORD" "$MY_KEYCHAIN"

echo "临时钥匙串配置完成，开始构建..."

# ===== 构建 =====
python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    --cacheDir="$HOME/telegram-bazel-cache" \
    build \
    --configurationPath=build-system/appstore-configuration.json \
    --codesigningInformationPath=build-system/fake-codesigning \
    --buildNumber=1 \
    --configuration=release_arm64 \
    --outputBuildArtifactsPath="$OUTPUT_PATH"

# ===== 清理临时钥匙串 =====
echo "清理临时钥匙串..."
security delete-keychain "$MY_KEYCHAIN" 2>/dev/null || true

echo "构建完成！IPA及DSYM文件保存在: $OUTPUT_PATH"
open "$OUTPUT_PATH"
