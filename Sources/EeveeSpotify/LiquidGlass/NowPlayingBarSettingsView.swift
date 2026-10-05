import SwiftUI

struct NowPlayingBarSettingsView: View {
    @State private var options = UserDefaults.nowPlayingBarOptions
    @State private var flagsVersion = 0
    @State private var flagsDefault = FlagOverrides.areDefault(NowPlayingBarSettingsView.flags.map(\.1))
    private let launchHideConnect = UserDefaults.nowPlayingBarOptions.hideConnect

    private static let flags: [(String, String)] = [
        ("npb_flag_two_lines", "ios-feature-nowplayingbar.two_lines_information_unit"),
        ("npb_flag_add_button", "ios-feature-nowplayingbar.add_button"),
        ("npb_flag_queue_badge", "ios-feature-nowplayingbar.queue_badge"),
        ("npb_flag_resize", "ios-feature-nowplayingbar.hold_and_drag_to_resize"),
        ("npb_flag_video", "ios-feature-nowplaying.video_in_miniplayer"),
        ("npb_flag_cover_morph", "ios-feature-nowplaying.bartocoverart_animation_enabled"),
        ("npb_flag_transitions", "ios-feature-nowplaying.miniplayer_transition_animations"),
    ]

    var body: some View {
        List {
            Section(header: Text("glass_style".localized)) {
                SettingsToggle(title: "npb_album_tint".localized, icon: "paintbrush.fill", color: .pink, isOn: $options.albumTint)
                SettingsToggle(title: "npb_round_artwork".localized, icon: "circle.fill", color: .orange, isOn: $options.roundArtwork)
            }

            Section(footer: Text("restart_is_required_description".localized)) {
                SettingsToggle(title: "npb_hide_connect".localized, icon: "hifispeaker.fill", color: .gray, isOn: $options.hideConnect)
            }

            Section(header: Text("spotify_flags".localized), footer: Text("restart_is_required_description".localized)) {
                ForEach(Self.flags, id: \.1) { FlagOverrideRow(title: $0.0.localized, key: $0.1) { flagsVersion += 1 } }
            }
            .id(flagsVersion)

            SettingsResetSection(visible: options != NowPlayingBarOptions() || !flagsDefault) {
                options = NowPlayingBarOptions()
                FlagOverrides.clear(Self.flags.map(\.1))
                flagsVersion += 1
            }

            if options.hideConnect != launchHideConnect {
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
        .onChange(of: options) { options in
            UserDefaults.nowPlayingBarOptions = options
            NotificationCenter.default.post(name: .eeveeNowPlayingBarOptionsChanged, object: nil)
        }
        .onAppear(perform: refreshFlags)
        .onChange(of: flagsVersion) { _ in refreshFlags() }
    }

    private func refreshFlags() {
        flagsDefault = FlagOverrides.areDefault(Self.flags.map(\.1))
    }
}
