import Foundation
import UIKit
import NVActivityIndicatorView

class VerifyTwoFactorViewController: UIViewController, NVActivityIndicatorViewable {


    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var label0: UILabel!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    @IBOutlet weak var label5: UILabel!
    @IBOutlet weak var backButton: UIButton!

    var twoFactor: TwoFactorCall? = nil
    var onboarding = false
    var pinCode: String = ""

    var views: Array<UIView> = Array<UIView>()
    var labels: Array<UILabel> = Array<UILabel>()
    var indicator: UIView? = nil
    var hideButton = false
    var popToRoot = true

    override func viewDidLoad() {
        super.viewDidLoad()
        labels.append(contentsOf: [label0, label1, label2, label3, label4, label5])
        for label in labels {
            label.isHidden = true
        }
        backButton.isHidden = hideButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setTitle()
    }

    func setTitle() {
        do{
            if let json = try twoFactor?.getStatus() {
                let method = json["method"] as! String
                if (method == "sms") {
                    topLabel.text = NSLocalizedString(TitleText.sms.rawValue, comment: "")
                } else if (method == "phone") {
                    topLabel.text = NSLocalizedString(TitleText.phone.rawValue, comment: "")
                } else if (method == "gauth") {
                    topLabel.text = NSLocalizedString(TitleText.gauth.rawValue, comment: "")
                } else if (method == "email") {
                    topLabel.text = NSLocalizedString(TitleText.email.rawValue, comment: "")
                }
            }
        } catch {
            print("couldn't get status")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateView()
    }

    @IBAction func numberClicked(_ sender: UIButton) {
        pinCode += (sender.titleLabel?.text)!
        updateView()
        if (pinCode.count == 6) {
            do {
                let json = try twoFactor?.getStatus()
                let status = json!["status"] as!  String
                if(status == "resolve_code") {
                    try twoFactor?.resolveCode(code: pinCode)
                    let resolve_json = try twoFactor?.getStatus()
                    let resolve_status = resolve_json!["status"] as! String
                    if(resolve_status == "call") {
                        try twoFactor?.call()
                        let call_json = try twoFactor?.getStatus()
                        let call_status = call_json!["status"] as! String
                        if (call_status == "done") {
                            //show hud success
                            if(onboarding) {
                                self.performSegue(withIdentifier: "mainMenu", sender: nil)
                            } else {
                                let action = call_json!["action"] as! String
                                if(action == "send_raw_tx") {
                                    self.startAnimating(CGSize(width: 30, height: 30), message: "Transaction Sent", messageFont: nil, type: NVActivityIndicatorType.blank)
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.1) {
                                        self.stopAnimating()
                                        self.pop()
                                    }
                                } else if (action == "cancel_reset" || action == "request_reset") {
                                    getAppDelegate().lock()
                                } else {
                                    pop()
                                }
                            }
                        } else if (call_status == "resolve_code") {
                            pinCode = ""
                            updateView()
                            setTitle()
                            //now confirm your new 2fa
                        } else {
                            print("wrong pin")
                            //show hud failure
                            self.navigationController?.popViewController(animated: true)
                            return
                        }
                        print(call_status)
                        print("hello2")
                    } else {
                        print("do not call ?")
                    }
                    //if success show success and go back to root view controller
                    //if fail show fail and go back to root view controller
                }
            } catch {

            }
        }
    }

    func updateView() {
        var index = 0
        for char in pinCode {
            labels[index].text = String(char)
            labels[index].isHidden = false
            index += 1
        }
        createIndicator(position: pinCode.count)
        for i in index..<labels.count {
            labels[i].isHidden = true
        }
    }

    func createIndicator(position: Int) {
        if (position >= 6) {
            indicator?.isHidden = true
            return
        }
        indicator?.layer.removeAllAnimations()
        indicator?.removeFromSuperview()
        let labelP = labels[position]
        indicator = UIView()
        indicator?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        indicator?.backgroundColor = UIColor.customMatrixGreen()
        indicator?.translatesAutoresizingMaskIntoConstraints = false
        indicator?.alpha = 1.0;
        self.view.addSubview(indicator!)
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 0, constant: 2).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 0, constant: 21).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: labelP, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: labelP, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: {

            self.indicator?.alpha = 0.0

        }, completion: nil)
    }

    @IBAction func deleteClicked(_ sender: UIButton) {
        if(pinCode.count > 0) {
            pinCode.removeLast()
            updateView()
            print(pinCode)
        }
    }

    func pop() {
        if(popToRoot) {
            self.navigationController?.popToRootViewController(animated: true)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}

public enum TitleText: String {
    case email = "id_enter_code_sent_to_your_email"
    case sms = "id_enter_code_received_via_sms"
    case phone = "id_enter_code_received_via_phone"
    case gauth = "id_enter_your_google_authenticator"
}
