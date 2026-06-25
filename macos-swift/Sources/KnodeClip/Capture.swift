import AppKit
import ApplicationServices

// 捕获“当前选中的文字”：先用 Accessibility 读，读不到就模拟 ⌘C 读剪贴板（用后还原）。
enum Capture {
    static func selectedText() -> String {
        if let t = axSelectedText(), !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t
        }
        return copyViaCmdC()
    }

    static func frontmostAppName() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
    }

    // 只用 Accessibility 读当前选中（不触发 ⌘C 回退）——给浮窗用，避免每次划词都改剪贴板
    static func selectedTextAXOnly() -> String? { axSelectedText() }

    // 是否已获辅助功能授权；prompt=true 会弹系统授权引导
    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    // —— Accessibility 读取焦点元素的选中文字 ——
    private static func axSelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let f = focused else { return nil }
        let element = f as! AXUIElement
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
           let s = value as? String {
            return s
        }
        return nil
    }

    // —— 回退：模拟 ⌘C，读剪贴板，再把用户原剪贴板还原 ——
    private static func copyViaCmdC() -> String {
        let pb = NSPasteboard.general
        // 完整快照用户原剪贴板（含图片/文件等所有类型）——划词探测很频繁，必须原样还原，不能只保字符串
        let saved: [[NSPasteboard.PasteboardType: Data]] = (pb.pasteboardItems ?? []).map { item in
            var dict = [NSPasteboard.PasteboardType: Data]()
            for t in item.types { if let d = item.data(forType: t) { dict[t] = d } }
            return dict
        }
        let savedCount = pb.changeCount
        sendCmdC()
        var result = ""
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            if pb.changeCount != savedCount {
                result = pb.string(forType: .string) ?? ""
                break
            }
            usleep(20_000)
        }
        // 稍后原样还原用户剪贴板，避免污染他的复制内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            pb.clearContents()
            let items = saved.compactMap { dict -> NSPasteboardItem? in
                guard !dict.isEmpty else { return nil }
                let it = NSPasteboardItem()
                for (t, d) in dict { it.setData(d, forType: t) }
                return it
            }
            if !items.isEmpty { pb.writeObjects(items) }
        }
        return result
    }

    private static func sendCmdC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmd: CGKeyCode = 0x37  // Command
        let cKey: CGKeyCode = 0x08 // C
        let loc = CGEventTapLocation.cghidEventTap
        // ⌘ 按下时事件本身要带 .maskCommand；⌘ 抬起时 flags 必须清空。
        // 每步之间留极短间隔，避免事件被合并 / ⌘「卡住」导致后续划词变成 ⌘+拖拽而选不中。
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: true);  cmdDown?.flags = .maskCommand
        let cDown   = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true);  cDown?.flags = .maskCommand
        let cUp     = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false); cUp?.flags = .maskCommand
        let cmdUp   = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: false);  cmdUp?.flags = []
        cmdDown?.post(tap: loc); usleep(9000)
        cDown?.post(tap: loc);   usleep(9000)
        cUp?.post(tap: loc);     usleep(9000)
        cmdUp?.post(tap: loc);   usleep(5000)
        // 兜底：再单独抬一次 ⌘，确保修饰键彻底释放（防止极少数情况下卡住）
        let cmdUp2 = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: false); cmdUp2?.flags = []
        cmdUp2?.post(tap: loc)
    }
}
