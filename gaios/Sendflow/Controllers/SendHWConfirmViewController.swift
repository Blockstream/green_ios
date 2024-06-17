import Foundation
import UIKit

class SendHWConfirmViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var loaderPlaceholderJ: UIView!
    @IBOutlet weak var loaderPlaceholderL: UIView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var icWallet: UIImageView!

    @IBOutlet weak var addressCard: UIView!
    @IBOutlet weak var lblAddressTitle: UILabel!
    @IBOutlet weak var addressTextView: UITextView!

    @IBOutlet weak var lblSumFeeKey: UILabel!
    @IBOutlet weak var lblSumFeeValue: UILabel!
    @IBOutlet weak var lblSumAmountKey: UILabel!
    @IBOutlet weak var lblSumAmountValue: UILabel!
    @IBOutlet weak var lblSumTotalKey: UILabel!
    @IBOutlet weak var lblSumTotalValue: UILabel!
    @IBOutlet weak var lblConversion: UILabel!
    @IBOutlet weak var recipientReceiveView: UIView!
    @IBOutlet weak var multiAddrView: UIView!
    @IBOutlet weak var lblMultiAddr: UILabel!

    private var obs: NSObjectProtocol?
    var viewModel: SendHWConfirmViewModel!
    var isDismissible = false

    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()

    let loadingIndicator: ProgressView = {
        let progress = ProgressView(colors: [UIColor.gGreenMatrix()], lineWidth: 2)
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTapToClose))
            tappableBg.addGestureRecognizer(tapToClose)

        if viewModel.isLedger {
            icWallet.image = UIImage(named: "ic_hww_ledger")
        } else {
            icWallet.image = UIImage(named: "ic_hww_jade_new")
        }

        obs = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            self.stop()
            self.start()
        }
        if viewModel.assetId != viewModel.session?.gdkNetwork.getFeeAsset() {
            [lblConversion].forEach {
                $0?.isHidden = true
            }
        }
        handle.isHidden = !isDismissible
    }

    deinit {
        print("deinit")
        if let obs = obs {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadingIndicator.isAnimating = true
        start()
        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        stop()
    }

    @objc func didTapToClose(gesture: UIGestureRecognizer) {
        if isDismissible {
            dismiss()
        }
    }

    func setContent() {
        lblTitle.text = "Confirm transaction on your device".localized
        lblAddressTitle.text = "id_address".localized

        lblSumFeeKey.text = "id_network_fee".localized
        lblSumFeeValue.text = viewModel.feeText
        lblSumAmountKey.text = "Recipient Receives"
        lblSumAmountValue.text = viewModel.amountText
        lblSumTotalKey.text = "Total Spent"
        lblSumTotalValue.text = viewModel.totalText
        lblConversion.text = "≈ \(viewModel?.totalFiatText ?? "")"
        multiAddrView.isHidden = true
        AddressDisplay.configure(address: viewModel.address ?? "",
                                 textView: addressTextView)

        if viewModel.isMultiAddressees {
            lblAddressTitle.text = "id_your_redeposit_address".localized
            recipientReceiveView.isHidden = true
            lblSumTotalValue.text = viewModel.feeText
            addressCard.isHidden = true
            multiAddrView.isHidden = false
            lblMultiAddr.text = "id_multiple_assets".localized
        }
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        addressCard.cornerRadius = 4.0
        [lblAddressTitle].forEach {
            $0?.setStyle(.sectionTitle)
        }
        [lblSumFeeKey, lblSumFeeValue, lblSumAmountKey, lblSumAmountValue, lblConversion].forEach {
            $0?.setStyle(.txtCard)
        }
        [lblSumTotalKey, lblSumTotalValue].forEach {
            $0?.setStyle(.txtBigger)
        }
    }

    func dismiss() {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                if isDismissible {
                    dismiss()
                }
            default:
                break
            }
        }
    }

    func start() {
        let lph = viewModel.isLedger ? loaderPlaceholderL : loaderPlaceholderJ
        guard let lph = lph else { return }

        lph.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor
                .constraint(equalTo: lph.centerXAnchor),
            loadingIndicator.centerYAnchor
                .constraint(equalTo: lph.centerYAnchor),
            loadingIndicator.widthAnchor
                .constraint(equalToConstant: lph.frame.width),
            loadingIndicator.heightAnchor
                .constraint(equalTo: lph.widthAnchor)
        ])

        loadingIndicator.isAnimating = true
        loadingIndicator.isHidden = false
    }

    func stop() {
        loadingIndicator.isAnimating = false
        loadingIndicator.isHidden = true
    }
}
