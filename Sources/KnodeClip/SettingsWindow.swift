import AppKit
import Carbon

// 录制快捷键的视图：点一下进入录制，按下"修饰键+某键"即捕获。
final class RecorderView: NSView {
    var onCapture: ((HotkeyConfig) -> Void)?
    private(set) var recording = false
    private let label = NSTextField(labelWithString: "")
    private var current: HotkeyConfig

    init(current: HotkeyConfig) {
        self.current = current
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        label.alignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        recording = true
        window?.makeFirstResponder(self)
        refresh()
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) { recording = false; refresh(); return }
        let cfg = HotkeyConfig.from(event: event)
        guard cfg.hasModifier else { return } // 必须带至少一个修饰键
        current = cfg
        recording = false
        refresh()
        onCapture?(cfg)
    }

    private func refresh() {
        if recording {
            label.stringValue = "请按下快捷键…（Esc 取消）"
            label.textColor = .secondaryLabelColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            label.stringValue = current.display
            label.textColor = .labelColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}

// 设置窗：显示/录制快捷键 + 恢复默认。
final class SettingsWindowController: NSWindowController {
    private let onChange: (HotkeyConfig) -> Void
    private var recorder: RecorderView!

    init(current: HotkeyConfig, onChange: @escaping (HotkeyConfig) -> Void) {
        self.onChange = onChange
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "设置"
        win.center()
        super.init(window: win)
        buildUI(current: current)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(current: HotkeyConfig) {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "划词开关热键")
        title.frame = NSRect(x: 20, y: 118, width: 300, height: 18)
        content.addSubview(title)

        recorder = RecorderView(current: current)
        recorder.frame = NSRect(x: 20, y: 74, width: 300, height: 36)
        recorder.onCapture = { [weak self] cfg in
            cfg.save()
            self?.onChange(cfg)
        }
        content.addSubview(recorder)

        let tip = NSTextField(labelWithString: "点上方方框，再按下想用的组合键（需含 ⌘/⌥/⌃ 之一）")
        tip.font = .systemFont(ofSize: 11)
        tip.textColor = .secondaryLabelColor
        tip.frame = NSRect(x: 20, y: 50, width: 300, height: 16)
        content.addSubview(tip)

        let reset = NSButton(title: "恢复默认（⌥⌘C）", target: self, action: #selector(resetDefault))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 20, y: 14, width: 300, height: 28)
        content.addSubview(reset)
    }

    @objc private func resetDefault() {
        let cfg = HotkeyConfig.default
        cfg.save()
        onChange(cfg)
        window?.close()
    }
}
