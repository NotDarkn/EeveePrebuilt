import EeveeSpotifyC
import Orion
import UIKit

struct GlassSearchGroup: HookGroup {}

// MARK: Search field

@available(iOS 26.0, *)
enum GlassSearchField {
    static let meter = PerfMeter("Glass][SearchField")
    private static var paneKey: UInt8 = 0
    private static var logged = false

    private static let setForeground = NSSelectorFromString("setForegroundColor:")

    static func style(_ button: UIView) {
        let fresh = objc_getAssociatedObject(button, &paneKey) == nil
        if fresh {
            let intercepted = EeveeInterceptBackground(button) { _ in }
            var pinned = 0
            var queue = button.subviews
            while !queue.isEmpty {
                let view = queue.removeFirst()
                queue += view.subviews
                if view is UILabel, EeveePinSetter(view, #selector(setter: UILabel.textColor), UIColor.white) { pinned += 1 }
                if NSStringFromClass(type(of: view)).contains("IconView"), view.responds(to: setForeground),
                   EeveePinSetter(view, setForeground, UIColor.white) { pinned += 1 }
            }
            if !logged {
                logged = true
                eeveeLog("[EeveeSpotify][Glass] Search field: background %@, %d parts pinned white", intercepted ? "intercepted" : "FAILED", pinned)
            }
        }
        let pane = GlassKit.pane(in: button, key: UnsafeRawPointer(&paneKey))
        if pane.frame != button.bounds {
            pane.frame = button.bounds
            pane.cornerConfiguration = .capsule()
        }
    }
}

class GlassSearchFieldHook: ClassHook<UIView> {
    typealias Group = GlassSearchGroup
    static let targetName = "_TtCCE16Encore_ButtonKitO16EncoreFoundation6Encore6Button8Tertiary"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard #available(iOS 26.0, *), target.accessibilityIdentifier == "SearchHeaderFind.SearchBar" else { return }
        GlassSearchField.meter.measure { GlassSearchField.style(target) }
    }
}

// MARK: Find bars

// In-page Find bars and the Sort pill beside them: Spotify's grey fill swapped for a glass capsule.
@available(iOS 26.0, *)
enum GlassFindField {
    static let meter = PerfMeter("Glass][FindBar")
    private static var paneKey: UInt8 = 0
    private static var logged = false

    static func style(_ field: UIView) {
        guard field.bounds.height > 0 else { return }
        if objc_getAssociatedObject(field, &paneKey) == nil {
            let intercepted = EeveeInterceptBackground(field) { _ in }
            if !logged {
                logged = true
                eeveeLog("[EeveeSpotify][Glass] Find bars on glass, background %@", intercepted ? "intercepted" : "FAILED")
            }
        }
        let pane = GlassKit.pane(in: field, key: UnsafeRawPointer(&paneKey))
        if pane.frame != field.bounds {
            pane.frame = field.bounds
            pane.cornerConfiguration = .capsule()
        }
    }
}

// Every in-page Find bar (playlists, podcasts, library) is this one Encore text field.
class GlassFindFieldHook: ClassHook<UIView> {
    typealias Group = GlassSearchGroup
    static let targetName = "_TtC19LegacyUI_ECMCoreKitP33_4733E8CE781A85C942EBD456DF9DE01815EncoreTextField"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard #available(iOS 26.0, *), target.accessibilityIdentifier == "Components.Header.UI.Toolbar.SearchField" else { return }
        GlassFindField.meter.measure { GlassFindField.style(target) }
    }
}

// MARK: Category cards

@available(iOS 26.0, *)
enum GlassSearchCards {
    static let meter = PerfMeter("Glass][SearchCards")
    private static let radius: CGFloat = 12
    private static var partsKey: UInt8 = 0
    private static let isHighlighted = NSSelectorFromString("isHighlighted")
    private static var logged = false

    private final class Parts {
        let plate = GradientView()
        let glass = UIVisualEffectView()
        var color: UIColor?
    }

    static func style(_ box: UIView) {
        guard let content = box.subviews.first(where: { $0.clipsToBounds && $0.bounds.size == box.bounds.size }),
              let fill = box.layer.sublayers?.first(where: { $0 is CAShapeLayer && !($0.delegate is UIView) }) as? CAShapeLayer
        else { return }

        let parts = objc_getAssociatedObject(box, &partsKey) as? Parts ?? {
            let parts = Parts()
            parts.plate.isUserInteractionEnabled = false
            parts.plate.gradient.startPoint = .zero
            parts.plate.gradient.endPoint = CGPoint(x: 1, y: 1)
            parts.glass.isUserInteractionEnabled = false
            parts.glass.overrideUserInterfaceStyle = .dark
            objc_setAssociatedObject(box, &partsKey, parts, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return parts
        }()
        if parts.plate.superview !== content { content.insertSubview(parts.plate, at: 0) }
        if parts.glass.superview !== content { content.insertSubview(parts.glass, aboveSubview: parts.plate) }

        let highlighted = box.responds(to: isHighlighted) && (box.value(forKey: "highlighted") as? Bool) == true
        if let cgColor = fill.fillColor, cgColor.alpha > 0, !highlighted {
            let color = UIColor(cgColor: cgColor)
            if parts.color != color {
                parts.color = color
                parts.plate.gradient.colors = [color.cgColor, darker(color).cgColor]
                let effect = UIGlassEffect(style: .clear)
                effect.tintColor = color.withAlphaComponent(0.35)
                parts.glass.effect = effect
            }
        }
        guard parts.color != nil else { return }
        // Spotify refills this layer every pass, so it's hidden instead of cleared.
        box.layer.sublayers?.forEach { if $0 is CAShapeLayer, !($0.delegate is UIView) { $0.isHidden = true } }

        for view in [box, content] where view.layer.cornerRadius != radius {
            view.layer.cornerRadius = radius
            view.layer.cornerCurve = .continuous
            view.layer.masksToBounds = true
        }
        if parts.plate.frame != content.bounds { parts.plate.frame = content.bounds }
        if parts.glass.frame != content.bounds { parts.glass.frame = content.bounds }
        box.transform = highlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity

        if !logged {
            logged = true
            eeveeLog("[EeveeSpotify][Glass] Search cards styled")
        }
    }

    private static func darker(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return color }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.55, alpha: alpha)
    }
}

class GlassSearchCardHook: ClassHook<UIView> {
    typealias Group = GlassSearchGroup
    static let targetName = "_TtCE16Encore_LayoutKitO16EncoreFoundation6Encore3Box"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard #available(iOS 26.0, *), target.superview?.accessibilityIdentifier == "Components.UI.CategoryCardBrowse" else { return }
        GlassSearchCards.meter.measure { GlassSearchCards.style(target) }
    }
}
