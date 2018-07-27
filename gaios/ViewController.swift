
import UIKit
import PromiseKit

class ViewController: UIViewController, WalletViewDelegate{

    @IBOutlet weak var walletHeaderView: UIView!
    @IBOutlet weak var walletView: WalletView!
    @IBOutlet weak var addWalletButton: UIButton!

    @IBOutlet weak var addCardViewButton: UIButton!
    var wallets:Array<WalletItem> = Array<WalletItem>()
    var pager: MainMenuPageViewController? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController!.navigationBar.isHidden = true
        addWalletButton.addTarget(self, action:#selector(self.addAccount(_:)), for: .touchUpInside)
        addWalletButton.imageView?.tintColor = UIColor.customLightGreen()
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
            cardView.wallet = item
            cardView.balanceLabel.text = String.satoshiToBTC(satoshi: item.balance)
            cardView.addressLabel.text = item.address
            cardView.nameLabel.text = item.name
            cardView.presentedCardViewColor = UIColor.customTitaniumMedium()
            cardView.depresentedCardViewColor = UIColor.customTitaniumMedium()
            cardView.presentedDidUpdate()
            cardView.QRImageView.image = QRImageGenerator.imageForAddress(address: item.address, frame: cardView.QRImageView.frame)
            let shadowSize : CGFloat = 5.0
            let shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                       y: 0,
                                                       width: cardView.QRImageView.frame.size.width + shadowSize,
                                                       height: cardView.QRImageView.frame.size.height + shadowSize))
            cardView.QRImageView.layer.masksToBounds = false
            cardView.QRImageView.layer.shadowColor = UIColor.customMatrixGreen().cgColor
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
        showButtons()
        self.navigationController!.navigationBar.isHidden = true
        self.tabBarController?.tabBar.isHidden = false
        DispatchQueue.global(qos: .background).async {
            // Background Thread
            AccountStore.shared.getWallets().done { (accs:Array<WalletItem>) in
                DispatchQueue.main.async {
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
        if (pager != nil){
            pager?.button.isHidden = true
            pager?.button1.isHidden = true
            pager?.button2.isHidden = true
        }
    }

    func showButtons() {
        if (pager != nil){
            pager?.button.isHidden = false
            pager?.button1.isHidden = false
            pager?.button2.isHidden = false
        }
    }

    func cardViewPresented() {
        hideButtons()
    }

    func cardViewDismissed() {
        if(self.viewIfLoaded?.window != nil ) {
            showButtons()
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

        do {
            try getSession().createSubaccount(type: SubaccountType._2of2, name: textFieldValue)
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

