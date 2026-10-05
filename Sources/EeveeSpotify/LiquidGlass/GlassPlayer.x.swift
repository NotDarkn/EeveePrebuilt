import EeveeSpotifyC
import Orion
import UIKit

struct PlayerBackdropGroup: HookGroup {}
struct PlayerLyricsCardGroup: HookGroup {}

// MARK: Placement

// The tilt view is shared with playlist and album headers, which keep their own look.
enum PlayerPlacement {
    private static var key: UInt8 = 0

    static func contains(_ view: UIView) -> Bool {
        if let verdict = objc_getAssociatedObject(view, &key) as? Bool { return verdict }
        guard view.window != nil else { return false }
        var ancestor = view.superview
        var inside = false
        while let next = ancestor, !inside {
            let name = NSStringFromClass(type(of: next))
            inside = name.contains("NowPlaying_") && !name.contains("NowPlaying_BarImpl")
            ancestor = next.superview
        }
        objc_setAssociatedObject(view, &key, inside, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return inside
    }
}

// MARK: Backdrop

enum PlayerBackdrop {
    static let meter = PerfMeter("Player][Backdrop")
    private static let artworkRadius: CGFloat = 12
    private static var backdropKey: UInt8 = 0
    private static var strippedKey: UInt8 = 0
    private static var timesKey: UInt8 = 0
    private static weak var backdrop: CoverBackdrop?
    private static weak var cover: UIImage?
    private static var restripUntil: CFTimeInterval = 0

    static func style(plane: UIView) {
        guard plane.bounds.height >= 200 else { return }
        let view = backdropView(in: plane)
        if view.superview !== plane { plane.insertSubview(view, at: 0) }
        view.frame = plane.bounds
        let count = plane.subviews.count
        // A track change can recolor subviews without adding any, so stripping repeats briefly after one.
        guard (objc_getAssociatedObject(plane, &strippedKey) as? Int) != count || CACurrentMediaTime() < restripUntil else { return }
        objc_setAssociatedObject(plane, &strippedKey, count, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        for sub in plane.subviews where sub !== view { sub.eeveeStripBackgrounds() }
    }

    private static func backdropView(in plane: UIView) -> CoverBackdrop {
        if let existing = objc_getAssociatedObject(plane, &backdropKey) as? CoverBackdrop { return existing }
        let intercepted = EeveeInterceptBackground(plane) { _ in }
        let view = CoverBackdrop()
        view.show(cover)
        backdrop = view
        objc_setAssociatedObject(plane, &backdropKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if !intercepted { eeveeLog("[EeveeSpotify][Player] Backdrop album color intercept FAILED") }
        return view
    }

    static func follow(_ list: UIScrollView) {
        let middle = list.contentOffset.x + list.bounds.width / 2
        var found: UIImage?
        var widest: CGFloat = 200
        for cell in list.subviews where cell.frame.minX <= middle && middle <= cell.frame.maxX {
            var queue = [cell]
            while !queue.isEmpty {
                let view = queue.removeFirst()
                queue += view.subviews
                if let image = view as? UIImageView, let picture = image.image, image.bounds.width > widest {
                    widest = image.bounds.width
                    found = picture
                }
            }
        }
        guard let found, found !== cover else { return }
        cover = found
        restripUntil = CACurrentMediaTime() + 2
        backdrop?.show(found)
    }

    static func styleArtwork(_ tilt: UIView) {
        let size = tilt.bounds.size
        guard size.width >= 200 else { return }
        for view in tilt.subviews where view.bounds.size == size && view.layer.cornerRadius != artworkRadius {
            view.layer.cornerRadius = artworkRadius
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
        }
        guard tilt.layer.shadowPath?.boundingBox != tilt.bounds else { return }
        tilt.layer.shadowColor = UIColor.black.cgColor
        tilt.layer.shadowOpacity = 0.45
        tilt.layer.shadowRadius = 32
        tilt.layer.shadowOffset = CGSize(width: 0, height: 12)
        tilt.layer.shadowPath = UIBezierPath(roundedRect: tilt.bounds, cornerRadius: artworkRadius).cgPath
    }

    private static let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    static func monospaceTimes(_ unit: UIViewController) {
        guard let host = unit.viewIfLoaded else { return }
        let cached = objc_getAssociatedObject(unit, &timesKey) as? NSHashTable<UILabel>
        var labels = cached?.allObjects.filter { $0.isDescendant(of: host) } ?? []
        if labels.count < 2 {
            labels = []
            var queue = [host]
            while !queue.isEmpty {
                let view = queue.removeFirst()
                queue += view.subviews
                if let label = view as? UILabel, label.font.pointSize <= 11 { labels.append(label) }
            }
            let table = NSHashTable<UILabel>.weakObjects()
            labels.forEach { table.add($0) }
            objc_setAssociatedObject(unit, &timesKey, table, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        for label in labels where label.font != timeFont { label.font = timeFont }
    }
}

class PlayerBackgroundHook: ClassHook<UIViewController> {
    typealias Group = PlayerBackdropGroup
    static let targetName = "_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard let plane = target.viewIfLoaded else { return }
        PlayerBackdrop.meter.measure { PlayerBackdrop.style(plane: plane) }
    }
}

class PlayerCoverListHook: ClassHook<UICollectionView> {
    typealias Group = PlayerBackdropGroup
    static let targetName = "_TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView"

    func layoutSubviews() {
        orig.layoutSubviews()
        PlayerBackdrop.meter.measure { PlayerBackdrop.follow(target) }
    }
}

class PlayerArtworkHook: ClassHook<UIView> {
    typealias Group = PlayerBackdropGroup
    static let targetName = "_TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard PlayerPlacement.contains(target) else { return }
        PlayerBackdrop.styleArtwork(target)
    }
}

class PlayerDurationHook: ClassHook<UIViewController> {
    typealias Group = PlayerBackdropGroup
    static let targetName = "_TtC20NowPlaying_ModesImpl19DurationElementUnit"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        PlayerBackdrop.monospaceTimes(target)
    }
}

// MARK: Lyrics card

@available(iOS 26.0, *)
enum PlayerLyricsCard {
    static let meter = PerfMeter("Glass][LyricsCard")
    private static var paneKey: UInt8 = 0
    private static var tint: UIColor?
    private static weak var pane: UIVisualEffectView?
    private static let cellClass: AnyClass? = NSClassFromString("_TtC12Element_List18CollectionViewCell")

