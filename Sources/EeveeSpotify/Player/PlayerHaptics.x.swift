import Orion
import UIKit

struct PlayerHapticsGroup: HookGroup {}

enum PlayerHaptics {
    private(set) static var enabled = false
    static let scrubMeter = PerfMeter("Haptics][Scrub")
    static let controlMeter = PerfMeter("Haptics][Control")
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static var lastImpact: CFTimeInterval = 0
    private static var scrubTenth = 0

    static let controlIds: Set<String> = [
        "SPTNowPlayingPlayButton",
        "SPTNowPlayingPreviousTrackButton",
        "SPTNowPlayingNextTrackButton",
        "Components.UI.ShuffleButton",
        "Nowplaying-RepeatButton",
        "Components.UI.AddToButton",
    ]

    static func activate() {
        enabled = true
    }

    // A target-action and a UIAction on the same tap would otherwise buzz twice.
    static func impact() {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastImpact > 0.08 else { return }
        lastImpact = now
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }

    // The play button's id sits on the PlayButtonView around the UIButton that acts.
    static func controlId(_ control: UIControl) -> String? {
        if let id = control.accessibilityIdentifier, !id.isEmpty { return controlIds.contains(id) ? id : nil }
        guard let id = control.superview?.accessibilityIdentifier else { return nil }
        return controlIds.contains(id) ? id : nil
    }

    static func controlActed(_ control: UIControl, event: UIEvent?) {
        guard controlId(control) != nil else { return }
        if let touches = event?.allTouches, !touches.isEmpty, !touches.contains(where: { $0.phase == .ended }) { return }
        impact()
    }

    static func scrubBegan(_ slider: UISlider) {
        scrubTenth = tenth(of: slider)
        selectionGenerator.prepare()
    }

    static func scrubMoved(_ slider: UISlider) {
        let current = tenth(of: slider)
        guard current != scrubTenth else { return }
        scrubTenth = current
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    private static func tenth(of slider: UISlider) -> Int {
        let span = slider.maximumValue - slider.minimumValue
        guard span > 0 else { return 0 }
        return Int(min((slider.value - slider.minimumValue) / span, 0.9999) * 10)
    }
}

class PlayerHapticsControlHook: ClassHook<UIControl> {
    typealias Group = PlayerHapticsGroup

    func sendAction(_ action: Selector, to target: Any?, forEvent event: UIEvent?) {
        orig.sendAction(action, to: target, forEvent: event)
        PlayerHaptics.controlMeter.measure { PlayerHaptics.controlActed(self.target, event: event) }
    }

    func sendAction(_ action: UIAction) {
        orig.sendAction(action)
        PlayerHaptics.controlMeter.measure { PlayerHaptics.controlActed(target, event: nil) }
    }
}

class PlayerHapticsSliderHook: ClassHook<UIControl> {
    typealias Group = PlayerHapticsGroup
    static let targetName = "_TtCO17NowPlaying_ECMKit11ProgressBar6Slider"

    func beginTrackingWithTouch(_ touch: UITouch, withEvent event: UIEvent?) -> Bool {
        let tracking = orig.beginTrackingWithTouch(touch, withEvent: event)
        if tracking, let slider = target as? UISlider { PlayerHaptics.scrubBegan(slider) }
        return tracking
    }

    func continueTrackingWithTouch(_ touch: UITouch, withEvent event: UIEvent?) -> Bool {
        let tracking = orig.continueTrackingWithTouch(touch, withEvent: event)
        PlayerHaptics.scrubMeter.measure {
            if let slider = target as? UISlider { PlayerHaptics.scrubMoved(slider) }
        }
        return tracking
    }
}

func activatePlayerHaptics() {
    guard UserDefaults.playerExtrasOptions.haptics else { return }
    let start = CFAbsoluteTimeGetCurrent()
    guard NSClassFromString(PlayerHapticsSliderHook.targetName) != nil else {
        eeveeLog("[EeveeSpotify][Haptics] Skipped: missing %@", PlayerHapticsSliderHook.targetName)
        return
    }
    PlayerHapticsGroup().activate()
    PlayerHaptics.activate()
    eeveeLog("[EeveeSpotify][Haptics] Active: %d controls + scrubber (%.2f ms)", PlayerHaptics.controlIds.count,
             (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
