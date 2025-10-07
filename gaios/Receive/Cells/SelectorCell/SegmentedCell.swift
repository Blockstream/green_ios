import UIKit

class SegmentedCell: UITableViewCell {

    class var identifier: String { return String(describing: self) }

    var onLeftTap: (() -> Void)?
    var onRightTap: (() -> Void)?

    @IBOutlet weak var segmented: UISegmentedControl!

    override func awakeFromNib() {
        super.awakeFromNib()
        segmented.setTitle("Liquid", forSegmentAt: 0)
        segmented.setTitle("Lightning", forSegmentAt: 1)
        segmented.selectedSegmentIndex = 0
    }

    func configure(selected: Int, onLeftTap: (() -> Void)?, onRightTap: (() -> Void)?) {
        segmented.selectedSegmentIndex = selected
        self.onLeftTap = onLeftTap
        self.onRightTap = onRightTap
    }
    @IBAction func onSegmentedTap(_ sender: Any) {
        if segmented.selectedSegmentIndex == 0 {
            onLeftTap?()
        } else {
            onRightTap?()
        }
    }
}
