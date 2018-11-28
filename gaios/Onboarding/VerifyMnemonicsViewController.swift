import Foundation
import UIKit
import NVActivityIndicatorView

class VerifyMnemonicsViewController: UIViewController, NVActivityIndicatorViewable {

    var selectionWordNumbers: [Int] = [Int](repeating: 0, count:4)
    var expectedWordNumbers: [Int] = [Int](repeating: 0, count:4)
    var mnemonics:[String] = []
    var questionCounter: Int = 0
    var questionPosition: Int = 0
    let numberOfSteps: Int = 4

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var button0: DesignableButton!
    @IBOutlet weak var button1: DesignableButton!
    @IBOutlet weak var button2: DesignableButton!
    @IBOutlet weak var button3: DesignableButton!
    @IBOutlet weak var bottomText: UILabel!
    lazy var buttonsArray: [UIButton] = [button0, button1, button2, button3]

    override func viewDidLoad() {
        super.viewDidLoad()
        expectedWordNumbers = generateRandomWordNumbers()
        mnemonics = getAppDelegate().getMnemonicWords()!
        newRandomWords()
        update()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for button in buttonsArray {
            button.addTarget(self, action:#selector(self.buttonClicked), for: .touchUpInside)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        for button in buttonsArray {
            button.removeTarget(self, action: #selector(self.buttonClicked), for: .touchUpInside)
        }
    }

    func newRandomWords() {
        questionPosition = expectedWordNumbers[questionCounter]
        selectionWordNumbers = generateRandomWordNumbers()
        if !selectionWordNumbers.contains(questionPosition) {
            selectionWordNumbers[getIndexFromUniformUInt32(count: 3)] = questionPosition
        }
    }

    func getIndexFromUniformUInt32(count: Int) -> Int {
        return Int(try! getUniformUInt32(upper_bound: UInt32(count)))
    }

    func generateRandomWordNumbers() -> [Int] {
        var words: [Int] = [Int](repeating: 0, count:4)
        repeat {
            words = words.map { (_) -> Int in getIndexFromUniformUInt32(count: 23) }
        } while Set(words).count != 4
        return words
    }

    func update() {
        // update title
        let localized = NSLocalizedString("id_select_word_number_d", comment: "")
        title = String(format: localized, questionPosition + 1)
        // update buttons
        buttonsArray.enumerated().forEach { (offset, element) in
            element.setTitle(mnemonics[selectionWordNumbers[offset]], for: .normal)
            element.isSelected = false
        }
        // update subtitle
        let rangeStart: Int
        let rangeEnd: Int
        if questionPosition == 0 {
            rangeStart = 0
            rangeEnd = 2
        } else if questionPosition == 23 {
            rangeStart = 21
            rangeEnd = 23
        } else {
            rangeStart = questionPosition - 1
            rangeEnd = questionPosition + 1
        }
        let question = "  ______   "
        let placeHolder = mnemonics[rangeStart...rangeEnd].joined(separator: " ").replacingOccurrences(of: mnemonics[questionPosition], with: question)
        let attributedString = NSMutableAttributedString(string: placeHolder)
        attributedString.setColor(color: UIColor.customMatrixGreen(), forText: question)
        bottomText.attributedText = attributedString
        // disable next button
        nextButton.backgroundColor = UIColor.customTitaniumLight()
        nextButton.isEnabled = false
        nextButton.layer.sublayers?.removeFirst()
    }

    func registerAndLogin(mnemonics: String) {
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Registering...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
        DispatchQueue.global(qos: .background).async {
            wrap {
                    let call = try getSession().registerUser(mnemonic: mnemonics)
                    try DummyResolve(call: call)
                }.done { _ in
                    wrap {
                            let call = try getSession().login(mnemonic: mnemonics)
                            try DummyResolve(call: call)
                        }.done { _ in
                            DispatchQueue.main.async {
                                self.stopAnimating()
                                Storage.wipeAll()
                                AccountStore.shared.initializeAccountStore()
                                self.performSegue(withIdentifier: "pin", sender: self)
                            }
                        }.catch { error in
                            print("Login failed")
                            DispatchQueue.main.async() {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed...")
                                self.stopAnimating()
                            }
                    }
                }.catch { error in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                        NVActivityIndicatorPresenter.sharedInstance.setMessage("Register Failed...")
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                        self.stopAnimating()
                    }
                    print("register failed")
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pinController = segue.destination as? PinLoginViewController {
            pinController.setPinMode = true
        }
    }

    @objc func buttonClicked(_ sender: UIButton) {
        for button in buttonsArray {
            button.isSelected = false
        }
        sender.isSelected = true
        nextButton.isEnabled = true
        nextButton.backgroundColor = UIColor.customMatrixGreen()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func nextClicked(_ sender: UIButton) {
        var selectedWord: String?
        for button in buttonsArray {
            if button.isSelected {
                selectedWord = button.titleLabel?.text
            }
        }
        if selectedWord == nil {
            return
        }
        if selectedWord == mnemonics[questionPosition] {
            if(questionCounter == numberOfSteps - 1) {
                let stringRepresentation = mnemonics.joined(separator: " ")
                registerAndLogin(mnemonics: stringRepresentation)
            } else {
                questionCounter += 1
                newRandomWords()
                update()
            }
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
}
