import SwiftUI
import UIKit

struct TabEntry: Equatable {
    let key: String
    let title: String
    let image: UIImage?
    let launchable: Bool

    static func == (lhs: TabEntry, rhs: TabEntry) -> Bool {
        lhs.key == rhs.key && lhs.title == rhs.title && lhs.launchable == rhs.launchable
            && (lhs.image == nil) == (rhs.image == nil)
    }
}

final class TabBarEditorView: UIView {
    var onReorder: (([String]) -> Void)?
    var onHide: ((String) -> Void)?
    var onSelect: ((String?) -> Void)?

    private(set) var tabs: [String] = []
    private var entries: [String: TabEntry] = [:]
    private var launchTab: String?
    private var hideLabels = false
    private var tiles: [String: TabTile] = [:]
    private var dragging: String?
    private var removeArmed = false

    private let glass: UIVisualEffectView = {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            return UIVisualEffectView(effect: effect)
        }
        return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    }()
    private let bubble = UIView()
    private let accent = UIColor(red: 0.12, green: 0.84, blue: 0.38, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        overrideUserInterfaceStyle = .dark
        glass.isUserInteractionEnabled = false
        glass.clipsToBounds = true
        addSubview(glass)
        bubble.backgroundColor = UIColor(white: 1, alpha: 0.14)
        bubble.alpha = 0
        glass.contentView.addSubview(bubble)

        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.15
        addGestureRecognizer(hold)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) { nil }

    func update(tabs: [TabEntry], launchTab: String?, hideLabels: Bool) {
        guard dragging == nil else { return }
        let keys = tabs.map(\.key)
        let changed = keys != self.tabs || hideLabels != self.hideLabels || tabs.contains { entries[$0.key] != $0 }
        self.launchTab = launchTab
        self.hideLabels = hideLabels
        if changed {
            self.tabs = keys
            entries = Dictionary(tabs.map { ($0.key, $0) }) { first, _ in first }
            tiles.values.forEach { $0.removeFromSuperview() }
            tiles = [:]
            for entry in tabs where tiles[entry.key] == nil { tiles[entry.key] = makeTile(entry) }
            tiles.values.forEach(addSubview)
        }
        setNeedsLayout()
        layoutIfNeeded()
        placeBubble(animated: !changed)
    }

    private func makeTile(_ entry: TabEntry) -> TabTile {
        let tile = TabTile(title: entry.title, image: entry.image ?? UIImage(systemName: "circle.dashed"))
        tile.label.isHidden = hideLabels
        return tile
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glass.frame = bounds
        glass.layer.cornerRadius = bounds.height / 2
        glass.layer.cornerCurve = .continuous
        guard dragging == nil else { return }
        layoutTiles(animated: false)
        placeBubble(animated: false)
    }

    private func slotWidth() -> CGFloat {
        (bounds.width - 16) / CGFloat(max(tabs.count, 1))
    }

    private func slotCenter(_ index: Int) -> CGPoint {
        CGPoint(x: 8 + slotWidth() * (CGFloat(index) + 0.5), y: bounds.midY)
    }

    private func slot(at x: CGFloat) -> Int {
        max(0, min(tabs.count - 1, Int((x - 8) / slotWidth())))
    }

    private func layoutTiles(animated: Bool) {
        let apply = {
            for (index, title) in self.tabs.enumerated() where title != self.dragging {
                guard let tile = self.tiles[title] else { continue }
                tile.bounds = CGRect(x: 0, y: 0, width: self.slotWidth() - 4, height: self.bounds.height)
                tile.center = self.slotCenter(index)
                tile.color = title == self.launchTab ? self.accent : .white
            }
        }
        animated ? UIView.animate(withDuration: 0.22, animations: apply) : apply()
    }

    private func placeBubble(animated: Bool) {
        guard let launchTab, let index = tabs.firstIndex(of: launchTab) else {
            UIView.animate(withDuration: 0.2) { self.bubble.alpha = 0 }
            return
        }
        let center = convert(slotCenter(index), to: glass.contentView)
        let frame = CGRect(x: center.x - slotWidth() / 2 + 2, y: 5, width: slotWidth() - 4, height: bounds.height - 10)
        let apply = {
            self.bubble.frame = frame
            self.bubble.layer.cornerRadius = frame.height / 2
            self.bubble.alpha = 1
        }
        animated && bubble.alpha > 0
            ? UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [], animations: apply)
            : apply()
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        guard !tabs.isEmpty else { return }
        let title = tabs[slot(at: tap.location(in: self).x)]
        guard entries[title]?.launchable != false else { return }
        launchTab = launchTab == title ? nil : title
        UISelectionFeedbackGenerator().selectionChanged()
        layoutTiles(animated: true)
        placeBubble(animated: true)
        onSelect?(launchTab)
    }

    @objc private func held(_ hold: UILongPressGestureRecognizer) {
        let point = hold.location(in: self)
        switch hold.state {
        case .began:
            guard !tabs.isEmpty else { return }
            let title = tabs[slot(at: point.x)]
            guard let tile = tiles[title] else { return }
            dragging = title
            removeArmed = false
            bringSubviewToFront(tile)
            UIView.animate(withDuration: 0.18) { tile.transform = CGAffineTransform(scaleX: 1.3, y: 1.3) }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            bubble.alpha = 0
        case .changed:
            guard let title = dragging, let tile = tiles[title] else { return }
            tile.center = point
            let arm = tabs.count > 1 && point.y < -24
            if arm != removeArmed {
                removeArmed = arm
                UISelectionFeedbackGenerator().selectionChanged()
                UIView.animate(withDuration: 0.15) { tile.alpha = arm ? 0.4 : 1 }
            }
            guard !arm, let from = tabs.firstIndex(of: title) else { return }
            let to = slot(at: point.x)
            if to != from {
                tabs.remove(at: from)
                tabs.insert(title, at: to)
                UISelectionFeedbackGenerator().selectionChanged()
                layoutTiles(animated: true)
            }
        case .ended, .cancelled, .failed:
            guard let title = dragging, let tile = tiles[title] else { return }
            dragging = nil
            if removeArmed && hold.state == .ended {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                UIView.animate(withDuration: 0.22, animations: {
                    tile.alpha = 0
                    tile.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
                }, completion: { _ in self.onHide?(title) })
                return
            }
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, options: [], animations: {
                tile.transform = .identity
                tile.alpha = 1
                self.layoutTiles(animated: false)
            })
            placeBubble(animated: false)
            onReorder?(tabs)
        default:
            break
        }
    }
}

