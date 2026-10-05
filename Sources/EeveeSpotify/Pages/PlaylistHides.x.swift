import Orion
import UIKit

struct PlaylistHeaderHidesGroup: HookGroup {}
struct PlaylistPillsHideGroup: HookGroup {}

enum PlaylistHides {
    static let hidden = Set(UserDefaults.playlistOptions.hiddenParts)
    static let meter = PerfMeter("Playlist][Hides")
    private static var scanKey: UInt8 = 0
    private static var pillsKey: UInt8 = 0
    private static var logged = Set<PlaylistPart>()
    private static var columnLogged = false

    private final class Scan {
        var rows: [PlaylistPart: PageLookup.WeakView] = [:]
        var time = CACurrentMediaTime()
    }

    private static func isMarker(_ view: UIView, for part: PlaylistPart) -> Bool {
        switch part {
        case .description:
            let name = NSStringFromClass(type(of: view))
            return name.contains("ExpandableTextView") || name.contains("HeaderDescriptionTextView")
        case .creator: return NSStringFromClass(type(of: view)).contains("FacepileView")
        case .metadata: return view.accessibilityIdentifier == "Components.Header.UI.Metadata"
        case .pills: return false
        }
    }

    static func styleHeader(_ layout: UIView) {
        guard PlaylistHeader.contains(layout) else { return }
        let wanted = hidden.subtracting([.pills])
        let scan = objc_getAssociatedObject(layout, &scanKey) as? Scan
        if let scan, wanted.allSatisfy({ scan.rows[$0]?.view?.isDescendant(of: layout) == true }) || CACurrentMediaTime() - scan.time < 1 {
            for row in scan.rows.values { if let view = row.view { hide(view) } }
            return
        }
        let fresh = Scan()
        objc_setAssociatedObject(layout, &scanKey, fresh, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        for (part, row) in rows(in: layout) where wanted.contains(part) {
            fresh.rows[part] = PageLookup.WeakView(row)
            hide(row)
            if logged.insert(part).inserted { eeveeLog("[EeveeSpotify][Playlist] Hid %@", part.rawValue) }
        }
    }

    private static func hide(_ row: UIView) {
        if !row.isHidden { row.isHidden = true }
    }

    // Title, description, creator and metadata share one column; it's where their ancestries meet.
    private static func rows(in layout: UIView) -> [PlaylistPart: UIView] {
        var markers: [PlaylistPart: UIView] = [:]
        var title: UIView?
        var queue = [layout]
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            if let part = [PlaylistPart.description, .creator, .metadata].first(where: { markers[$0] == nil && isMarker(view, for: $0) }) {
                markers[part] = view
                continue
            }
            if title == nil, let label = view as? UILabel, !(label.text ?? "").isEmpty { title = label }
            queue += view.subviews
        }
        let anchors = Array(markers.values) + [title].compactMap { $0 }
        guard anchors.count >= 2, let column = commonAncestor(anchors), column !== layout, column.isDescendant(of: layout) else {
            if !columnLogged {
                columnLogged = true
                eeveeLog("[EeveeSpotify][Playlist] Header column not found (%d anchors)", anchors.count)
            }
            return [:]
        }
        var rows: [PlaylistPart: UIView] = [:]
        for (part, marker) in markers {
            guard let row = child(of: column, containing: marker) else { continue }
            if let title, title.isDescendant(of: row) { continue }
            if markers.contains(where: { $0.key != part && !hidden.contains($0.key) && $0.value.isDescendant(of: row) }) { continue }
            rows[part] = row
        }
        return rows
    }

    private static func commonAncestor(_ views: [UIView]) -> UIView? {
        guard let first = views.first else { return nil }
        var candidate = first.superview
        while let view = candidate {
            if views.allSatisfy({ $0.isDescendant(of: view) }) { return view }
            candidate = view.superview
        }
        return nil
    }

    private static func child(of column: UIView, containing view: UIView) -> UIView? {
        var current = view
        while let parent = current.superview {
            if parent === column { return current }
            current = parent
        }
        return nil
    }

    private final class Verdict {
        weak var content: UIView?
        let hit: Bool
        let time = CACurrentMediaTime()
        init(content: UIView?, hit: Bool) { self.content = content; self.hit = hit }
    }

    static func isPills(_ cell: UICollectionViewCell) -> Bool {
        let content = cell.contentView.subviews.first
        if let verdict = objc_getAssociatedObject(cell, &pillsKey) as? Verdict, verdict.content === content, content != nil,
           verdict.hit || CACurrentMediaTime() - verdict.time < 1 {
            return verdict.hit
        }
        let hit = PageLookup.find("PlaylistCuration.Row.CurationActionsToolbar", in: cell) != nil
        objc_setAssociatedObject(cell, &pillsKey, Verdict(content: content, hit: hit), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if hit, logged.insert(.pills).inserted { eeveeLog("[EeveeSpotify][Playlist] Collapsed pills") }
        return hit
    }
}

class PlaylistHeaderHidesHook: ClassHook<UIView> {
    typealias Group = PlaylistHeaderHidesGroup
    static let targetName = "_TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout"

    func layoutSubviews() {
        orig.layoutSubviews()
        PlaylistHides.meter.measure { PlaylistHides.styleHeader(target) }
    }
}

class PlaylistPillsCellHook: ClassHook<UICollectionViewCell> {
    typealias Group = PlaylistPillsHideGroup
    static let targetName = "_TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell"

    func preferredLayoutAttributesFittingAttributes(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let result = orig.preferredLayoutAttributesFittingAttributes(attributes)
        let pills = PlaylistHides.meter.measure { PlaylistHides.isPills(target) }
        if target.clipsToBounds != pills { target.clipsToBounds = pills }
        if pills { result.size = CGSize(width: result.size.width, height: 0) }
        return result
    }
}

func activatePlaylistHides() {
    let hidden = PlaylistHides.hidden
    guard !hidden.isEmpty else { return }
    let start = CFAbsoluteTimeGetCurrent()
    var active = [String]()
    if !hidden.subtracting([.pills]).isEmpty, NSClassFromString(PlaylistHeaderHidesHook.targetName) != nil {
        PlaylistHeaderHidesGroup().activate()
        active.append("header")
    }
    if hidden.contains(.pills), NSClassFromString(PlaylistPillsCellHook.targetName) != nil {
        PlaylistPillsHideGroup().activate()
        active.append("pills")
    }
    eeveeLog("[EeveeSpotify][Playlist] Hiding %@, hooks %@ (%.2f ms)", hidden.map(\.rawValue).sorted().joined(separator: ", "),
             active.isEmpty ? "MISSING" : active.joined(separator: "+"), (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
