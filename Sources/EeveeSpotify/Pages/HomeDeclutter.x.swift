import Orion
import UIKit

struct HomeSectionsGroup: HookGroup {}
struct HomePillsGroup: HookGroup {}

enum HomePart: String, CaseIterable, Codable {
    case shortcuts, promos, previews, dj, pills

    var marker: String? {
        switch self {
        case .shortcuts: return "Home_AnchorsAndShortcutsKit"
        case .promos: return "Discovery_PromoElement"
        case .previews: return "Discovery_PreviewElement"
        case .dj: return "Discovery_DJElement"
        case .pills: return nil
        }
    }
}

extension UserDefaults {
    @UserDefault(key: "eeveeHomeHidden", defaultValue: [HomePart]())
    static var homeHidden
}

enum HomeDeclutter {
    static let hidden = Set(UserDefaults.homeHidden)
    static let meter = PerfMeter("Home][Declutter")
    private static var verdictKey: UInt8 = 0
    private static var logged = Set<HomePart>()

    private final class Verdict {
        weak var content: UIView?
        let part: HomePart?
        let final: Bool
        let time = CACurrentMediaTime()
        init(content: UIView?, part: HomePart?, final: Bool) { self.content = content; self.part = part; self.final = final }
    }

    static func hiddenSection(for cell: UICollectionViewCell) -> HomePart? {
        let content = cell.contentView.subviews.first
        if let verdict = objc_getAssociatedObject(cell, &verdictKey) as? Verdict, verdict.content === content, content != nil,
           verdict.final || CACurrentMediaTime() - verdict.time < 1 {
            return verdict.part
        }
        let result = classify(cell)
        objc_setAssociatedObject(cell, &verdictKey, Verdict(content: content, part: result.part, final: result.final), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return result.part
    }

    private static func classify(_ cell: UICollectionViewCell) -> (part: HomePart?, final: Bool) {
        var ancestor = cell.superview
        while let view = ancestor {
            if view is UICollectionViewCell { return (nil, true) }
            ancestor = view.superview
        }
        var names = [String]()
        var queue: [UIView] = [cell]
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            if view !== cell, view is UICollectionView { view.layoutIfNeeded() }
            names.append(NSStringFromClass(type(of: view)))
            queue += view.subviews
        }
        let all = names.joined()
        guard all.contains("Home_EvoPageImpl") else { return (nil, true) }
        let part = HomePart.allCases.first { hidden.contains($0) && $0.marker.map(all.contains) == true }
        if let part, logged.insert(part).inserted { eeveeLog("[EeveeSpotify][Home] Collapsed %@", part.rawValue) }
        // Sections fill in after their first pass, so a visible verdict is only final once content has settled.
        return (part, part != nil || queue.count > 40)
    }
}

class HomeSectionCellHook: ClassHook<UICollectionViewCell> {
    typealias Group = HomeSectionsGroup
    static let targetName = "_TtC12Element_List18CollectionViewCell"

    func preferredLayoutAttributesFittingAttributes(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let result = orig.preferredLayoutAttributesFittingAttributes(attributes)
        let hidden = HomeDeclutter.meter.measure { HomeDeclutter.hiddenSection(for: target) } != nil
        if target.clipsToBounds != hidden { target.clipsToBounds = hidden }
        if hidden { result.size = CGSize(width: result.size.width, height: 0) }
        return result
    }
}

class HomePillsHook: ClassHook<UIView> {
    typealias Group = HomePillsGroup
    static let targetName = "_TtC14Home_PillUIKit14PillScrollView"

    func didMoveToWindow() {
        orig.didMoveToWindow()
        target.isHidden = true
    }
}

func activateHomeDeclutter() {
    let hidden = HomeDeclutter.hidden
    guard !hidden.isEmpty else { return }
    let start = CFAbsoluteTimeGetCurrent()
    var active = [String]()
    if hidden.contains(.pills), NSClassFromString(HomePillsHook.targetName) != nil {
        HomePillsGroup().activate()
        active.append("pills")
    }
    if !hidden.subtracting([.pills]).isEmpty, NSClassFromString(HomeSectionCellHook.targetName) != nil {
        HomeSectionsGroup().activate()
        active.append("sections")
    }
    eeveeLog("[EeveeSpotify][Home] Declutter: hiding %@, hooks %@ (%.2f ms)", hidden.map(\.rawValue).sorted().joined(separator: ", "),
             active.isEmpty ? "MISSING" : active.joined(separator: "+"), (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
