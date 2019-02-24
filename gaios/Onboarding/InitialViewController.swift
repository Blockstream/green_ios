import UIKit

class InitialViewController: UIViewController {

    @IBOutlet weak var topButton: UIButton!
    @IBOutlet weak var networkButton: UIButton!
    @IBOutlet weak var restoreWalletbutton: UIButton!
    @IBOutlet weak var optionsBarButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        topButton.setDefaultButtonText(string: NSLocalizedString("id_create_wallet", comment: ""))
        topButton.setGradient(true)
        restoreWalletbutton.setDefaultButtonText(string: NSLocalizedString("id_restore_existing_wallet", comment: ""), fontColor: UIColor.customMatrixGreen())
        optionsBarButton.title = NSLocalizedString("id_login_options", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateNetworkButtonTitle()
    }

    func updateNetworkButtonTitle() {
        let defaults = getUserNetworkSettings()
        let networkName = defaults?["network"] as? String ?? "Bitcoin"
        networkButton.setTitle(networkName == "Mainnet" ? "Bitcoin" : networkName, for: .normal)
    }

    @IBAction func networkButtonClicked(_ sender: Any) {
        let networkSelector = self.storyboard?.instantiateViewController(withIdentifier: "networkSelection") as! NetworkSelectionSettings
        networkSelector.onSave = {
            self.updateNetworkButtonTitle()
            let network = getNetwork()
            onFirstInitialization(network: network)
            if isPinEnabled(network: network) {
                getAppDelegate().instantiateViewControllerAsRoot(identifier: "PinLoginNavigationController")
            }
        }
        networkSelector.providesPresentationContextTransitionStyle = true
        networkSelector.definesPresentationContext = true
        networkSelector.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        networkSelector.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        self.present(networkSelector, animated: true, completion: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        topButton.updateGradientLayerFrame()
    }

    private func onAction(identifier: String) {
        if isPinEnabled(network: getNetwork()) {
            let message = String(format: NSLocalizedString("id_there_is_already_a_pin_set_for", comment: ""), getNetwork())
            let alert = UIAlertController(title: NSLocalizedString("id_warning", comment: ""), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in })
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_ok", comment: ""), style: .default) { _ in
                self.performSegue(withIdentifier: identifier, sender: self)
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            self.performSegue(withIdentifier: identifier, sender: self)
        }
    }

    @IBAction func createWalletAction(_ sender: Any) {
        onAction(identifier: "createWallet")
    }

    @IBAction func restoreWalletAction(_ sender: Any) {
        onAction(identifier: "enterMnemonic")
    }

    @IBAction func optionsBarButtonClick(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: NSLocalizedString("id_login_options", comment: ""), message: "", preferredStyle: .actionSheet)
        if isPinEnabled(network: getNetwork()) {
            alert.addAction(UIAlertAction(title: NSLocalizedString("id_enter_pin", comment: ""), style: .default) { _ in
                self.performSegue(withIdentifier: "pin", sender: self)
            })
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_watchonly_login", comment: ""), style: .default) { _ in
            self.performSegue(withIdentifier: "watchonly", sender: self)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("id_cancel", comment: ""), style: .cancel) { _ in })
        self.present(alert, animated: true, completion: nil)
    }
}
