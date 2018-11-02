import Foundation
import UIKit

class TwoFactorSlectorViewController: UIViewController {

    var factorHelper: TwoFactorCallHelper? = nil
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
            let json = try factorHelper?.caller.getStatus()
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

    //FIXME: comapring title is bad
    @IBAction func buttonClicked(_ sender: Any) {
        let button = sender as! UIButton
        print("button " + String(button.tag) + " clicked")
        do {
        if(button.title(for: .normal) == NSLocalizedString("id_email", comment: "")) {
            try factorHelper?.caller.requestCode(method: "email")
        } else if (button.title(for: .normal) == NSLocalizedString("id_sms", comment: "")) {
            try factorHelper?.caller.requestCode(method: "sms")
        } else if (button.title(for: .normal) == NSLocalizedString("id_google_auth", comment: "")) {
            try factorHelper?.caller.requestCode(method: "gauth")
        } else if (button.title(for: .normal) == NSLocalizedString("id_call", comment: "")) {
            try factorHelper?.caller.requestCode(method: "phone")
        }
        try factorHelper?.resolve()
        } catch {
            factorHelper?.delegate?.onError(factorHelper!, text: "")
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }

}
