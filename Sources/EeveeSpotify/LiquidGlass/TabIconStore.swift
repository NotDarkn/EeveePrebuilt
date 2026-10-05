import UIKit

enum TabIconStore {
    private static var saved = Set<String>()
    private static var loaded: [String: UIImage] = [:]
    private static var missing = Set<String>()

    private static let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EeveeSpotify/TabIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func url(_ title: String) -> URL {
        directory.appendingPathComponent(title.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? title)
            .appendingPathExtension("png")
    }

    static func save(_ image: UIImage, for title: String) {
        guard saved.insert(title).inserted else { return }
        loaded[title] = image.withRenderingMode(.alwaysTemplate)
        missing.remove(title)
        DispatchQueue.global(qos: .utility).async {
            try? image.pngData()?.write(to: url(title), options: .atomic)
        }
    }

    static func load(_ title: String) -> UIImage? {
        if let image = loaded[title] { return image }
        guard !missing.contains(title) else { return nil }
        guard let data = try? Data(contentsOf: url(title)) else {
            missing.insert(title)
            return nil
        }
        let scale = UITraitCollection.current.displayScale
        let image = UIImage(data: data, scale: scale > 0 ? scale : 2)?.withRenderingMode(.alwaysTemplate)
        loaded[title] = image
        return image
    }
}
