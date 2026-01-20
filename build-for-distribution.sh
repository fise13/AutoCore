#!/bin/bash

# Скрипт для сборки AutoCore для распространения на другие Mac
# Использование: ./build-for-distribution.sh

set -e

echo "🔨 Building AutoCore for distribution..."

# Очистка предыдущих сборок
echo "🧹 Cleaning previous builds..."
xcodebuild clean -project AutoCore.xcodeproj -scheme AutoCore -configuration Release

# Сборка Release версии с ad-hoc подписью (без сертификата)
echo "📦 Building Release version..."
xcodebuild \
    -project AutoCore.xcodeproj \
    -scheme AutoCore \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    DEVELOPMENT_TEAM="" \
    ENABLE_HARDENED_RUNTIME=YES \
    -derivedDataPath ./build

# Находим собранное приложение
APP_PATH=$(find ./build -name "AutoCore.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: AutoCore.app not found in build directory"
    exit 1
fi

echo "✅ Build successful!"
echo "📱 App location: $APP_PATH"

# Создаём архив для распространения
ARCHIVE_NAME="AutoCore-$(date +%Y%m%d-%H%M%S).zip"
ARCHIVE_PATH="./$ARCHIVE_NAME"

echo "📦 Creating archive..."
ditto -c -k --keepParent "$APP_PATH" "$ARCHIVE_PATH"

echo ""
echo "✅ Distribution archive created: $ARCHIVE_PATH"
echo ""
echo "📋 Instructions for users:"
echo "   1. Extract the ZIP file"
echo "   2. Right-click AutoCore.app → Open"
echo "   3. Click 'Open' in the security dialog"
echo "   OR"
echo "   Run: xattr -cr AutoCore.app"
echo "   Then double-click to open"
echo ""
