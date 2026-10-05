import EeveeSpotifyC
import Orion
import UIKit

struct HomeGradientGroup: HookGroup {}
struct LibraryGradientGroup: HookGroup {}
struct SearchGradientGroup: HookGroup {}

enum GradientPage: String, Codable, CaseIterable {
    case home, library, search

    var meter: PerfMeter {
        switch self {
        case .home: return Self.homeMeter
        case .library: return Self.libraryMeter
        case .search: return Self.searchMeter
        }
    }

    private static let homeMeter = PerfMeter("Home][Gradient")
    private static let libraryMeter = PerfMeter("Library][Gradient")
    private static let searchMeter = PerfMeter("Search][Gradient")
}

struct HomeGradientOptions: Codable, Equatable {
    var enabled = false
    var tintRGB: Int?
    var strength = 1
    var height = 1
    var fade: Int?
    var followAlbum: Bool?
    var pages: Set<GradientPage>?
    var solidFill: Bool?

    var shownPages: Set<GradientPage> {
        get { enabled ? pages ?? [.home] : [] }
        set { pages = newValue == [.home] ? nil : newValue }
    }

    static let tints: [Int?] = [nil, 0x1ED760, 0x2DD4BF, 0x3B82F6, 0x6366F1, 0xA855F7, 0xEC4899, 0xEF4444, 0xF59E0B]
    static let strengths: [CGFloat] = [0.18, 0.27, 0.4]
    static let heights: [CGFloat] = [260, 390, 560, 0]

    var color: UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        let base = followAlbum == true ? AlbumColor.current ?? Theme.accent : tintRGB.map(Theme.color) ?? Theme.accent
        base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let level = Self.strengths[max(0, min(Self.strengths.count - 1, strength))]
        return UIColor(hue: hue, saturation: min(saturation, 0.85), brightness: level, alpha: 1)
    }

    var span: CGFloat { Self.heights[max(0, min(Self.heights.count - 1, height))] }

    static let holds: [CGFloat] = [0, 0.45, 0.8]

    func solid(of span: CGFloat) -> CGFloat {
        max(52, span * Self.holds[max(0, min(Self.holds.count - 1, fade ?? 0))])
    }
}

extension Notification.Name {
    static let eeveeHomeGradientChanged = Notification.Name("EeveeHomeGradientChanged")
}

extension UserDefaults {
    @UserDefault(key: "eeveeHomeGradient", defaultValue: HomeGradientOptions())
    static var homeGradient
}

enum HomeGradient {
    static let launchPages = UserDefaults.homeGradient.shownPages
    private static let overscroll: CGFloat = 600
    private static var stateKey: UInt8 = 0
    private static var listKey: UInt8 = 0
    private static var paintedKey: UInt8 = 0
    private static var logged = Set<GradientPage>()
    private static var loggedScrim = false
    private static let lists = NSHashTable<UIScrollView>.weakObjects()
    private static var options = UserDefaults.homeGradient
    private static let observer = NotificationCenter.default.addObserver(
        forName: .eeveeHomeGradientChanged, object: nil, queue: .main
    ) { _ in
        options = UserDefaults.homeGradient
        relayout(animated: false)
    }
    private static let albumObserver = NotificationCenter.default.addObserver(
        forName: .eeveeAlbumColorChanged, object: nil, queue: .main
    ) { _ in
        if options.followAlbum == true { relayout(animated: true) }
    }

    private final class Wash {
        let view = GradientView()
        let page: GradientPage
        var paint: (UIColor, CGFloat, CGFloat)?
        var scroll: NSKeyValueObservation?
        weak var host: UIView?
        init(_ page: GradientPage) { self.page = page }
    }

    private final class Mark {
        weak var content: UIView?
        init(_ content: UIView?) { self.content = content }
    }

    static func isWashed(_ list: UIScrollView) -> Bool {
        objc_getAssociatedObject(list, &stateKey) != nil
    }

