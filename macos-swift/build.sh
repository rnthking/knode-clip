#!/usr/bin/env bash
# 编译 + 打包成 KnodeClip.app（菜单栏 App，无 Dock 图标）。未签名，本机自用。
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build -c release"
swift build -c release

BIN=".build/release/KnodeClip"
APP="KnodeClip.app"
MACOS="$APP/Contents/MacOS"

echo "==> 打包 $APP"
rm -rf "$APP"
mkdir -p "$MACOS"
cp "$BIN" "$MACOS/KnodeClip"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>KnodeClip</string>
  <key>CFBundleDisplayName</key><string>KNode 划线</string>
  <key>CFBundleIdentifier</key><string>cn.ithinkai.knode.clip</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>KnodeClip</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>用于读取选中文字</string>
</dict>
</plist>
PLIST

# Ad-hoc 签名：让下载后的 App 能右键→打开（Apple Silicon 上未签名+quarantine 会被拦成「已损坏」）。
# 仍是"未识别开发者"，首次需右键→打开；但不再是硬性"已损坏"。
echo "==> codesign（ad-hoc）"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "（codesign 跳过/失败，不影响本机运行）"

echo "==> 完成：$(pwd)/$APP"
echo "    运行：open \"$APP\"   或双击 Finder 里的 KnodeClip.app"
echo "    首次运行请在 系统设置 → 隐私与安全性 → 辅助功能 中允许 KnodeClip。"
