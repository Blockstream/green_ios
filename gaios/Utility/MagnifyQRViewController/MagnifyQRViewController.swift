import Foundation
import UIKit
import gdk

protocol MagnifyQRViewControllerDelegate: AnyObject {
    func close()
    func next()
}

class MagnifyQRViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var qr: UIImageView!
    @IBOutlet weak var btnClose: UIButton!
    @IBOutlet weak var btnNavClose: UIButton!
    @IBOutlet weak var navView: UIView!
    @IBOutlet weak var plainTxt: UILabel!
    @IBOutlet weak var groupedTxt: UITextView!

    @IBOutlet weak var mnemonicWarnView: UIView!
    @IBOutlet weak var warnIcon1: UIImageView!
    @IBOutlet weak var warnTitle1: UILabel!
    @IBOutlet weak var warnHint1: UILabel!
    @IBOutlet weak var warnIcon2: UIImageView!
    @IBOutlet weak var warnTitle2: UILabel!
    @IBOutlet weak var warnHint2: UILabel!
    @IBOutlet weak var mnemonicHeadView: UIStackView!
    @IBOutlet weak var lblMnemonicTitle: UILabel!
    @IBOutlet weak var lblMnemonicHint: UILabel!

    var qrTxt: String?
    var qrBcur: BcurEncodedData?
    var textNoURI: String?
    var showBtn = false
    var textBtn = "id_close"
    var showTxt = false
    var isMnemonic = false
    var showClose = false
    weak var delegate: MagnifyQRViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()

        // let tapRecognizer =
        // UITapGestureRecognizer(target: self, action: #selector(onTap))
        // view.addGestureRecognizer(tapRecognizer)

        plainTxt.isHidden = true
        groupedTxt.isHidden = true
        btnClose.isHidden = !showBtn
        btnNavClose.isHidden = false
        if showTxt {
            if qrTxt == textNoURI {
                if let textNoURI = textNoURI {
                    AddressDisplay.configure(
                        address: textNoURI,
                        textView: groupedTxt,
                        style: .default,
                        truncate: false,
                        appearance: .light,
                        wordsPerRow: 5)
                    groupedTxt.isHidden = false
                }
            } else {
                plainTxt.text = qrTxt
                plainTxt.isHidden = false
            }
        }
        btnClose.isHidden = !showClose
        navView.isHidden = showClose
        mnemonicWarnView.isHidden = !isMnemonic
        mnemonicHeadView.isHidden = !isMnemonic
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        btnClose.setTitle("id_close".localized, for: .normal)
        if isMnemonic {
            btnClose.setTitle("id_back".localized, for: .normal)
        }
        warnTitle1.text = "id_safe_environment".localized
        warnTitle2.text = "id_sensitive_information".localized
        warnHint1.text = "id_make_sure_you_are_alone_and_no".localized
        warnHint2.text = "id_whomever_can_access_your".localized
        lblMnemonicTitle.text = "id_recovery_phrase".localized
        lblMnemonicHint.text = "id_the_recovery_phrase_can_be_used".localized
    }

    func setStyle() {
        btnClose.setStyle(.primary)
        if isMnemonic {
            btnClose.setStyle(.outlined)
        }
        btnNavClose.setImage(UIImage(named: "cancel")!.maskWithColor(color: .black), for: .normal)
        plainTxt.lineBreakMode = .byTruncatingTail
        plainTxt.textColor = .black
        warnIcon1.image = UIImage(named: "ic_info_home")!.withTintColor(UIColor.gAccent())
        warnIcon2.image = UIImage(named: "ic_info_warn")!.withTintColor(UIColor.gAccent())
        [lblMnemonicTitle, warnTitle1, warnTitle2].forEach {
            $0?.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
            $0?.textColor = .black
        }
        [lblMnemonicHint, warnHint1, warnHint2].forEach {
            $0?.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
            $0?.textColor = .black.withAlphaComponent(0.6)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let bcur = qrBcur {
            qr.bcurQrCode(bcur: bcur)
        } else if let text = qrTxt {
            qr.qrCode(text: text)
        } else {
            qr.image = UIImage()
        }
    }

    @objc func onTap(sender: UITapGestureRecognizer) {
        dismiss() { [weak self] in
            self?.delegate?.close()
        }
    }

    func dismiss(completion: @escaping ()->Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                completion()
            })
        })
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss() { [weak self] in
            self?.delegate?.next()
        }
    }

    @IBAction func btnNavClose(_ sender: Any) {
        dismiss() { [weak self] in
            self?.delegate?.close()
        }
    }
}
