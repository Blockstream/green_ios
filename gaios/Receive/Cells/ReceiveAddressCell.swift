import UIKit

class ReceiveAddressCell: UITableViewCell {

    @IBOutlet weak var bgCard: UIView!
    @IBOutlet weak var bgCardQR: UIView!
    @IBOutlet weak var envelopeView: UIView!
    @IBOutlet weak var envelopeBorderView: UIView!
    @IBOutlet weak var btnQRCode: UIButton!
    @IBOutlet weak var qrFrame: UIView!
    @IBOutlet weak var loader: UIActivityIndicatorView!
    @IBOutlet weak var lnBannerBox: UIView!
    @IBOutlet weak var lnBanner: UIView!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var btnRefresh: UIButton!
    @IBOutlet weak var btnMagnify: UIButton!
    @IBOutlet weak var btnCopyAddress: UIButton!

    @IBOutlet weak var plainTxt: UILabel!
    @IBOutlet weak var groupedTxt: UITextView!

    static var identifier: String { return String(describing: self) }

    var onCopyToClipboard: (() -> Void)?
    var onRefreshClick: (() -> Void)?
    var onLongpress: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        bgCard.setStyle(CardStyle.defaultStyle)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        qrFrame.addGestureRecognizer(longPressRecognizer)
        lnBanner.backgroundColor = UIColor.gAccent()
        lnBanner.cornerRadius = 5.0
        lblInfo.setStyle(.txtCard)
        lblInfo.textColor = .black
        lnBannerBox.isHidden = true
        envelopeBorderView.backgroundColor = .clear
        envelopeBorderView.borderWidth = 5.0
        envelopeBorderView.borderColor = UIColor.gAccent()
        envelopeBorderView.cornerRadius = 20.0
        btnMagnify.setTitle("id_increase_qr_size".localized, for: .normal)
        btnCopyAddress.setTitle("id_copy_address".localized, for: .normal)
        [btnMagnify, btnCopyAddress].forEach {
            $0.setStyle(.blackWithImg)
        }
        plainTxt.lineBreakMode = .byTruncatingTail
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(model: ReceiveAddressCellModel,
                   isAnimating: Bool,
                   onCopyToClipboard: (() -> Void)?,
                   onRefreshClick: (() -> Void)?,
                   onLongpress: (() -> Void)? = nil
    ) {
        plainTxt.isHidden = true
        groupedTxt.isHidden = true
        bgCard.borderWidth = 1.0
        bgCard.borderColor = UIColor.gGrayCardBorder()
        if !model.isBip21 && !model.isLightning {
            groupedTxt.isHidden = false
            AddressDisplay.configure(
                address: model.text ?? "",
                textView: groupedTxt,
                style: .default,
                truncate: true)
        } else {
            plainTxt.isHidden = false
            plainTxt.text = model.text
        }
        self.onCopyToClipboard = onCopyToClipboard
        self.onRefreshClick = onRefreshClick
        if let uri = model.text, !uri.isEmpty {
            let dim = min(qrFrame.frame.size.width, qrFrame.frame.size.height)
            let frame = CGRect(x: 0.0, y: 0.0, width: dim, height: dim)
            btnQRCode.setImage(QRImageGenerator.imageForTextWhite(text: uri, frame: frame), for: .normal)
            btnQRCode.imageView?.contentMode = .scaleAspectFit
            qrFrame.backgroundColor = .white
            qrFrame.cornerRadius = 10.0
            if model.type == .bolt11 {
                qrFrame.backgroundColor = .white
            }
        } else {
            btnQRCode.setImage(UIImage(), for: .normal)
            qrFrame.backgroundColor = .clear
        }
        if isAnimating {
            loader.startAnimating()
            loader.isHidden = false
        } else {
            loader.stopAnimating()
            loader.isHidden = true
        }
        lnBannerBox.isHidden = true
        if let onChaininfo = model.onChaininfo, model.type == .breezSwap {
            lnBannerBox.isHidden = false
            lblInfo.text = onChaininfo
            btnRefresh.isHidden = true
            bgCard.borderColor = UIColor.gAccent()        }

        self.onLongpress = onLongpress
    }

    @objc func longPressed(sender: UILongPressGestureRecognizer) {

        if sender.state == UIGestureRecognizer.State.began {
            onLongpress?()
        }
    }

    @IBAction func refreshClick(_ sender: Any) {
        onRefreshClick?()
    }

    @IBAction func btnMagnify(_ sender: Any) {
        onLongpress?()
    }

    @IBAction func btnCopyaddress(_ sender: Any) {
        onCopyToClipboard?()
    }

    @IBAction func btnQRCode(_ sender: Any) {
        onCopyToClipboard?()
    }
}
