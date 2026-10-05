import UIKit
import SwiftUI

/// Presents the custom karaoke lyrics view as a full-screen modal, on top
/// of whatever screen is currently shown — the "overlay" approach (Option D)
/// rather than replacing Spotify's native LyricsViewControllerImplementation,
/// since that would need a live-runtime hook point we weren't able to find
/// safely (Spotify's anti-instrumentation protections crash on Frida attach
/// before enumeration/hooking can happen).
final class KaraokeOverlayPresenter {
    private(set) static var isPresented = false

    static func present() {
        guard !isPresented else { return }
        guard UserDefaults.karaokeOptions.enabled, UserDefaults.lyricsSource.supportsCustomLyricsView else {
            writeDebugLog("[Karaoke] present() skipped: custom lyrics view disabled in settings or unsupported by the lyrics source")
            return
        }
        guard #available(iOS 15.0, *) else {
            writeDebugLog("[Karaoke] present() skipped: requires iOS 15+")
            return
        }
        guard let host = topVC() else {
            writeDebugLog("[Karaoke] present() called but no top view controller found")
            return
        }
        guard let trackId = KaraokePlaybackTracker.shared.currentTrackId(),
              let lyrics = KaraokeLyricsStore.shared.lyrics(forTrackId: trackId) else {
            writeDebugLog("[Karaoke] present() called but no karaoke (Syllable) data available for current track")
            return
        }

        let view = KaraokeLyricsView(trackId: trackId, lyrics: lyrics, onDismiss: {
            guard isPresented else { return }
            isPresented = false
            topVC()?.dismiss(animated: true)
        })
        let hosting = UIHostingController(rootView: view)
        hosting.overrideUserInterfaceStyle = .dark
        // Glass needs the player visible behind it; the animated backdrop is opaque.
        let glass = KaraokeGlass.isEnabled
        hosting.modalPresentationStyle = glass ? .overFullScreen : .fullScreen
        hosting.view.backgroundColor = glass ? .clear : .black

        isPresented = true
        host.present(hosting, animated: true)
    }

    /// True if karaoke data exists for the current track — callers (e.g.
    /// whatever decides whether to show a "Karaoke" button at all) should
    /// check this rather than always presenting and risking a no-op.
    static func isAvailableForCurrentTrack() -> Bool {
        guard UserDefaults.karaokeOptions.enabled, UserDefaults.lyricsSource.supportsCustomLyricsView else { return false }
        guard let trackId = KaraokePlaybackTracker.shared.currentTrackId() else { return false }
        return KaraokeLyricsStore.shared.lyrics(forTrackId: trackId) != nil
    }

    /// Walks from WindowHelper's captured-at-launch root view controller
    /// (NOT a fresh `UIApplication.shared...windows` lookup) down to
    /// whatever's actually topmost right now.
    private static func topVC() -> UIViewController? {
        var top = WindowHelper.shared.rootViewController
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
