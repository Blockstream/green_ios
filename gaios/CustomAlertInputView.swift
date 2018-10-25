import Foundation
import UIKit

class CustomAlertInputView: UIViewController {


    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var alertView: UIView!

    var delegate: CustomAlertViewInputDelegate?
    var selectedOption = "First"
    let alertViewGrayColor = UIColor(red: 224.0/255.0, green: 224.0/255.0, blue: 224.0/255.0, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        textField.becomeFirstResponder()
        hideKeyboardWhenTappedAround()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupView()
        animateView()
        let titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
    }

    func setupView() {
        alertView.layer.cornerRadius = 15
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    }

    func animateView() {
        alertView.alpha = 0;
        self.alertView.frame.origin.y = self.alertView.frame.origin.y + 50
        UIView.animate(withDuration: 0.4, animations: { () -> Void in
            self.alertView.alpha = 1.0;
            self.alertView.frame.origin.y = self.alertView.frame.origin.y - 50
        })
    }

    @IBAction func okButtonClicked(_ sender: Any) {
        textField.resignFirstResponder()
        delegate?.okButtonTapped(selectedOption: selectedOption, textFieldValue: textField.text!)
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func cancelButtonClicked(_ sender: Any) {
        textField.resignFirstResponder()
        delegate?.cancelButtonTapped()
        self.dismiss(animated: true, completion: nil)
    }
}

protocol CustomAlertViewInputDelegate: class {
    func okButtonTapped(selectedOption: String, textFieldValue: String)
    func cancelButtonTapped()
}

