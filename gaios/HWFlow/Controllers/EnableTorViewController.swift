import Foundation
import UIKit
import core

enum EnableTorAction {
    case connect
    case close
}

class EnableTorViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var alertView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var btnClose: UIButton!

    var domains: [String] = []

    var onConnect: (() -> Void)?
    var onClose: (() -> Void)?

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
        lblTitle.text = "Do you want to enable Tor to connect to the PIN oracle server?".localized
        btnConnect.setTitle("Enable Tor".localized, for: .normal)
        btnClose.setTitle("Cancel".localized, for: .normal)
    }

    func setStyle() {
        alertView.layer.cornerRadius = 5
        alertView.backgroundColor = UIColor.gGrayCard()
        alertView.borderWidth = 1.0
        alertView.borderColor = .white.withAlphaComponent(0.1)
        [lblTitle].forEach {
            $0?.setStyle(.subTitle)
        }
        btnConnect.setStyle(.primary)
        btnClose.setStyle(.outlined)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func dismiss(_ action: EnableTorAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                switch action {
                case .connect:
                    self.onConnect?()
                case .close:
                    self.onClose?()
                }
            })
        })
    }

    @IBAction func btnConnect(_ sender: Any) {
        GdkSettings.enableTor()
        dismiss(.connect)
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(.close)
    }
}
