import Foundation
import UIKit

class CongratsViewController : UIViewController {

    @IBOutlet weak var text: UILabel!
    @IBOutlet weak var subtext: UILabel!
    @IBOutlet weak var button: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        self.text.text = NSLocalizedString("id_congratulations", comment: "")
        self.subtext.text = NSLocalizedString("id_your_green_wallet_is_now_ready", comment: "")
        self.button.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)
    }
}
