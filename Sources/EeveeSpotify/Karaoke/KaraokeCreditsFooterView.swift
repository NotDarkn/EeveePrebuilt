import SwiftUI

struct KaraokeCreditsFooterView: View {
    let lyrics: KaraokeLyricsDto

    private var providerLabel: String? {
        nonEmpty(lyrics.providerName) ?? nonEmpty(lyrics.providerCode).map { _ in SpicyLyricsRepository.providerName }
    }

    private func nonEmpty(_ value: String?) -> String? {
        (value ?? "").isEmpty ? nil : value
    }

    private func creditLine(_ prefix: String, name: String, url: String?) -> some View {
        HStack(spacing: 4) {
            Text(prefix)
                .foregroundColor(.white.opacity(0.4))

            if let url = url, let destination = URL(string: url) {
                Link(name, destination: destination)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(name)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .font(.system(size: 12, weight: .regular))
    }

    var body: some View {
        let maker = nonEmpty(lyrics.makerName)
        let uploader = nonEmpty(lyrics.uploaderName)

        if !lyrics.songWriters.isEmpty || providerLabel != nil || maker != nil || uploader != nil {
            VStack(alignment: .center, spacing: 4) {
                if !lyrics.songWriters.isEmpty {
                    Text("\("lyrics_written_by".localized) \(lyrics.songWriters.joined(separator: ", "))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                if let providerLabel = providerLabel {
                    Text("\("lyrics_provided_by".localized) \(providerLabel)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                if let maker = maker {
                    creditLine("lyrics_made_by".localized, name: maker, url: lyrics.makerUrl)
                }
                if let uploader = uploader {
                    creditLine("lyrics_uploaded_by".localized, name: uploader, url: lyrics.uploaderUrl)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }
}
