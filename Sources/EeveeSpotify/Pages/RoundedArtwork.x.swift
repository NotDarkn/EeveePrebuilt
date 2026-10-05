import Orion
import UIKit

struct RoundedArtworkGroup: HookGroup {}

enum RoundedArtwork {
    static let radius: CGFloat = 10

    // Circles (artists) are left alone; only square covers get the softer corner.
    static func round(_ view: UIView) {
        let layer = view.layer
        guard layer.cornerRadius < view.bounds.width / 2 - 1, layer.cornerRadius != radius else { return }
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        view.clipsToBounds = true
    }
}

class LibraryRowArtworkHook: ClassHook<UIView> {
    typealias Group = RoundedArtworkGroup
    static let targetName = "_TtC19LegacyUI_ECMCoreKitP33_3DFE6A8953CA91BDEBA7A38450631F5815ImageViewHolder"

    func layoutSubviews() {
        orig.layoutSubviews()
        if target.accessibilityIdentifier == "Artwork.Row.Library" { RoundedArtwork.round(target) }
    }
}

class TrackRowArtworkHook: ClassHook<UIView> {
    typealias Group = RoundedArtworkGroup
    static let targetName = "_TtCE15Encore_MediaKitO16EncoreFoundation6Encore9ImageView"

    func layoutSubviews() {
        orig.layoutSubviews()
        if target.superview?.accessibilityIdentifier == "TrackRowElement.Media" { RoundedArtwork.round(target) }
    }
}

func activateRoundedArtwork() {
    guard UserDefaults.roundedArtwork else { return }
    let start = CFAbsoluteTimeGetCurrent()
    guard NSClassFromString(LibraryRowArtworkHook.targetName) != nil, NSClassFromString(TrackRowArtworkHook.targetName) != nil else {
        eeveeLog("[EeveeSpotify][Artwork] Skipped: artwork classes missing")
        return
    }
    RoundedArtworkGroup().activate()
    eeveeLog("[EeveeSpotify][Artwork] Rounded artwork on (%.2f ms)", (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
