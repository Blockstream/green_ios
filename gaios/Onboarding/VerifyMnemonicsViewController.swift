import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class VerifyMnemonicsViewController: UIViewController, NVActivityIndicatorViewable {

    var selectionWordNumbers: [Int] = [Int](repeating: 0, count:4)
    var expectedWordNumbers: [Int] = [Int](repeating: 0, count:4)
    var mnemonics:[String] = []
    var questionCounter: Int = 0
    var questionPosition: Int = 0
    let numberOfSteps: Int = 4

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
    }

    func registerAndLogin(mnemonics: String) {
        let bgq = DispatchQueue.global(qos: .background)
        let appDelegate = getAppDelegate()

        firstly {
            self.startAnimating(message: NSLocalizedString("id_logging_in", comment: ""))
            return Guarantee()
        }.compactMap(on: bgq) {
            try appDelegate.disconnect()
        }.compactMap(on: bgq) {
            try appDelegate.connect()
        }.compactMap(on: bgq) {
            try getSession().registerUser(mnemonic: mnemonics)
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.compactMap(on: bgq) { call in
            try getSession().login(mnemonic: mnemonics)
        }.compactMap(on: bgq) { call in
            try call.resolve(self)
        }.ensure {
            self.stopAnimating()
        }.done { _ in
            if isPinEnabled(network: getNetwork()) {
                GreenAddressService.restoreFromMnemonics = true
                self.performSegue(withIdentifier: "mainView", sender: self)
            } else {
                self.performSegue(withIdentifier: "pin", sender: self)
            }
        }.catch { error in
            let message: String
            if let err = error as? GaError, err != GaError.GenericError {
                message = NSLocalizedString("id_you_are_not_connected_to_the", comment: "")
            } else {
                message = NSLocalizedString("id_login_failed", comment: "")
            }
            self.startAnimating(message: message)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                self.stopAnimating()
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
        next()
    }

    func next() {
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
