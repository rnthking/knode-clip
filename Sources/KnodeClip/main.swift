import AppKit

// 入口：菜单栏 App（.accessory = 无 Dock 图标，只在菜单栏）
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
