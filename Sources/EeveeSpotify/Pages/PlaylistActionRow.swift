import EeveeSpotifyC
import UIKit

// Glass shuffle / Play / add row over Spotify's hidden header controls, which still receive every tap.
@available(iOS 26.0, *)
final class PlaylistActionRow: UIView {
    static weak var current: PlaylistActionRow?
    weak var shuffle: UIView?
    weak var play: UIView?
    weak var add: UIView?
    weak var share: UIView?
    weak var explore: UIView?
    weak var followControl: UIView?
    weak var anchor: UIView?
    // Spotify's single play button moves into the nav bar once its row collapses; ours steps aside and lets it show there.
    weak var playHolder: UIView?
    weak var controlsRow: UIView?
    private var scrollObservation: NSKeyValueObservation?
    private weak var followed: UIScrollView?
    private var faded = false

    // Hosted outside Spotify's header (adding views there stalls its layout), so it follows the header's scroll itself.
    func follow(_ scrollView: UIScrollView?) {
        guard let scrollView, scrollView !== followed else { return }
        followed = scrollView
        scrollObservation = scrollView.observe(\.contentOffset) { [weak self] _, _ in self?.place() }
    }

    func place() {
        guard let host = superview, host.window != nil else { return }
        if let anchor, anchor.window != nil, anchor.bounds.height > 0 {
            let frame = anchor.convert(anchor.bounds, to: host)
            let target = CGRect(x: 0, y: frame.midY - 24, width: host.bounds.width, height: 48)
            if self.frame != target { self.frame = target }
        }
        let pinned = collapsed() || convert(bounds, to: nil).minY < (window?.safeAreaInsets.top ?? 0) + 50
        playHolder.map { holder in
            if holder.alpha != (pinned ? 1 : 0) { holder.alpha = pinned ? 1 : 0 }
            holder.isUserInteractionEnabled = pinned
        }
        guard pinned != faded else { return }
        faded = pinned
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.alpha = pinned ? 0 : 1
        }
    }

    private func collapsed() -> Bool {
        var view = controlsRow
        while let current = view, current !== superview {
            if current.isHidden || current.alpha < 0.5 { return true }
            view = current.superview
        }
        return false
    }

    private let shuffleButton = PlaylistActionRow.circle("shuffle")
    private let shuffleDot: UIView = {
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        dot.layer.cornerRadius = 2
        dot.isUserInteractionEnabled = false
        dot.isHidden = true
        return dot
    }()
    private let addButton = PlaylistActionRow.circle("plus")
    private let followButton: UIButton = {
        var config = UIButton.Configuration.glass()
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = .systemFont(ofSize: 15, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: config)
        button.isHidden = true
        return button
    }()
    private let shareButton = PlaylistActionRow.circle("square.and.arrow.up")
    private let playButton: UIButton = {
        var config = UIButton.Configuration.prominentGlass()
        config.cornerStyle = .capsule
        config.baseForegroundColor = .black
        config.imagePadding = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = .systemFont(ofSize: 16, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: config)
        button.tintColor = .white
        return button
    }()

    private static let playImage = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
    private static let pauseImage = UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
    private static let plusImage = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
    private static let checkImage = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
    private static let playTitle = "playlist_play".localized
    private static let pauseTitle = "playlist_pause".localized

    private static func circle(_ symbol: String) -> UIButton {
        var config = UIButton.Configuration.glass()
        config.cornerStyle = .capsule
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        return UIButton(configuration: config)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        overrideUserInterfaceStyle = .dark
        [shuffleButton, playButton, addButton, shareButton, followButton].forEach(addSubview)
        shuffleButton.addSubview(shuffleDot)
        shuffleButton.addAction(UIAction { [weak self] _ in self?.forward(self?.shuffle, "shuffle") }, for: .primaryActionTriggered)
        playButton.addAction(UIAction { [weak self] _ in self?.forward(self?.play, "play") }, for: .primaryActionTriggered)
        addButton.addAction(UIAction { [weak self] _ in self?.forward(self?.add, "add") }, for: .primaryActionTriggered)
        followButton.addAction(UIAction { [weak self] _ in self?.forward(self?.followControl, "follow") }, for: .primaryActionTriggered)
        shareButton.addAction(UIAction { [weak self] _ in self?.forward(self?.share, "share") }, for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 48, gap: CGFloat = 12
        let y = (bounds.height - side) / 2
        var playWidth: CGFloat = 140
        if let explore, explore.window != nil, explore.bounds.width > 0 {
            let clear = explore.convert(explore.bounds, to: self).maxX + 8
            playWidth = max(96, min(playWidth, 2 * (bounds.midX - clear - side - gap)))
        }
        playButton.frame = CGRect(x: bounds.midX - playWidth / 2, y: y, width: playWidth, height: side)
        shuffleButton.frame = CGRect(x: playButton.frame.minX - gap - side, y: y, width: side, height: side)
        shuffleDot.center = CGPoint(x: side / 2, y: side - 7)
        var x = playButton.frame.maxX + gap
        for button in [addButton, shareButton, followButton] where !button.isHidden {
            let width = button === followButton ? max(side, button.intrinsicContentSize.width) : side
            button.frame = CGRect(x: x, y: y, width: width, height: side)
            x += width + gap
        }
    }

    private func forward(_ source: UIView?, _ name: String) {
        guard let source else { return }
        let control = (source as? UIControl) ?? source.eeveeFirst(UIControl.self)
        let fired = control.map { EeveeFireTap($0) } ?? false
        if !fired { eeveeLog("[EeveeSpotify][Glass] Playlist %@ tap FAILED", name) }
        for delay in [0.4, 1.2, 2.5] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.sync() } }
    }

    func sync() {
        if addButton.isHidden != (add == nil) {
            addButton.isHidden = add == nil
            setNeedsLayout()
        }
        let followTitle = followControl?.eeveeFirst(UILabel.self)?.text
        var followConfig = followButton.configuration
        followConfig?.title = followTitle
        if followButton.configuration != followConfig || followButton.isHidden != (followTitle == nil) {
            followButton.configuration = followConfig
            followButton.isHidden = followTitle == nil
            setNeedsLayout()
        }
        if shareButton.isHidden != (share == nil) {
            shareButton.isHidden = share == nil
            setNeedsLayout()
        }
        let playing = (play?.accessibilityLabel ?? play?.eeveeFirst(UIControl.self)?.accessibilityLabel)?.lowercased().contains("pause") == true
        var config = playButton.configuration
        config?.image = playing ? Self.pauseImage : Self.playImage
        config?.title = playing ? Self.pauseTitle : Self.playTitle
        if playButton.configuration != config { playButton.configuration = config }

        let liked = add?.accessibilityLabel?.lowercased().contains("remove") == true
        var addConfig = addButton.configuration
        addConfig?.image = liked ? Self.checkImage : Self.plusImage
        addConfig?.baseForegroundColor = liked ? Theme.accent : .white
        if addButton.configuration != addConfig { addButton.configuration = addConfig }

        // Spotify marks shuffle with a small dot under its icon and swaps the icon for smart shuffle.
        let dot = shuffle?.eeveeFirst(UIView.self) { $0.bounds.width <= 8 && $0.bounds.width > 0 && $0.backgroundColor != nil && !$0.isHidden }
        let shuffled = (shuffle as? UIControl)?.isSelected == true || dot != nil
        var shuffleConfig = shuffleButton.configuration
        shuffleConfig?.baseForegroundColor = shuffled ? Theme.accent : .white
        if let icon = shuffle?.eeveeFirst(UIImageView.self, where: { $0.image != nil && $0.bounds.width >= 16 })?.image {
            shuffleConfig?.image = icon.withRenderingMode(.alwaysTemplate)
        }
        shuffleDot.isHidden = !shuffled
        shuffleDot.backgroundColor = Theme.accent
        if shuffleButton.configuration != shuffleConfig { shuffleButton.configuration = shuffleConfig }
    }
}