    private static func relayout(animated: Bool) {
        for list in lists.allObjects {
            guard let wash = objc_getAssociatedObject(list, &stateKey) as? Wash else { continue }
            if animated {
                UIView.transition(with: list, duration: 0.6, options: [.transitionCrossDissolve, .allowUserInteraction]) { layout(list, wash.page, page: wash.host) }
            } else {
                layout(list, wash.page, page: wash.host)
            }
        }
    }

    private static var chromeKey: UInt8 = 0
    private static var chromeLogged = Set<GradientPage>()
    private static var sizeKey: UInt8 = 0
    private static var followLogged = Set<GradientPage>()

    // A page-level wash doesn't scroll by itself, so it's slid up with the list; a solid fill looks the same either way.
    static func follow(_ list: UIScrollView) {
        guard let wash = objc_getAssociatedObject(list, &stateKey) as? Wash, wash.host != nil else { return }
        let scrolled = options.solidFill == true ? 0 : max(0, list.contentOffset.y + list.adjustedContentInset.top)
        let transform = CGAffineTransform(translationX: 0, y: -scrolled)
        guard wash.view.transform != transform else { return }
        wash.view.transform = transform
        if scrolled > 0, followLogged.insert(wash.page).inserted {
            eeveeLog("[EeveeSpotify][HomeGradient] %@: wash follows scroll (%.0f pt)", wash.page.rawValue, scrolled)
        }
    }

