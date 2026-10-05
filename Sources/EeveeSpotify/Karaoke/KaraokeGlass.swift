import SwiftUI
import UIKit

/// Liquid glass for the custom lyrics view. Follows the master Liquid Glass switch
/// plus its own "Custom lyrics view" surface toggle, read at launch like the other surfaces.
enum KaraokeGlass {
    static var isEnabled: Bool {
        guard #available(iOS 26.0, *) else { return false }
        let options = LiquidGlass.launchOptions
        return options.enabled && options.lyricsView != false
    }
}

/// Full-screen glass that replaces the animated backdrop. The view is presented
/// over the player (see KaraokeOverlayPresenter), so the glass picks up what is behind it.
@available(iOS 15.0, *)
struct KaraokeGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        view.overrideUserInterfaceStyle = .dark
        view.isUserInteractionEnabled = false
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.tintColor = AlbumColor.current?.withAlphaComponent(0.25)
            view.effect = effect
        }
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

/// A glass capsule (a circle on a square frame) for controls drawn in SwiftUI.
@available(iOS 15.0, *)
struct KaraokeGlassCapsule: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        view.overrideUserInterfaceStyle = .dark
        view.isUserInteractionEnabled = false
        if #available(iOS 26.0, *) {
            view.effect = UIGlassEffect(style: .regular)
            view.cornerConfiguration = .capsule()
        }
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}
