import SwiftUI

struct KaraokeLineLayout {
    let words: [[KaraokeSyllableDto]]
    let isRTL: Bool
}

extension KaraokeTextAlignment {
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

@available(iOS 15.0, *)
struct KaraokeLineView: View {
    let layout: KaraokeLineLayout
    let currentMs: Int
    let isActiveLine: Bool
    let availableWidth: CGFloat
    let alignment: HorizontalAlignment

    var body: some View {
        KaraokeFlowLayout(spacing: 8, alignment: alignment) {
            ForEach(Array(layout.words.enumerated()), id: \.offset) { _, word in
                KaraokeWordView(syllables: word, currentMs: currentMs, isActiveLine: isActiveLine, isRTL: layout.isRTL)
            }
        }
        .frame(width: availableWidth)
        .opacity(isActiveLine ? 1.0 : 0.4)
        .blur(radius: isActiveLine ? 0 : CGFloat(UserDefaults.karaokeOptions.blurIntensity))
        .scaleEffect(isActiveLine ? 1.0 : 0.97, anchor: .center)
        .animation(.easeOut(duration: 0.35), value: isActiveLine)
        // Mirrors word/row order for RTL lines; the fill gradient is flipped separately below.
        .environment(\.layoutDirection, layout.isRTL ? .rightToLeft : .leftToRight)
    }
}

@available(iOS 15.0, *)
private struct KaraokeWordView: View {
    let syllables: [KaraokeSyllableDto]
    let currentMs: Int
    let isActiveLine: Bool
    let isRTL: Bool

    private var wordStartMs: Int { syllables.first?.startMs ?? 0 }
    private var wordEndMs: Int { syllables.last?.endMs ?? wordStartMs }

    private var wordProgress: Double {
        guard isActiveLine, wordEndMs > wordStartMs else {
            return currentMs >= wordEndMs ? 1 : 0
        }
        let raw = Double(currentMs - wordStartMs) / Double(wordEndMs - wordStartMs)
        return min(1, max(0, raw))
    }

    private var scale: Double { KaraokeAnimationCurve.wordScale.value(at: wordProgress) }
    private var glow: Double { KaraokeAnimationCurve.glow.value(at: wordProgress) }
    private var yOffsetFraction: Double { KaraokeAnimationCurve.yOffset.value(at: wordProgress) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(syllables.enumerated()), id: \.offset) { _, syllable in
                KaraokeSyllableTextView(
                    syllable: syllable,
                    currentMs: currentMs,
                    isActiveLine: isActiveLine,
                    isRTL: isRTL
                )
            }
        }
        .scaleEffect(scale)
        // Curve offsets are em fractions; 28 is the syllable font size.
        .offset(y: CGFloat(yOffsetFraction) * 28)
        .shadow(color: .white.opacity(glow * 0.8), radius: CGFloat(glow * 8))
        .animation(.linear(duration: 1.0 / 30.0), value: wordProgress)
    }
}

@available(iOS 15.0, *)
private struct KaraokeSyllableTextView: View {
    let syllable: KaraokeSyllableDto
    let currentMs: Int
    let isActiveLine: Bool
    let isRTL: Bool

    // LinearGradient never mirrors .leading/.trailing for RTL, so pick the physical edges here.
    private var gradientStart: UnitPoint { isRTL ? .trailing : .leading }
    private var gradientEnd: UnitPoint { isRTL ? .leading : .trailing }

    private var progress: Double {
        guard isActiveLine, syllable.endMs > syllable.startMs else {
            return currentMs >= syllable.endMs ? 1 : 0
        }
        let raw = Double(currentMs - syllable.startMs) / Double(syllable.endMs - syllable.startMs)
        return min(1, max(0, raw))
    }

    var body: some View {
        Text(syllable.text)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: progress),
                        .init(color: .white.opacity(0.35), location: progress),
                        .init(color: .white.opacity(0.35), location: 1),
                    ],
                    startPoint: gradientStart,
                    endPoint: gradientEnd
                )
            )
            .animation(.linear(duration: 0.08), value: progress)
    }
}
