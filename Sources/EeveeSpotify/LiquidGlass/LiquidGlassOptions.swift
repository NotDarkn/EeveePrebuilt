import UIKit

struct LiquidGlassOptions: Codable, Equatable {
    var enabled = false
    var spotifyGlass = true
    var tabBar = true
    var nowPlayingBar = true
    var newPlayerDesign = false
    var search: Bool?
    var home: Bool?
    var playlist: Bool?
    var lyricsView: Bool?
}

struct TabBarOptions: Codable, Equatable {
    var order: [String] = []
    var hidden: [String] = []
    var hideLabels = false
    var launchTab: String?
    var albumTint: Bool?
    var custom: [CustomTab]?

    var customTabs: [CustomTab] {
        get { custom ?? [] }
        set { custom = newValue.isEmpty ? nil : newValue }
    }

    func arrange<T>(_ tabs: [T], title: (T) -> String?) -> [T] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }) { first, _ in first }
        let visible = tabs.enumerated()
            .filter { !hidden.contains(title($1) ?? "") }
            .sorted { (rank[title($0.1) ?? ""] ?? order.count + $0.0, $0.0) < (rank[title($1.1) ?? ""] ?? order.count + $1.0, $1.0) }
            .map(\.1)
        return visible.isEmpty ? tabs : visible
    }
}

struct CustomTab: Codable, Equatable, Hashable {
    var title: String
    var uri: String
    var sfSymbol: String

    var key: String { "uri:" + uri }
    var displayTitle: String { Self.presets.first { $0.uri == uri }?.title ?? title }
    var image: UIImage? { UIImage(systemName: sfSymbol) ?? UIImage(systemName: "star.fill") }

    // Spotify's own tabs are outlined until selected; the outline is the symbol without ".fill" when one exists.
    var outlineImage: UIImage? {
        let outline = sfSymbol.hasSuffix(".fill") ? String(sfSymbol.dropLast(5)) : sfSymbol
        return UIImage(systemName: outline) ?? image
    }

    static let presets = [
        CustomTab(title: "tab_liked_songs".localized, uri: "spotify:collection:tracks", sfSymbol: "heart.fill"),
        CustomTab(title: "tab_downloads".localized, uri: "spotify:collection:downloads", sfSymbol: "arrow.down.circle.fill"),
        CustomTab(title: "tab_podcasts".localized, uri: "spotify:collection:podcasts", sfSymbol: "mic.fill"),
        CustomTab(title: "tab_queue".localized, uri: "spotify:now-playing:queue", sfSymbol: "list.bullet"),
    ]

    static func uri(from text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = URLComponents(string: text) else { return nil }
        if parts.scheme?.lowercased() == "spotify", text.count > 8 { return text }
        guard parts.scheme?.lowercased().hasPrefix("http") == true, parts.host?.lowercased() == "open.spotify.com" else { return nil }
        var path = parts.path.split(separator: "/").map(String.init)
        if path.first?.hasPrefix("intl-") == true { path.removeFirst() }
        return path.count >= 2 ? "spotify:" + path.joined(separator: ":") : nil
    }
}

struct NowPlayingBarOptions: Codable, Equatable {
    var albumTint = true
    var roundArtwork = false
    var hideConnect = false
}

struct PlayerOptions: Codable, Equatable {
    var backdrop = true
    var glassLyricsCard = true
    var hidden: [PlayerPart]?

    var hiddenParts: [PlayerPart] {
        get { hidden ?? [] }
        set { hidden = newValue }
    }
}

struct PlaylistOptions: Codable, Equatable {
    var fullCover = false
    var dividers = false
    var hideFind = false
    var hidden: [PlaylistPart]?

    var hiddenParts: [PlaylistPart] {
        get { hidden ?? [] }
        set { hidden = newValue.isEmpty ? nil : newValue }
    }
}

enum PlaylistPart: String, CaseIterable, Codable {
    case description, creator, metadata, pills
}

extension Notification.Name {
    static let eeveeTabBarOptionsChanged = Notification.Name("EeveeTabBarOptionsChanged")
    static let eeveePlaylistOptionsChanged = Notification.Name("EeveePlaylistOptionsChanged")
    static let eeveeNowPlayingBarOptionsChanged = Notification.Name("EeveeNowPlayingBarOptionsChanged")
}

extension UserDefaults {
    @UserDefault(key: "eeveeLiquidGlassOptions", defaultValue: LiquidGlassOptions())
    static var liquidGlassOptions

    @UserDefault(key: "eeveeTabBarOptions", defaultValue: TabBarOptions())
    static var tabBarOptions

    @UserDefault(key: "eeveeNowPlayingBarOptions", defaultValue: NowPlayingBarOptions())
    static var nowPlayingBarOptions

    @UserDefault(key: "eeveePlayerOptions", defaultValue: PlayerOptions())
    static var playerOptions

    @UserDefault(key: "eeveePlaylistOptions", defaultValue: PlaylistOptions())
    static var playlistOptions

    @UserDefault(key: "eeveeKnownTabs", defaultValue: [String]())
    static var knownTabs
}
