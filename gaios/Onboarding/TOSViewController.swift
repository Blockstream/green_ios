import Foundation
import UIKit

class TOSViewController: UIViewController {

    @IBOutlet weak var nButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var tosTextView: UITextView!
    @IBOutlet weak var tosButton: DesignableButton!
    @IBOutlet weak var secondaryLabel: UILabel!

    @IBAction func nextButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "next", sender: self)
    }

    @IBAction func agreeTOSClicked(_ sender: UIButton) {
        nButton.isEnabled = !nButton.isEnabled
        updateButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nButton.updateGradientLayerFrame()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let whiteString = NSLocalizedString("id_i_agree_to_the", comment: "")
        let linkString = NSLocalizedString("id_terms_of_service", comment: "")
        let tosString = NSMutableAttributedString(string: whiteString + " " + linkString)
        tosString.addAttribute(.link, value: "https://greenaddress.it/tos", range: NSRange(location: whiteString.count + 1, length: linkString.count))
        tosString.setColor(color: UIColor.white, forText: whiteString)
        let linkAttributes: [String : Any] = [
            NSAttributedStringKey.foregroundColor.rawValue: UIColor.customMatrixGreen(),
            NSAttributedStringKey.underlineColor.rawValue: UIColor.customMatrixGreen(),
            NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue
        ]
        tosTextView.linkTextAttributes = linkAttributes
        tosTextView.attributedText = tosString
        tosTextView.font = UIFont.systemFont(ofSize: 16)
        tosTextView.isUserInteractionEnabled = true
        let stringLocalized = NSLocalizedString("id_welcome_to", comment: "") + " GREEN"
        let topString = NSMutableAttributedString(string: stringLocalized)
        topString.setColor(color: UIColor.customMatrixGreen(), forText: "GREEN")
        topLabel.attributedText = topString
        secondaryLabel.text = NSLocalizedString("id_you_have_full_control_of_your", comment: "")
        nButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
        nButton.isEnabled = false
        updateButtons()
    }

    func updateButtons() {
        let accept = nButton.isEnabled
        tosButton.backgroundColor = accept ? UIColor.customMatrixGreen() : UIColor.clear
        tosButton.layer.borderColor =  UIColor.customTitaniumLight().cgColor
        tosButton.setImage(accept ? UIImage(named: "check") : nil, for: UIControlState.normal)
        tosButton.tintColor = UIColor.white
        nButton.toggleGradient(accept)
    }
}
