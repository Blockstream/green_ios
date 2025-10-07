import Foundation
import UIKit

protocol SendFeeInfoViewControllerDelegate: AnyObject {
    func didTapMore()
}

enum SendFeeInfoAction {
    case more
    case cancel
}

enum SendFeeScope {
    case info
    case lwkSwap(swap: String, chain: String, total: String, fiat: String)
}

class SendFeeInfoViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnFeeInfo: UIButton!

    @IBOutlet weak var lwkPanel: UIView!
    @IBOutlet weak var lblSwapFeeTitle: UILabel!
    @IBOutlet weak var lblSwapFeeValue: UILabel!
    @IBOutlet weak var lblSwapFeeHint: UILabel!
    @IBOutlet weak var lblChainFeeTitle: UILabel!
    @IBOutlet weak var lblChainFeeValue: UILabel!
    @IBOutlet weak var lblChainFeeHint: UILabel!
    @IBOutlet weak var lblTotalTitle: UILabel!
    @IBOutlet weak var lblTotalValue1: UILabel!
    @IBOutlet weak var lblTotalValue2: UILabel!

    weak var delegate: SendFeeInfoViewControllerDelegate?
    var scope: SendFeeScope = .info

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
    }

    deinit {
        print("deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    @objc func didTapToClose(gesture: UIGestureRecognizer) {
        dismiss(.cancel)
    }

    func setContent() {
        switch scope {
        case .info:
            lblTitle.text = "id_network_fee".localized
            lblHint.text = "id_fees_are_not_collected_by".localized
            lwkPanel.isHidden = true
        case .lwkSwap(let swap, let chain, let total, let fiat):
            lblTitle.text = "Total Fees".localized
            lblHint.text = "Fees are not collected by Blockstream, but by Bitcoin miners, Liquid functionaries, and Lightning nodes that process your transaction.".localized
            lwkPanel.isHidden = false
            lblSwapFeeTitle.text = "Network fee and Swap fee".localized
            lblSwapFeeValue.text = swap
            lblSwapFeeHint.text = "Includes service and Lightning routing.".localized
            lblChainFeeTitle.text = "Liquid on-chain".localized
            lblChainFeeValue.text = chain
            lblChainFeeHint.text = "Miner fee to send LBTC on Liquid.".localized
            lblTotalTitle.text = "Total".localized
            lblTotalValue1.text = total
            lblTotalValue2.text = fiat
        }
        btnFeeInfo.setStyle(.underline(txt: "id_read_more".localized, color: .gAccent()))
        btnFeeInfo.setImage(UIImage(named: "ic_squared_out_small")?.maskWithColor(color: .gAccent()), for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        [lblSwapFeeTitle, lblChainFeeTitle].forEach { $0?.setStyle(.txt) }
        [lblSwapFeeHint, lblChainFeeHint, lblSwapFeeValue, lblChainFeeValue].forEach { $0?.setStyle(.txtCard) }
        lblTotalTitle.setStyle(.txtBigger)
        lblTotalValue1.setStyle(.txtBigger)
        lblTotalValue2.setStyle(.txtCard)
        lblHint.setStyle(.txtCard)
    }

    func dismiss(_ action: SendFeeInfoAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            switch action {
            case .more:
                self?.delegate?.didTapMore()
            case .cancel:
                break
            }
            self?.dismiss(animated: false, completion: nil)
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(.cancel)
            default:
                break
            }
        }
    }

    @IBAction func btnFeeInfo(_ sender: Any) {
        dismiss(.more)
    }
}
