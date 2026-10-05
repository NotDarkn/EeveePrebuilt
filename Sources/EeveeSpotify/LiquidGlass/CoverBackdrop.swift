import UIKit

// Blurred cover behind a page: the cover shrunk until no shape survives, blurred, under a scrim that ends near black.
final class CoverBackdrop: UIView {
    private let imageView = UIImageView()
    private let tracker = CoverTracker()
    private weak var source: UIImage?

    func track(_ cover: UIImageView?) {
        tracker.track(cover) { [weak self] in self?.show($0) }
    }

    init(bottomAlpha: CGFloat = 0.94) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        imageView.contentMode = .scaleAspectFill
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)

        let scrim = GradientView()
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrim.gradient.colors = [0.35, 0.6, bottomAlpha].map { UIColor(white: 0, alpha: $0).cgColor }
        scrim.gradient.locations = [0, 0.5, 1]
        addSubview(scrim)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.forEach { $0.frame = bounds }
    }

    func show(_ cover: UIImage?) {
        guard let cover, cover !== source else { return }
        source = cover
        let sample = Self.downsample(cover)
        UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve) { self.imageView.image = sample }
    }

    private static func downsample(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: 48, height: 48)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradient: CAGradientLayer { layer as! CAGradientLayer }
}

// The cover itself across the top of a page, fading into black.
final class HeroCover: UIView {
    private let imageView = UIImageView()
    private let fade = CAGradientLayer()
    private let tracker = CoverTracker()
    private weak var source: UIImage?

    func track(_ cover: UIImageView?) {
        tracker.track(cover) { [weak self] in self?.show($0) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        backgroundColor = .black
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        fade.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        fade.locations = [0, 0.6, 1]
        imageView.layer.mask = fade
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.width
        imageView.frame = CGRect(x: 0, y: 0, width: side, height: min(side * 1.1, bounds.height))
        fade.frame = imageView.bounds
    }

    func show(_ cover: UIImage?) {
        guard let cover, cover !== source else { return }
        source = cover
        UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve) { self.imageView.image = cover }
    }
}

private final class CoverTracker {
    private weak var tracked: UIImageView?
    private var observation: NSKeyValueObservation?

    func track(_ cover: UIImageView?, _ show: @escaping (UIImage?) -> Void) {
        guard let cover, cover !== tracked else { return }
        tracked = cover
        observation = cover.observe(\.image, options: [.initial, .new]) { view, _ in
            DispatchQueue.main.async { show(view.image) }
        }
    }
}
