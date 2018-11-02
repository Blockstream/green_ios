import Foundation
import UIKit
import NVActivityIndicatorView

class VerifyTwoFactorViewController: UIViewController, NVActivityIndicatorViewable {

    var factorHelper: TwoFactorCallHelper? = nil
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var label0: UILabel!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    @IBOutlet weak var label5: UILabel!
    @IBOutlet weak var backButton: UIButton!

    var onboarding = false
    var pinCode: String = ""

    var views: Array<UIView> = Array<UIView>()
    var labels: Array<UILabel> = Array<UILabel>()
    var indicator: UIView? = nil
    var hideButton = false

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
            if let json = try factorHelper?.caller.getStatus() {
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
                try factorHelper?.caller.resolveCode(code: pinCode)
                try factorHelper?.resolve()
            } catch {
                print("resolve failed")
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

    @IBAction func backButtonClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

public enum TitleText: String {
    case email = "id_enter_code_sent_to_your_email"
    case sms = "id_enter_code_received_via_sms"
    case phone = "id_enter_code_received_via_phone"
    case gauth = "id_enter_your_google_authenticator"
}
