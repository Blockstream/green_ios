import UIKit
import gdk

class TFANetworkSelectCell: UITableViewCell {

    @IBOutlet weak var networkSegmentedControl: UISegmentedControl!
    var onChange: ((Int) -> Void)?

    class var identifier: String { return String(describing: self) }

    override func awakeFromNib() {
        super.awakeFromNib()
        networkSegmentedControl.setTitleTextAttributes (
            [NSAttributedString.Key.foregroundColor: UIColor.black], for: .selected)
        networkSegmentedControl.setTitleTextAttributes (
            [NSAttributedString.Key.foregroundColor: UIColor.white], for: .normal)
        networkSegmentedControl.selectedSegmentIndex = 0 // showBitcoin ? 0 : 1
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    func configure(networks: [NetworkSecurityCase], onChange: ((Int) -> Void)?) {
        networks.enumerated().forEach { (i, net) in
            let title = net.chain.firstCapitalized
            networkSegmentedControl.setTitle(title, forSegmentAt: i)
        }
        self.onChange = onChange
    }
    @IBAction func onSegmentChange(_ sender: Any) {
        onChange?(networkSegmentedControl.selectedSegmentIndex)
    }
}
