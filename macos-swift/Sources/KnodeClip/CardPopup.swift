import AppKit

// 桌面 AI 解读卡片浮层：点药丸「✨解读」后，在划词位置「下方」弹出一张精致卡片
// （引文 + ✦一句话解读 + 💡关键点 + 🤔追问 + 💎加入知识卡片 + 底部小字）。
private final class KeyPanel: NSPanel { override var canBecomeKey: Bool { true } }

private final class RoundView: NSView {
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(srgbRed: 0.80, green: 0.72, blue: 0.98, alpha: 0.55).cgColor
    }
}

// 全宽渐变按钮
private final class GradientButton: NSView {
    var onClick: (() -> Void)?
    private let c1: NSColor, c2: NSColor
    init(title: String, c1: NSColor, c2: NSColor) {
        self.c1 = c1; self.c2 = c2
        super.init(frame: .zero)
        wantsLayer = true
        let l = NSTextField(labelWithString: title)
        l.font = .systemFont(ofSize: 14.5, weight: .bold)
        l.textColor = .white; l.backgroundColor = .clear; l.isBezeled = false; l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        addSubview(l)
        NSLayoutConstraint.activate([l.centerXAnchor.constraint(equalTo: centerXAnchor), l.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func makeBackingLayer() -> CALayer {
        let g = CAGradientLayer()
        g.colors = [c1.cgColor, c2.cgColor]
        g.startPoint = CGPoint(x: 0, y: 0.5); g.endPoint = CGPoint(x: 1, y: 0.5)
        g.cornerRadius = 13; g.masksToBounds = true
        return g
    }
    override func layout() { super.layout(); layer?.cornerRadius = 13 }
    override func mouseDown(with event: NSEvent) { onClick?() }
}

final class CardPopup: NSObject {
    private var panel: KeyPanel?
    private let W: CGFloat = 410
    private let padX: CGFloat = 22
    private let topPad: CGFloat = 20
    private let bottomPad: CGFloat = 18
    private var onAdd: (() -> Void)?

    // 主题色
    private let purple     = NSColor(srgbRed: 0.49, green: 0.23, blue: 0.93, alpha: 1)
    private let purpleDark = NSColor(srgbRed: 0.42, green: 0.16, blue: 0.84, alpha: 1)
    private let pink       = NSColor(srgbRed: 0.93, green: 0.28, blue: 0.60, alpha: 1)
    private let lavender   = NSColor(srgbRed: 0.957, green: 0.937, blue: 0.992, alpha: 1)

    private var innerW: CGFloat { W - padX * 2 }

    private func panelRef() -> KeyPanel {
        if let p = panel { return p }
        let p = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: W, height: 200),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel = p
        return p
    }

    // 自适应高度的换行文字
    private func wrap(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxW: CGFloat, lineSpacing: CGFloat = 3) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: s)
        t.font = .systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.backgroundColor = .clear
        t.isBezeled = false; t.isEditable = false; t.isSelectable = false
        let para = NSMutableParagraphStyle(); para.lineSpacing = lineSpacing
        t.attributedStringValue = NSAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: para,
        ])
        t.preferredMaxLayoutWidth = maxW
        t.frame.size = NSSize(width: maxW, height: t.fittingSize.height)
        return t
    }

    // 淡紫圆角块（引文 / 追问）；accent != nil 时左侧有竖条
    private func box(text: String, size: CGFloat, weight: NSFont.Weight, textColor: NSColor, accent: NSColor?) -> NSView {
        let bar: CGFloat = accent != nil ? 3 : 0
        let padIn: CGFloat = 13
        let lead: CGFloat = accent != nil ? bar + 9 : 0
        let lab = wrap(text, size: size, weight: weight, color: textColor, maxW: innerW - padIn * 2 - lead)
        let h = lab.frame.height + padIn * 2
        let v = NSView(frame: NSRect(x: 0, y: 0, width: innerW, height: h))
        v.wantsLayer = true
        v.layer?.backgroundColor = lavender.cgColor
        v.layer?.cornerRadius = 11
        if let ac = accent {
            let b = NSView(frame: NSRect(x: padIn - 3, y: padIn - 2, width: bar, height: h - (padIn - 2) * 2))
            b.wantsLayer = true; b.layer?.backgroundColor = ac.cgColor; b.layer?.cornerRadius = 1.5
            v.addSubview(b)
        }
        lab.frame.origin = NSPoint(x: padIn + lead, y: padIn)
        v.addSubview(lab)
        return v
    }

    private func mkClose() -> NSButton {
        let b = NSButton(title: "✕", target: self, action: #selector(closeTapped))
        b.isBordered = false
        b.attributedTitle = NSAttributedString(string: "✕", attributes: [
            .foregroundColor: NSColor(white: 0.6, alpha: 1),
            .font: NSFont.systemFont(ofSize: 15, weight: .medium)])
        b.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
        return b
    }

    private func place(_ p: KeyPanel, height: CGFloat, root: NSView, near anchor: NSPoint) {
        p.setContentSize(NSSize(width: W, height: height))
        root.frame = NSRect(x: 0, y: 0, width: W, height: height)
        p.contentView = root
        let a = anchor == .zero ? NSEvent.mouseLocation : anchor
        let screen = NSScreen.screens.first { $0.frame.contains(a) } ?? NSScreen.main
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // 出现在划词位置「下方」：卡片顶边贴着锚点稍下
        var x = a.x
        var originY = (a.y - 16) - height
        if originY < vf.minY + 8 { originY = vf.minY + 8 }
        if originY + height > vf.maxY - 8 { originY = vf.maxY - 8 - height }
        if x + W > vf.maxX - 8 { x = vf.maxX - 8 - W }
        if x < vf.minX + 8 { x = vf.minX + 8 }
        p.setFrameOrigin(NSPoint(x: x, y: originY))
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // —— 加载中 ——
    func showLoading(near anchor: NSPoint) {
        let p = panelRef()
        let H: CGFloat = 120
        let root = RoundView()
        let spin = NSProgressIndicator(frame: NSRect(x: W / 2 - 12, y: H - 52, width: 24, height: 24))
        spin.style = .spinning; spin.isIndeterminate = true; spin.startAnimation(nil)
        root.addSubview(spin)
        let lab = wrap("✨ 正在 AI 解读…", size: 13.5, weight: .semibold, color: NSColor(white: 0.4, alpha: 1), maxW: innerW)
        lab.alignment = .center
        lab.frame = NSRect(x: padX, y: 24, width: innerW, height: lab.frame.height)
        root.addSubview(lab)
        place(p, height: H, root: root, near: anchor)
    }

    // —— 出错 ——
    func showError(_ msg: String, near anchor: NSPoint) {
        let p = panelRef()
        let lab = wrap("⚠️ " + msg, size: 13, weight: .regular, color: NSColor(srgbRed: 0.72, green: 0.11, blue: 0.11, alpha: 1), maxW: innerW)
        let H = topPad + lab.frame.height + 14 + 30 + bottomPad
        let root = RoundView()
        lab.frame.origin = NSPoint(x: padX, y: H - topPad - lab.frame.height)
        root.addSubview(lab)
        let close = NSButton(title: "关闭", target: self, action: #selector(closeTapped))
        close.bezelStyle = .rounded; close.frame = NSRect(x: W - padX - 70, y: bottomPad, width: 70, height: 30)
        root.addSubview(close)
        place(p, height: H, root: root, near: anchor)
    }

    // —— 解读卡片 ——
    func showCard(_ card: AICard, text: String, near anchor: NSPoint, onAdd: @escaping () -> Void) {
        self.onAdd = onAdd
        let p = panelRef()
        let root = RoundView()

        let header = wrap("AI 解读", size: 14.5, weight: .bold, color: purple, maxW: innerW - 30)
        let close = mkClose()
        let quoteBox = box(text: text, size: 13.5, weight: .regular, textColor: NSColor(white: 0.30, alpha: 1), accent: purple)
        let l1 = wrap("✦ 一句话解读", size: 12, weight: .bold, color: purple, maxW: innerW)
        let explain = wrap(card.explain.isEmpty ? text : card.explain, size: 16.5, weight: .semibold, color: NSColor(white: 0.10, alpha: 1), maxW: innerW)

        var pl: NSTextField? = nil, pb: NSTextField? = nil
        if !card.points.isEmpty {
            pl = wrap("💡 关键点", size: 12, weight: .bold, color: NSColor(white: 0.22, alpha: 1), maxW: innerW)
            pb = wrap(card.points.map { "·  " + $0 }.joined(separator: "\n"), size: 13.5, weight: .regular, color: NSColor(white: 0.32, alpha: 1), maxW: innerW - 6, lineSpacing: 5)
        }
        var ask: NSView? = nil
        if !card.ask.isEmpty { ask = box(text: "🤔  " + card.ask, size: 13, weight: .medium, textColor: purpleDark, accent: nil) }

        let btn = GradientButton(title: "💎 加入知识卡片", c1: pink, c2: purple)
        btn.frame = NSRect(x: 0, y: 0, width: innerW, height: 48)
        btn.onClick = { [weak self] in self?.onAdd?() }
        let footer = wrap("看懂后再主动加入 · 之后用深度记忆法学它", size: 11, weight: .regular, color: NSColor(white: 0.62, alpha: 1), maxW: innerW)
        footer.alignment = .center

        let headerH: CGFloat = 24
        var H = topPad + headerH + 14 + quoteBox.frame.height + 18 + l1.frame.height + 7 + explain.frame.height
        if let pl = pl, let pb = pb { H += 18 + pl.frame.height + 7 + pb.frame.height }
        if let ask = ask { H += 14 + ask.frame.height }
        H += 18 + 48 + 11 + footer.frame.height + bottomPad

        var y = H - topPad
        // header
        y -= headerH
        header.frame.origin = NSPoint(x: padX, y: y + 3)
        close.frame.origin = NSPoint(x: W - padX - close.frame.width, y: y + 1)
        root.addSubview(header); root.addSubview(close)
        y -= 14
        // 引文
        y -= quoteBox.frame.height; quoteBox.frame.origin = NSPoint(x: padX, y: y); root.addSubview(quoteBox)
        y -= 18
        // 一句话解读
        y -= l1.frame.height; l1.frame.origin = NSPoint(x: padX, y: y); root.addSubview(l1)
        y -= 7
        y -= explain.frame.height; explain.frame.origin = NSPoint(x: padX, y: y); root.addSubview(explain)
        // 关键点
        if let pl = pl, let pb = pb {
            y -= 18; y -= pl.frame.height; pl.frame.origin = NSPoint(x: padX, y: y); root.addSubview(pl)
            y -= 7; y -= pb.frame.height; pb.frame.origin = NSPoint(x: padX, y: y); root.addSubview(pb)
        }
        // 追问
        if let ask = ask { y -= 14; y -= ask.frame.height; ask.frame.origin = NSPoint(x: padX, y: y); root.addSubview(ask) }
        // 按钮
        y -= 18; y -= 48; btn.frame.origin = NSPoint(x: padX, y: y); root.addSubview(btn)
        // 底部小字
        y -= 11; y -= footer.frame.height; footer.frame.origin = NSPoint(x: padX, y: y); root.addSubview(footer)

        place(p, height: H, root: root, near: anchor)
    }

    func hide() { panel?.orderOut(nil) }

    @objc private func closeTapped() { hide() }
}