    // The page's own layout runs before its list is sized and filled, so the list's size change drives a second pass.
    static func attach(_ list: UIScrollView, in root: UIView, _ page: GradientPage) {
        layout(list, page, page: root)
        clearChrome(root, around: list, page)
        guard objc_getAssociatedObject(list, &sizeKey) == nil else { return }
        let observation = list.observe(\.bounds) { [weak root] list, _ in
            guard let root, list.bounds.width > 0 else { return }
            layout(list, page, page: root)
            clearChrome(root, around: list, page)
        }
        objc_setAssociatedObject(list, &sizeKey, observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func list(in root: UIView) -> UIScrollView? {
        if let list = (objc_getAssociatedObject(root, &listKey) as? PageLookup.WeakView)?.view as? UIScrollView,
           list.window != nil, !list.isHidden, list.isDescendant(of: root) { return list }
        // Lists are still 0×0 and empty on the page's first layout, so the shallowest, largest one wins regardless.
        var best: UIScrollView?
        var level = root.subviews
        for _ in 0..<4 where !level.isEmpty && best == nil {
            var next: [UIView] = []
            for view in level where !view.isHidden && view.alpha > 0 {
                guard let scroll = view as? UIScrollView else { next += view.subviews; continue }
                if let current = best, scroll.bounds.width * scroll.bounds.height <= current.bounds.width * current.bounds.height { continue }
                best = scroll
            }
            level = next
        }
        if let best { objc_setAssociatedObject(root, &listKey, PageLookup.WeakView(best), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
        return best
    }

    static func layout(_ list: UIScrollView, _ page: GradientPage, page root: UIView? = nil) {
        _ = observer
        _ = albumObserver
        guard list.bounds.width > 0 else { return }
        let wash = objc_getAssociatedObject(list, &stateKey) as? Wash ?? {
            let wash = Wash(page)
            wash.view.isUserInteractionEnabled = false
            // Lists insert cells at index 0, so depth rather than subview order keeps the wash behind them.
            wash.view.layer.zPosition = -1
            if page != .home {
                wash.scroll = list.observe(\.contentOffset) { list, _ in
                    page.meter.measure {
                        follow(list)
                        clearCells(of: list)
                    }
                }
            }
            objc_setAssociatedObject(list, &stateKey, wash, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            lists.add(list)
            return wash
        }()
        guard options.enabled, options.shownPages.contains(page) else {
            wash.view.removeFromSuperview()
            return
        }
        // Library and Search keep their header above the list, so their wash sits behind the whole page from the screen top.
        if let root { wash.host = root }
        let host: UIView = root ?? list
        if wash.view.superview !== host { host.insertSubview(wash.view, at: 0) }

        let fill = options.solidFill == true
        let span: CGFloat
        if fill {
            span = root == nil ? max(list.contentSize.height + list.adjustedContentInset.top, list.bounds.height) + list.bounds.height : host.bounds.height
        } else {
            span = options.span > 0 ? options.span : list.bounds.height
        }
        let frame = root == nil
            ? CGRect(x: 0, y: -overscroll - list.adjustedContentInset.top, width: list.bounds.width, height: overscroll + span)
            : CGRect(x: 0, y: -overscroll, width: host.bounds.width, height: overscroll + span)
        if wash.view.bounds.size != frame.size || wash.view.center != CGPoint(x: frame.midX, y: frame.midY) {
            wash.view.transform = .identity
            wash.view.frame = frame
        }
        let color = options.color
        let solid = fill ? overscroll + span : options.solid(of: span)
        if wash.paint?.0 != color || wash.paint?.1 != span || wash.paint?.2 != solid {
            wash.paint = (color, span, solid)
            wash.view.gradient.colors = [color.cgColor, color.cgColor, color.withAlphaComponent(fill ? 1 : 0).cgColor]
            wash.view.gradient.locations = [0, NSNumber(value: Double(min(1, (overscroll + solid) / (overscroll + span)))), 1]
        }
        follow(list)
        clearCells(of: list)

        if !logged.contains(page) {
            logged.insert(page)
            eeveeLog("[EeveeSpotify][HomeGradient] %@: %@ behind %@ (%.0fx%.0f), span %.0f, %@", page.rawValue, fill ? "solid" : "gradient",
                     NSStringFromClass(type(of: list)), list.bounds.width, list.bounds.height, span,
                     root == nil ? "scrolls inside list" : "page-level, follows scroll")
        }
    }

    // Rows paint the base surface over the wash; their late-arriving shelves get a second pass.
    private static func clearCells(of list: UIScrollView) {
        for cell in list.subviews where cell.bounds.width > 0 && (cell is UICollectionReusableView || cell is UITableViewCell) {
            let content = ((cell as? UICollectionViewCell)?.contentView ?? (cell as? UITableViewCell)?.contentView ?? cell).subviews.first
            if let content, (objc_getAssociatedObject(cell, &paintedKey) as? Mark)?.content === content { continue }
            objc_setAssociatedObject(cell, &paintedKey, Mark(content), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            clear(cell)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak cell] in if let cell { clear(cell) } }
        }
    }

    private static func clear(_ cell: UIView) {
        var queue = [cell]
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            queue += view.subviews
            guard let fill = view.layer.backgroundColor, fill.alpha > 0.9 else { continue }
            let color = UIColor(cgColor: fill)
            if color.isBaseSurface || (Theme.launchAmoled && isBlack(color)) { _ = EeveeInterceptBackground(view) { _ in } }
        }
    }

    // Library and Search draw their header outside the list on its own dark fill, which would cover the wash's top.
    static func clearChrome(_ root: UIView, around list: UIScrollView, _ page: GradientPage) {
        let now = CACurrentMediaTime()
        let first = (objc_getAssociatedObject(root, &chromeKey) as? NSNumber)?.doubleValue ?? now
        if objc_getAssociatedObject(root, &chromeKey) == nil {
            objc_setAssociatedObject(root, &chromeKey, NSNumber(value: now), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        guard now - first < 6 else { return }
        var cleared = 0
        var queue = [root]
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            if view === list { continue }
            queue += view.subviews
            guard let fill = view.layer.backgroundColor, fill.alpha > 0.9 else { continue }
            let color = UIColor(cgColor: fill)
            if color.isBaseSurface || isBlack(color), EeveeInterceptBackground(view, { _ in }) { cleared += 1 }
        }
        if let fill = list.layer.backgroundColor, fill.alpha > 0.9, EeveeInterceptBackground(list, { _ in }) { cleared += 1 }
        var scrims = 0
        index = 0
        queue = [root]
        while index < queue.count {
            let view = queue[index]
            index += 1
            if view === list { continue }
            queue += view.subviews
            if !view.isHidden, !(view is GradientView), NSStringFromClass(type(of: view)).contains("GradientView") {
                view.isHidden = true
                scrims += 1
            }
        }
        if #available(iOS 26.0, *), !list.topEdgeEffect.isHidden { list.topEdgeEffect.isHidden = true; scrims += 1 }
        cleared += scrims
        if cleared > 0, chromeLogged.insert(page).inserted {
            eeveeLog("[EeveeSpotify][HomeGradient] %@: cleared %d header fills", page.rawValue, cleared)
        }
    }

    private static func isBlack(_ color: UIColor) -> Bool {
        var white: CGFloat = 0, alpha: CGFloat = 0
        return color.getWhite(&white, alpha: &alpha) && white < 0.02
    }

    static func hideScrim(in root: UIView) {
        for wrapper in root.subviews {
            for view in wrapper.subviews where !view.isHidden && !(view is GradientView)
                && NSStringFromClass(type(of: view)).contains("GradientView") {
                view.isHidden = true
                if !loggedScrim {
                    loggedScrim = true
                    eeveeLog("[EeveeSpotify][HomeGradient] Hid header scrim %@", NSStringFromClass(type(of: view)))
                }
            }
        }
    }
}

class HomeGradientPageHook: ClassHook<UIViewController> {
    typealias Group = HomeGradientGroup
    static let targetName = "_TtC16Home_EvoPageImpl33EvoLoadableResourceViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard let list = target.viewIfLoaded?.subviews.first(where: { $0 is UICollectionView }) as? UIScrollView else { return }
        GradientPage.home.meter.measure { HomeGradient.layout(list, .home) }
    }
}

// Same class backs album, artist and playlist lists, hence the wash check.
class HomeGradientListHook: ClassHook<UIScrollView> {
    typealias Group = HomeGradientGroup
    static let targetName = "_TtC16Home_CarouselKit29TouchCancellingCollectionView"

    func layoutSubviews() {
        orig.layoutSubviews()
        guard HomeGradient.isWashed(target) else { return }
        GradientPage.home.meter.measure { HomeGradient.layout(target, .home) }
    }
}

class HomeGradientScrimHook: ClassHook<UIViewController> {
    typealias Group = HomeGradientGroup
    static let targetName = "_TtC19Home_FunkisPageImpl20FunkisViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        if let root = target.viewIfLoaded { HomeGradient.hideScrim(in: root) }
    }
}

class LibraryGradientPageHook: ClassHook<UIViewController> {
    typealias Group = LibraryGradientGroup
    static let targetName = "_TtC28YourLibrary_YourLibraryXImpl25YourLibraryViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        GradientPage.library.meter.measure {
            if let root = target.viewIfLoaded, let list = HomeGradient.list(in: root) { HomeGradient.attach(list, in: root, .library) }
        }
    }
}

