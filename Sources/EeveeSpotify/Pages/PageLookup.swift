import UIKit

enum PageLookup {
    final class WeakView {
        weak var view: UIView?
        init(_ view: UIView) { self.view = view }
    }

    static func cached(_ key: UnsafeRawPointer, in root: UIView, _ lookup: () -> UIView?) -> UIView? {
        if let view = (objc_getAssociatedObject(root, key) as? WeakView)?.view, view.isDescendant(of: root) { return view }
        guard let found = lookup() else { return nil }
        objc_setAssociatedObject(root, key, WeakView(found), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return found
    }

    static func find(_ id: String, in root: UIView) -> UIView? {
        root.eeveeFirst(UIView.self) { $0.accessibilityIdentifier == id }
    }

    static func ancestor(of view: UIView, id: String) -> UIView? {
        var current = view.superview
        while let candidate = current {
            if candidate.accessibilityIdentifier == id { return candidate }
            current = candidate.superview
        }
        return nil
    }

    // Ancestry only settles once the view is in a window, so a verdict is kept from then on.
    static func isInside(_ view: UIView, id: String, key: UnsafeRawPointer) -> Bool {
        if let verdict = objc_getAssociatedObject(view, key) as? Bool { return verdict }
        let inside = ancestor(of: view, id: id) != nil
        if inside || view.window != nil { objc_setAssociatedObject(view, key, inside, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
        return inside
    }
}
