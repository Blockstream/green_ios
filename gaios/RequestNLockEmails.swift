import Foundation
import UIKit
import NVActivityIndicatorView

class RequestNLockEmails : UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = NSLocalizedString("prequest_nlocktime", comment: "")
        descriptionLabel.text = NSLocalizedString("prequest_will_send_nlocktimezip", comment: "")
        requestButton.setTitle(NSLocalizedString("prequest", comment: ""), for: .normal)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func requestClicked(_ sender: Any) {
        let size = CGSize(width: 30, height: 30)
        let message = NSLocalizedString("psending_request", comment: "")
        self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        wrap {
            try getSession().sendNlocktimes()
        }.done {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("prequest_sent", comment: ""))
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.stopAnimating()
            }
        }.catch { error in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                NVActivityIndicatorPresenter.sharedInstance.setMessage(NSLocalizedString("prequest_failed", comment: ""))
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.stopAnimating()
            }
        }
    }
}
