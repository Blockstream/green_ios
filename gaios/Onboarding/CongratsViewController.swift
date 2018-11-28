import Foundation
import UIKit

class CongratsViewController : UIViewController {

    @IBOutlet weak var text: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
    }
}
