import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkey: Hotkey?
    private var loginWC: LoginWindowController?
    private var settingsWC: SettingsWindowController?
    private var hotkeyConfig = HotkeyConfig.load()

    private var floating: FloatingButton?
    private var cardPopup: CardPopup?
    private var lastSelPoint: NSPoint = .zero   // 最近一次划词位置（卡片在此下方弹出）
    private var lastSelText: String = ""        // 划词时已抓到的文字（点药丸直接用，保证有内容）
    private var mouseUpMonitor: Any?
    private var dismissMonitor: Any?
    private var downPoint: NSPoint = .zero
    private static let kPopup = "knode_popup_enabled"
    private var popupEnabled = UserDefaults.standard.bool(forKey: kPopup) // 未设置默认 false（启动不激活划词）

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()  // 杀掉重复打开的旧进程，避免“关不掉、到处弹浮窗”
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon()
        statusItem.button?.toolTip = "KNode 划线（\(hotkeyConfig.display) 收集选中文字）"
        rebuildMenu()
        hotkey = Hotkey(config: hotkeyConfig) { [weak self] in self?.toggleClipMode() }
        floating = FloatingButton { [weak self] mode in self?.collectFromPopup(mode) }
        cardPopup = CardPopup()
        installSelectionWatcher()
        Api.fetchAIKey()  // 同步后台下发的 DeepSeek Key
        _ = Capture.accessibilityTrusted(prompt: true) // 首次启动引导授权
    }

    // 关掉同 App 的其它实例（重复 open 时旧进程不会自动退出）
    private func terminateOtherInstances() {
        let me = NSRunningApplication.current
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier == me.bundleIdentifier && app.processIdentifier != me.processIdentifier {
            app.terminate()
        }
    }

    // —— 划词浮窗：监听鼠标松开。原生 App 用 AX 精确判断；其它 App 用“拖拽手势”判断 ——
    private func installSelectionWatcher() {
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.onMouseUp()
        }
        // 记录按下位置（算拖拽距离用）；并在别处点击/按键时收起浮窗
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] e in
            if e.type == .leftMouseDown { self?.downPoint = NSEvent.mouseLocation }
            self?.floating?.hide()
        }
    }

    private func onMouseUp() {
        guard popupEnabled, Api.isLoggedIn else { return }
        let up = NSEvent.mouseLocation
        let dragged = hypot(up.x - downPoint.x, up.y - downPoint.y) > 6  // 必须真的划动过才算划词
        // 纯点击（没划动）不弹浮窗——避免一点鼠标就冒泡
        guard dragged else { lastSelText = ""; floating?.hide(); return }
        // 略等一下让前台 App 把选区生效，然后真的抓一次文字：先 AX，取不到再 ⌘C。
        // 只有抓到内容才弹浮窗（顺便缓存，点药丸时直接用，既保证有内容又免去二次抓取）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            guard Capture.accessibilityTrusted(prompt: false) else { return }
            let text = Capture.selectedText().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                self.lastSelText = text
                self.lastSelPoint = up        // 记下划词位置，AI 卡片在此下方弹出
                self.floating?.show(at: up)
            } else {
                self.lastSelText = ""
                self.floating?.hide()         // 划了但没选中文字 → 不弹
            }
        }
    }

    // 点浮窗时直接用划词时已抓到的文字（保证有内容）；极端情况下缓存空了再补抓一次
    private func collectFromPopup(_ mode: String) {
        var text = lastSelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { text = Capture.selectedText().trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !text.isEmpty else { flash("没选中文字"); return }
        if mode == "ai" { showAICard(text: text) }   // ✨解读 → 桌面就地弹解读卡片
        else { send(text: text, mode: "direct") }     // 收集 → 直接存卡
    }

    // ✨ AI 解读：调 DeepSeek 出解读 → 弹卡片 → 点「加入卡片」才上传成知识点卡片
    private func showAICard(text: String) {
        guard Api.isLoggedIn else { flash("请先登录"); showLogin(); return }
        let anchor = lastSelPoint
        cardPopup?.showLoading(near: anchor)
        Api.analyze(text: text) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let card):
                self.cardPopup?.showCard(card, text: text, near: anchor) { [weak self] in
                    self?.addAICard(text: text)
                }
            case .failure(let msg):
                self.cardPopup?.showError(msg, near: anchor)
            }
        }
    }

    // 「加入卡片」：上传成 AI 卡片（网页端「知识卡片」即可见）
    private func addAICard(text: String) {
        let app = Capture.frontmostAppName()
        Api.postClip(text: text, source: app, sourceTitle: app, mode: "ai") { [weak self] result in
            switch result {
            case .success:
                self?.cardPopup?.animateOut()   // 淡出收尾动效，再收起
                self?.flash("✓ 已加入卡片")
            case .failure(let msg):
                self?.flash(msg)
            }
        }
    }

    // 划词模式总开关：热键/菜单都走这里
    @objc private func toggleClipMode() {
        popupEnabled.toggle()
        UserDefaults.standard.set(popupEnabled, forKey: AppDelegate.kPopup)
        if !popupEnabled { floating?.hide() }
        rebuildMenu()
        flash(popupEnabled ? "划词已开启" : "划词已关闭")  // flash 结束后会按状态还原图标+绿点
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let login = Api.isLoggedIn ? "已登录" : "未登录"
        let clip = popupEnabled ? "划词中 🟢" : "已关闭 🔴"
        let head = NSMenuItem(title: "KNode 划线 · \(login) · \(clip)", action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        menu.addItem(.separator())
        let clipItem = NSMenuItem(title: "划词收集（\(hotkeyConfig.display) 开关）", action: #selector(toggleClipMode), keyEquivalent: "")
        clipItem.state = popupEnabled ? .on : .off
        menu.addItem(clipItem)
        menu.addItem(NSMenuItem(title: "直接收集当前选中", action: #selector(captureAndSend), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "✨ AI 解读当前选中", action: #selector(captureAndAnalyze), keyEquivalent: ""))
        menu.addItem(.separator())
        if Api.isLoggedIn {
            menu.addItem(NSMenuItem(title: "退出登录", action: #selector(logout), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "登录…", action: #selector(showLogin), keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "退出 KNode 划线", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    @objc private func showSettings() {
        settingsWC = SettingsWindowController(current: hotkeyConfig) { [weak self] cfg in
            guard let self = self else { return }
            self.hotkeyConfig = cfg
            self.hotkey?.update(cfg)
            self.statusItem.button?.toolTip = "KNode 划线（\(cfg.display) 收集选中文字）"
            self.rebuildMenu()
        }
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showLogin() {
        loginWC = LoginWindowController { [weak self] in self?.rebuildMenu() }
        loginWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func logout() {
        Api.token = nil
        rebuildMenu()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // 菜单/热键：直接收集（原文存卡）
    @objc func captureAndSend() { captureCurrent(mode: "direct") }
    // 菜单：AI 解读收集
    @objc func captureAndAnalyze() { captureCurrent(mode: "ai") }

    private func captureCurrent(mode: String) {
        guard Api.isLoggedIn else { flash("请先登录"); showLogin(); return }
        guard Capture.accessibilityTrusted(prompt: true) else {
            flash("需在「辅助功能」里授权")
            return
        }
        let text = Capture.selectedText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { flash("没选中文字"); return }
        send(text: text, mode: mode)
    }

    // 浮窗与菜单共用的上传逻辑（mode: direct=直接存卡 / ai=AI 解读）
    private func send(text: String, mode: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard Api.isLoggedIn else { flash("请先登录"); showLogin(); return }
        let app = Capture.frontmostAppName()
        flash(mode == "ai" ? "✨ 解读收集中…" : "收集中…")
        Api.postClip(text: text, source: app, sourceTitle: app, mode: mode) { [weak self] result in
            switch result {
            case .success:
                self?.flash(mode == "ai" ? "✓ 已收集(待AI解读)" : "✓ 已收集")
            case .failure(let msg):
                self?.flash(msg)
                if msg.contains("过期") { self?.rebuildMenu() }
            }
        }
    }

    // 菜单栏 logo：SF Symbol（荧光笔，template 自动适配深浅色）；
    // 始终显示一个状态点：绿点=划词已激活，红点=已关闭（用彩色 ● 小标题，不破坏图标自适应）
    private func setIcon() {
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let img = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "KNode 划线")?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.attributedTitle = NSAttributedString(string: " ●", attributes: [
            .foregroundColor: popupEnabled ? NSColor.systemGreen : NSColor.systemRed,
            .font: NSFont.systemFont(ofSize: 9),
        ])
    }

    // 把菜单栏图标短暂换成提示文字，1.6s 后还原 logo
    private func flash(_ s: String) {
        statusItem.button?.image = nil
        statusItem.button?.title = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.setIcon()
        }
    }
}
