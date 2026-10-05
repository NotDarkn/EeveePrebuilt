import UIKit

@available(iOS 26.0, *)
enum GlassKit {
    private static var paneKey: UInt8 = 0

    static func pane(in host: UIView, key: UnsafeRawPointer = UnsafeRawPointer(&paneKey)) -> UIVisualEffectView {
        if let pane = objc_getAssociatedObject(host, key) as? UIVisualEffectView {
            if pane.superview !== host { host.insertSubview(pane, at: 0) }
            else if host.subviews.first !== pane { host.sendSubviewToBack(pane) }
            return pane
        }
        let pane = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        pane.isUserInteractionEnabled = false
        pane.overrideUserInterfaceStyle = .dark
        pane.accessibilityElementsHidden = true
        objc_setAssociatedObject(host, key, pane, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        host.insertSubview(pane, at: 0)
        return pane
    }

    static func tint(_ pane: UIVisualEffectView, _ color: UIColor?) {
        guard let glass = pane.effect as? UIGlassEffect, glass.tintColor != color else { return }
        let effect = UIGlassEffect(style: .regular)
        effect.tintColor = color
        pane.effect = effect
    }

    // Many Encore controls already carry a blur view; swapping its effect gives real glass with no extra views.
    @discardableResult
    static func glassBlur(in view: UIView) -> Bool {
        guard let blur = view.subviews.first(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView else { return false }
        guard !(blur.effect is UIGlassEffect) else { return true }
        blur.effect = UIGlassEffect(style: .regular)
        blur.cornerConfiguration = .capsule()
        view.backgroundColor = .clear
        return true
    }
}

enum AlbumColor {
    static private(set) var current: UIColor?

    static func publish(_ color: UIColor) {
        guard color != current else { return }
        current = color
        NotificationCenter.default.post(name: .eeveeAlbumColorChanged, object: nil)
    }
}

extension Notification.Name {
    static let eeveeAlbumColorChanged = Notification.Name("EeveeAlbumColorChanged")
}

extension UIView {
    func eeveeStripBackgrounds() {
        if self is UIVisualEffectView || self is GradientView { return }
        layer.backgroundColor = nil
        if layer is CAGradientLayer || NSStringFromClass(type(of: self)).contains("GradientView") { isHidden = true }
        layer.sublayers?.forEach { if $0 is CAGradientLayer, !($0.delegate is GradientView) { $0.isHidden = true } }
        subviews.forEach { $0.eeveeStripBackgrounds() }
    }

    func eeveeFirst<T: UIView>(_ type: T.Type, where match: (T) -> Bool = { _ in true }) -> T? {
        var queue: [UIView] = [self]
        var index = 0
        while index < queue.count {
            let next = queue[index]
            index += 1
            if let view = next as? T, match(view) { return view }
            queue += next.subviews
        }
        return nil
    }
}

extension UIColor {
    var isWhite: Bool {
        var white: CGFloat = 0, alpha: CGFloat = 0
        if getWhite(&white, alpha: &alpha) { return white > 0.95 && alpha > 0.5 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        return getRed(&r, green: &g, blue: &b, alpha: &alpha) && min(r, g, b) > 0.95 && alpha > 0.5
    }

    var isBaseSurface: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return abs(r - 0.071) < 0.02 && abs(g - 0.071) < 0.02 && abs(b - 0.071) < 0.02
    }

    var isOpaqueish: Bool {
        cgColor.alpha > 0.5
    }
}
