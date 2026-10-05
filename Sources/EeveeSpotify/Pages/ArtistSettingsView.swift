import SwiftUI

struct ArtistSettingsView: View {
    @State private var hidden = Set(UserDefaults.artistHidden)

    private static let rows: [(ArtistPart, String, Color)] = [
        (.verified, "checkmark.seal.fill", .blue),
        (.listeners, "person.2.fill", .purple),
        (.tabs, "rectangle.split.3x1.fill", .orange),
    ]

    var body: some View {
        List {
            Section(header: Text("home_hide".localized), footer: Text("restart_is_required_description".localized)) {
                ForEach(Self.rows, id: \.0) { part, icon, color in
                    SettingsToggle(title: "artist_\(part.rawValue)".localized, icon: icon, color: color, isOn: Binding(
                        get: { hidden.contains(part) },
                        set: { if $0 { hidden.insert(part) } else { hidden.remove(part) } }
                    ))
                }
            }

            SettingsResetSection(visible: !hidden.isEmpty) { hidden = [] }

            RestartSection(visible: hidden != ArtistHides.hidden)

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: hidden) { UserDefaults.artistHidden = ArtistPart.allCases.filter($0.contains) }
    }
}
