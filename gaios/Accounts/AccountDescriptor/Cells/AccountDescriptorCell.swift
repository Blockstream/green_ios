import UIKit
import gdk
import core

class AccountDescriptorCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var lblDescriptor: UILabel!
    @IBOutlet weak var btnClipboard: UIButton!
    @IBOutlet weak var btnQR: UIButton!
    var model: AccountDescriptorCellModel!
    private var onClipboard: ((String) -> Void)?
    private var onQR: ((QRDialogInfo) -> Void)?

    static var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        bg.borderColor = .white.withAlphaComponent(0.1)
        [lblDescriptor].forEach {
            $0?.setStyle(.txtCard)
        }
    }

    func configure(model: AccountDescriptorCellModel,
                   onClipboard: ((String) -> Void)?,
                   onQR: ((QRDialogInfo) -> Void)?
    ) {
        self.model = model
        self.onClipboard = onClipboard
        self.onQR = onQR
        self.lblDescriptor.text = model.descriptor
    }
    @IBAction func btnClipboard(_ sender: Any) {
        bg.pressAnimate {
            self.onClipboard?(self.model.descriptor)
        }
    }
    @IBAction func btnQR(_ sender: Any) {
        bg.pressAnimate {
            let qrInfo = QRDialogInfo(item: self.model.descriptor, title: "Output Descriptor", hint: "")
            self.onQR?(qrInfo)
        }
    }
}
