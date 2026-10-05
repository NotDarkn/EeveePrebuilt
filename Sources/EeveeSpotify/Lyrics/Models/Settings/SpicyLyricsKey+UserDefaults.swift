import Foundation

extension UserDefaults {
    private static let spicyLyricsApiKeyKey = "spicyLyricsApiKey"

    static let spicyLyricsDefaultApiKey = "sl_pk_2bickG_gRxepd6CvYUPwUpsMcLWaOE9zJ3mdk9fEF8Y"

    static var spicyLyricsApiKey: String {
        get {
            (container.string(forKey: spicyLyricsApiKeyKey) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set (key) {
            container.set(
                key.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: spicyLyricsApiKeyKey
            )
        }
    }

    static var effectiveSpicyLyricsApiKey: String {
        let key = spicyLyricsApiKey
        return key.isEmpty ? spicyLyricsDefaultApiKey : key
    }
}
