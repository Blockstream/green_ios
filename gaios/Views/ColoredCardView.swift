
import UIKit

class ColoredCardView: CardView {

    @IBOutlet weak var contentView: UIView!
    
    var presentedCardViewColor:          UIColor = UIColor.customLightGreen()
    
    lazy var depresentedCardViewColor:   UIColor = { return UIColor.customLightGreen() }()
    
    @IBOutlet weak var indexLabel: UILabel!
    var index: Int = 0 {
        didSet {
            indexLabel.text = "# \(index)"
        }
    }
    
     override func awakeFromNib() {
        
        contentView.layer.cornerRadius  = 10
        contentView.layer.masksToBounds = true
        
        presentedDidUpdate()
        
    }
    
    override var presented: Bool { didSet { presentedDidUpdate() } }
    
    func presentedDidUpdate() {
        
        removeCardViewButton.isHidden = !presented
        contentView.backgroundColor = presented ? presentedCardViewColor : depresentedCardViewColor
        contentView.addTransitionFade()
        
    }
    
    @IBOutlet weak var removeCardViewButton: UIButton!
    @IBAction func removeCardView(_ sender: Any) {
        walletView?.remove(cardView: self, animated: true)
    }
    
}
