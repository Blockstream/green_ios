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
        guard let twoFactorReset = getGAService().getTwoFactorReset() else { return }
        if twoFactorReset.isResetActive {
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
            cardView.balanceLabel.text = String.formatBtc(satoshi: item.satoshi)
            cardView.addressLabel.text = String()
            cardView.nameLabel.text = item.localizedName()
            cardView.nameLabel.textColor = UIColor.customMatrixGreen()
            cardView.index = index
            cardView.balanceLabel.textColor = UIColor.white
            cardView.presentedCardViewColor = UIColor.customTitaniumMedium()
            cardView.depresentedCardViewColor = UIColor.customTitaniumMedium()
            cardView.presentedDidUpdate()
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
        AccountStore.shared.getWallets(cached: true).done { accounts in
            guard !accounts.isEmpty else {
                return
            }

            DispatchQueue.main.async {
                // Run UI Updates or call completion block
                self.walletView.remove(cardViews: self.walletView.insertedCardViews)
                self.wallets = accounts
                self.reloadWallets()
            }
        }.catch { _ in
        }
    }

    func refreshBalance() {
        AccountStore.shared.GDKQueue.async{
            for wallet in self.wallets {
                do {
                    let balance = try getSession().getBalance(subaccount: wallet.pointer, numConfs: 0)
                    DispatchQueue.main.async {
                        let satoshi = balance!["satoshi"] as! UInt64
                        wallet.satoshi = satoshi
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
        wallet.nameLabel.textColor = UIColor.customMatrixGreen()
        wallet.QRImageView.isUserInteractionEnabled = true
        presentedWallet = wallet.wallet
        try! getSession().setCurrentSubaccount(subaccount: (presentedWallet!.pointer))
    }

    func cardViewDismissed(cardView: CardView) {
        presented = false
        let wallet = cardView as! ColoredCardView
        wallet.QRImageView.isUserInteractionEnabled = false
        wallet.nameLabel.textColor = UIColor.customMatrixGreen()
        wallet.balanceLabel.textColor = UIColor.white
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

