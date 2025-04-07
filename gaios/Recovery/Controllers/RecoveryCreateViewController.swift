import Foundation
import UIKit
import gdk
import core
import greenaddress

class RecoveryCreateViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblNote: UILabel!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var word1: UILabel!
    @IBOutlet weak var word2: UILabel!
    @IBOutlet weak var word3: UILabel!
    @IBOutlet weak var word4: UILabel!
    @IBOutlet weak var word5: UILabel!
    @IBOutlet weak var word6: UILabel!

    lazy var arrayLabels: [UILabel] = [self.word1, self.word2, self.word3, self.word4, self.word5, self.word6]

    private var mnemonicSize: Int = 0
    private var mnemonic: [Substring]?

    var wm: WalletManager? { WalletManager.current }
    var session: SessionManager? { wm?.prominentSession }

    private var pageCounter = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        customBack()
        setContent()
        setStyle()

        Task {
            let credentials = try? await wm?.prominentSession?.getCredentials(password: "")
            mnemonic = credentials?.mnemonic?.split(separator: " ")
            mnemonicSize = (mnemonic ?? []).count
            loadWords()
            pageControl.numberOfPages = mnemonicSize / Constants.wordsPerPage
        }
    }

    func customBack() {
        let view = UIView()
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.setTitle("id_back".localized, for: .normal)
        button.addTarget(self, action: #selector(RecoveryCreateViewController.back(sender:)), for: .touchUpInside)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
        button.sizeToFit()
        view.addSubview(button)
        view.frame = button.bounds
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: view)
        navigationItem.hidesBackButton = true
    }

    @objc func back(sender: UIBarButtonItem) {
        if pageCounter == 0 {
            navigationController?.popViewController(animated: true)
        } else {
            pageCounter -= 1
            loadWords()
        }
    }

    func setContent() {
        let title = "id_write_down_your_recovery_phrase".localized
        let strs = ["id_recovery_phrase".localized, "id_correct_order".localized]

        let attributedText = NSMutableAttributedString.init(string: title)
        for str1 in strs {
            let range = (title.lowercased() as NSString).range(of: str1.lowercased())
            attributedText.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.gGreenMatrix(), range: range)
            lblTitle.attributedText = attributedText
        }

        lblHint.text = "id_store_it_somewhere_safe".localized
        btnNext.setTitle("id_next".localized, for: .normal)
        lblNote.text = "id_make_sure_to_be_in_a_private".localized
    }

    func setStyle() {
        btnNext.setStyle(.primary)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)

        pageCounter = 0
        loadWords()
    }

    func loadWords() {
        if let mnemonic = mnemonic {
            pageControl.currentPage = pageCounter

            let start = pageCounter * Constants.wordsPerPage
            let end = start + Constants.wordsPerPage
            for index in start..<end {
                let real = index+1
                let formattedString = NSMutableAttributedString(string: String("\(real) \(mnemonic[index])"))
                formattedString.setColor(color: UIColor.gGreenMatrix(), forText: String(format: "%d", real))
                formattedString.setFont(font: UIFont.systemFont(ofSize: 16, weight: .semibold), stringValue: String(format: "%d", real))
                arrayLabels[index % Constants.wordsPerPage].attributedText = formattedString
            }
        }
    }

    @IBAction func btnNext(_ sender: Any) {
        if pageCounter == (mnemonicSize / Constants.wordsPerPage) - 1 {
            let storyboard = UIStoryboard(name: "Recovery", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "RecoveryVerifyViewController") as? RecoveryVerifyViewController {
                vc.mnemonic = mnemonic
                navigationController?.pushViewController(vc, animated: true)
            }
        } else {
            pageCounter += 1
            loadWords()
        }
    }

}
