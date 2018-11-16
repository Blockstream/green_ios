import Foundation
import UIKit

class CreateWalletViewController: UIViewController {

    var viewArray: Array<UIView> = []
    var mnemonics:[String] = []
    var pageCounter:Int = 0;
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var word1: UILabel!
    @IBOutlet weak var word2: UILabel!
    @IBOutlet weak var word3: UILabel!
    @IBOutlet weak var word4: UILabel!
    @IBOutlet weak var word5: UILabel!
    @IBOutlet weak var word6: UILabel!
    lazy var arrayLabels: [UILabel] = [self.word1, self.word2, self.word3, self.word4, self.word5, self.word6]

    @IBOutlet weak var indicatorView: UIView!
    var indicatorBoxes: Array<UIView> = []
    var indicatorLayers: [CAGradientLayer?] = [CAGradientLayer?](repeatElement(nil, count: 24))
    var widths: Array<Int>  = []
    var firstTime = true

    override func viewDidLoad() {
        super.viewDidLoad()
        getAppDelegate().setMnemonicWords(try! generateMnemonic().components(separatedBy: " "))
        mnemonics = getAppDelegate().getMnemonicWords()!
        let maxWidth = self.view.frame.width - 50 - 60
        let width = maxWidth / 6
        widths = generateAllWidths(maxWidth: Int(maxWidth), blockWidth: Int(width))
        createIndicators()
        loadWords()
        title = NSLocalizedString("id_write_down_the_words", comment: "")
        nextButton.setTitle(NSLocalizedString("id_next", comment: ""), for: .normal)

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(CreateWalletViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        if(firstTime) {
            firstTime = false
            return
        }
        animateBackwardsRow(row: 0)
        animateBackwardsRow(row: 1)
        animateBackwardsRow(row: 2)
        animateBackwardsRow(row: 3)
        pageCounter = 0
        loadWords()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateRow(row: 0)
    }

    func createIndicators() {
        let height = 10
        for index in 0..<24 {
            let row = index / 6
            let position = index % 6
            let box = UIView()
            box.frame = CGRect(x: 0, y: 0, width: widths[index], height: height)
            box.backgroundColor = UIColor.clear
            box.borderWidth = 1
            box.borderColor = UIColor.customMatrixGreen()
            box.translatesAutoresizingMaskIntoConstraints = false
            indicatorBoxes.append(box)
            indicatorView.addSubview(box)
            if (row == 0) {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: indicatorView, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 0).isActive = true
            } else {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: indicatorBoxes[index - 6], attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 15).isActive = true
            }
            if (position == 0) {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: indicatorView, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 0).isActive = true
            } else {
                NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: indicatorBoxes[index - 1], attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: 10).isActive = true
            }
            NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: CGFloat(widths[index])).isActive = true
            NSLayoutConstraint(item: box, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: CGFloat(height)).isActive = true
            //width height
        }
    }

    func generateAllWidths(maxWidth: Int, blockWidth: Int) -> Array<Int> {
        var tmp: Array<Int> = []
        for _ in 0..<4 {
            tmp.append(contentsOf: generateWidthsForRow(maxWidth: maxWidth, blockWidth: blockWidth))
        }
        return tmp
    }

    func generateWidthsForRow(maxWidth: Int, blockWidth: Int) -> Array<Int>{
        var tmp: Array<Int> = []
        var sum = maxWidth + 1
        while (sum > maxWidth) {
            sum = 0
            tmp.removeAll()
            for _ in 0..<6 {
                let width = randomNumber(MIN: blockWidth - 15, MAX: blockWidth + 15)
                tmp.append(width)
                sum += width
            }
        }
        return tmp
    }

    func randomNumber(MIN: Int, MAX: Int)-> Int{
        var list : [Int] = []
        for i in MIN...MAX {
            list.append(i)
        }
        return list[Int(arc4random_uniform(UInt32(list.count)))]
    }

    func animateRow(row: Int) {
        let start = row * 6
        var column = 0
            for index in start..<start+6 {
                createGradiendLayers(index: index)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(column * 500)) {
                    self.animateColorChange(index: index)
                }
                column += 1
            }
    }

    func animateBackwardsRow(row: Int) {
        var column = 0
        let start = row * 6
        let end = (row * 6) + 6

        for index in start..<end {
            if ( indicatorLayers[index] != nil) {
                indicatorLayers[index]!.removeFromSuperlayer()
                indicatorLayers[index] = nil
            }
            column += 1
        }
    }

    func createGradiendLayers(index: Int) {
        let startLocations = [0, 0]
        let endLocations = [1, 2]
        let abc = self.indicatorBoxes[index]

        let layer = CAGradientLayer()
        layer.colors = [UIColor.customMatrixGreen().cgColor, UIColor.clear.cgColor]
        layer.frame = abc.bounds
        layer.locations = startLocations as [NSNumber]
        layer.startPoint = CGPoint(x: 0.0, y: 1.0)
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        indicatorLayers[index] = layer
    }

    func animateColorChange(index: Int) {
        let layer = indicatorLayers[index]
        let abc = self.indicatorBoxes[index]
        if (layer == nil) {
            return
        }
        abc.layer.addSublayer(layer!)
        let startLocations = [0, 0]
        let endLocations = [1, 2]
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = startLocations
        anim.toValue = endLocations
        anim.duration = 0.5
        layer?.add(anim, forKey: "loc")
        layer?.locations = endLocations as [NSNumber]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    @IBAction func nextButtonClicked(_ sender: Any) {
        if (pageCounter == 3) {
            self.performSegue(withIdentifier: "next", sender: nil)
        } else {
            pageCounter += 1
            animateRow(row: pageCounter)
            loadWords()
        }
    }

    func loadWords() {
        let start = pageCounter * 6
        let end = start + 6
        for index in start..<end {
            let real = index+1
            let formattedString = NSMutableAttributedString(string: String(format: "%d  %@", real, mnemonics[index]))
            formattedString.setColor(color: UIColor.customMatrixGreen(), forText: String(format: "%d", real))
            formattedString.setFont(font: UIFont.systemFont(ofSize: 13), stringValue: String(format: "%d", real))
            arrayLabels[index % 6].attributedText = formattedString

        }
    }

    @objc func back(sender: UIBarButtonItem) {
        if(pageCounter == 0) {
            navigationController?.popViewController(animated: true)
        } else {
            animateBackwardsRow(row: pageCounter)
            pageCounter -= 1
            loadWords()
        }
    }
}
