import SwiftUI

struct BackgroundColorView: View {
    @State private var gradient = UserDefaults.homeGradient

    private static let pages: [(GradientPage, String, Color)] = [
        (.home, "house.fill", .blue),
        (.library, "books.vertical.fill", .purple),
        (.search, "magnifyingglass", .orange),
    ]
    private static let strengths = ["home_gradient_subtle", "home_gradient_medium", "home_gradient_bold"]
    private static let heights = ["home_gradient_short", "home_gradient_medium", "home_gradient_tall", "home_gradient_full"]
    private static let styles = ["home_gradient_style_gradient", "home_gradient_style_solid"]
    private static let fades = ["home_gradient_fade_top", "home_gradient_fade_mid", "home_gradient_fade_low"]

    var body: some View {
        List {
            Section {
                BackgroundColorPreview(options: gradient)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                SettingsToggle(
                    title: "background_color".localized, icon: "circle.lefthalf.fill",
                    color: Color(gradient.tintRGB.map(Theme.color) ?? Theme.accent), isOn: $gradient.enabled
                )
            }

            if gradient.enabled {
                Section(header: Text("home_gradient_pages".localized), footer: Text("restart_is_required_description".localized)) {
                    ForEach(Self.pages, id: \.0) { page, icon, color in
                        SettingsToggle(title: "home_gradient_page_\(page.rawValue)".localized, icon: icon, color: color, isOn: Binding(
                            get: { gradient.shownPages.contains(page) },
                            set: { if $0 { gradient.shownPages.insert(page) } else { gradient.shownPages.remove(page) } }
                        ))
                    }
                }

                Section(header: Text("glass_style".localized), footer: Text("home_gradient_footer".localized)) {
                    swatches
                    segments("home_gradient_style", Self.styles, selection: Binding(
                        get: { gradient.solidFill == true ? 1 : 0 }, set: { gradient.solidFill = $0 == 1 ? true : nil }
                    ))
                    segments("home_gradient_strength", Self.strengths, selection: $gradient.strength)
                    if gradient.solidFill != true {
                        segments("home_gradient_height", Self.heights, selection: $gradient.height)
                        segments("home_gradient_fade", Self.fades, selection: Binding(get: { gradient.fade ?? 0 }, set: { gradient.fade = $0 == 0 ? nil : $0 }))
                    }
                }
            }

            SettingsResetSection(visible: gradient != HomeGradientOptions()) {
                gradient = HomeGradientOptions()
            }

            RestartSection(visible: gradient.shownPages != HomeGradient.launchPages)

            SpacerView()
        }
        .eeveeSettingsStyle()
        .animation(.default, value: gradient)
        .onChange(of: gradient) { options in
            UserDefaults.homeGradient = options
            NotificationCenter.default.post(name: .eeveeHomeGradientChanged, object: nil)
        }
    }

    private func segments(_ title: String, _ keys: [String], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.localized).font(.subheadline).foregroundColor(.secondary)
            Picker(title.localized, selection: selection) {
                ForEach(keys.indices, id: \.self) { Text(keys[$0].localized).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.vertical, 4)
    }

    private var swatches: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button { gradient.followAlbum = true } label: {
                    Circle()
                        .fill(AngularGradient(colors: [.pink, .orange, .yellow, .green, .blue, .purple, .pink], center: .center))
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.primary, lineWidth: gradient.followAlbum == true ? 2.5 : 0))
                        .overlay(Image(systemName: "music.note").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                }
                .buttonStyle(.borderless)
                ForEach(HomeGradientOptions.tints.indices, id: \.self) { index in
                    let tint = HomeGradientOptions.tints[index]
                    Button {
                        gradient.tintRGB = tint
                        gradient.followAlbum = nil
                    } label: {
                        Circle()
                            .fill(Color(tint.map(Theme.color) ?? Theme.accent))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.primary, lineWidth: gradient.followAlbum != true && gradient.tintRGB == tint ? 2.5 : 0))
                            .overlay(tint == nil ? Image(systemName: "paintpalette.fill").font(.system(size: 12)).foregroundColor(.white) : nil)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct BackgroundColorPreview: View {
    let options: HomeGradientOptions
    private let base = UserDefaults.amoled ? Color.black : Color(hex: "#121212")
    private let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                base
                if options.enabled { wash(scale: proxy.size.height / screenHeight) }
                screen
            }
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.vertical, 8)
    }

    private func wash(scale: CGFloat) -> some View {
        let fill = options.solidFill == true
        let span = fill ? screenHeight : options.span > 0 ? options.span : screenHeight
        let tint = Color(options.color)
        return LinearGradient(gradient: Gradient(stops: [
            .init(color: tint, location: 0),
            .init(color: tint, location: fill ? 1 : options.solid(of: span) / span),
            .init(color: tint.opacity(fill ? 1 : 0), location: 1),
        ]), startPoint: .top, endPoint: .bottom)
        .frame(height: span * scale)
    }

    private var screen: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("9:41")
                Spacer()
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 9, weight: .semibold))

            HStack(spacing: 5) {
                Circle().fill(Color.white.opacity(0.3)).frame(width: 14, height: 14)
                ForEach(0..<3) { index in
                    Capsule().fill(Color.white.opacity(index == 0 ? 0.85 : 0.14)).frame(width: 34, height: 14)
                }
                Spacer()
                if options.enabled && options.followAlbum == true {
                    Text("♪")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
            }

            ForEach(0..<2) { _ in
                HStack(spacing: 6) {
                    ForEach(0..<2) { _ in
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.1)).frame(height: 20)
                    }
                }
            }

            ForEach(0..<3) { _ in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.14)).frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(Color.white.opacity(0.5)).frame(width: 90, height: 5)
                        Capsule().fill(Color.white.opacity(0.22)).frame(width: 60, height: 5)
                    }
                }
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
