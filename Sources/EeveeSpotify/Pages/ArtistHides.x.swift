import Orion
import UIKit

struct ArtistHeaderHidesGroup: HookGroup {}
struct ArtistTabsHideGroup: HookGroup {}

enum ArtistPart: String, CaseIterable, Codable {
    case verified, listeners, tabs
}

extension UserDefaults {
    @UserDefault(key: "eeveeArtistHidden", defaultValue: [ArtistPart]())
    static var artistHidden
}

enum ArtistHides {
    static let hidden = Set(UserDefaults.artistHidden)
    static let meter = PerfMeter("Artist][Hides")
    private static var pageKey: UInt8 = 0
    private static var badgeKey: UInt8 = 0
    private static var listenersKey: UInt8 = 0
    private static var stripKey: UInt8 = 0
    private static var logged = Set<ArtistPart>()

    private static func onArtistPage(_ view: UIView) -> Bool {
        PageLookup.isInside(view, id: "creator-page", key: &pageKey)
    }

    private static func vanish(_ view: UIView, _ part: ArtistPart) {
        guard view.alpha != 0 else { return }
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        if logged.insert(part).inserted { eeveeLog("[EeveeSpotify][Artist] Hid %@", part.rawValue) }
    }

    static func styleHeader(_ header: UIView) {
        guard onArtistPage(header) else { return }
        if hidden.contains(.verified),
           let badge = PageLookup.cached(&badgeKey, in: header, { PageLookup.find("ImageHeaderView.VerifiedBadge", in: header) }) {
            vanish(badge, .verified)
        }
        if hidden.contains(.listeners),
           let line = PageLookup.cached(&listenersKey, in: header, { PageLookup.find("Components.Header.UI.Metadata", in: header) }) {
            vanish(line, .listeners)
        }
    }

    // The strip sits in a stack that traps on hidden views, so it goes invisible and the pages slide up into its place.
    static func hideStrip(around button: UIView) {
        guard let strip = PageLookup.cached(&stripKey, in: button, {
                  PageLookup.ancestor(of: button, id: "Components.UI.TabsSectionHeading")
              }),
              onArtistPage(strip) else { return }
        vanish(strip, .tabs)
        guard strip.bounds.height > 0, let container = strip.superview else { return }
        let lift = CGAffineTransform(translationX: 0, y: -strip.bounds.height)
        for case let pages as UIScrollView in container.subviews where pages.transform != lift {
            pages.isScrollEnabled = false
            pages.transform = lift
        }
    }
}

class ArtistHeaderHook: ClassHook<UIView> {
    typealias Group = ArtistHeaderHidesGroup
    static let targetName = "_TtC35CreativeWorkPlatform_ImageHeaderKit15ImageHeaderView"

    func layoutSubviews() {
        orig.layoutSubviews()
        ArtistHides.meter.measure { ArtistHides.styleHeader(target) }
    }
}

class ArtistTabButtonHook: ClassHook<UIView> {
    typealias Group = ArtistTabsHideGroup
    static let targetName = "_TtCOOOE16PodcastUI_ECMKitO19LegacyUI_ECMCoreKit10Components18TabsSectionHeading2UI7Private9TabButton"

    func layoutSubviews() {
        orig.layoutSubviews()
        ArtistHides.meter.measure { ArtistHides.hideStrip(around: target) }
    }
}

func activateArtistHides() {
    let hidden = ArtistHides.hidden
    guard !hidden.isEmpty else { return }
    let start = CFAbsoluteTimeGetCurrent()
    var active = [String]()
    if !hidden.subtracting([.tabs]).isEmpty, NSClassFromString(ArtistHeaderHook.targetName) != nil {
        ArtistHeaderHidesGroup().activate()
        active.append("header")
    }
    if hidden.contains(.tabs), NSClassFromString(ArtistTabButtonHook.targetName) != nil {
        ArtistTabsHideGroup().activate()
        active.append("tabs")
    }
    eeveeLog("[EeveeSpotify][Artist] Hiding %@, hooks %@ (%.2f ms)", hidden.map(\.rawValue).sorted().joined(separator: ", "),
             active.isEmpty ? "MISSING" : active.joined(separator: "+"), (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