    static func style(_ card: UIView) {
        guard let cellClass else { return }
        var ancestor = card.superview
        while let view = ancestor, !view.isKind(of: cellClass) { ancestor = view.superview }
        guard let cell = ancestor, cell.bounds.height >= 40 else { return }

        if objc_getAssociatedObject(cell, &paneKey) == nil {
            var queue = [cell]
            while !queue.isEmpty {
                let view = queue.removeFirst()
                queue += view.subviews
                if let color = view.layer.backgroundColor, color.alpha > 0.5 {
                    _ = EeveeInterceptBackground(view) { color in
                        tint = color.withAlphaComponent(0.2)
                        if let pane { GlassKit.tint(pane, tint) }
                    }
                    tint = UIColor(cgColor: color).withAlphaComponent(0.2)
                }
            }
            cell.eeveeStripBackgrounds()
        }

        let glass = GlassKit.pane(in: cell, key: UnsafeRawPointer(&paneKey))
        pane = glass
        if glass.frame != cell.bounds {
            glass.frame = cell.bounds
            glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            glass.cornerConfiguration = .uniformCorners(radius: .fixed(16))
        }
        GlassKit.tint(glass, tint)
    }
}

class PlayerLyricsCardHook: ClassHook<UIView> {
    typealias Group = PlayerLyricsCardGroup
    static let targetName = "_TtC22Lyrics_CardElementImpl8CardView"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard #available(iOS 26.0, *) else { return }
        PlayerLyricsCard.meter.measure { PlayerLyricsCard.style(target) }
    }
}

// MARK: Lyrics page

@available(iOS 26.0, *)
enum GlassLyricsPage {
    static let meter = PerfMeter("Glass][LyricsPage")
    private static var paneKey: UInt8 = 0
    private static weak var pane: UIVisualEffectView?
    private static var tint: UIColor?

    static func style(_ page: UIView) {
        guard page.bounds.height >= 200 else { return }
        if objc_getAssociatedObject(page, &paneKey) == nil {
            let intercepted = EeveeInterceptBackground(page) { color in
                tint = color.withAlphaComponent(0.25)
                if let pane { GlassKit.tint(pane, tint) }
            }
            if !intercepted { eeveeLog("[EeveeSpotify][Glass] Lyrics page album color intercept FAILED") }
        }
        // The page is presented over the player; clearing up to the transition view lets the player's backdrop through.
        var ancestor: UIView? = page
        while let view = ancestor, !(view is UIWindow), !NSStringFromClass(type(of: view)).hasPrefix("UITransition") {
            view.layer.backgroundColor = nil
            ancestor = view.superview
        }
        let glass = GlassKit.pane(in: page, key: UnsafeRawPointer(&paneKey))
        pane = glass
        if glass.frame != page.bounds {
            glass.frame = page.bounds
            glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        GlassKit.tint(glass, tint)
    }
}

class GlassLyricsPageHook: ClassHook<UIView> {
    typealias Group = PlayerLyricsCardGroup
    static let targetName = "_TtC32Lyrics_FullscreenElementPageImpl14FullscreenView"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard #available(iOS 26.0, *) else { return }
        GlassLyricsPage.meter.measure { GlassLyricsPage.style(target) }
    }
}
