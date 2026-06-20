import Foundation

enum LyricsSource: Int, CaseIterable, CustomStringConvertible {
    case genius
    case lrclib
    case musixmatch
    case petit
    case notReplaced
    case spicylyrics

    public static var allCases: [LyricsSource] {
        return [.spicylyrics, .musixmatch, .lrclib, .genius, .petit]
    }

    var description: String {
        switch self {
        case .genius:       return "Genius"
        case .lrclib:       return "LRCLIB"
        case .musixmatch:   return "Musixmatch"
        case .petit:        return "PetitLyrics"
        case .notReplaced:  return "Spotify"
        case .spicylyrics:  return "SpicyLyrics"
        }
    }

    var isReplacingLyrics: Bool { self != .notReplaced }

    static var defaultSource: LyricsSource {
        .spicylyrics
    }
}
