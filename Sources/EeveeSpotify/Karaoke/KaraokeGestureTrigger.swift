import UIKit

// Long-press on the now playing bar opens karaoke; the player footer button is the visible trigger.
final class KaraokeGestureTrigger: NSObject {
    static let shared = KaraokeGestureTrigger()
    private static let barClass: AnyClass? = NSClassFromString("_TtC18NowPlaying_BarImpl27NowPlayingBarViewController")
    private static var attachedKey: UInt8 = 0
    private weak var bar: UIView?
    private var lastSearch: CFTimeInterval = 0
    private var logged = false

    func attachIfNeeded() {
        if let bar, bar.window != nil { return }
        let now = CACurrentMediaTime()
        guard now - lastSearch >= 1 else { return }
        lastSearch = now
        guard let barClass = Self.barClass,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow),
              let view = window.eeveeFirst(UIView.self, where: { ($0.next as? UIViewController)?.isKind(of: barClass) == true })
        else { return }
        bar = view
        guard objc_getAssociatedObject(view, &Self.attachedKey) == nil else { return }
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.5
        view.addGestureRecognizer(recognizer)
        objc_setAssociatedObject(view, &Self.attachedKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if !logged {
            logged = true
            eeveeLog("[EeveeSpotify][Karaoke] long-press on now playing bar")
        }
    }

    @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began, KaraokeOverlayPresenter.isAvailableForCurrentTrack() else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        KaraokeOverlayPresenter.present()
    }
}
