import SwiftUI

struct LiquidGlassSettingsView: View {
    @State private var glass = UserDefaults.liquidGlassOptions

    static let supported: Bool = {
        if #available(iOS 26.0, *) { return true }
        return false
    }()

    private var surfacesDefault: Bool {
        glass.spotifyGlass && glass.tabBar && glass.nowPlayingBar && glass.search != false && glass.home != false && glass.playlist != false && glass.lyricsView != false
    }

    var body: some View {
        List {
            Section(footer: Text((Self.supported ? "liquid_glass_footer" : "liquid_glass_unsupported").localized)) {
                SettingsToggle(title: "liquid_glass".localized, icon: "drop.fill", color: Color(hex: "#30B0C7"), isOn: $glass.enabled)
                    .disabled(!Self.supported)
            }

            if glass.enabled && Self.supported {
                Section(header: Text("glass_surfaces".localized)) {
                    SettingsToggle(title: "glass_spotify".localized, icon: "menubar.rectangle", color: Color(hex: "#5E5CE6"), isOn: $glass.spotifyGlass)
                    SettingsToggle(title: "glass_tab_bar".localized, icon: "dock.rectangle", color: .blue, isOn: $glass.tabBar)
                    SettingsToggle(title: "glass_now_playing_bar".localized, icon: "play.rectangle.fill", color: EeveeTheme.accent, isOn: $glass.nowPlayingBar)
                    SettingsToggle(title: "glass_search".localized, icon: "magnifyingglass", color: .orange, isOn: optIn(\.search))
                    SettingsToggle(title: "glass_home".localized, icon: "house.fill", color: .purple, isOn: optIn(\.home))
                    SettingsToggle(title: "glass_playlist".localized, icon: "music.note.list", color: .pink, isOn: optIn(\.playlist))
                    SettingsToggle(title: "glass_lyrics_view".localized, icon: "quote.bubble.fill", color: Color(hex: "#30B0C7"), isOn: optIn(\.lyricsView))
                }

                if glass.tabBar {
                    Section {
                        SettingsLink(title: "tab_bar".localized, subtitle: "tab_bar_subtitle".localized, icon: "dock.rectangle", color: .blue) {
                            TabBarSettingsView()
                        }
                    }
                }

                SettingsResetSection(visible: !surfacesDefault) {
                    glass.spotifyGlass = true
                    glass.tabBar = true
                    glass.nowPlayingBar = true
                    glass.search = nil
                    glass.home = nil
                    glass.playlist = nil
                    glass.lyricsView = nil
                }
            }

            if glass != LiquidGlass.launchOptions {
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
        .animation(.default, value: glass)
        .onChange(of: glass) { options in
            UserDefaults.liquidGlassOptions = options
            if !options.enabled { LiquidGlass.clearDefaults() }
        }
    }

    private func optIn(_ key: WritableKeyPath<LiquidGlassOptions, Bool?>) -> Binding<Bool> {
        Binding(get: { glass[keyPath: key] != false }, set: { glass[keyPath: key] = $0 })
    }
}
