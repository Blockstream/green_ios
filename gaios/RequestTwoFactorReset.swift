import Foundation
import UIKit

class RequestTwoFactorReset : UIViewController, TwoFactorCallDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var disputeButton: UIButton!
    var isReset = false
    var twoFactorController: UIViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.attributedPlaceholder = NSAttributedString(string: "email@domain.com",
                                                                  attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        hideKeyboardWhenTappedAround()
        titleLabel.text = NSLocalizedString("id_request_twofactor_reset", comment: "")
        emailLabel.text = NSLocalizedString("id_enter_new_email", comment: "")
        warningLabel.text = NSLocalizedString("id_warning_resetting_twofactor", comment: "")
        requestButton.setTitle(NSLocalizedString("id_request", comment: ""), for: .normal)
        NotificationCenter.default.addObserver(self, selector: #selector(self.resetChanged(_:)), name: NSNotification.Name(rawValue: "twoFactorReset"), object: nil)
    }

    func updateUI() {
        let data = AccountStore.shared.getTwoFactorResetData()
        if (data.isReset) {
            isReset = true
            disputeButton.isHidden = false
            warningLabel.text = NSLocalizedString("id_two_factor_reset_is_in_progress", comment: "")
            disputeButton.setTitle(NSLocalizedString("id_dispute_twofactor_reset", comment: ""), for: .normal)
            requestButton.setTitle(NSLocalizedString("id_cancel_twofactor_reset", comment: ""), for: .normal)
            emailLabel.isHidden = true
            emailTextField.isHidden = true
        } else {
            isReset = false
            disputeButton.isHidden = true
            requestButton.setTitle(NSLocalizedString("id_request", comment: ""), for: .normal)
        }
    }

    @objc func resetChanged(_ notification: NSNotification) {
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func disputeButtonClicekd(_ sender: Any) {
        self.performSegue(withIdentifier: "disputeRequest", sender: nil)
    }

    @IBAction func requestClicked(_ sender: Any) {
        if (isReset) {
            DispatchQueue.global(qos: .background).async {
                wrap {
                     try getSession().cancelTwoFactorReset()
                    }.done { (result: TwoFactorCall?) in
                        do {
                            let resultHelper = TwoFactorCallHelper(result!)
                            resultHelper.delegate = self
                            try resultHelper.resolve()
                        } catch {
                            print(error)
                        }
                    } .catch { error in
                        print(error)
                }
            }
        } else {
            if let email = emailTextField.text {
                DispatchQueue.global(qos: .background).async {
                    wrap {
                        try getSession().resetTwoFactor(email: email, isDispute: false)
                        }.done { (result: TwoFactorCall?) in
                            do {
                                let resultHelper = TwoFactorCallHelper(result!)
                                resultHelper.delegate = self
                                try resultHelper.resolve()
                            } catch {
                                print(error)
                            }
                        } .catch { error in
                            print(error)
                    }
                }
            }
        }
    }

    func onResolve(_ sender: TwoFactorCallHelper) {
        let alert = TwoFactorCallHelper.CodePopup(sender)
        presetTwoFactorController(c: alert)
    }

    func onRequest(_ sender: TwoFactorCallHelper) {
        let selector = TwoFactorCallHelper.MethodPopup(sender)
        presetTwoFactorController(c: selector)
    }

    func presetTwoFactorController(c: UIViewController) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: {
                self.twoFactorController = c
                self.present(c, animated: true, completion: nil)
            })
        } else {
            twoFactorController = c
            self.present(c, animated: true, completion: nil)
        }
    }

    func onDone(_ sender: TwoFactorCallHelper) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.1) {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    func onError(_ sender: TwoFactorCallHelper, text: String) {
        if (twoFactorController != nil) {
            twoFactorController?.dismiss(animated: false, completion: nil)
        }
    }
}
