import SwiftUI
import UIKit

struct TabBarSettingsView: View {
    @State private var tabs = UserDefaults.tabBarOptions
    private let knownTabs = UserDefaults.knownTabs

    private var allTabs: [String] {
        knownTabs + tabs.customTabs.map(\.key)
    }

    private var visibleTabs: [String] {
        tabs.arrange(allTabs) { $0 }.filter { !tabs.hidden.contains($0) }
    }

    private var hiddenTabs: [String] {
        allTabs.filter { tabs.hidden.contains($0) }
    }

    private func entry(_ key: String) -> TabEntry { Self.entry(key, in: tabs) }

    static func entry(_ key: String, in tabs: TabBarOptions) -> TabEntry {
        if let tab = tabs.customTabs.first(where: { $0.key == key }) {
            return TabEntry(key: key, title: tab.displayTitle, image: tab.outlineImage, launchable: false)
        }
        return TabEntry(key: key, title: key, image: TabIconStore.load(key), launchable: true)
    }

    static func visibleEntries(_ tabs: TabBarOptions) -> [TabEntry] {
        let all = UserDefaults.knownTabs + tabs.customTabs.map(\.key)
        return tabs.arrange(all) { $0 }.filter { !tabs.hidden.contains($0) }.map { entry($0, in: tabs) }
    }

    var body: some View {
        List {
            if knownTabs.isEmpty {
                Section {
                    Text("tab_bar_empty".localized).font(.footnote).foregroundColor(.secondary)
                }
            } else {
                Section(footer: Text("tab_bar_editor_hint".localized)) {
                    editor
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section(header: Text("tab_custom".localized), footer: Text("tab_custom_footer".localized)) {
                addTabMenu
                ForEach(tabs.customTabs, id: \.key) { tab in
                    HStack(spacing: 14) {
                        SettingsIcon(systemName: tab.sfSymbol, color: Color(hex: "#5E5CE6"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tab.title)
                            Text(tab.uri).font(.footnote).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
                .onDelete { offsets in removeCustomTabs(offsets.map { tabs.customTabs[$0] }) }
            }

            Section(header: Text("glass_style".localized)) {
                SettingsToggle(title: "tab_bar_hide_labels".localized, icon: "textformat", color: .gray, isOn: $tabs.hideLabels)
                SettingsToggle(
                    title: "npb_album_tint".localized, icon: "paintbrush.fill", color: .pink,
                    isOn: Binding(get: { tabs.albumTint == true }, set: { tabs.albumTint = $0 })
                )
            }

            SettingsResetSection(visible: tabs != TabBarOptions()) {
                tabs = TabBarOptions()
            }

            SpacerView()
        }
        .eeveeSettingsStyle()
        .animation(.default, value: tabs)
        .onChange(of: tabs) { options in
            UserDefaults.tabBarOptions = options
            NotificationCenter.default.post(name: .eeveeTabBarOptionsChanged, object: nil)
        }
    }

    private var editor: some View {
        VStack(spacing: 14) {
            TabBarPreviewCard {
                TabBarEditor(
                    tabs: visibleTabs.map(entry),
                    launchTab: tabs.launchTab,
                    hideLabels: tabs.hideLabels,
                    onReorder: { tabs.order = $0 + hiddenTabs },
                    onHide: { title in
                        tabs.hidden.append(title)
                        if tabs.launchTab == title { tabs.launchTab = nil }
                    },
                    onSelect: { tabs.launchTab = $0 }
                )
            }

            if !hiddenTabs.isEmpty {
                HStack(spacing: 10) {
                    ForEach(hiddenTabs, id: \.self) { key in
                        Button {
                            tabs.hidden.removeAll { $0 == key }
                        } label: {
                            VStack(spacing: 4) {
                                icon(key).foregroundColor(.secondary)
                                Text(entry(key).title).font(.caption2.weight(.medium)).foregroundColor(.secondary).lineLimit(1)
                            }
                            .frame(width: 72, height: 58)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func icon(_ key: String) -> Image {
        entry(key).image.map { Image(uiImage: $0) } ?? Image(systemName: "circle.dashed")
    }

    private var addTabMenu: some View {
        Menu {
            ForEach(CustomTab.presets.filter { preset in !tabs.customTabs.contains { $0.uri == preset.uri } }, id: \.key) { preset in
                Button { tabs.customTabs.append(preset) } label: { Label(preset.title, systemImage: preset.sfSymbol) }
            }
            Button(action: promptCustomTab) { Label("tab_custom_uri".localized, systemImage: "link") }
        } label: {
            SettingsLabel(title: "tab_add".localized, icon: "plus", color: .green)
        }
    }

    private func removeCustomTabs(_ removed: [CustomTab]) {
        let keys = Set(removed.map(\.key))
        tabs.customTabs.removeAll { keys.contains($0.key) }
        tabs.order.removeAll(where: keys.contains)
        tabs.hidden.removeAll(where: keys.contains)
    }

    private func promptCustomTab() {
        let alert = UIAlertController(title: "tab_custom_uri".localized, message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "tab_custom_title".localized }
        alert.addTextField {
            $0.placeholder = "spotify:playlist:…"
            $0.keyboardType = .URL
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addTextField {
            $0.placeholder = "star.fill"
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel".uiKitLocalized, style: .cancel))
        alert.addAction(UIAlertAction(title: "tab_add".localized, style: .default) { _ in
            let fields = alert.textFields?.map { ($0.text ?? "").trimmingCharacters(in: .whitespaces) } ?? []
            guard fields.count == 3, let uri = CustomTab.uri(from: fields[1]) else {
                let invalid = UIAlertController(title: "tab_invalid_uri".localized, message: nil, preferredStyle: .alert)
                invalid.addAction(UIAlertAction(title: "OK".uiKitLocalized, style: .cancel))
                WindowHelper.shared.present(invalid)
                return
            }
            guard !tabs.customTabs.contains(where: { $0.uri == uri }) else { return }
            let symbol = UIImage(systemName: fields[2]) != nil ? fields[2] : "star.fill"
            tabs.customTabs.append(CustomTab(title: fields[0].isEmpty ? uri : fields[0], uri: uri, sfSymbol: symbol))
        })
        WindowHelper.shared.present(alert)
    }
}

struct TabBarPreviewCard<Bar: View>: View {
    @ViewBuilder let bar: () -> Bar

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hex: "#1ED760").opacity(0.55), Color(hex: "#5E5CE6").opacity(0.6), Color(hex: "#FF375F").opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            bar()
                .frame(height: 66)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
