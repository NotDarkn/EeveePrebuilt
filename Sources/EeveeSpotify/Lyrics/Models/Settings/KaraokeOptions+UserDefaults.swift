import Foundation

extension UserDefaults {
    @UserDefault(
        key: "karaokeOptions",
        defaultValue: KaraokeOptions()
    )
    static var karaokeOptions
}
