import AppKit

// 简单登录窗口：邮箱 + 密码 + 登录按钮。成功后回调 onSuccess 让菜单刷新。
final class LoginWindowController: NSWindowController, NSWindowDelegate {
    private let emailField = NSTextField(frame: .zero)
    private let passField = NSSecureTextField(frame: .zero)
    private let hint = NSTextField(labelWithString: "")
    private let loginButton = NSButton(title: "登录", target: nil, action: nil)
    private let onSuccess: () -> Void

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "登录 KNode"
        win.center()
        super.init(window: win)
        win.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let emailLabel = NSTextField(labelWithString: "邮箱")
        let passLabel = NSTextField(labelWithString: "密码")
        passField.bezelStyle = .roundedBezel
        emailField.bezelStyle = .roundedBezel
        emailField.placeholderString = "you@example.com"
        loginButton.bezelStyle = .rounded
        loginButton.keyEquivalent = "\r"
        loginButton.target = self
        loginButton.action = #selector(doLogin)
        hint.textColor = .systemRed
        hint.font = .systemFont(ofSize: 11)
        hint.maximumNumberOfLines = 2

        let rows = [emailLabel, emailField, passLabel, passField, loginButton, hint]
        var y: CGFloat = 168
        for v in rows {
            v.translatesAutoresizingMaskIntoConstraints = true
            content.addSubview(v)
        }
        emailLabel.frame = NSRect(x: 20, y: y, width: 280, height: 18); y -= 24
        emailField.frame = NSRect(x: 20, y: y, width: 280, height: 24); y -= 34
        passLabel.frame = NSRect(x: 20, y: y, width: 280, height: 18); y -= 24
        passField.frame = NSRect(x: 20, y: y, width: 280, height: 24); y -= 36
        loginButton.frame = NSRect(x: 20, y: y, width: 280, height: 28); y -= 26
        hint.frame = NSRect(x: 20, y: y, width: 280, height: 18)
    }

    @objc private func doLogin() {
        let email = emailField.stringValue.trimmingCharacters(in: .whitespaces)
        let pass = passField.stringValue
        guard !email.isEmpty, !pass.isEmpty else { hint.stringValue = "请输入邮箱和密码"; return }
        loginButton.isEnabled = false
        hint.stringValue = "登录中…"
        Api.login(email: email, password: pass) { [weak self] result in
            guard let self = self else { return }
            self.loginButton.isEnabled = true
            switch result {
            case .success:
                self.onSuccess()
                self.window?.close()
            case .failure(let msg):
                self.hint.stringValue = msg
            }
        }
    }
}
