import Foundation
import UIKit

import gdk
import hw

protocol UpdateFirmwareViewControllerDelegate: AnyObject {
    func didUpdate(version: String, firmware: Firmware)
    func didSkip()
}

class UpdateFirmwareViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnUpdate: UIButton!
    @IBOutlet weak var btnSkip: UIButton!
    @IBOutlet weak var animateView: UIView!

    weak var delegate: UpdateFirmwareViewControllerDelegate?
    var version: String!
    var firmware: Firmware!
    var needCableUpdate: Bool { version < "0.1.28" }
    var isRequired: Bool { version < Jade.MIN_ALLOWED_FW_VERSION }
    let rvm = RiveModel.animationTwoArrows

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
        let riveView = rvm.createRiveView()
        animateView.addSubview(riveView)
        riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
    }

    func setContent() {
        lblTitle.text = "id_new_jade_firmware_available".localized
        lblHint.text = "Current firmware: \(version ?? "")\nLatest firmware: \(firmware.version)"
        btnUpdate.setTitle("id_update".localized, for: .normal)
        btnSkip.setTitle("id_skip".localized, for: .normal)
        if needCableUpdate {
            lblHint.text = "id_connect_jade_with_a_usb_cable".localized
        }
        if isRequired {
            lblTitle.text = "id_new_jade_firmware_required".localized
        }
    }

    func setStyle() {
        cardView.setStyle(.alert)
        lblTitle.font = UIFont.systemFont(ofSize: 24.0, weight: .bold)
        lblHint.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        lblTitle.textColor = .white
        lblHint.textColor = .white.withAlphaComponent(0.6)
        btnUpdate.setStyle(.primary)
        btnUpdate.isHidden = needCableUpdate
        btnSkip.setStyle(.inline)
        btnSkip.setTitleColor(.white, for: .normal)
        btnSkip.isHidden = isRequired
    }

    func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    @IBAction func btnUpdate(_ sender: Any) {
        dismiss {
            self.delegate?.didUpdate(version: self.version, firmware: self.firmware)
        }
    }

    @IBAction func btnSkip(_ sender: Any) {
        dismiss {
            self.delegate?.didSkip()
        }
    }
}
