import Carbon
import AppKit

// 注册全局热键，按下回调 action。支持运行时改键（update）。
final class Hotkey {
    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(config: HotkeyConfig, action: @escaping () -> Void) {
        self.action = action
        installHandler()
        register(config)
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let me = Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)
    }

    func update(_ config: HotkeyConfig) {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
        register(config)
    }

    private func register(_ config: HotkeyConfig) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4B4E4F44), id: 1) // 'KNOD'
        RegisterEventHotKey(config.keyCode,
                            config.carbonModifiers,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &ref)
    }
}
