import Foundation

/// Values come from Config.xcconfig (gitignored — see Config.xcconfig.example),
/// injected into Info.plist at build time. Real secrets never enter git history.
enum AppConfig {
    static let backendURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String,
            let url = URL(string: raw)
        else {
            fatalError("BACKEND_URL missing or invalid — copy Config.xcconfig.example to Config.xcconfig and fill it in")
        }
        return url
    }()

    static let backendSharedSecret: String = {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "BACKEND_SHARED_SECRET") as? String else {
            fatalError("BACKEND_SHARED_SECRET missing — copy Config.xcconfig.example to Config.xcconfig and fill it in")
        }
        return secret
    }()
}
