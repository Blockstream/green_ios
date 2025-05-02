import UIKit

class TransactActionsCell: UITableViewCell {

    @IBOutlet weak var controlBuy: UIView!
    @IBOutlet weak var controlSend: UIView!
    @IBOutlet weak var controlReceive: UIView!
    @IBOutlet weak var iconBuy: UIImageView!
    @IBOutlet weak var iconSend: UIImageView!
    @IBOutlet weak var iconReceive: UIImageView!
    @IBOutlet weak var lblBuy: UILabel!
    @IBOutlet weak var lblSend: UILabel!
    @IBOutlet weak var lblReceive: UILabel!

    var onBuy: (() -> Void)?
    var onSend: (() -> Void)?
    var onReceive: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        [controlBuy, controlSend, controlReceive].forEach {
            $0?.backgroundColor = UIColor.gGrayCard()
            $0?.borderWidth = 1.0
            $0?.borderColor = UIColor.gGrayCardBorder()
            $0?.cornerRadius = 3.0
        }
        [lblBuy, lblSend, lblReceive].forEach {
            $0?.setStyle(.txtBigger)
        }
        let tapBuy = UITapGestureRecognizer(target: self, action: #selector(didTapBuy))
        controlBuy.addGestureRecognizer(tapBuy)
        let tapSend = UITapGestureRecognizer(target: self, action: #selector(didTapSend))
        controlSend.addGestureRecognizer(tapSend)
        let tapReceive = UITapGestureRecognizer(target: self, action: #selector(didTapReceive))
        controlReceive.addGestureRecognizer(tapReceive)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(onBuy: (() -> Void)?,
                   onSend: (() -> Void)?,
                   onReceive: (() -> Void)?) {
        self.onBuy = onBuy
        self.onSend = onSend
        self.onReceive = onReceive
        iconBuy.image = TransactActions.buy.icon
        iconSend.image = TransactActions.send.icon
        iconReceive.image = TransactActions.receive.icon
        lblBuy.text = TransactActions.buy.name
        lblSend.text = TransactActions.send.name
        lblReceive.text = TransactActions.receive.name
    }
    @objc func didTapBuy() {
        controlBuy.pressAnimate { [weak self] in
            self?.onBuy?()
        }

    }
    @objc func didTapSend() {
        controlSend.pressAnimate { [weak self] in
            self?.onSend?()
        }
    }
    @objc func didTapReceive() {
        controlReceive.pressAnimate { [weak self] in
            self?.onReceive?()
        }
    }
}
