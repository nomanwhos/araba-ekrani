import UIKit

/// The car display: the mirrored phone screen when a broadcast is live,
/// otherwise a dark marquee telling the passenger what to do on the phone.
final class CarScreenViewController: UIViewController {
    private let frameLayer = CALayer()
    private let idleView = CarIdleView()
    private var fillObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "Night")
        frameLayer.backgroundColor = UIColor.black.cgColor
        frameLayer.isHidden = true
        view.layer.addSublayer(frameLayer)

        idleView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(idleView)
        NSLayoutConstraint.activate([
            idleView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            idleView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            idleView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            idleView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
        ])

        applyGravity()
        fillObserver = NotificationCenter.default.addObserver(
            forName: MirrorState.fillDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyGravity() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frameLayer.frame = view.bounds
        CATransaction.commit()
    }

    /// nil means the broadcast ended.
    func show(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frameLayer.contents = image
        frameLayer.isHidden = image == nil
        CATransaction.commit()
        idleView.isHidden = image != nil
    }

    private func applyGravity() {
        frameLayer.contentsGravity = MirrorState.shared.fillsCarScreen ? .resizeAspectFill : .resizeAspect
        frameLayer.masksToBounds = true
    }

    deinit {
        if let fillObserver {
            NotificationCenter.default.removeObserver(fillObserver)
        }
    }
}

/// Bulb row, the name in marquee letters, and one instruction.
private final class CarIdleView: UIView {
    private static let bulbCount = 9

    override init(frame: CGRect) {
        super.init(frame: frame)
        let marquee = UIColor(named: "AccentColor") ?? .systemOrange

        let bulbs = UIStackView(arrangedSubviews: (0..<Self.bulbCount).map { _ in
            let bulb = UIView()
            bulb.backgroundColor = marquee
            bulb.layer.cornerRadius = 4
            bulb.layer.shadowColor = marquee.cgColor
            bulb.layer.shadowOpacity = 0.8
            bulb.layer.shadowRadius = 6
            bulb.layer.shadowOffset = CGSize(width: 0, height: 1)
            bulb.widthAnchor.constraint(equalToConstant: 8).isActive = true
            bulb.heightAnchor.constraint(equalToConstant: 8).isActive = true
            return bulb
        })
        bulbs.spacing = 14

        let title = UILabel()
        title.text = "TORPİDO"
        title.textColor = marquee
        title.font = UIFont.systemFont(ofSize: 34, weight: .black, width: .expanded)

        let hint = UILabel()
        hint.text = "Telefonda Torpido'yu açın ve Yansıtmayı Başlat'a dokunun."
        hint.textColor = UIColor(white: 1, alpha: 0.78)
        hint.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        hint.numberOfLines = 0
        hint.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [bulbs, title, hint])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.setCustomSpacing(24, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}
