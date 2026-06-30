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
    case lwkSwap(networkFee: String, lightningSetupFee: String?, swapFee: String, total: String, fiat: String)
}

class SendFeeInfoViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnFeeInfo: UIButton!

    @IBOutlet weak var lwkPanel: UIView!
    @IBOutlet weak var lblNetworkFeeTitle: UILabel!
    @IBOutlet weak var lblNetworkFeeValue: UILabel!
    @IBOutlet weak var lblNetworkFeeHint: UILabel!
    
    @IBOutlet weak var lightningSetupFeeStack: UIStackView!
    @IBOutlet weak var lblLightningSetupFeeTitle: UILabel!
    @IBOutlet weak var lblLightningSetupFeeValue: UILabel!
    @IBOutlet weak var lblLightningSetupFeeHint: UILabel!
    
    @IBOutlet weak var lblSwapFeeTitle: UILabel!
    @IBOutlet weak var lblSwapFeeValue: UILabel!
    @IBOutlet weak var lblSwapFeeHint: UILabel!
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
            closeButton.isHidden = true
        case .lwkSwap(let networkFee, let lightningSetupFee, let swapFee, let total, let fiat):
            lblTitle.text = "Total Fees".localized
            lblHint.isHidden = true
            lwkPanel.isHidden = false
            
            lblNetworkFeeTitle.text = "Network Fee".localized
            lblNetworkFeeHint.text = "Covers transaction confirmation".localized
            lblNetworkFeeValue.text = networkFee
            
            lightningSetupFeeStack.isHidden = lightningSetupFee == nil
            lblLightningSetupFeeTitle.text = "Lightning Setup Fee".localized
            lblLightningSetupFeeHint.text = "Covers your first Lightning payment".localized
            lblLightningSetupFeeValue.text = lightningSetupFee
            
            lblSwapFeeTitle.text = "Swap Fee".localized
            lblSwapFeeHint.text = "Covers swap service".localized
            lblSwapFeeValue.text = swapFee

            lblTotalTitle.text = "Total".localized
            lblTotalValue1.text = total
            lblTotalValue2.text = fiat
        }
        btnFeeInfo.setStyle(.underline(txt: "Learn More".localized, color: .gAccent()))
        btnFeeInfo.setImage(UIImage(named: "ic_squared_out_small")?.maskWithColor(color: .gAccent()), for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblHint.setStyle(.txtCard)
        [lblNetworkFeeTitle, lblLightningSetupFeeTitle, lblSwapFeeTitle].forEach { $0?.setStyle(.txt) }
        [lblNetworkFeeHint, lblLightningSetupFeeHint, lblSwapFeeHint, lblNetworkFeeValue, lblLightningSetupFeeValue, lblSwapFeeValue].forEach { $0?.setStyle(.txtCard) }
        lblTotalTitle.setStyle(.txtBigger)
        lblTotalValue1.setStyle(.txtBigger)
        lblTotalValue2.setStyle(.txtCard)
        closeButton.tintColor = .gGrayTxt()
        closeButton.backgroundColor = .gGrayCard()
        closeButton.layer.cornerRadius = closeButton.frame.height / 2
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
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        dismiss(.cancel)
    }
}
