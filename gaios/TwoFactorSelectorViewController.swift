import Foundation
import UIKit

class TwoFactorSlectorViewController: UIViewController {

    var twoFactor: TwoFactorCall? = nil
    @IBOutlet weak var firstButton: UIButton!
    @IBOutlet weak var secondButton: UIButton!
    @IBOutlet weak var thirdButton: UIButton!
    @IBOutlet weak var fourthButton: UIButton!
    @IBOutlet weak var firstImage: UIImageView!
    @IBOutlet weak var secondImage: UIImageView!
    @IBOutlet weak var thirdImage: UIImageView!
    @IBOutlet weak var fourthImage: UIImageView!
    @IBOutlet weak var firstArrow: UIImageView!
    @IBOutlet weak var secondArrow: UIImageView!
    @IBOutlet weak var thirdArrow: UIImageView!
    @IBOutlet weak var fourthArrow: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!

    lazy var buttons: [UIButton] = [firstButton, secondButton, thirdButton, fourthButton]
    lazy var iconImage: [UIImageView] = [firstImage, secondImage, thirdImage, fourthImage]
    lazy var arrowImage: [UIImageView] = [firstArrow, secondArrow, thirdArrow, fourthArrow]
    var hideButton: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            let json = try twoFactor?.getStatus()
            let methods = json!["methods"] as! NSArray
            for index in 0..<methods.count {
                let method = methods[index] as! String
                if(method == "email") {
                    buttons[index].setTitle(NSLocalizedString("id_email", comment: ""), for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "email")
                } else if (method == "sms") {
                    buttons[index].setTitle(NSLocalizedString("id_sms", comment: ""), for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "sms")
                } else if (method == "gauth") {
                    buttons[index].setTitle(NSLocalizedString("id_google_auth", comment: ""), for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "gauth")
                } else if (method == "phone") {
                    buttons[index].setTitle(NSLocalizedString("id_call", comment: ""), for: UIControlState.normal)
                    iconImage[index].image = #imageLiteral(resourceName: "phoneCall")
                }
            }
            for index in methods.count..<buttons.count {
                buttons[index].isHidden = true
                iconImage[index].isHidden = true
                arrowImage[index].isHidden = true
            }
        } catch {
           print("couldn't get status")
        }
        titleLabel.text = NSLocalizedString("id_approve_using", comment: "")
        backButton.isHidden = hideButton
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? VerifyTwoFactorViewController {
            let pair = sender as! (TwoFactorCall, String)
            nextController.twoFactor = pair.0
            nextController.hideButton = true
        }
    }

    //FIXME: comapring title is bad
    @IBAction func buttonClicked(_ sender: Any) {
        let button = sender as! UIButton
        print("button " + String(button.tag) + " clicked")
        do {
        var method = ""
        if(button.title(for: .normal) == NSLocalizedString("id_email", comment: "")) {
            try twoFactor?.requestCode(method: "email")
            method = "email"
        } else if (button.title(for: .normal) == NSLocalizedString("id_sms", comment: "")) {
            try twoFactor?.requestCode(method: "sms")
            method = "sms"
        } else if (button.title(for: .normal) == NSLocalizedString("id_google_auth", comment: "")) {
            try twoFactor?.requestCode(method: "gauth")
            method = "gauth"
        } else if (button.title(for: .normal) == NSLocalizedString("id_call", comment: "")) {
            try twoFactor?.requestCode(method: "phone")
            method = "phone"
        }
            let status = try twoFactor?.getStatus()
            let parsed = status!["status"] as! String
            if(parsed == "resolve_code") {
                self.performSegue(withIdentifier: "twoFactor", sender: (twoFactor, method))
            }
        } catch {
            print("couldn't get status")
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

}
