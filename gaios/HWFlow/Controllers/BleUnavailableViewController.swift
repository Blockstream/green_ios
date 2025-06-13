import Foundation
import UIKit

protocol BleUnavailableViewControllerDelegate: AnyObject {
    func onAction(_ action: BleUnavailableAction)
}

enum BleUnavailableAction {
    case settings
    case cancel
}

enum BleUnavailableState {
    case powerOff
    case unauthorized
    case other
}

class BleUnavailableViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnSettings: UIButton!

    weak var delegate: BleUnavailableViewControllerDelegate?

    var state: BleUnavailableState = .other

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        view.alpha = 0.0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        lblHint.text = "id_green_uses_bluetooth_for".localized
        btnCancel.setTitle("id_cancel".localized, for: .normal)
        switch state {
        case .unauthorized:
            lblTitle.text = "id_grant_green_bluetooth_permission".localized
            btnSettings.setTitle("id_open_permissions".localized, for: .normal)
        case .other, .powerOff:
            lblTitle.text = "id_enable_bluetooth_from_ios".localized
            btnSettings.isHidden = true
        }
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnCancel.setStyle(.outlinedWhite)
        btnSettings.setStyle(.primary)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: BleUnavailableAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                self.delegate?.onAction(action)
            })
        })
    }

    @IBAction func btnCancel(_ sender: Any) {
        dismiss(.cancel)
    }

    @IBAction func btnSettings(_ sender: Any) {
        switch state {
        case .powerOff:
            let url = URL(string: "App-Prefs:root=")
            if let url = url {
                UIApplication.shared.open(url)
            }
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        dismiss(.settings)
    }
}
