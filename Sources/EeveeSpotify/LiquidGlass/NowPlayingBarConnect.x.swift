import Orion
import UIKit

struct NowPlayingBarConnectGroup: HookGroup {}

class NowPlayingBarConnectHook: ClassHook<UIViewController> {
    typealias Group = NowPlayingBarConnectGroup
    static let targetName = "_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"

    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        guard let root = target.viewIfLoaded else { return }
        NowPlayingBarConnect.meter.measure { NowPlayingBarConnect.hide(in: root) }
    }
}

enum NowPlayingBarConnect {
    static let meter = PerfMeter("NowPlayingBar][Connect")
    private static weak var hidden: UIView?

    // The "playing on…" label inside InformationContainer is Connect too, but it belongs to the title and stays.
    static func hide(in root: UIView) {
        if let hidden, hidden.isHidden, hidden.isDescendant(of: root) { return }
        var queue = [root]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            let name = NSStringFromClass(type(of: view))
            if name.contains("InformationContainer") { continue }
            if name.contains("ConnectButtonView") || name.contains("ConnectStateView") {
                var item = view
                while let parent = item.superview, parent !== root, !(parent is UIStackView) { item = parent }
                if item.superview === root { item = view }
                if !item.isHidden { item.isHidden = true }
                hidden = item
                continue
            }
            queue += view.subviews
        }
    }
}

func activateNowPlayingBarConnect() {
    guard UserDefaults.nowPlayingBarOptions.hideConnect else { return }
    guard NSClassFromString(NowPlayingBarConnectHook.targetName) != nil else {
        eeveeLog("[EeveeSpotify][NowPlayingBar] Skipped hide device: bar class missing")
        return
    }
    NowPlayingBarConnectGroup().activate()
    eeveeLog("[EeveeSpotify][NowPlayingBar] Device button hidden")
}
