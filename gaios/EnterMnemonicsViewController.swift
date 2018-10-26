import Foundation
import UIKit

class EnterMnemonicsViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    var textFields: Array<UITextField> = []
    var box:UIView = UIView()
    var constraint: NSLayoutConstraint? = nil
    var isKeyboardShown = false
    var suggestionView = UIView()
    var suggestion1 = UILabel()
    var suggestion2 = UILabel()
    var suggestion3 = UILabel()
    lazy var labels = [suggestion1, suggestion2, suggestion3]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        createUI()
        NotificationCenter.default.addObserver(self, selector: #selector(EnterMnemonicsViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(EnterMnemonicsViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        hideKeyboardWhenTappedAround()
        topLabel.text = NSLocalizedString("id_enter_your_wallet_recovery_seed", comment: "")
        doneButton.setTitle(NSLocalizedString("id_done", comment: ""), for: .normal)
        createSuggestionView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doneButton.backgroundColor = UIColor.customTitaniumLight()
        doneButton.isUserInteractionEnabled = false
    }

    func createSuggestionView() {
        suggestionView.frame = CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 42)
        suggestionView.backgroundColor = UIColor.lightGray
        let separator1 = UIView()
        separator1.backgroundColor = UIColor.customTitaniumLight()
        separator1.frame = CGRect(x: suggestionView.frame.width / 3, y: 0, width: 2, height: suggestionView.frame.height)
        suggestionView.addSubview(separator1)
        let separator2 = UIView()
        separator2.backgroundColor = UIColor.customTitaniumLight()
        separator2.frame = CGRect(x: suggestionView.frame.width*2 / 3, y: 0, width: 2, height: suggestionView.frame.height)
        suggestionView.addSubview(separator2)

        suggestion1.frame = CGRect(x: 0, y: 0, width: suggestionView.frame.width / 3, height: suggestionView.frame.height)
        suggestion2.frame = CGRect(x: suggestionView.frame.width / 3, y: 0, width: suggestionView.frame.width / 3, height: suggestionView.frame.height)
        suggestion3.frame = CGRect(x: suggestionView.frame.width * 2 / 3, y: 0, width: suggestionView.frame.width / 3, height: suggestionView.frame.height)

        suggestion1.textAlignment = .center
        suggestion2.textAlignment = .center
        suggestion3.textAlignment = .center

        suggestionView.addSubview(suggestion1)
        suggestionView.addSubview(suggestion2)
        suggestionView.addSubview(suggestion3)

        suggestion1.textColor = UIColor.white
        suggestion2.textColor = UIColor.white
        suggestion3.textColor = UIColor.white

        suggestion1.isUserInteractionEnabled = true
        suggestion2.isUserInteractionEnabled = true
        suggestion3.isUserInteractionEnabled = true

        let tap1 = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped))
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped))
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(suggestionTapped))

        suggestion1.addGestureRecognizer(tap1)
        suggestion2.addGestureRecognizer(tap2)
        suggestion3.addGestureRecognizer(tap3)

        suggestionView.isHidden = true
        self.view.addSubview(suggestionView)
    }

    @objc func suggestionTapped(sender:UITapGestureRecognizer) {
        let label = sender.view as! UILabel
        print(label.text)
        for index in 0..<textFields.count {
            let textField = textFields[index]
            if textField.isFirstResponder {
                textField.text = label.text
                if(index < textFields.count - 1) {
                    let next = textFields[index+1]
                    next.becomeFirstResponder()
                }
                break
            }
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }

    func mergeTextFields() -> String {
        var result = ""
        for textfield in textFields {
            result += textfield.text! + " "
        }
        result = String(result.dropLast())
        return result.lowercased()
    }

    func updateSuggestions(prefix: String) {
        if let suggestions = Bip39helper.shared.searchForBIP39Words(prefix: prefix) {
            if (suggestions.count > 0) {
                for index in 0..<suggestions.count {
                    if(index == 3) {
                        break
                    } else if (index == suggestions.count-1) {
                        for kindex in index..<3 {
                            labels[kindex].text = ""
                        }
                    }
                    labels[index].text = suggestions[index]
                }
                suggestionView.isHidden = false
            } else {
                suggestionView.isHidden = true
            }
        } else {
            suggestionView.isHidden = true
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        if((textField.text?.count)! > 0) {
            updateSuggestions(prefix: textField.text!)
        } else {
            suggestionView.isHidden = true
        }
        for field in textFields {
            if(field.text == nil || field.text == "") {
                return
            }
        }
        doneButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
        doneButton.isUserInteractionEnabled = true
    }

    @IBAction func doneButtonClicked(_ sender: Any) {
        let trimmedUserProvidedMnemonic = mergeTextFields()
        //print(trimmedUserProvidedMnemonic)
        //let trimmedUserProvidedMnemonic = getNetwork() == Network.LocalTest ? "cotton slot artwork now grace assume syrup route moment crisp cargo sock wrap duty craft joy adult typical nut mad way autumn comic silent".trimmingCharacters(in: .whitespacesAndNewlines) : "current tomato armed onion able case donkey summer shrimp ridge into keen motion parent twin mobile paper member satisfy gather crane soft genuine produce".trimmingCharacters(in: .whitespacesAndNewlines)
        //let trimmedUserProvidedMnemonic = getNetwork() == Network.LocalTest ? "cotton slot artwork now grace assume syrup route moment crisp cargo sock wrap duty craft joy adult typical nut mad way autumn comic silent".trimmingCharacters(in: .whitespacesAndNewlines) : "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive spike pond industry time hero trim verb mammal asthma".trimmingCharacters(in: .whitespacesAndNewlines)
        retry(session: getSession(), network: getNetwork()) {
            wrap { return try getSession().login(mnemonic: trimmedUserProvidedMnemonic) }
            }.done { _ in
                Storage.wipeAll()
                let array = getAppDelegate().getMnemonicsArray(mnemonics: trimmedUserProvidedMnemonic)
                getAppDelegate().setMnemonicWords(array!)
                AppDelegate.removeKeychainData()
                AccountStore.shared.initializeAccountStore()
                self.performSegue(withIdentifier: "next", sender: self)
            }.catch { error in
                print("Login failed")
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let errorViewController = storyboard.instantiateViewController(withIdentifier: "error") as! NoInternetViewController
                self.navigationController?.pushViewController(errorViewController, animated: true)
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if(isKeyboardShown) {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            var frame = suggestionView.frame
            frame.origin.y = self.view.frame.height - keyboardSize.height - 42
            suggestionView.frame = frame
            suggestionView.layoutIfNeeded()
            isKeyboardShown = true
            print("showing keyboard")
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if(!isKeyboardShown) {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            var frame = suggestionView.frame
            frame.origin.y = self.view.frame.height
            suggestionView.frame = frame
            isKeyboardShown = false
            print("hiding keyboard")

        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    func createBlock(number: Int) -> UIView {
        let numberString = String(format: "%d", number+1) //loop start with 0, ui starts with 1
        let block:UIView = UIView()
        block.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        block.translatesAutoresizingMaskIntoConstraints = false

        let label: UILabel = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        label.text = numberString
        label.textColor = UIColor.customMatrixGreen()
        label.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(label)
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 14).isActive = true
        let size = label.sizeThatFits(CGSize(width: 25, height: 15))
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.lessThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: size.width).isActive = true

        let textField: TextField = TextField()
        textField.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .none
        textField.textColor = UIColor.white
        textField.autocorrectionType = .no
        textField.adjustsFontSizeToFitWidth = true
        textField.delegate = self
        textField.returnKeyType = UIReturnKeyType.done
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        block.addSubview(textField)
        textFields.append(textField)

        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: label, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -5).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -1).isActive = true
        NSLayoutConstraint(item: textField, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 30).isActive = true

        let bottomLine:UIView = UIView()
        bottomLine.frame = CGRect(x: 0, y: 0, width: 8, height: 14)
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = UIColor.customTitaniumMedium()
        block.addSubview(bottomLine)
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 1).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: label, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: bottomLine, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: block, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -5).isActive = true

        return block
    }

    func createUI() {
        let blockWidth = (view.frame.width - 32) / 4
        box.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        box.translatesAutoresizingMaskIntoConstraints = false
        let height = 360
        view.addSubview(box)
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.width, multiplier: 0, constant: view.frame.width).isActive = true
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: CGFloat(height)).isActive = true
        constraint = NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: topLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 40)
        constraint!.isActive = true
        NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true

        for index in 0..<24 {
            let row:Int = index / 4
            let block = createBlock(number: index)
            box.addSubview(block)

            let leadingConstant:CGFloat = CGFloat(16 + CGFloat(index % 4) * blockWidth)
            let topConstant:CGFloat = CGFloat(row * 60)

            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 0, constant: blockWidth).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 45).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: box, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: leadingConstant).isActive = true
            NSLayoutConstraint(item: block, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: box, attribute: NSLayoutAttribute.top, multiplier: 1, constant: topConstant).isActive = true
            //add constraints tp block
        }
    }
}
