import EeveeSpotifyC
import Orion
import UIKit

struct GlassHomeGroup: HookGroup {}

@available(iOS 26.0, *)
enum GlassHomeShortcuts {
    static let meter = PerfMeter("Glass][HomeShortcuts")
    private static let radius: CGFloat = 12
    private static var paneKey: UInt8 = 0
    private static var logged = false

    static func style(_ tile: UIView) {
        if objc_getAssociatedObject(tile, &paneKey) == nil {
            let fills = tile.subviews.filter { ($0.layer.backgroundColor?.alpha ?? 0) > 0.01 && $0.bounds.size == tile.bounds.size }
            let intercepted = fills.filter { EeveeInterceptBackground($0) { _ in } }.count
            if !logged {
                logged = true
                eeveeLog("[EeveeSpotify][Glass] Home shortcut tile: %d of %d fills intercepted", intercepted, fills.count)
            }
        }
        let pane = GlassKit.pane(in: tile, key: &paneKey)
        if pane.frame != tile.bounds {
            pane.frame = tile.bounds
            pane.cornerConfiguration = .uniformCorners(radius: .fixed(radius))
        }
        if tile.layer.cornerRadius != radius {
            tile.layer.cornerRadius = radius
            tile.layer.cornerCurve = .continuous
            tile.clipsToBounds = true
        }
    }
}

class GlassHomeShortcutHook: ClassHook<UIView> {
    typealias Group = GlassHomeGroup
    static let targetName = "_TtC19LegacyUI_ECMCoreKit31InteractableLayoutBackingButton"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard #available(iOS 26.0, *), target.accessibilityIdentifier == "Shortcut.Card.Home" else { return }
        GlassHomeShortcuts.meter.measure { GlassHomeShortcuts.style(target) }
    }
}
