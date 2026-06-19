import Foundation

// 让 String 可直接当作错误用（MVP 简化；失败信息就是给用户看的文案）
// 不加 @retroactive：老版本 Swift 没有该关键字，新版本只是警告——两边都能编。
extension String: Error {}

// KNode 后端交互：登录拿 token + 上传划线。token 暂存 UserDefaults（MVP；以后可换 Keychain）。
enum Api {
    // 线上地址；本地联调可临时改成 http://localhost:8000
    static let base = "https://spark.ithinkai.cn"
    private static let tokenKey = "knode_token"

    static var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }
    static var isLoggedIn: Bool { !((token ?? "").isEmpty) }

    // 后台下发的 DeepSeek Key（与 Web 同源；目前 AI 解读在 Web 完成，这里先同步缓存备用）
    static var dsKey: String? {
        get { UserDefaults.standard.string(forKey: "knode_ds_key") }
        set { UserDefaults.standard.set(newValue, forKey: "knode_ds_key") }
    }

    static func login(email: String, password: String, completion: @escaping (Result<Void, String>) -> Void) {
        request(path: "/spark/auth/login", body: ["email": email, "password": password], auth: false) { result in
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let json):
                if (json["code"] as? Int) == 0,
                   let data = json["data"] as? [String: Any],
                   let tok = data["token"] as? String {
                    token = tok
                    fetchAIKey()   // 登录后同步后台的 DeepSeek Key
                    completion(.success(()))
                } else {
                    completion(.failure((json["msg"] as? String) ?? "登录失败"))
                }
            }
        }
    }

    // 拉取后台配置的 DeepSeek Key 并缓存（公开接口，无需鉴权）
    static func fetchAIKey() {
        guard let url = URL(string: base + "/spark/ai-key") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let d = obj["data"] as? [String: Any],
                  let k = d["key"] as? String, !k.isEmpty else { return }
            dsKey = k
        }.resume()
    }

    static func postClip(text: String, source: String, sourceTitle: String, mode: String, completion: @escaping (Result<Void, String>) -> Void) {
        request(path: "/spark/clip", body: ["text": text, "source": source, "sourceTitle": sourceTitle, "mode": mode], auth: true) { result in
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let json):
                let code = json["code"] as? Int
                if code == 0 {
                    completion(.success(()))
                } else if code == 401 {
                    token = nil
                    completion(.failure("登录已过期，请重新登录"))
                } else {
                    completion(.failure((json["msg"] as? String) ?? "上传失败"))
                }
            }
        }
    }

    private static func request(path: String, body: [String: Any], auth: Bool, completion: @escaping (Result<[String: Any], String>) -> Void) {
        guard let url = URL(string: base + path) else { completion(.failure("URL 错误")); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let t = token { req.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, _, err in
            DispatchQueue.main.async {
                if let err = err { completion(.failure(err.localizedDescription)); return }
                guard let data = data,
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure("响应解析失败")); return
                }
                completion(.success(obj))
            }
        }.resume()
    }
}
