import Foundation

/// The lyrics source the app started with. Touched once at launch (see activateKaraokeHooks)
/// so it holds the launch value, not whatever is selected when settings is first opened.
enum LyricsLaunchSource {
    static let value = UserDefaults.lyricsSource
}
