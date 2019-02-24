import UIKit

class CreateWalletViewController: UIViewController {

    var mnemonic: [Substring] = {
        return try! generateMnemonic().split(separator: " ")
    }()
    var pageCounter:Int = 0;
    lazy var arrayLabels: [UILabel] = [self.word1, self.word2, self.word3, self.word4, self.word5, self.word6]

    @IBOutlet weak var blockProgressView: BlockProgressView!
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

        title = NSLocalizedString("id_write_down_the_words", comment: "")
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(CreateWalletViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton

        nextButton.setGradient(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        blockProgressView.progress = 0
        pageCounter = 0
        hideWords()
        loadWords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        nextButton.updateGradientLayerFrame()
     }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let verifyMnemonics = segue.destination as? VerifyMnemonicsViewController {
            verifyMnemonics.mnemonic = mnemonic
        }
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        if pageCounter == 3 {
            self.performSegue(withIdentifier: "next", sender: nil)
        } else {
            blockProgressView.progress += 1
            pageCounter += 1
            hideWords()
            loadWords()
        }
    }

    func hideWords() {
        arrayLabels.forEach {
            $0.alpha = 0
        }
    }

    func loadWords() {
        progressView.progress = Float(pageCounter + 1) / 4
        let start = pageCounter * 6
        let end = start + 6
        for index in start..<end {
            let real = index+1
            let formattedString = NSMutableAttributedString(string: String("\(real) \(mnemonic[index])"))
            formattedString.setColor(color: UIColor.customMatrixGreen(), forText: String(format: "%d", real))
            formattedString.setFont(font: UIFont.systemFont(ofSize: 18, weight: .semibold), stringValue: String(format: "%d", real))
            arrayLabels[index % 6].attributedText = formattedString

        }
        var delay = 0.15
        arrayLabels.forEach { label in
            UIView.animate(withDuration: 0.2, delay: delay, options: .curveEaseIn, animations: {
                label.alpha = 1
            }, completion: nil)
            delay += 0.15
        }
    }

    @objc func back(sender: UIBarButtonItem) {
        if pageCounter == 0 {
            navigationController?.popViewController(animated: true)
        } else {
            blockProgressView.progress -= 1
            pageCounter -= 1
            loadWords()
        }
    }
}
