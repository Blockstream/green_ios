
import UIKit
import PromiseKit

class ViewController: UIViewController {

    @IBOutlet weak var walletHeaderView: UIView!
    @IBOutlet weak var walletView: WalletView!
    @IBOutlet weak var addWalletButton: UIButton!

    @IBOutlet weak var addCardViewButton: UIButton!
    var wallets:Array<WalletItem> = Array<WalletItem>()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController!.navigationBar.isHidden = true
        addWalletButton.addTarget(self, action:#selector(self.addAccount(_:)), for: .touchUpInside)
        addWalletButton.imageView?.tintColor = UIColor.customLightGreen()
        walletView.presentedFooterView.receiveButton.addTarget(self, action: #selector(self.receiveToWallet(_:)), for: .touchUpInside)
        walletView.presentedFooterView.sendButton.addTarget(self, action: #selector(self.sendfromWallet(_:)), for: .touchUpInside)
    }

    @objc func sendfromWallet(_ sender: UIButton) {
        self.performSegue(withIdentifier: "sendBTC", sender: self)
    }

    @objc func receiveToWallet(_ sender: UIButton) {
        self.performSegue(withIdentifier: "receiveBTC", sender: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }


    func reloadWallets() {
        walletView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)

        var coloredCardViews = [ColoredCardView]()
        for index in 0..<wallets.count {
            let item = wallets[index]
            let cardView = ColoredCardView.nibForClass()
            cardView.balanceLabel.text = String.satoshiToBTC(satoshi: item.balance)
            cardView.addressLabel.text = item.address
            cardView.nameLabel.text = item.name
            cardView.presentedCardViewColor = UIColor.customWalletCardColor()
            cardView.depresentedCardViewColor = UIColor.customWalletCardColor()
            cardView.presentedDidUpdate()
            cardView.QRImageView.image = QRImageGenerator.imageForAddress(address: item.address, frame: cardView.QRImageView.frame)
            let shadowSize : CGFloat = 5.0
            let shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                       y: 0,
                                                       width: cardView.QRImageView.frame.size.width + shadowSize,
                                                       height: cardView.QRImageView.frame.size.height + shadowSize))
            cardView.QRImageView.layer.masksToBounds = false
            cardView.QRImageView.layer.shadowColor = UIColor.customQRColorGreen().cgColor
            cardView.QRImageView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
            cardView.QRImageView.layer.shadowOpacity = 0.5
            cardView.QRImageView.layer.shadowPath = shadowPath.cgPath
            coloredCardViews.append(cardView)
        }

        walletView.reload(cardViews: coloredCardViews)

        walletView.didUpdatePresentedCardViewBlock = { [weak self] (_) in
            self?.addCardViewButton.addTransitionFade()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController!.navigationBar.isHidden = true
        self.tabBarController?.tabBar.isHidden = false
        AccountStore.shared.getWallets().done { (accs:Array<WalletItem>) in
            self.walletView.remove(cardViews: self.walletView.insertedCardViews)
            self.wallets = accs.reversed()
            self.reloadWallets()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        walletView.dismissPresentedCardView(animated: true)
        if let nextController = segue.destination as? SendBtcViewController {
            self.navigationController!.navigationBar.isHidden = false

        }
    }

    @IBAction func addCardViewAction(_ sender: Any) {
    }

    @objc func addAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "Name for new wallet", message: "", preferredStyle: .alert)

        alert.addTextField { (textField) in
            textField.placeholder = "Wallet1"
        }

        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
            do {
                try getSession().createSubaccount(type: SubaccountType._2of2, name: (textField?.text)!)
            } catch {
                print("something went worng with creating subAccount")
            }
        }))

        self.present(alert, animated: true, completion: nil)
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }



}

