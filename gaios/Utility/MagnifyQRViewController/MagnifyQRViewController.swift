import Foundation
import UIKit
import gdk

class MagnifyQRViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var qr: UIImageView!
    @IBOutlet weak var btnClose: UIButton!
    @IBOutlet weak var btnNavClose: UIButton!

    @IBOutlet weak var plainTxt: UILabel!
    @IBOutlet weak var groupedTxt: UITextView!

    var qrTxt: String?
    var qrBcur: BcurEncodedData?
    var textNoURI: String?
    var showClose = false
    var showTxt = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()

        // let tapRecognizer =
        // UITapGestureRecognizer(target: self, action: #selector(onTap))
        // view.addGestureRecognizer(tapRecognizer)

        plainTxt.isHidden = true
        groupedTxt.isHidden = true
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
        btnNavClose.isHidden = showClose
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
        btnClose.setTitle("id_close".localized, for: .normal)
    }

    func setStyle() {
        btnClose.setStyle(.primary)
        btnNavClose.setImage(UIImage(named: "cancel")!.maskWithColor(color: .black), for: .normal)
        plainTxt.lineBreakMode = .byTruncatingTail
        plainTxt.textColor = .black
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let text = qrTxt {
            qr.qrCode(text: text)
        } else if let bcur = qrBcur {
            qr.bcurQrCode(bcur: bcur)
        } else {
            qr.image = UIImage()
        }
    }

    @objc func onTap(sender: UITapGestureRecognizer) {
        dismiss()
    }

    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
            })
        })
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss()
    }

    @IBAction func btnNavClose(_ sender: Any) {
        dismiss()
    }
}
