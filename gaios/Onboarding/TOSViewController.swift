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
        setup()

    }

    func setup() {
        let whiteString = NSLocalizedString("id_i_agree_to_the", comment: "")
        let linkString = NSLocalizedString("id_terms_of_service", comment: "")
        let tosString = NSMutableAttributedString(string: whiteString + " " + linkString)
        tosString.addAttribute(.link, value: "https://greenaddress.it/tos", range: NSRange(location: whiteString.count + 1, length: linkString.count))
        tosString.setColor(color: UIColor.white, forText: whiteString)
        tosString.setKerning(kerning: 0.19, stringValue: whiteString + " " + linkString)
        tosString.setFont(font: UIFont.systemFont(ofSize: 14, weight: .light), stringValue: whiteString)
        tosString.setFont(font: UIFont.systemFont(ofSize: 14, weight: .medium), stringValue: linkString)
        let linkAttributes: [String : Any] = [
            NSAttributedStringKey.foregroundColor.rawValue: UIColor.customMatrixGreen(),
        ]
        tosTextView.linkTextAttributes = linkAttributes
        tosTextView.attributedText = tosString
        tosTextView.isUserInteractionEnabled = true

        let welcomeLocalized = NSLocalizedString("id_welcome_to", comment: "")
        let stringLocalized = welcomeLocalized + " GREEN"
        let topString = NSMutableAttributedString(string: stringLocalized)
        topString.setKerning(kerning: 0.24, stringValue: welcomeLocalized)
        topString.setFont(font: UIFont.systemFont(ofSize: 24, weight: .regular), stringValue: welcomeLocalized)
        topString.setKerning(kerning: 4.2, stringValue: "GREEN")
        topString.setColor(color: UIColor.customMatrixGreen(), forText: "GREEN")
        topString.setFont(font: UIFont.systemFont(ofSize: 24, weight: .bold), stringValue: "GREEN")
        topLabel.attributedText = topString

        let fullControlString = NSLocalizedString("id_you_have_full_control_of_your", comment: "")
        let attributedFullControlString = NSMutableAttributedString(string: fullControlString)
        attributedFullControlString.setFont(font: UIFont.systemFont(ofSize: 14, weight: .regular), stringValue: fullControlString)
        attributedFullControlString.setKerning(kerning: 0.7, stringValue: fullControlString)
        secondaryLabel.attributedText = attributedFullControlString

        nButton.isEnabled = false
        updateButtons()
    }

    func updateButtons() {
        let accept = nButton.isEnabled
        tosButton.backgroundColor = .clear
        tosButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        tosButton.setBackgroundImage(accept ? UIImage(named: "tosSelected") : nil, for: .normal)
        tosButton.tintColor = UIColor.customMatrixGreen()
        nButton.toggleGradient(accept)

        //set font to white
        let buttonString = NSLocalizedString("id_next", comment: "")
        nButton.setDefaultButtonText(string: buttonString, fontColor: accept ? .white : .disabledColor())
//        nButton.addArrow()
    }
}
