import UIKit
import PromiseKit

class ViewController: UIViewController, WalletViewDelegate {

    @IBOutlet weak var walletHeaderView: UIView!
    @IBOutlet weak var walletView: WalletView!
    @IBOutlet weak var addWalletButton: UIButton!
    @IBOutlet weak var walletsLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!

    @IBOutlet weak var addCardViewButton: UIButton!
    var wallets:Array<WalletItem> = Array<WalletItem>()
    var pager: MainMenuPageViewController? = nil
    var zoomView: UIView? = nil
    var presented: Bool = false
    var presentedWallet: WalletItem? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController!.navigationBar.isHidden = true
        addWalletButton.addTarget(self, action:#selector(self.addAccount(_:)), for: .touchUpInside)
        addWalletButton.imageView?.tintColor = UIColor.customMatrixGreen()
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
            warningLabel.text = NSLocalizedString("id_two_factor_reset_in_progress", comment: "")
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
            let denomination = SettingsStore.shared.getDenominationSettings()
            let balance = String.satoshiToBTC(satoshi: item.balance)
            cardView.wallet = item
            cardView.balanceLabel.text = String(format: "%@ %@", balance, denomination.rawValue)
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
            let tap = UITapGestureRecognizer(target: self, action: #selector(zoomQR))
            cardView.QRImageView.isUserInteractionEnabled = false
            cardView.QRImageView.addGestureRecognizer(tap)
            cardView.QRImageView.tag = index
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
            if(self.wallets.count == 0) {
                self.refreshWallets()
            } else {
                self.refreshBalance()
            }
        }
    }

    @objc func zoomQR(recognizer: UITapGestureRecognizer) {
        if(!presented) {
            return
        }
        if let tag = recognizer.view?.tag {
            let addressDetail = self.storyboard?.instantiateViewController(withIdentifier: "addressDetail") as! AddressDetailViewController
            let item = wallets[tag]
            addressDetail.wallet = item
            addressDetail.providesPresentationContextTransitionStyle = true
            addressDetail.definesPresentationContext = true
            addressDetail.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            addressDetail.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
            hideButtons()
            self.present(addressDetail, animated: true, completion: nil)
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
        if let nextController = segue.destination as? SendBtcViewController {
            self.navigationController!.navigationBar.isHidden = false
            nextController.wallet = (walletView.presentedCardView as! ColoredCardView).wallet
        }
        if let nextController = segue.destination as? ReceiveBtcViewController {
            nextController.receiveAddress = (walletView.presentedCardView as! ColoredCardView).addressLabel.text
            nextController.wallet = (walletView.presentedCardView as! ColoredCardView).wallet
        }
        if let nextController = segue.destination as? TransactionDetailViewController {
            nextController.transaction_g = sender as? TransactionItem
            if presentedWallet != nil {
                nextController.pointer = presentedWallet!.pointer
            }
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
        presented = true
        hideButtons()
        let wallet = cardView as! ColoredCardView
        wallet.balanceLabel.textColor = UIColor.white
        wallet.nameLabel.textColor = UIColor.white
        wallet.QRImageView.isUserInteractionEnabled = true
        presentedWallet = wallet.wallet
    }

    func cardViewDismissed(cardView: CardView) {
        presented = false
        if(self.navigationController?.viewControllers.count == 1) {
            showButtons()
        }
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
        let dict = ["type": "2of2", "name": textFieldValue]
        do {
            try getSession().createSubaccount(details: dict)
            refreshWallets()
        } catch {
            print("something went worng with creating subAccount")
        }
        showButtons()
    }

    func cancelButtonTapped() {
        print("cancelButtonTapped")
        showButtons()
    }
}

