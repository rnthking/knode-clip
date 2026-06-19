import AppKit

// 淡紫渐变药丸视图：背景层是 CAGradientLayer，居中文字，点击回调。
private final class GradientPill: NSView {
    var onClick: (() -> Void)?
    private let label: NSTextField
    private let c1: NSColor
    private let c2: NSColor

    init(text: String, textColor: NSColor, c1: NSColor, c2: NSColor) {
        self.label = NSTextField(labelWithString: text)
        self.c1 = c1
        self.c2 = c2
        super.init(frame: .zero)
        wantsLayer = true
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = textColor
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func makeBackingLayer() -> CALayer {
        let g = CAGradientLayer()
        g.colors = [c1.cgColor, c2.cgColor]
        g.startPoint = CGPoint(x: 0, y: 1)
        g.endPoint = CGPoint(x: 1, y: 0)
        g.masksToBounds = true
        return g
    }
    // 圆角按高度一半算 → 恒为药丸形
    override func layout() { super.layout(); layer?.cornerRadius = bounds.height / 2 }
    override func mouseDown(with event: NSEvent) { onClick?() }
}

// 划词后在光标旁冒出的小浮窗：两颗药丸「收集 / ✨解读」，点哪个回调对应 mode。
final class FloatingButton: NSObject {
    private var panel: NSPanel?
    private let onPick: (String) -> Void   // "direct" / "ai"
    private let pill = NSSize(width: 70, height: 26)
    private let gap: CGFloat = 8
    private var size: NSSize { NSSize(width: pill.width * 2 + gap, height: pill.height) }

    init(onPick: @escaping (String) -> Void) {
        self.onPick = onPick
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(at point: NSPoint) {
        if panel == nil { panel = makePanel() }
        guard let panel = panel else { return }
        var origin = NSPoint(x: point.x + 10, y: point.y - size.height - 10)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            origin.x = min(max(origin.x, f.minX + 4), f.maxX - size.width - 4)
            origin.y = min(max(origin.y, f.minY + 4), f.maxY - size.height - 4)
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true

        let container = NSView(frame: NSRect(origin: .zero, size: size))

        // 直接收集（浅紫底 + 深紫字）
        let direct = GradientPill(text: "收集",
                                  textColor: NSColor(srgbRed: 0.36, green: 0.13, blue: 0.71, alpha: 1),
                                  c1: NSColor(srgbRed: 0.85, green: 0.80, blue: 1.00, alpha: 1),
                                  c2: NSColor(srgbRed: 0.72, green: 0.62, blue: 1.00, alpha: 1))
        direct.frame = NSRect(x: 0, y: 0, width: pill.width, height: pill.height)
        direct.onClick = { [weak self] in self?.pick("direct") }

        // AI 解读（深紫底 + 白字）
        let ai = GradientPill(text: "✨解读",
                              textColor: .white,
                              c1: NSColor(srgbRed: 0.55, green: 0.36, blue: 0.96, alpha: 1),
                              c2: NSColor(srgbRed: 0.42, green: 0.16, blue: 0.84, alpha: 1))
        ai.frame = NSRect(x: pill.width + gap, y: 0, width: pill.width, height: pill.height)
        ai.onClick = { [weak self] in self?.pick("ai") }

        container.addSubview(direct)
        container.addSubview(ai)
        p.contentView = container
        return p
    }

    private func pick(_ mode: String) {
        hide()
        onPick(mode)
    }
}
