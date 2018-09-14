
import UIKit
import PromiseKit

class ViewController: UIViewController, WalletViewDelegate{

    @IBOutlet weak var walletHeaderView: UIView!
    @IBOutlet weak var walletView: WalletView!
    @IBOutlet weak var addWalletButton: UIButton!
    @IBOutlet weak var walletsLabel: UILabel!

    @IBOutlet weak var addCardViewButton: UIButton!
    var wallets:Array<WalletItem> = Array<WalletItem>()
    var pager: MainMenuPageViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController!.navigationBar.isHidden = true
        addWalletButton.addTarget(self, action:#selector(self.addAccount(_:)), for: .touchUpInside)
        addWalletButton.imageView?.tintColor = UIColor.customMatrixGreen()
        walletView.presentedFooterView.receiveButton.addTarget(self, action: #selector(self.receiveToWallet(_:)), for: .touchUpInside)
        walletView.presentedFooterView.sendButton.addTarget(self, action: #selector(self.sendfromWallet(_:)), for: .touchUpInside)
        walletView.delegate = self
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

        var coloredCardViews = [ColoredCardView]()
        for index in 0..<wallets.count {
            let item = wallets[index]
            let cardView = ColoredCardView.nibForClass()
            let denomination = SettingsStore.shared.getDenominationSettings()
            let balance = String.satoshiToBTC(satoshi: item.balance)
            cardView.wallet = item
            cardView.balanceLabel.text = String(format: "%@ %@", balance, denomination)
            cardView.addressLabel.text = item.address
            cardView.nameLabel.text = item.name
            cardView.index = index
            if(index < wallets.count - 1) {
                cardView.balanceLabel.textColor = UIColor.customTitaniumLight()
                cardView.nameLabel.textColor = UIColor.customTitaniumLight()
            } else {
                cardView.balanceLabel.textColor = UIColor.white
                cardView.nameLabel.textColor = UIColor.white
            }
            cardView.presentedCardViewColor = UIColor.customTitaniumMedium()
            cardView.depresentedCardViewColor = UIColor.customTitaniumMedium()
            cardView.presentedDidUpdate()
            let uri = bip21Helper.btcURIforAddress(address: item.address)
            cardView.QRImageView.image = QRImageGenerator.imageForTextDark(text: uri, frame: cardView.QRImageView.frame)
            coloredCardViews.append(cardView)
        }

        walletView.reload(cardViews: coloredCardViews)

        walletView.didUpdatePresentedCardViewBlock = { [weak self] (card: CardView?) in
            self?.addCardViewButton.addTransitionFade()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showButtons()
        self.navigationController!.navigationBar.isHidden = true
        self.tabBarController?.tabBar.isHidden = false
        DispatchQueue.global(qos: .background).async {
            // Background Thread
            AccountStore.shared.getWallets().done { (accs:Array<WalletItem>) in
                DispatchQueue.main.async {
                    if(accs.count == 0) {
                        return
                    }
                    // Run UI Updates or call completion block
                    self.walletView.remove(cardViews: self.walletView.insertedCardViews)
                    self.wallets = accs.reversed()
                    self.reloadWallets()
                }
            }
        }

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //walletView.dismissPresentedCardView(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        walletView.dismissPresentedCardView(animated: true)
        if let nextController = segue.destination as? SendBtcViewController {
            self.navigationController!.navigationBar.isHidden = false
            nextController.wallet = (walletView.presentedCardView as! ColoredCardView).wallet
        }
        if let nextController = segue.destination as? ReceiveBtcViewController {
            nextController.receiveAddress = (walletView.presentedCardView as! ColoredCardView).addressLabel.text
        }
        hideButtons()
    }

    @IBAction func addCardViewAction(_ sender: Any) {
    }

    func hideButtons() {
        pager?.hideButtons()
        walletsLabel.isHidden = true
        addWalletButton.isHidden = true
    }

    func showButtons() {
        pager?.showButtons()
        walletsLabel.isHidden = false
        addWalletButton.isHidden = false
    }

    func cardViewPresented(cardView: CardView) {
        hideButtons()
        let wallet = cardView as! ColoredCardView
        wallet.balanceLabel.textColor = UIColor.white
        wallet.nameLabel.textColor = UIColor.white
    }

    func cardViewDismissed(cardView: CardView) {
        if(self.navigationController?.viewControllers.count == 1) {
            showButtons()
        }
        let wallet = cardView as! ColoredCardView
        if(wallet.index < wallets.count - 1) {
            wallet.balanceLabel.textColor = UIColor.customTitaniumLight()
            wallet.nameLabel.textColor = UIColor.customTitaniumLight()
        } else {
            wallet.balanceLabel.textColor = UIColor.white
            wallet.nameLabel.textColor = UIColor.white
        }
    }

    @objc func addAccount(_ sender: UIButton) {
        let customAlert = self.storyboard?.instantiateViewController(withIdentifier: "CustomAlertView") as! CustomAlertInputView
        customAlert.providesPresentationContextTransitionStyle = true
        customAlert.definesPresentationContext = true
        customAlert.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        customAlert.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        customAlert.delegate = self
        hideButtons()
        self.present(customAlert, animated: true, completion: nil)
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

}

extension ViewController: CustomAlertViewInputDelegate {

    func okButtonTapped(selectedOption: String, textFieldValue: String) {

     /* do {
            try getSession().createSubaccount(type: SubaccountType._2of2, name: textFieldValue)
        } catch {
            print("something went worng with creating subAccount")
        }*/
        showButtons()
    }

    func cancelButtonTapped() {
        print("cancelButtonTapped")
        showButtons()
    }
}

