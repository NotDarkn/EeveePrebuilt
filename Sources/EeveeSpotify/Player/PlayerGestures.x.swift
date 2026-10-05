import EeveeSpotifyC
import Orion
import UIKit

struct PlayerGesturesGroup: HookGroup {}
struct PlayerTiltSuppressGroup: HookGroup {}

@objc private protocol NowPlayingPlayback {
    func seekForwardBySeconds(_ seconds: Double)
    func seekBackwardBySeconds(_ seconds: Double)
    func skipToNextWhileDragging(_ dragging: Bool)
    func skipToPreviousWhileDragging(_ dragging: Bool)
    func setPaused(_ paused: Bool)
    var isPaused: Bool { get }
    var seekingAllowed: Bool { get }
}

enum PlayerZoneAction: String {
    case seekBack, seekForward, playPause, previous, next

    var symbol: String {
        switch self {
        case .seekBack: return "gobackward.10"
        case .seekForward: return "goforward.10"
        case .playPause: return "playpause.fill"
        case .previous: return "backward.fill"
        case .next: return "forward.fill"
        }
    }

    var buttonId: String? {
        switch self {
        case .seekBack, .seekForward: return nil
        case .previous: return "SPTNowPlayingPreviousTrackButton"
        case .next: return "SPTNowPlayingNextTrackButton"
        case .playPause: return "SPTNowPlayingPlayButton"
        }
    }
}

final class PlayerGestures: NSObject, UIGestureRecognizerDelegate {
    static let shared = PlayerGestures()
    static let options = UserDefaults.playerExtrasOptions
    static let attachMeter = PerfMeter("Gestures][Attach")
    static weak var playback: NSObject?
    private static var tapKey: UInt8 = 0
    private static let seekStep = 10.0

    private let actions: [PlayerZoneAction] = {
        let sides: [PlayerZoneAction] = PlayerGestures.options.doubleTap == .seek ? [.seekBack, .seekForward] : [.previous, .next]
        return PlayerGestures.options.threeZones ? [sides[0], .playPause, sides[1]] : sides
    }()

    func attach(to host: UIView) {
        guard objc_getAssociatedObject(host, &Self.tapKey) == nil else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        tap.delegate = self
        host.addGestureRecognizer(tap)
        objc_setAssociatedObject(host, &Self.tapKey, tap, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        (other as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
    }

    // The host is the sideways-scrolled cover list, so its bounds origin is the scroll offset.
    @objc private func doubleTapped(_ tap: UITapGestureRecognizer) {
        guard let host = tap.view, host.bounds.width > 0 else { return }
        let x = tap.location(in: host).x - host.bounds.minX
        let index = max(0, min(actions.count - 1, Int(x / host.bounds.width * CGFloat(actions.count))))
        let action = actions[index]
        if let failure = perform(action, near: host) {
            eeveeLog("[EeveeSpotify][Gestures] Double tap %@ FAILED: %@", action.rawValue, failure)
        }
        PlayerHaptics.impact()
        showBubble(action, zone: index, in: host)
    }

    private func perform(_ action: PlayerZoneAction, near host: UIView) -> String? {
        if let object = Self.playback {
            let player = unsafeBitCast(object, to: NowPlayingPlayback.self)
            switch action {
            case .seekBack: if player.seekingAllowed { player.seekBackwardBySeconds(Self.seekStep) }
            case .seekForward: if player.seekingAllowed { player.seekForwardBySeconds(Self.seekStep) }
            case .playPause: player.setPaused(!player.isPaused)
            case .previous: player.skipToPreviousWhileDragging(false)
            case .next: player.skipToNextWhileDragging(false)
            }
            return nil
        }
        guard let id = action.buttonId else { return "no controller" }
        let button = host.window?.eeveeFirst(UIView.self) { $0.accessibilityIdentifier == id }
        return button.map { EeveeFireTap($0) } == true ? nil : "no controller or button"
    }

    private func showBubble(_ action: PlayerZoneAction, zone: Int, in host: UIView) {
        guard let parent = host.superview else { return }
        let size: CGFloat = 64
        let width = host.frame.width / CGFloat(actions.count)
        let center = CGPoint(x: host.frame.minX + width * (CGFloat(zone) + 0.5), y: host.frame.midY)
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) { effect = UIGlassEffect(style: .regular) } else { effect = UIBlurEffect(style: .systemThinMaterialDark) }
        let bubble = UIVisualEffectView(effect: effect)
        bubble.frame = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        bubble.layer.cornerRadius = size / 2
        bubble.clipsToBounds = true
        bubble.isUserInteractionEnabled = false
        bubble.overrideUserInterfaceStyle = .dark
        let icon = UIImageView(image: UIImage(systemName: action.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.frame = bubble.bounds
        bubble.contentView.addSubview(icon)
        parent.addSubview(bubble)
        bubble.alpha = 0
        bubble.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
            bubble.alpha = 1
            bubble.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.35, options: .curveEaseIn) {
                bubble.alpha = 0
            } completion: { _ in bubble.removeFromSuperview() }
        }
    }
}

class PlayerPlaybackControllerHook: ClassHook<NSObject> {
    typealias Group = PlayerGesturesGroup
    static let targetName = "SPTNowPlayingPlaybackControllerImplementation"

