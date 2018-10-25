import Foundation
import UIKit
import NVActivityIndicatorView

class RequestNLockEmails : UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("id_request_nlocktime", comment: "")
        descriptionLabel.text = NSLocalizedString("id_request_will_send_nlocktimezip", comment: "")
        requestButton.setTitle(NSLocalizedString("id_request", comment: ""), for: .normal)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func requestClicked(_ sender: Any) {
        let size = CGSize(width: 30, height: 30)
        let message = NSLocalizedString("id_sending_request", comment: "")
        self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        wrap {
            try getSession().sendNlocktimes()
        }.done {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("id_request_sent", comment: ""))
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.stopAnimating()
            }
        }.catch { error in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("id_request_failed", comment: ""))
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.stopAnimating()
            }
        }
    }
}
