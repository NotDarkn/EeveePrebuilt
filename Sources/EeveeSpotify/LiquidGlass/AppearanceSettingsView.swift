import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @State private var amoled = UserDefaults.amoled
    @AppStorage("eeveeAccent", store: UserDefaults.container) private var accent = -1
    @State private var roundedArtwork = UserDefaults.roundedArtwork
    @State private var glass = UserDefaults.liquidGlassOptions
    @State private var gradient = UserDefaults.homeGradient
    @State private var tabs = UserDefaults.tabBarOptions
    private let launchRounded = UserDefaults.roundedArtwork

    private var glassSubtitle: String {
        guard LiquidGlassSettingsView.supported else { return "liquid_glass_unsupported".localized }
        return (glass.enabled ? "state_on" : "state_off").localized
    }

    private var gradientSubtitle: String {
        let pages = GradientPage.allCases.filter(gradient.shownPages.contains)
        guard !pages.isEmpty else { return "state_off".localized }
        return pages.map { "home_gradient_page_\($0.rawValue)".localized }.joined(separator: ", ")
    }

    private var showsTabPreview: Bool {
        LiquidGlassSettingsView.supported && glass.enabled && glass.tabBar && !UserDefaults.knownTabs.isEmpty
    }

    var body: some View {
        List {
            if showsTabPreview {
                Section {
                    Button {
                        SettingsNavigator.push(TabBarSettingsView(), title: "tab_bar".localized)
                    } label: {
                        TabBarPreviewCard {
                            TabBarEditor(tabs: TabBarSettingsView.visibleEntries(tabs), launchTab: tabs.launchTab, hideLabels: tabs.hideLabels,
                                         onReorder: { _ in }, onHide: { _ in }, onSelect: { _ in })
                                .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section(header: Text("theme".localized), footer: Text("theme_footer".localized)) {
                SettingsToggle(title: "amoled".localized, icon: "moon.fill", color: Color(hex: "#3A3A3C"), isOn: $amoled)
                accentRow
                SettingsToggle(title: "rounded_artwork".localized, icon: "square.on.square", color: .orange, isOn: $roundedArtwork)
            }

            Section {
                SettingsLink(
                    title: "background_color".localized, subtitle: gradientSubtitle, icon: "circle.lefthalf.fill",
                    color: Color(gradient.tintRGB.map(Theme.color) ?? Theme.accent)
                ) {
                    BackgroundColorView()
                }
                SettingsLink(title: "liquid_glass".localized, subtitle: glassSubtitle, icon: "drop.fill", color: Color(hex: "#30B0C7")) {
                    LiquidGlassSettingsView()
                }
            }

            Section(header: Text("appearance_pages".localized)) {
                SettingsLink(title: "glass_now_playing_bar".localized, subtitle: "npb_subtitle".localized, icon: "play.rectangle.fill", color: EeveeTheme.accent) {
                    NowPlayingBarSettingsView()
                }
                SettingsLink(title: "player".localized, subtitle: "player_subtitle".localized, icon: "rectangle.portrait.fill", color: .purple) {
                    PlayerSettingsView()
                }
                SettingsLink(title: "glass_playlist".localized, subtitle: "playlist_subtitle".localized, icon: "music.note.list", color: .pink) {
                    PlaylistSettingsView()
                }
                SettingsLink(title: "artist".localized, subtitle: "artist_subtitle".localized, icon: "music.mic", color: .orange) {
                    ArtistSettingsView()
                }
                SettingsLink(title: "home".localized, subtitle: "home_subtitle".localized, icon: "house.fill", color: .blue) {
                    HomeSettingsView()
                }
            }

            SettingsResetSection(visible: amoled || accent >= 0 || roundedArtwork) {
                amoled = false
                accent = -1
                roundedArtwork = false
            }

            if amoled != Theme.launchAmoled || accent != Theme.launchAccent || roundedArtwork != launchRounded {
                Section {
                    Button(action: exitApplication) {
                        Text("restart_now".localized).fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                    .foregroundColor(EeveeTheme.accent)
                }
            }

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: amoled) { UserDefaults.amoled = $0 }
        .onChange(of: roundedArtwork) { UserDefaults.roundedArtwork = $0 }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .eeveeTabBarOptionsChanged)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .eeveeHomeGradientChanged)) { _ in refresh() }
    }

    private func refresh() {
        glass = UserDefaults.liquidGlassOptions
        gradient = UserDefaults.homeGradient
        tabs = UserDefaults.tabBarOptions
    }

    private var accentRow: some View {
        HStack {
            ColorPicker(selection: Binding(
                get: { Color(Theme.color(Theme.accentOrGreen(accent))) },
                set: { accent = Theme.rgb(of: UIColor($0)) }
            ), supportsOpacity: false) {
                SettingsLabel(title: "accent_color".localized, icon: "paintpalette.fill", color: Color(Theme.color(Theme.accentOrGreen(accent))))
            }
            if accent >= 0 {
                Button { accent = -1 } label: { Image(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(.secondary) }
                    .buttonStyle(.borderless)
            }
        }
    }
}