class SearchGradientPageHook: ClassHook<UIViewController> {
    typealias Group = SearchGradientGroup
    static let targetName = "_TtC21Browse_BrowsePageImpl24BrowsePageViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        GradientPage.search.meter.measure {
            if let root = target.viewIfLoaded, let list = HomeGradient.list(in: root) { HomeGradient.attach(list, in: root, .search) }
        }
    }
}

func activateHomeGradient() {
    let pages = HomeGradient.launchPages
    guard !pages.isEmpty else { return }
    let groups: [(GradientPage, () -> Void, [String])] = [
        (.home, { HomeGradientGroup().activate() }, [HomeGradientPageHook.targetName, HomeGradientListHook.targetName, HomeGradientScrimHook.targetName]),
        (.library, { LibraryGradientGroup().activate() }, [LibraryGradientPageHook.targetName]),
        (.search, { SearchGradientGroup().activate() }, [SearchGradientPageHook.targetName]),
    ]
    for (page, activate, targets) in groups where pages.contains(page) {
        let start = CFAbsoluteTimeGetCurrent()
        let missing = targets.filter { NSClassFromString($0) == nil }
        if missing.isEmpty { activate() }
        eeveeLog("[EeveeSpotify][HomeGradient] %@ %@ (%.2f ms)", page.rawValue,
                 missing.isEmpty ? "active" : "skipped, missing " + missing.joined(separator: ", "),
                 (CFAbsoluteTimeGetCurrent() - start) * 1000)
    }
}
