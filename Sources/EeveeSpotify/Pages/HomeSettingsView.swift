import SwiftUI

struct HomeSettingsView: View {
    @State private var hidden = Set(UserDefaults.homeHidden)

    private static let rows: [(HomePart, String, Color)] = [
        (.pills, "rectangle.3.group.fill", .blue),
        (.shortcuts, "square.grid.2x2.fill", .purple),
        (.promos, "megaphone.fill", .orange),
        (.previews, "play.square.stack.fill", .pink),
        (.dj, "waveform", .green),
    ]

    var body: some View {
        List {
            Section(header: Text("home_hide".localized), footer: Text("restart_is_required_description".localized)) {
                ForEach(Self.rows, id: \.0) { part, icon, color in
                    SettingsToggle(title: "home_\(part.rawValue)".localized, icon: icon, color: color, isOn: Binding(
                        get: { hidden.contains(part) },
                        set: { if $0 { hidden.insert(part) } else { hidden.remove(part) } }
                    ))
                }
            }

            SettingsResetSection(visible: !hidden.isEmpty) {
                hidden = []
            }

            RestartSection(visible: hidden != HomeDeclutter.hidden)

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: hidden) { UserDefaults.homeHidden = HomePart.allCases.filter($0.contains) }
    }
}