final class TabTile: UIView {
    let icon = UIImageView()
    let label = UILabel()

    var color: UIColor = .white {
        didSet {
            icon.tintColor = color
            label.textColor = color
        }
    }

    init(title: String, image: UIImage?) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        icon.image = image
        icon.contentMode = .scaleAspectFit
        icon.tintColor = color
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textAlignment = .center
        label.textColor = color
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        addSubview(icon)
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSide: CGFloat = 24, gap: CGFloat = 4, labelHeight: CGFloat = 12
        let content = label.isHidden ? iconSide : iconSide + gap + labelHeight
        let top = (bounds.height - content) / 2
        icon.frame = CGRect(x: (bounds.width - iconSide) / 2, y: top, width: iconSide, height: iconSide)
        label.frame = CGRect(x: 2, y: top + iconSide + gap, width: bounds.width - 4, height: labelHeight)
    }
}

struct TabBarEditor: UIViewRepresentable {
    let tabs: [TabEntry]
    let launchTab: String?
    let hideLabels: Bool
    let onReorder: ([String]) -> Void
    let onHide: (String) -> Void
    let onSelect: (String?) -> Void

    func makeUIView(context: Context) -> TabBarEditorView {
        TabBarEditorView()
    }

    func updateUIView(_ view: TabBarEditorView, context: Context) {
        view.onReorder = onReorder
        view.onHide = onHide
        view.onSelect = onSelect
        view.update(tabs: tabs, launchTab: launchTab, hideLabels: hideLabels)
    }
}
