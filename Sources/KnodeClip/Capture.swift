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
        let saved = pb.string(forType: .string)
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
        // 稍后还原原剪贴板，避免污染用户的复制内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            pb.clearContents()
            if let saved = saved { pb.setString(saved, forType: .string) }
        }
        return result
    }

    private static func sendCmdC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmd: CGKeyCode = 0x37  // Command
        let cKey: CGKeyCode = 0x08 // C
        let loc = CGEventTapLocation.cghidEventTap
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: true)
        let cDown = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true); cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false); cUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: false)
        cmdDown?.post(tap: loc); cDown?.post(tap: loc); cUp?.post(tap: loc); cmdUp?.post(tap: loc)
    }
}
