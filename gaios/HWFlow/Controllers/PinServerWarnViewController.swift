import Foundation
import UIKit

enum PinServerWarnAction {
    case support
    case connect
    case close
}

class PinServerWarnViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var alertView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblAlertHead: UILabel!
    @IBOutlet weak var lblAlertTitle: UILabel!
    @IBOutlet weak var lblAlertHint: UILabel!
    @IBOutlet weak var lblAdvHead: UILabel!
    @IBOutlet weak var lblAdvTitle: UILabel!
    @IBOutlet weak var btnSupport: UIButton!
    @IBOutlet weak var btnAdvanced: UIButton!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var askView: UIView!
    @IBOutlet weak var lblAskTitle: UILabel!
    @IBOutlet weak var iconAsk: UIImageView!
    @IBOutlet weak var btnAsk: UIButton!
    @IBOutlet weak var btnClose: UIButton!

    var showAdvanced = false {
        didSet {
            refresh()
        }
    }
    var domains: [String] = []
    var notAskAgain: Bool = false {
        didSet {
            iconAsk.image = notAskAgain ? UIImage(named: "ic_checkbox_on")! : UIImage(named: "ic_checkbox_off")!
        }
    }

    var onSupport: (() -> Void)?
    var onConnect: ((Bool) -> Void)?
    var onClose: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        view.alpha = 0.0
        showAdvanced = false
        notAskAgain = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        lblAlertHead.text = "id_warning".localized
        lblAlertTitle.text = "id_connection_blocked".localized

        lblAdvHead.text = "Connection attempt to:\n".localized + domains.joined(separator: ", ")
        lblAdvTitle.text = "id_this_is_not_the_default_blind".localized
        btnSupport.setTitle("id_contact_support".localized, for: .normal)
        btnAdvanced.setTitle("id_advanced".localized, for: .normal)
        btnConnect.setTitle("id_allow_nondefault_connection".localized, for: .normal)
        lblAskTitle.text = "id_dont_ask_me_again_for_this".localized
        btnClose.setImage(UIImage(named: "cancel")?.maskWithColor(color: .white), for: .normal)
    }

    func setStyle() {
        alertView.layer.cornerRadius = 5
        alertView.backgroundColor = UIColor.gRedWarn()
        alertView.borderWidth = 1.0
        alertView.borderColor = .white.withAlphaComponent(0.3)
        [lblAlertHead, lblAlertTitle].forEach {
            $0?.setStyle(.subTitle)
        }
        [lblAdvHead, lblAdvTitle].forEach {
            $0?.setStyle(.txtBigger)
        }
        [lblAlertHint].forEach {
            $0?.setStyle(.txt)
            $0?.alpha = 0.6
        }
        btnSupport.setStyle(.warnWhite)
        btnAdvanced.setStyle(.warnRed)
        btnConnect.setStyle(.outlinedWhite)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func refresh() {

        lblAlertTitle.isHidden = showAdvanced
        lblAdvHead.isHidden = !showAdvanced
        lblAdvTitle.isHidden = !showAdvanced
        btnAdvanced.isHidden = showAdvanced
        btnConnect.isHidden = !showAdvanced
        askView.isHidden = !showAdvanced

        if showAdvanced {
            lblAlertHint.text = "id_if_you_did_not_change_your".localized
        } else {
            lblAlertHint.text = "id_jade_is_trying_to_connect_to_a".localized
        }
    }

    func dismiss(_ action: PinServerWarnAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                switch action {
                case .connect:
                    self.onConnect?(self.notAskAgain)
                case .support:
                    self.onSupport?()
                case .close:
                    self.onClose?()
                }
            })
        })
    }

    @IBAction func btnSupport(_ sender: Any) {
        dismiss(.support)
    }

    @IBAction func btnAdvanced(_ sender: Any) {
        showAdvanced = true
    }

    @IBAction func btnConnect(_ sender: Any) {
        dismiss(.connect)
    }

    @IBAction func btnAsk(_ sender: Any) {
        notAskAgain.toggle()
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(.close)
    }
}
