import SwiftUI

enum EeveeTheme {
    static var accent: Color {
        Color(Theme.color(Theme.accentOrGreen(UserDefaults.accentRGB)))
    }
}

struct EeveeSettingsStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(InsetGroupedListStyle())
            .toggleStyle(SwitchToggleStyle(tint: EeveeTheme.accent))
            .accentColor(EeveeTheme.accent)
    }
}

extension View {
    func eeveeSettingsStyle() -> some View {
        modifier(EeveeSettingsStyle())
    }
}

struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            )
    }
}

struct SettingsLabel: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    var chevron = false

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if chevron { ChevronRightView() }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

struct SettingsToggle: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(title: title, subtitle: subtitle, icon: icon, color: color)
        }
    }
}

struct SettingsHero: View {

    @ViewBuilder private var logo: some View {
        if let image = BundleHelper.shared.uiImage("EeveeLogo") {
            Image(uiImage: image).resizable()
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(EeveeTheme.accent)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            logo
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: EeveeTheme.accent.opacity(0.45), radius: 18)
            Text("EeveeSpotify")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("v\(EeveeSpotify.version) (build \(EeveeSpotify.buildNumber)) · Spotify \(EeveeSpotify.spotifyVersion)")
                .font(.footnote.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

struct SettingsEntry: Identifiable {
    let key: String
    let icon: String
    let color: Color
    let make: () -> AnyView

    var id: String { key }
}

struct SettingsGroup: Identifiable {
    let key: String
    let entries: [SettingsEntry]

    var id: String { key }
}

struct SettingsGroupSection: View {
    let group: SettingsGroup
    let open: (SettingsEntry) -> Void

    var body: some View {
        Section(header: Text(group.key.localized)) {
            ForEach(group.entries) { entry in
                Button {
                    open(entry)
                } label: {
                    SettingsLabel(
                        title: entry.key.localized,
                        subtitle: "\(entry.key)_subtitle".localized,
                        icon: entry.icon,
                        color: entry.color,
                        chevron: true
                    )
                }
            }
        }
    }
}

enum SettingsNavigator {
    static weak var navigationController: UINavigationController?

    static func push<V: View>(_ view: V, title: String) {
        guard let navigationController else { return }
        navigationController.pushViewController(
            EeveeSettingsViewController(navigationController.view.frame, settingsView: AnyView(view), navigationTitle: title),
            animated: true
        )
    }
}

struct SettingsLink<Destination: View>: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    let destination: () -> Destination

    var body: some View {
        Button {
            SettingsNavigator.push(destination(), title: title)
        } label: {
            SettingsLabel(title: title, subtitle: subtitle, icon: icon, color: color, chevron: true)
        }
    }
}

struct SettingsResetSection: View {
    let visible: Bool
    let action: () -> Void

    var body: some View {
        if visible {
            Section {
                Button {
                    confirmDestructive(title: "reset_page_title".localized, confirm: "reset_page".localized) { withAnimation { action() } }
                } label: {
                    SettingsLabel(title: "reset_page".localized, icon: "arrow.counterclockwise", color: .red)
                }
            }
        }
    }
}

struct RestartSection: View {
    let visible: Bool

    var body: some View {
        if visible {
            Section {
                Button(action: exitApplication) {
                    Text("restart_now".localized).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .foregroundColor(EeveeTheme.accent)
            }
        }
    }
}

func confirmDestructive(title: String, message: String? = nil, confirm: String, action: @escaping () -> Void) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel".uiKitLocalized, style: .cancel))
    alert.addAction(UIAlertAction(title: confirm, style: .destructive) { _ in action() })
    WindowHelper.shared.present(alert)
}
