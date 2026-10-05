import SwiftUI

struct PlaylistSettingsView: View {
    @State private var options = UserDefaults.playlistOptions

    private static let rows: [(PlaylistPart, String, Color)] = [
        (.description, "text.alignleft", .blue),
        (.creator, "person.crop.circle.fill", .purple),
        (.metadata, "clock.fill", .gray),
        (.pills, "capsule.fill", .orange),
    ]

    var body: some View {
        List {
            Section(footer: Text("playlist_footer".localized)) {
                SettingsToggle(title: "playlist_full_cover".localized, icon: "photo.fill", color: .purple, isOn: $options.fullCover)
                SettingsToggle(title: "playlist_dividers".localized, icon: "line.3.horizontal", color: .gray, isOn: $options.dividers)
                SettingsToggle(title: "playlist_hide_find".localized, icon: "magnifyingglass", color: .orange, isOn: $options.hideFind)
            }

            Section(header: Text("home_hide".localized), footer: Text("restart_is_required_description".localized)) {
                ForEach(Self.rows, id: \.0) { part, icon, color in
                    SettingsToggle(title: "playlist_part_\(part.rawValue)".localized, icon: icon, color: color, isOn: Binding(
                        get: { options.hiddenParts.contains(part) },
                        set: { on in options.hiddenParts = PlaylistPart.allCases.filter { $0 == part ? on : options.hiddenParts.contains($0) } }
                    ))
                }
            }

            SettingsResetSection(visible: options != PlaylistOptions()) { options = PlaylistOptions() }

            RestartSection(visible: Set(options.hiddenParts) != PlaylistHides.hidden)

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: options) { options in
            UserDefaults.playlistOptions = options
            NotificationCenter.default.post(name: .eeveePlaylistOptionsChanged, object: nil)
        }
    }
}
