import UIKit
import PromiseKit

class WalletsController: UIViewController, WalletViewDelegate {

    @IBOutlet weak var walletView: WalletView!
    @IBOutlet weak var warningLabel: UILabel!

    var wallets:Array<WalletItem> = Array<WalletItem>()
    var presented: Bool = false
    var presentedWallet: WalletItem? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        walletView.presentedFooterView.receiveButton.addTarget(self, action: #selector(self.receiveToWallet(_:)), for: .touchUpInside)
        walletView.presentedFooterView.sendButton.addTarget(self, action: #selector(self.sendfromWallet(_:)), for: .touchUpInside)
        walletView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(self.newAddress(_:)), name: NSNotification.Name(rawValue: "addressChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.resetChanged(_:)), name: NSNotification.Name(rawValue: "twoFactorReset"), object: nil)
        updateWallet()
    }

    func updateWallet() {
        let data = AccountStore.shared.getTwoFactorResetData()
        if (data.isReset) {
            warningLabel.text = NSLocalizedString("id_twofactor_reset_in_progress", comment: "")
            warningLabel.isHidden = false
        } else {
            warningLabel.isHidden = true
        }
    }

    @objc func resetChanged(_ notification: NSNotification) {
        updateWallet()
    }

    @objc func newAddress(_ notification: NSNotification) {
        print(notification.userInfo ?? "")
        if let dict = notification.userInfo as NSDictionary? {
            if let pointer = dict["pointer"] as? Int {
                walletView.updateWallet(forCardview: pointer)
            }
        }
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

    func showTransaction(tx: TransactionItem) {
        self.performSegue(withIdentifier: "txDetails", sender: tx)
    }

    func reloadWallets() {

        var coloredCardViews = [ColoredCardView]()
        for index in 0..<wallets.count {
            let item = wallets[index]
            let cardView = ColoredCardView.nibForClass()
            cardView.wallet = item
            cardView.balanceLabel.text = String.formatBtc(satoshi: UInt64(item.balance)!)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .background).async {
            // Background Thread
            if(self.wallets.count == 0) {
                self.refreshWallets()
            } else {
                self.refreshBalance()
            }
        }
    }

    func refreshWallets() {
        AccountStore.shared.getWallets(cached: true).done { (accs:Array<WalletItem>) in
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

    func refreshBalance() {
        AccountStore.shared.GDKQueue.async{
            for wallet in self.wallets {
                do {
                    let balance = try getSession().getBalance(subaccount: wallet.pointer, numConfs: 0)
                    DispatchQueue.main.async {
                        let satoshi = balance!["satoshi"] as! UInt32
                        wallet.balance = String(satoshi)
                        self.walletView.updateBalance(forCardview: Int(wallet.pointer), sat: String(satoshi))
                    }
                } catch {
                    print("error updating balance")
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //walletView.dismissPresentedCardView(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? TransactionsController {
            nextController.presentingWallet = (sender as! ColoredCardView).wallet
        }
    }

    func cardViewPresented(cardView: CardView) {
        self.performSegue(withIdentifier: "account", sender: cardView)
        presented = true
        let wallet = cardView as! ColoredCardView
        wallet.balanceLabel.textColor = UIColor.white
        wallet.nameLabel.textColor = UIColor.white
        wallet.QRImageView.isUserInteractionEnabled = true
        presentedWallet = wallet.wallet
        wrap {_ in
            try getSession().setCurrentSubaccount(subaccount: (presentedWallet!.pointer))
        }.catch {_ in
            print("error on set subaccount")
        }
    }

    func cardViewDismissed(cardView: CardView) {
        presented = false
        let wallet = cardView as! ColoredCardView
        wallet.QRImageView.isUserInteractionEnabled = false
        if(wallet.index < wallets.count - 1) {
            wallet.balanceLabel.textColor = UIColor.customTitaniumLight()
            wallet.nameLabel.textColor = UIColor.customTitaniumLight()
        } else {
            wallet.balanceLabel.textColor = UIColor.white
            wallet.nameLabel.textColor = UIColor.white
        }
        presentedWallet = nil
    }

    @IBAction func addAccount(_ sender: Any) {
        let customAlert = self.storyboard?.instantiateViewController(withIdentifier: "CustomAlertView") as! CustomAlertInputView
        customAlert.providesPresentationContextTransitionStyle = true
        customAlert.definesPresentationContext = true
        customAlert.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        customAlert.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        customAlert.delegate = self
        self.present(customAlert, animated: true, completion: nil)
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

}

extension WalletsController: CustomAlertViewInputDelegate {

    func okButtonTapped(selectedOption: String, textFieldValue: String) {
        let dict = ["type": "2of2", "name": textFieldValue]
        do {
            let call = try getSession().createSubaccount(details: dict)
            try DummyResolve(call: call)
            refreshWallets()
        } catch {
            print("something went worng with creating subAccount")
        }
    }

    func cancelButtonTapped() {
        print("cancelButtonTapped")
    }
}

