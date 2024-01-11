import Foundation
import UIKit
import gdk

class MagnifyQRViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var qr: UIImageView!

    var qrTxt: String?
    var qrBcur: BcurEncodedData?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()

        let tapRecognizer =
        UITapGestureRecognizer(target: self, action: #selector(onTap))
        view.addGestureRecognizer(tapRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func setContent() {
    }

    func setStyle() {
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
}
