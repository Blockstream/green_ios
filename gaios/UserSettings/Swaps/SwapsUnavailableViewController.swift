import UIKit

import core

@MainActor
final class SwapsUnavailableViewModel {
    let wm: WalletManager
    let mainWallet: Wallet

    var canRescan: Bool {
        mainWallet.hasBoltzKey
    }

    init(wm: WalletManager, mainWallet: Wallet) {
        self.wm = wm
        self.mainWallet = mainWallet
    }

    func rescan() async throws {
        try await SwapRescanService(wm: wm).rescan()
    }
}

final class SwapsUnavailableViewController: UIViewController {
    private let viewModel: SwapsUnavailableViewModel

    private let helperLabel = UILabel()
    private let rescanButton = UIButton(type: .system)
    private let learnMoreButton = UIButton(type: .system)

    init(viewModel: SwapsUnavailableViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    private func configureUI() {
        view.backgroundColor = UIColor.gBlackBg()
        view.accessibilityIdentifier = AccessibilityIds.SwapsUnavailableScreen.view

        let imageView = UIImageView(image: UIImage(named: "ic_swaps_unavailable"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Swaps Unavailable"
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.setStyle(.subTitle)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "New swaps are temporarily disabled due to a service interruption. Your funds are safe. We are working to restore functionality."
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.setStyle(.txtCard)
        subtitleLabel.textColor = UIColor.gGrayTxt()

        let messageStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        messageStack.axis = .vertical
        messageStack.alignment = .fill
        messageStack.spacing = 8

        let mainStack = UIStackView(arrangedSubviews: [imageView, messageStack])
        mainStack.axis = .vertical
        mainStack.alignment = .center
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        helperLabel.text = "Have a stuck swap?"
        helperLabel.textAlignment = .center
        helperLabel.setStyle(.txtSmaller)
        helperLabel.textColor = UIColor.gGrayTxt()

        rescanButton.setTitle("Reset Stuck Swaps", for: .normal)
        rescanButton.setStyle(.primary)
        rescanButton.addTarget(self, action: #selector(rescanSwaps), for: .touchUpInside)
        rescanButton.accessibilityIdentifier = AccessibilityIds.SwapsUnavailableScreen.btnRescan

        learnMoreButton.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
        learnMoreButton.setImage(UIImage(named: "ic_learn_more")?.withRenderingMode(.alwaysTemplate), for: .normal)
        learnMoreButton.tintColor = UIColor.gAccent()
        learnMoreButton.semanticContentAttribute = .forceRightToLeft
        learnMoreButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        learnMoreButton.addTarget(self, action: #selector(learnMore), for: .touchUpInside)

        let actionsStack = UIStackView(arrangedSubviews: [helperLabel, rescanButton, learnMoreButton])
        actionsStack.axis = .vertical
        actionsStack.alignment = .fill
        actionsStack.spacing = 12
        actionsStack.setCustomSpacing(12, after: rescanButton)
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(actionsStack)

        helperLabel.isHidden = !viewModel.canRescan
        rescanButton.isHidden = !viewModel.canRescan

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 128),
            imageView.heightAnchor.constraint(equalToConstant: 128),
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 36),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            messageStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -48),
            rescanButton.heightAnchor.constraint(equalToConstant: 56),
            learnMoreButton.heightAnchor.constraint(equalToConstant: 44),
            actionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    @objc private func rescanSwaps() {
        startLoader(message: "Processing stuck swaps...")
        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.rescan()
                stopLoader()
                DropAlert().success(message: "Swaps Processed")
                navigationController?.popViewController(animated: true)
            } catch {
                stopLoader()
                showError(error.description().localized)
            }
        }
    }

    @objc private func learnMore() {
        SafeNavigationManager.shared.navigate(ExternalUrls.swapsUnavailable)
    }
}
