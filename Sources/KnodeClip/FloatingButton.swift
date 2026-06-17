import AppKit

// 淡紫渐变药丸视图：背景层是 CAGradientLayer，居中深紫字，点击回调。
private final class GradientPill: NSView {
    var onClick: (() -> Void)?
    private let label = NSTextField(labelWithString: "Knode收集")

    override func makeBackingLayer() -> CALayer {
        let g = CAGradientLayer()
        g.colors = [
            NSColor(srgbRed: 0.85, green: 0.80, blue: 1.00, alpha: 1).cgColor, // 淡紫
            NSColor(srgbRed: 0.72, green: 0.62, blue: 1.00, alpha: 1).cgColor, // 稍深淡紫
        ]
        g.startPoint = CGPoint(x: 0, y: 1)
        g.endPoint = CGPoint(x: 1, y: 0)   // 左上 → 右下
        g.masksToBounds = true
        return g
    }

    // 圆角按高度一半算 → 恒为药丸形（不受尺寸改动影响）
    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(srgbRed: 0.36, green: 0.13, blue: 0.71, alpha: 1) // 深紫
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

    override func mouseDown(with event: NSEvent) { onClick?() }
}

// 划词后在光标旁冒出的小浮窗，点一下回调 onClick（由外部决定怎么抓文字）。
final class FloatingButton: NSObject {
    private var panel: NSPanel?
    private let onClick: () -> Void
    private let size = NSSize(width: 84, height: 26)

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(at point: NSPoint) {
        if panel == nil { panel = makePanel() }
        guard let panel = panel else { return }

        // 默认放在光标右下方一点，避免遮住选区；再夹到屏幕可见区域内
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

        let pill = GradientPill(frame: NSRect(origin: .zero, size: size))
        pill.onClick = { [weak self] in
            guard let self = self else { return }
            self.hide()
            self.onClick()
        }
        p.contentView = pill
        return p
    }
}
