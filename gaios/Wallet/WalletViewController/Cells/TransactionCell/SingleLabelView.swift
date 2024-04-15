import UIKit

class SingleLabelView: UIView {

    @IBOutlet weak var lbl: UILabel!
    
    func configure(_ txt: String) {
        lbl.text = txt
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = UIColor.gGrayTxt()
    }
}
