import UIKit

protocol NetworkDelegate {
    func networkDismissed()
}

class InitialViewController: UIViewController, NetworkDelegate {

    @IBOutlet weak var topButton: DesignableButton!
    @IBOutlet weak var networkButton: UIButton!
    @IBOutlet weak var restoreWalletbutton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        topButton.setTitle(NSLocalizedString("id_create_wallet", comment: ""), for: .normal)
        restoreWalletbutton.setTitle(NSLocalizedString("id_restore_an_existing_wallet", comment: ""), for: .normal)
        titleLabel.text = NSLocalizedString("id_bitcoins_most_secure_wallet", comment: "")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        networkButton.setTitle(stringForNetwork(net: getNetwork()), for: .normal)
    }

    func networkDismissed() {
        networkButton.setTitle(stringForNetwork(net: getNetwork()), for: .normal)
    }

    @IBAction func networkButtonClicked(_ sender: Any) {
        let networkSelector = self.storyboard?.instantiateViewController(withIdentifier: "networkSelection") as! NetworkSelectionSettings
        networkSelector.delegate = self
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
