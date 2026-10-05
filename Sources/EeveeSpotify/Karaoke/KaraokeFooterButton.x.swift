import Orion
import UIKit

struct KaraokeFooterGroup: HookGroup {}

extension Notification.Name {
    static let eeveeKaraokeLyricsChanged = Notification.Name("EeveeKaraokeLyricsChanged")
}

class KaraokeFooterUnitHook: ClassHook<UIViewController> {
    typealias Group = KaraokeFooterGroup
    static let targetName = "_TtC20NowPlaying_ModesImpl18FooterElementsUnit"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard #available(iOS 15.0, *), let root = target.viewIfLoaded else { return }
        KaraokeFooterButton.meter.measure { KaraokeFooterButton.attach(to: root) }
    }
}

@available(iOS 15.0, *)
enum KaraokeFooterButton {
    static let meter = PerfMeter("Karaoke][FooterButton")

    private static let button: UIButton = {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *), KaraokeGlass.isEnabled {
            config = .glass()
        } else {
            config = .plain()
            config.background.backgroundColor = UIColor(white: 1, alpha: 0.15)
        }
        config.title = "karaoke_word_synced_button".localized
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = .systemFont(ofSize: 13, weight: .semibold)
            return attributes
        }
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        let button = UIButton(configuration: config)
        button.overrideUserInterfaceStyle = .dark
        button.addAction(UIAction { _ in KaraokeOverlayPresenter.present() }, for: .primaryActionTriggered)
        return button
    }()

    private static let observer = NotificationCenter.default.addObserver(
        forName: .eeveeKaraokeLyricsChanged, object: nil, queue: .main
    ) { _ in update() }

    private static weak var row: UIStackView?

    static func attach(to root: UIView) {
        _ = observer
        if row?.isDescendant(of: root) != true {
            row = root.eeveeFirst(UIStackView.self, where: { $0.arrangedSubviews.count >= 2 })
        }
        guard let row else { return }
        let rowFrame = row.convert(row.bounds, to: root)
        if button.superview !== root { root.addSubview(button) }
        else if root.subviews.last !== button { root.bringSubviewToFront(button) }
        let size = button.intrinsicContentSize
        let frame = CGRect(x: root.bounds.midX - size.width / 2, y: rowFrame.midY - size.height / 2, width: size.width, height: size.height)
        if button.frame != frame { button.frame = frame }
        update()
    }

    private static func update() {
        button.isHidden = !KaraokeOverlayPresenter.isAvailableForCurrentTrack()
    }
}

func activateKaraokeFooterButton() {
    guard #available(iOS 15.0, *), UserDefaults.lyricsSource.supportsCustomLyricsView else { return }
    let start = CFAbsoluteTimeGetCurrent()
    guard NSClassFromString(KaraokeFooterUnitHook.targetName) != nil else {
        eeveeLog("[EeveeSpotify][Karaoke] Footer button skipped: footer unit missing")
        return
    }
    KaraokeFooterGroup().activate()
    eeveeLog("[EeveeSpotify][Karaoke] Footer button active (%.2f ms)", (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
