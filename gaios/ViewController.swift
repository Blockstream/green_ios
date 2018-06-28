
import UIKit
import PromiseKit

class ViewController: UIViewController {

    @IBOutlet weak var walletHeaderView: UIView!
    @IBOutlet weak var walletView: WalletView!

    @IBOutlet weak var addCardViewButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        walletView.walletHeader = walletHeaderView
        
        walletView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        let colors: [UIColor] = [UIColor.darkGray, UIColor.customLightGreen(), UIColor.customLightGray()]
        var coloredCardViews = [ColoredCardView]()
        for index in 1...3 {
            let cardView = ColoredCardView.nibForClass()
            cardView.index = index
            cardView.presentedCardViewColor = colors[index % colors.count]
            cardView.depresentedCardViewColor = colors[index % colors.count]
            cardView.presentedDidUpdate()
            coloredCardViews.append(cardView)
        }
        
        walletView.reload(cardViews: coloredCardViews)
        
        walletView.didUpdatePresentedCardViewBlock = { [weak self] (_) in
            self?.showAddCardViewButtonIfNeeded()
            self?.addCardViewButton.addTransitionFade()
        }
        
    }
    
    func showAddCardViewButtonIfNeeded() {
        addCardViewButton.alpha = walletView.presentedCardView == nil || walletView.insertedCardViews.count <= 1 ? 1.0 : 0.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            let balance = try getSession().getBalance(numConfs: 10)
            print("balance is ", balance)
            } catch {
            print("something went worng with getting balance")
        }
    }
    
    @IBAction func addCardViewAction(_ sender: Any) {
        do {
            try getSession().createSubaccount(type: SubaccountType._2of2, name: "test account")
        } catch {
            print("something went worng with creating subAccount")
        }
        walletView.insert(cardView: ColoredCardView.nibForClass(), animated: true, presented: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    
    
}

