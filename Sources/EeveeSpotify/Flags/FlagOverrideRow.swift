import SwiftUI

struct FlagOverrideRow: View {
    let title: String
    let key: String
    let onChange: () -> Void
    @State private var value: Bool?

    init(title: String, key: String, onChange: @escaping () -> Void = {}) {
        self.title = title
        self.key = key
        self.onChange = onChange
        _value = State(initialValue: (RemoteFlags.overrides[key] as? NSNumber)?.boolValue)
    }

    var body: some View {
        if let forced = RemoteFlags.shared.forced[key] {
            HStack {
                Text(title).foregroundColor(.primary)
                Spacer()
                Label((forced as? NSNumber)?.boolValue == true ? "flags_on".localized : "flags_off".localized, systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } else {
            menu
        }
    }

    private var menu: some View {
        Menu {
            Button("flags_auto".localized) { set(nil) }
            Button("flags_on".localized) { set(true) }
            Button("flags_off".localized) { set(false) }
        } label: {
            HStack {
                Text(title).foregroundColor(.primary)
                Spacer()
                Text((value.map { $0 ? "flags_on" : "flags_off" } ?? "flags_auto").localized)
                    .foregroundColor(value == nil ? .secondary : EeveeTheme.accent)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    private func set(_ newValue: Bool?) {
        value = newValue
        var overrides = RemoteFlags.overrides
        overrides[key] = newValue
        RemoteFlags.overrides = overrides
        onChange()
    }
}

enum FlagOverrides {
    static func areDefault(_ keys: [String]) -> Bool {
        let overrides = RemoteFlags.overrides
        return keys.allSatisfy { overrides[$0] == nil }
    }

    static func clear(_ keys: [String]) {
        var overrides = RemoteFlags.overrides
        keys.forEach { overrides[$0] = nil }
        RemoteFlags.overrides = overrides
    }
}
