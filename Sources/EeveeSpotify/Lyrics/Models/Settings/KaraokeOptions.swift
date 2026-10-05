import Foundation

enum KaraokeTextAlignment: String, Codable, CaseIterable {
    case leading
    case center
    case trailing

    var displayName: String {
        "karaoke_alignment_\(rawValue)".localized
    }
}

struct KaraokeOptions: Codable, Hashable {
    var textAlignment: KaraokeTextAlignment = .center
    var reversedDirection = false
    var enabled = true
    var blurIntensity: Double = 1.5

    init(textAlignment: KaraokeTextAlignment = .center, reversedDirection: Bool = false, enabled: Bool = true, blurIntensity: Double = 1.5) {
        self.textAlignment = textAlignment
        self.reversedDirection = reversedDirection
        self.enabled = enabled
        self.blurIntensity = blurIntensity
    }

    private enum CodingKeys: String, CodingKey {
        case textAlignment, reversedDirection, enabled, blurIntensity
    }

    // Settings saved before these fields existed must keep decoding.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textAlignment = try container.decodeIfPresent(KaraokeTextAlignment.self, forKey: .textAlignment) ?? .center
        reversedDirection = try container.decodeIfPresent(Bool.self, forKey: .reversedDirection) ?? false
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        blurIntensity = try container.decodeIfPresent(Double.self, forKey: .blurIntensity) ?? 1.5
    }
}
