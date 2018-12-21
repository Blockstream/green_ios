import UIKit

class InitialViewController: UIViewController {

    @IBOutlet weak var topButton: DesignableButton!
    @IBOutlet weak var networkButton: UIButton!
    @IBOutlet weak var restoreWalletbutton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        topButton.setTitle(NSLocalizedString("id_create_wallet", comment: ""), for: .normal)
        restoreWalletbutton.setTitle(NSLocalizedString("id_restore_existing_wallet", comment: ""), for: .normal)
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
            if getAppDelegate().isPinEnabled(network: getNetwork()) {
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
        topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func unwindToInitialViewController(segue: UIStoryboardSegue) {
    }
}
