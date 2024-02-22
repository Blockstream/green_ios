import Foundation
import UIKit

protocol BleUnavailableViewControllerDelegate: AnyObject {
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
        switch state {
        case .powerOff:
            lblTitle.text = "Enable Bluetooth".localized
            lblHint.text = "Text adding details of the current page".localized
            btnCancel.setTitle("Cancel", for: .normal)
            btnSettings.setTitle("iOS Settings", for: .normal)
        case .unauthorized:
            lblTitle.text = "Grant Green Bluetooth permission".localized
            lblHint.text = "Text adding details of the current page".localized
            btnCancel.setTitle("Cancel".localized, for: .normal)
            btnSettings.setTitle("Open Permissions".localized, for: .normal)
        case .other:
            lblTitle.text = "Enable Bluetooth from iOS settings to continue".localized
            lblHint.text = "Text adding details of the current page".localized
            btnCancel.setTitle("Cancel".localized, for: .normal)
            btnSettings.isHidden = true
        }
    }

    func setStyle() {
        cardView.layer.cornerRadius = 10
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnCancel.setStyle(.outlinedWhite)
        btnSettings.setStyle(.primary)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
//                self.delegate?.onDone()
            })
        })
    }

    @IBAction func btnCancel(_ sender: Any) {
        dismiss()
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
        dismiss()
    }
}
