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

    @IBAction func backButtonClicked(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func agreeTOSClicked(_ sender: UIButton) {
        sender.backgroundColor = UIColor.customMatrixGreen()
        sender.layer.borderColor = UIColor.customMatrixGreen().cgColor
        sender.setImage(UIImage(named: "stepIndicator"), for: UIControlState.normal)
        sender.tintColor = UIColor.white
        nButton.isUserInteractionEnabled = true
        nButton.backgroundColor = UIColor.customMatrixGreen()
        nButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nButton.backgroundColor = UIColor.customTitaniumLight()
        nButton.isUserInteractionEnabled = false
        nButton.layer.sublayers?.removeFirst()
        tosButton.backgroundColor = UIColor.clear
        tosButton.layer.borderColor = UIColor.customTitaniumLight().cgColor
        tosButton.setImage(nil, for: UIControlState.normal)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tosString = NSMutableAttributedString(string: "I agree to the Terms of Service")
        tosString.addAttribute(.link, value: SettingsStore.shared.tosURL, range: NSRange(location: 15, length: 16))
        tosString.setColor(color: UIColor.white, forText: "I agree to the")
        let linkAttributes: [String : Any] = [
            NSAttributedStringKey.foregroundColor.rawValue: UIColor.customMatrixGreen(),
            NSAttributedStringKey.underlineColor.rawValue: UIColor.customMatrixGreen(),
            NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue
        ]
        tosTextView.linkTextAttributes = linkAttributes
        tosTextView.attributedText = tosString
        tosTextView.font = UIFont.systemFont(ofSize: 16)
        tosTextView.isUserInteractionEnabled = true
        let stringLocalized = NSLocalizedString("pgreen_is_noncustodial_bitcoin", comment: "")
        let topString = NSMutableAttributedString(string: stringLocalized)

        topString.setColor(color: UIColor.customMatrixGreen(), forText: "GREEN")
        topLabel.attributedText = topString
        secondaryLabel.text = NSLocalizedString("", comment: "")
        nButton.setTitle(NSLocalizedString("pnext", comment: ""), for: .normal)
    }
}
