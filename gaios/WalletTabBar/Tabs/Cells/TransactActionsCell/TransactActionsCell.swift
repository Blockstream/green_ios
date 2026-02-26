import UIKit

class TransactActionsCell: UITableViewCell {

    @IBOutlet weak var controlBuy: UIView!
    @IBOutlet weak var controlSend: UIView!
    @IBOutlet weak var controlReceive: UIView!
    @IBOutlet weak var controlSwap: UIView!
    @IBOutlet weak var iconBuy: UIImageView!
    @IBOutlet weak var iconSend: UIImageView!
    @IBOutlet weak var iconReceive: UIImageView!
    @IBOutlet weak var iconSwap: UIImageView!
    @IBOutlet weak var lblBuy: UILabel!
    @IBOutlet weak var lblSend: UILabel!
    @IBOutlet weak var lblReceive: UILabel!
    @IBOutlet weak var lblSwap: UILabel!

    var onBuy: (() -> Void)?
    var onSend: (() -> Void)?
    var onReceive: (() -> Void)?
    var onSwap: (() -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        [controlBuy, controlSend, controlReceive, controlSwap].forEach {
            $0?.backgroundColor = UIColor.gGrayCard()
            $0?.borderWidth = 1.0
            $0?.borderColor = UIColor.gGrayCardBorder()
            $0?.cornerRadius = 3.0
        }
        [lblBuy, lblSend, lblReceive, lblSwap].forEach {
            $0?.setStyle(.txtBigger)
        }
        let tapBuy = UITapGestureRecognizer(target: self, action: #selector(didTapBuy))
        controlBuy.addGestureRecognizer(tapBuy)
        let tapSend = UITapGestureRecognizer(target: self, action: #selector(didTapSend))
        controlSend.addGestureRecognizer(tapSend)
        let tapReceive = UITapGestureRecognizer(target: self, action: #selector(didTapReceive))
        controlReceive.addGestureRecognizer(tapReceive)
        let tapSwap = UITapGestureRecognizer(target: self, action: #selector(didTapSwap))
        controlSwap.addGestureRecognizer(tapSwap)
        controlBuy.accessibilityIdentifier = AccessibilityIds.CommonElements.ctaViewBuy
        controlSend.accessibilityIdentifier = AccessibilityIds.CommonElements.ctaViewSend
        controlReceive.accessibilityIdentifier = AccessibilityIds.CommonElements.ctaViewReceive
        controlSwap.accessibilityIdentifier = AccessibilityIds.CommonElements.ctaViewSwap
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(onBuy: (() -> Void)?,
                   onSend: (() -> Void)?,
                   onReceive: (() -> Void)?,
                   onSwap: (() -> Void)?
    ) {
        self.onBuy = onBuy
        self.onSend = onSend
        self.onReceive = onReceive
        self.onSwap = onSwap
        iconBuy.image = TransactActions.buy.icon
        iconSend.image = TransactActions.send.icon
        iconReceive.image = TransactActions.receive.icon
        iconSwap.image = TransactActions.swap.icon
        lblBuy.text = TransactActions.buy.name
        lblSend.text = TransactActions.send.name
        lblReceive.text = TransactActions.receive.name
        lblSwap.text = TransactActions.swap.name
        controlBuy.isHidden = onBuy == nil

        // Handle disabled state for send button
        if onSend == nil {
            controlSend.alpha = 0.3
            controlSend.isUserInteractionEnabled = false
        }
        if onSwap == nil {
            controlSwap.alpha = 0.3
            controlSwap.isUserInteractionEnabled = false
        }
    }
    @objc func didTapBuy() {
        controlBuy.pressAnimate { [weak self] in
            self?.onBuy?()
        }

    }
    @objc func didTapSend() {
        if controlSend.isUserInteractionEnabled {
            controlSend.pressAnimate { [weak self] in
                self?.onSend?()
            }
        }
    }
    @objc func didTapReceive() {
        if controlReceive.isUserInteractionEnabled {
            controlReceive.pressAnimate { [weak self] in
                self?.onReceive?()
            }
        }
    }
    @objc func didTapSwap() {
        if controlSwap.isUserInteractionEnabled {
            controlSwap.pressAnimate { [weak self] in
                self?.onSwap?()
            }
        }
    }
}
