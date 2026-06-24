import AppKit

// 桌面 AI 解读卡片浮层：点药丸「✨解读」后，就地弹出一张卡片（标题/解读/要点/相关/原文）
// + 「📌 加入卡片」按钮 → 回调上传成知识点卡片。无 Dock、悬浮在最前。
private final class KeyPanel: NSPanel { override var canBecomeKey: Bool { true } }

private final class RoundView: NSView {
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 0, alpha: 0.08).cgColor
    }
}

final class CardPopup: NSObject {
    private var panel: KeyPanel?
    private let W: CGFloat = 360
    private let padX: CGFloat = 20
    private var onAdd: (() -> Void)?

    private var innerW: CGFloat { W - padX * 2 }

    private func panelRef() -> KeyPanel {
        if let p = panel { return p }
        let p = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: W, height: 160),
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
    private func wrap(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: s)
        t.font = .systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.backgroundColor = .clear
        t.isBezeled = false; t.isEditable = false; t.isSelectable = false
        t.preferredMaxLayoutWidth = innerW
        t.frame.size = NSSize(width: innerW, height: t.fittingSize.height)
        return t
    }

    private func mkButton(_ title: String, primary: Bool, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = .systemFont(ofSize: 12, weight: .semibold)
        b.sizeToFit()
        var fr = b.frame; fr.size.width = max(fr.size.width + 16, 64); fr.size.height = 30; b.frame = fr
        if primary {
            b.isBordered = false
            b.wantsLayer = true
            b.layer?.backgroundColor = NSColor(srgbRed: 0.49, green: 0.23, blue: 0.93, alpha: 1).cgColor
            b.layer?.cornerRadius = 8
            b.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)])
            var f2 = b.frame; f2.size.width = max(f2.size.width, 96); b.frame = f2
        }
        return b
    }

    private func place(_ p: KeyPanel, height: CGFloat, root: NSView) {
        p.setContentSize(NSSize(width: W, height: height))
        root.frame = NSRect(x: 0, y: 0, width: W, height: height)
        p.contentView = root
        // 居中显示在鼠标所在屏幕
        let pt = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pt) } ?? NSScreen.main
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        p.setFrameOrigin(NSPoint(x: vf.midX - W / 2, y: vf.midY - height / 2))
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // —— 加载中 ——
    func showLoading() {
        let p = panelRef()
        let H: CGFloat = 116
        let root = RoundView()
        let spin = NSProgressIndicator(frame: NSRect(x: W / 2 - 12, y: H - 50, width: 24, height: 24))
        spin.style = .spinning; spin.isIndeterminate = true; spin.startAnimation(nil)
        root.addSubview(spin)
        let lab = wrap("✨ 正在 AI 解读…", size: 13, weight: .semibold, color: NSColor(white: 0.4, alpha: 1))
        lab.alignment = .center
        lab.frame = NSRect(x: padX, y: 22, width: innerW, height: lab.frame.height)
        root.addSubview(lab)
        place(p, height: H, root: root)
    }

    // —— 出错 ——
    func showError(_ msg: String) {
        let p = panelRef()
        let lab = wrap("⚠️ " + msg, size: 13, weight: .regular, color: NSColor(srgbRed: 0.72, green: 0.11, blue: 0.11, alpha: 1))
        let H = 24 + lab.frame.height + 14 + 30 + 16
        let root = RoundView()
        lab.frame.origin = NSPoint(x: padX, y: H - 24 - lab.frame.height)
        root.addSubview(lab)
        let close = mkButton("关闭", primary: false, action: #selector(closeTapped))
        close.frame.origin = NSPoint(x: W - padX - close.frame.width, y: 16)
        root.addSubview(close)
        place(p, height: H, root: root)
    }

    // —— 解读卡片 ——
    func showCard(_ card: AICard, text: String, onAdd: @escaping () -> Void) {
        self.onAdd = onAdd
        let p = panelRef()
        let root = RoundView()

        var blocks: [NSTextField] = []
        blocks.append(wrap("✨ AI 解读", size: 11, weight: .bold, color: NSColor(srgbRed: 0.49, green: 0.23, blue: 0.93, alpha: 1)))
        if !card.title.isEmpty { blocks.append(wrap(card.title, size: 16, weight: .bold, color: NSColor(white: 0.1, alpha: 1))) }
        if !card.explain.isEmpty { blocks.append(wrap(card.explain, size: 13, weight: .regular, color: NSColor(white: 0.25, alpha: 1))) }
        if !card.points.isEmpty {
            blocks.append(wrap(card.points.map { "· " + $0 }.joined(separator: "\n"), size: 12.5, weight: .regular, color: NSColor(white: 0.3, alpha: 1)))
        }
        if !card.relate.isEmpty { blocks.append(wrap("🔗 " + card.relate, size: 11.5, weight: .medium, color: NSColor(srgbRed: 0.42, green: 0.16, blue: 0.84, alpha: 1))) }
        let quote = String(text.prefix(120)) + (text.count > 120 ? "…" : "")
        blocks.append(wrap("「" + quote + "」", size: 11, weight: .regular, color: NSColor(white: 0.55, alpha: 1)))

        let gap: CGFloat = 8
        let topPad: CGFloat = 18
        let btnH: CGFloat = 30
        let btnGap: CGFloat = 14
        let bottomPad: CGFloat = 16
        let contentH = blocks.reduce(0) { $0 + $1.frame.height } + gap * CGFloat(max(0, blocks.count - 1))
        let H = topPad + contentH + btnGap + btnH + bottomPad

        // 从上往下摆（AppKit 原点在左下）
        var y = H - topPad
        for b in blocks {
            y -= b.frame.height
            b.frame.origin = NSPoint(x: padX, y: y)
            root.addSubview(b)
            y -= gap
        }
        // 底部按钮：右对齐「关闭 + 📌加入卡片」
        let add = mkButton("📌 加入卡片", primary: true, action: #selector(addTapped))
        let close = mkButton("关闭", primary: false, action: #selector(closeTapped))
        add.frame.origin = NSPoint(x: W - padX - add.frame.width, y: bottomPad)
        close.frame.origin = NSPoint(x: add.frame.minX - 8 - close.frame.width, y: bottomPad)
        root.addSubview(add); root.addSubview(close)

        place(p, height: H, root: root)
    }

    func hide() { panel?.orderOut(nil) }

    @objc private func addTapped() { onAdd?() }
    @objc private func closeTapped() { hide() }
}
