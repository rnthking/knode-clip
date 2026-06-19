# KnodeClip · 划线收集小工具（Windows / macOS）

在任意 App 选中文字，按 `Ctrl/⌘ + Shift + K`，就把它收进 KNode 的「收集箱」，在网页端「知识卡片 → 最近收集」里可见、可 AI 转卡片。

## 它怎么工作
- 托盘常驻（无主窗口）。
- 按热键时，应用会对前台**模拟一次复制**（mac=osascript，win=PowerShell SendKeys，linux=xdotool），读剪贴板内容上传，再**还原**你原来的剪贴板。
- 两种收集模式（托盘菜单切换）：**直接收集**（原文存卡）/ **AI 解读**（DeepSeek，解读在网页端完成）。

## 安装
- **macOS**：下载 `KnodeClip-mac.dmg` → 拖到「应用程序」。未签名，首次**右键 → 打开**；若提示「已损坏」，终端执行
  `xattr -dr com.apple.quarantine /Applications/KnodeClip.app`。
  还需在 **系统设置 → 隐私与安全性 → 辅助功能** 勾选 KnodeClip（模拟复制需要）。
- **Windows**：下载 `KnodeClip-win.exe` 安装。首次 SmartScreen 提示 → 「更多信息 → 仍要运行」。

固定下载地址（GitHub 最新 Release）：
- mac：`https://github.com/rnthking/knode-clip/releases/latest/download/KnodeClip-mac.dmg`
- win：`https://github.com/rnthking/knode-clip/releases/latest/download/KnodeClip-win.exe`

## 使用
1. 托盘 ✎ 图标 → **登录…**（与网页端同一账号）。
2. 选「收集模式」：直接 / AI 解读。
3. 任意 App 选中文字 → `Ctrl/⌘ + Shift + K` → 托盘提示「✓ 已收集」。
4. 网页端 → 知识卡片 → 最近收集 查看。

## 本地开发 / 打包
```bash
npm install
npm start          # 本地运行
npm run dist       # 当前平台打包到 release/
```

## 说明 / 限制
- 未签名/未公证，分发给他人会有系统拦截提示（按上面步骤打开）。
- macOS 当前 Release 为 Apple Silicon(arm64)。
- 旧的 macOS 原生 Swift 版在 `macos-swift/`（已归档，不再维护）。
