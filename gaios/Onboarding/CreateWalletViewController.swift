import Foundation
import UIKit

class CreateWalletViewController: UIViewController {

    var mnemonics:[String] = []
    var pageCounter:Int = 0;
    lazy var arrayLabels: [UILabel] = [self.word1, self.word2, self.word3, self.word4, self.word5, self.word6]

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var word1: UILabel!
    @IBOutlet weak var word2: UILabel!
    @IBOutlet weak var word3: UILabel!
    @IBOutlet weak var word4: UILabel!
    @IBOutlet weak var word5: UILabel!
    @IBOutlet weak var word6: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        getAppDelegate().setMnemonicWords(try! generateMnemonic().components(separatedBy: " "))
        mnemonics = getAppDelegate().getMnemonicWords()!
        title = NSLocalizedString("id_write_down_the_words", comment: "")
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(CreateWalletViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        pageCounter = 0
        loadWords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        if (pageCounter == 3) {
            self.performSegue(withIdentifier: "next", sender: nil)
        } else {
            pageCounter += 1
            loadWords()
        }
    }

    func loadWords() {
        progressView.progress = Float(pageCounter) / 4
        let start = pageCounter * 6
        let end = start + 6
        for index in start..<end {
            let real = index+1
            let formattedString = NSMutableAttributedString(string: String(format: "%d  %@", real, mnemonics[index]))
            formattedString.setColor(color: UIColor.customMatrixGreen(), forText: String(format: "%d", real))
            formattedString.setFont(font: UIFont.systemFont(ofSize: 13), stringValue: String(format: "%d", real))
            arrayLabels[index % 6].attributedText = formattedString

        }
    }

    @objc func back(sender: UIBarButtonItem) {
        if(pageCounter == 0) {
            navigationController?.popViewController(animated: true)
        } else {
            pageCounter -= 1
            loadWords()
        }
    }
}
