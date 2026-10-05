import Orion
import UIKit

struct GlassTransitionGroup: HookGroup {}

// Snapshots can't render glass, so live glass copies go behind them.
@available(iOS 26.0, *)
enum GlassTransition {
    private static var logged = 0

    static func backWithGlass(_ snapshot: UIView?, source: UIView?, _ what: String) {
        guard let image = snapshot as? UIImageView, let source, image.image != nil, image.subviews.isEmpty else { return }
        var panes = [UIView]()
        collectPanes(source, into: &panes)
        guard !panes.isEmpty else { return }

        let scaleX = source.bounds.width > 0 ? image.bounds.width / source.bounds.width : 1
        let scaleY = source.bounds.height > 0 ? image.bounds.height / source.bounds.height : 1
        for pane in panes {
            let frame = pane.convert(pane.bounds, to: source)
            let glass = copy(pane)
            glass.frame = CGRect(x: frame.minX * scaleX, y: frame.minY * scaleY, width: frame.width * scaleX, height: frame.height * scaleY)
            glass.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            image.addSubview(glass)
        }
        let content = UIImageView(image: image.image)
        content.frame = image.bounds
        content.contentMode = image.contentMode
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        image.image = nil
        image.addSubview(content)

        if logged < 4 {
            logged += 1
            eeveeLog("[EeveeSpotify][Glass] Transition %@ snapshot got %d glass panes", what, panes.count)
        }
    }

    private static func collectPanes(_ view: UIView, into panes: inout [UIView]) {
        for sub in view.subviews where !sub.isHidden && sub.alpha > 0.01 {
            if sub is UIVisualEffectView || NSStringFromClass(type(of: sub)).hasSuffix("PlatterView") {
                panes.append(sub)
            } else {
                collectPanes(sub, into: &panes)
            }
        }
    }

    private static func copy(_ pane: UIView) -> UIVisualEffectView {
        let source = pane as? UIVisualEffectView
        let glass = UIVisualEffectView(effect: source?.effect ?? UIGlassEffect(style: .regular))
        glass.isUserInteractionEnabled = false
        glass.overrideUserInterfaceStyle = pane.traitCollection.userInterfaceStyle
        if let source {
            glass.cornerConfiguration = source.cornerConfiguration
        } else {
            glass.cornerConfiguration = .capsule()
        }
        glass.layer.cornerRadius = pane.layer.cornerRadius
        glass.layer.cornerCurve = pane.layer.cornerCurve
        glass.clipsToBounds = pane.clipsToBounds
        return glass
    }

    static func ivar(_ object: AnyObject, _ name: String) -> UIView? {
        guard let ivar = class_getInstanceVariable(type(of: object), name) else { return nil }
        return object_getIvar(object, ivar) as? UIView
    }
}

class BarOverlayTransitionHook: ClassHook<NSObject> {
    typealias Group = GlassTransitionGroup
    static let targetName = "SPTBarOverlayPresentationTransition"

    func setBarSnapshotView(_ view: UIView?) {
        if #available(iOS 26.0, *) {
            GlassTransition.backWithGlass(view, source: GlassTransition.ivar(target, "_bottomBarView"), "bar")
        }
        orig.setBarSnapshotView(view)
    }

    func setTabBarSnapshotView(_ view: UIView?) {
        if #available(iOS 26.0, *) {
            GlassTransition.backWithGlass(view, source: GlassTransition.ivar(target, "_tabBarView"), "tab bar")
        }
        orig.setTabBarSnapshotView(view)
    }
}

class CompactOverlayTransitionHook: ClassHook<NSObject> {
    typealias Group = GlassTransitionGroup
    static let targetName = "_TtC19MainUI_TabBarUIImpl24CompactOverlayTransition"

    func animateTransition(_ context: AnyObject) {
        orig.animateTransition(context)
        guard #available(iOS 26.0, *) else { return }
        GlassTransition.backWithGlass(GlassTransition.ivar(target, "npbSnapshotView"), source: GlassTransition.ivar(target, "npbView"), "bar")
        GlassTransition.backWithGlass(GlassTransition.ivar(target, "tabBarSnapshotView"), source: GlassTransition.ivar(target, "tabBarView"), "tab bar")
    }
}