    func initWithPlayer(_ player: AnyObject?, testManager: AnyObject?, inStreamClient: AnyObject?) -> Target {
        let controller = orig.initWithPlayer(player, testManager: testManager, inStreamClient: inStreamClient)
        PlayerGestures.playback = controller
        return controller
    }
}

class PlayerCoverGestureHook: ClassHook<UIView> {
    typealias Group = PlayerGesturesGroup
    static let targetName = "_TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView"

    func layoutSubviews() {
        orig.layoutSubviews()
        PlayerGestures.attachMeter.measure { PlayerGestures.shared.attach(to: target) }
    }
}

// The cover's single tap opens tilt mode, which is the first half of every double tap.
class PlayerTiltSuppressHook: ClassHook<UIView> {
    typealias Group = PlayerTiltSuppressGroup
    static let targetName = "_TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView"

    func handleTap() {
        guard !PlayerPlacement.contains(target) else { return }
        orig.handleTap()
    }
}

func activatePlayerGestures() {
    let options = PlayerGestures.options
    guard options.doubleTap != .off else { return }
    let start = CFAbsoluteTimeGetCurrent()
    let required = [PlayerPlaybackControllerHook.targetName, PlayerCoverGestureHook.targetName]
    let missing = required.filter { NSClassFromString($0) == nil }
    guard missing.isEmpty else {
        eeveeLog("[EeveeSpotify][Gestures] Skipped: missing %@", missing.joined(separator: ", "))
        return
    }
    let playback: AnyClass? = NSClassFromString(PlayerPlaybackControllerHook.targetName)
    let selectors = ["initWithPlayer:testManager:inStreamClient:", "seekForwardBySeconds:", "seekBackwardBySeconds:",
                     "skipToNextWhileDragging:", "skipToPreviousWhileDragging:", "setPaused:", "isPaused", "seekingAllowed"]
    let absent = selectors.filter { class_getInstanceMethod(playback, NSSelectorFromString($0)) == nil }
    guard absent.isEmpty else {
        eeveeLog("[EeveeSpotify][Gestures] Skipped: controller lacks %@", absent.joined(separator: ", "))
        return
    }
    PlayerGesturesGroup().activate()
    let tilt = NSClassFromString(PlayerTiltSuppressHook.targetName)
    let suppressTilt = class_getInstanceMethod(tilt, NSSelectorFromString("handleTap")) != nil
    if suppressTilt { PlayerTiltSuppressGroup().activate() }
    eeveeLog("[EeveeSpotify][Gestures] Active: %@, %d zones, tilt %@ (%.2f ms)", options.doubleTap.rawValue,
             options.threeZones ? 3 : 2, suppressTilt ? "suppressed" : "untouched", (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
