import EeveeSpotifyC
import Orion
import UIKit

struct GlassNowPlayingBarGroup: HookGroup {}

@available(iOS 26.0, *)
enum GlassNowPlayingBar {
    static let meter = PerfMeter("Glass][NowPlayingBar")
    private static weak var card: UIView?
    private static weak var pane: UIVisualEffectView?
    private static weak var container: UIViewController?
    private static weak var artwork: UIView?
    private static var albumColor: UIColor?
    private static var misses = 0
    private static var styled: Styled?
    private static var options = UserDefaults.nowPlayingBarOptions
    private static let observer = NotificationCenter.default.addObserver(
        forName: .eeveeNowPlayingBarOptionsChanged, object: nil, queue: .main
    ) { _ in
        options = UserDefaults.nowPlayingBarOptions
        eeveeLog("[EeveeSpotify][Glass] Now playing bar options changed")
        if let container { style(container) }
    }

    private struct Styled: Equatable {
        let frame: CGRect
        let artwork: CGSize?
        let options: NowPlayingBarOptions
    }

    private static var tint: UIColor? {
        options.albumTint ? albumColor?.withAlphaComponent(0.2) : nil
    }

    static func style(_ container: UIViewController) {
        _ = observer
        self.container = container
        guard let host = container.viewIfLoaded else { return }
        host.backgroundColor = .clear

        if card?.isDescendant(of: host) != true {
            guard let found = findCard(in: host) else {
                if misses < 10 {
                    misses += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak container] in
                        if let container { style(container) }
                    }
                }
                return
            }
            card = found
            misses = 0
            let intercepted = EeveeInterceptBackground(found) { color in
                albumColor = color
                AlbumColor.publish(color)
                if let pane { GlassKit.tint(pane, tint) }
            }
            eeveeLog("[EeveeSpotify][Glass] Now playing card %@ %@, color %@",
                  NSStringFromClass(type(of: found)), NSCoder.string(for: found.frame), intercepted ? "intercepted" : "FAILED")
        }
        guard let card else { return }
        if artwork?.isDescendant(of: card) != true { artwork = findArtwork(in: card) }
        let frame = card.convert(card.bounds, to: host)
        let now = Styled(frame: frame, artwork: artwork?.bounds.size, options: options)
        if now == styled, let pane, pane.superview === host, host.subviews.first === pane, pane.frame == frame,
           card.layer.cornerRadius == card.bounds.height / 2, artwork.map({ $0.layer.cornerRadius == artworkRadius($0) }) != false {
            GlassKit.tint(pane, tint)
            return
        }
        styled = now
        let radius = card.bounds.height / 2
        if card.layer.cornerRadius != radius {
            card.layer.cornerRadius = radius
            card.layer.cornerCurve = .continuous
        }
        // Clipping can't live in the radius check: iPad already ships a capsule corner radius, so the
        // branch is skipped there and the artwork renders straight past the rounded corners.
        card.clipsToBounds = true

        let glass = GlassKit.pane(in: host)
        pane = glass
        if glass.frame != frame {
            glass.frame = frame
            glass.cornerConfiguration = .capsule()
        }
        GlassKit.tint(glass, tint)

        if let artwork {
            artwork.layer.cornerRadius = artworkRadius(artwork)
            artwork.layer.cornerCurve = .continuous
            artwork.clipsToBounds = true
        }
    }

    private static func artworkRadius(_ artwork: UIView) -> CGFloat {
        options.roundArtwork ? artwork.bounds.width / 2 : 12
    }

    // The iPad bar is taller than the iPhone one, so a fixed 32...56pt window misses its artwork entirely.
    // The bar's own height is the limit instead, and the leftmost qualifying view wins.
    private static func findArtwork(in card: UIView) -> UIView? {
        let limit = card.bounds.height
        guard limit > 0 else { return nil }
        var best: UIView?
        var bestMinX = CGFloat.greatestFiniteMagnitude
        var queue = card.subviews
        while !queue.isEmpty {
            let view = queue.removeFirst()
            queue += view.subviews
            let size = view.bounds.size
            guard size.width >= 24, size.width <= limit, abs(size.width - size.height) < 1 else { continue }
            let minX = view.convert(view.bounds, to: card).minX
            guard minX < card.bounds.width / 3, minX < bestMinX else { continue }
            bestMinX = minX
            best = view
        }
        return best
    }

    private static func findCard(in root: UIView) -> UIView? {
        var best: UIView?
        var bestArea: CGFloat = 0
        var queue = [root]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            queue += view.subviews
            guard !(view is UIVisualEffectView), let color = view.backgroundColor, color.isOpaqueish else { continue }
            let size = view.bounds.size
            guard size.width >= 200, size.height >= 40, size.height <= 160,
                  root.bounds.contains(view.convert(view.bounds, to: root)) else { continue }
            if size.width * size.height > bestArea {
                bestArea = size.width * size.height
                best = view
            }
        }
        return best
    }
}

class GlassNowPlayingBarContainerHook: ClassHook<UIViewController> {
    typealias Group = GlassNowPlayingBarGroup
    static let targetName = "_TtC18NowPlaying_BarImpl36NowPlayingBarContainerViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard #available(iOS 26.0, *) else { return }
        GlassNowPlayingBar.meter.measure { GlassNowPlayingBar.style(target) }
    }
}

class GlassNowPlayingBarHook: ClassHook<UIViewController> {
    typealias Group = GlassNowPlayingBarGroup
    static let targetName = "_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard #available(iOS 26.0, *), let container = target.parent,
              NSStringFromClass(type(of: container)).contains("NowPlayingBarContainer") else { return }
        GlassNowPlayingBar.meter.measure { GlassNowPlayingBar.style(container) }
    }
}
