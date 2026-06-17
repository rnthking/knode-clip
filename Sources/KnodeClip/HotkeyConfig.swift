import AppKit
import Carbon

// 热键配置：虚拟键码 + Carbon 修饰键掩码。存 UserDefaults，默认 ⌥⌘C。
struct HotkeyConfig: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = HotkeyConfig(keyCode: UInt32(kVK_ANSI_C),
                                        carbonModifiers: UInt32(cmdKey | optionKey))

    private static let kKey = "knode_hotkey_keycode"
    private static let kMods = "knode_hotkey_mods"

    static func load() -> HotkeyConfig {
        let d = UserDefaults.standard
        guard d.object(forKey: kKey) != nil else { return .default }
        let k = UInt32(d.integer(forKey: kKey))
        let m = UInt32(d.integer(forKey: kMods))
        guard m != 0 else { return .default }   // 必须带修饰键
        return HotkeyConfig(keyCode: k, carbonModifiers: m)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: HotkeyConfig.kKey)
        d.set(Int(carbonModifiers), forKey: HotkeyConfig.kMods)
    }

    // 人类可读：⌃⌥⇧⌘ + 键名
    var display: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + HotkeyConfig.keyName(keyCode)
    }

    // 由 NSEvent 构造（录制时用）：Cocoa 修饰键 → Carbon 掩码
    static func from(event: NSEvent) -> HotkeyConfig {
        var mods: UInt32 = 0
        let f = event.modifierFlags
        if f.contains(.command) { mods |= UInt32(cmdKey) }
        if f.contains(.option)  { mods |= UInt32(optionKey) }
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.shift)   { mods |= UInt32(shiftKey) }
        return HotkeyConfig(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
    }

    var hasModifier: Bool { carbonModifiers != 0 }

    // 常用键码 → 显示名；其余回退十六进制
    static func keyName(_ code: UInt32) -> String {
        let map: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
            UInt32(kVK_Escape): "⎋",
            UInt32(kVK_ANSI_Period): ".", UInt32(kVK_ANSI_Comma): ",",
            UInt32(kVK_ANSI_Slash): "/", UInt32(kVK_ANSI_Semicolon): ";",
            UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_LeftBracket): "[",
            UInt32(kVK_ANSI_RightBracket): "]", UInt32(kVK_ANSI_Backslash): "\\",
            UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
            UInt32(kVK_ANSI_Grave): "`",
        ]
        return map[code] ?? String(format: "0x%02X", code)
    }
}
