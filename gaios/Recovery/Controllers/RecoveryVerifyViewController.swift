import Foundation
import UIKit
import core
import gdk
import greenaddress

class RecoveryVerifyViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var textLabel: UILabel!

    @IBOutlet weak var button0: UIButton!
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var button3: UIButton!

    @IBOutlet weak var pageControl: UIPageControl!

    lazy var buttonsArray: [UIButton] = [button0, button1, button2, button3]

    var mnemonic: [Substring]!
    var selectionWordNumbers: [Int] = [Int](repeating: 0, count: Constants.wordsPerQuiz)
    var expectedWordNumbers: [Int] = []
    var questionCounter: Int = 0
    var questionPosition: Int = 0
    var numberOfSteps: Int = 4

    override func viewDidLoad() {
        super.viewDidLoad()
        expectedWordNumbers = generateExpectedWordNumbers()
        newRandomWords()

        customBack()
        pageControl.numberOfPages = numberOfSteps
        updatePageControl()
        reload()

        lblTitle.text = "id_recovery_phrase_check".localized
        updateHint()

        buttonsArray.forEach {
            $0.setStyle(.outlinedWhite)
        }

        AnalyticsManager.shared.recordView(.recoveryCheck, sgmt: AnalyticsManager.shared.ntwSgmtUnified())
    }

    func customBack() {
        let view = UIView()
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.setTitle("Back".localized, for: .normal)
        button.addTarget(self, action: #selector(RecoveryVerifyViewController.back(sender:)), for: .touchUpInside)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
        button.sizeToFit()
        view.addSubview(button)
        view.frame = button.bounds
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: view)
        navigationItem.hidesBackButton = true
    }

    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for button in buttonsArray {
            button.addTarget(self, action: #selector(self.click), for: .touchUpInside)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for button in buttonsArray {
            button.removeTarget(self, action: #selector(self.click), for: .touchUpInside)
        }
    }

    @objc func click(_ sender: UIButton) {
        var selectedWord: String?
        for button in buttonsArray {
            button.isSelected = false
            if button == sender {
                button.isSelected = true
                selectedWord = button.titleLabel?.text
            }
        }
        if selectedWord != nil, selectedWord == String(mnemonic[questionPosition]) {
            if isComplete() {
                DispatchQueue.main.async {
                    self.next()
                }
            } else {
                questionCounter += 1
                newRandomWords()
                reload()
                updatePageControl()
            }
        } else {
            DropAlert().warning(message: "id_wrong_choice_check_your".localized, delay: 4)
            navigationController?.popViewController(animated: true)
        }
    }

    func next() {
        guard let account =  WalletManager.current?.account else {
            return
        }
        BackupHelper.shared.removeFromBackupList(account.id)
        if !account.hasManualPin {
            pushSetPinViewController()
        } else {
            pushBackupSuccessViewController()
        }
    }

    func pushSetPinViewController() {
        let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController") as? SetPinViewController {
            vc.pinFlow = .backup
            vc.viewModel = OnboardViewModel()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func pushBackupSuccessViewController() {
        let storyboard = UIStoryboard(name: "Recovery", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "BackupSuccessViewController") as? BackupSuccessViewController {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    func updatePageControl() {
        pageControl.currentPage = questionCounter
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
        var words: [Int] = [Int](repeating: 0, count: Constants.wordsPerQuiz)
        repeat {
            // mnemonic.endIndex is 12
            // words in in range 0...11
            words = words.map { (_) -> Int in getIndexFromUniformUInt32(count: mnemonic.endIndex) }
        } while Set(words).count != Constants.wordsPerQuiz
        return words
    }

    func generateExpectedWordNumbers() -> [Int] {
        var words: [Int] = [Int](repeating: 0, count: numberOfSteps)
        repeat {
            words = words.map { (_) -> Int in getIndexFromUniformUInt32(count: mnemonic.endIndex) }
        } while Set(words).count != numberOfSteps
        return words
    }

    func updateHint() {
        lblHint.text = String(format: "id_what_is_word_number_s".localized, String(questionPosition + 1))
    }

    func isComplete() -> Bool {
        return questionCounter == numberOfSteps - 1
    }

    func reload() {
        // update buttons
        buttonsArray.enumerated().forEach { (offset, element) in
            let word = String(mnemonic[selectionWordNumbers[offset]])
            element.setTitle(word, for: .normal)
            element.isSelected = false
            #if DEBUG
            element.isSelected = mnemonic[questionPosition] == word
            #endif
        }
        // update subtitle
        let rangeStart: Int
        let rangeEnd: Int
        if questionPosition == 0 {
            rangeStart = 0
            rangeEnd = 2
        } else if questionPosition == mnemonic.endIndex - 1 {
            rangeStart = (mnemonic.endIndex - 1) - 2
            rangeEnd = mnemonic.endIndex - 1
        } else {
            rangeStart = questionPosition - 1
            rangeEnd = questionPosition + 1
        }

        let question = " ______   "
//        var str = ""
        let attributedString = NSMutableAttributedString(string: "")
        for idx in rangeStart...rangeEnd {

            let prefix = "\(idx + 1)."
            if mnemonic[questionPosition] == mnemonic[idx] {
                attributedString.append(NSMutableAttributedString(string: " \(prefix)\(question)"))
            } else {
                attributedString.append(NSMutableAttributedString(string: "\(prefix) \(mnemonic[idx]) "))
            }
            attributedString.setColor(color: UIColor.gAccent(), forText: question)
            attributedString.setColor(color: UIColor.gAccent(), forText: prefix)
        }
        textLabel.attributedText = attributedString
        updateHint()
    }
}
