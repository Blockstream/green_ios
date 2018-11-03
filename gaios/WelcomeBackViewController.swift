import Foundation
import UIKit

class WelcomeBackViewController: UIViewController {

    @IBOutlet weak var welcomeLabel: UILabel!
    let bioID = BiometricIDAuth()
    @IBOutlet weak var topButton: UIButton!
    @IBOutlet weak var bottomButon: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        welcomeLabel.text = NSLocalizedString("id_welcome_back_to_your_wallet", comment: "")
        topButton.setTitle(NSLocalizedString("id_enable_face_id", comment: ""), for: .normal)
        bottomButon.setTitle(NSLocalizedString("id_set_pin", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if(bioID.canEvaluatePolicy()){
            if(bioID.biometricType() == BiometricType.faceID) {
                topButton.setTitle("Enable Face ID", for: UIControlState.normal)
                topButton.layoutIfNeeded()
                topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
            } else if (bioID.biometricType() == BiometricType.touchID) {
                topButton.setTitle("Enabe Touch ID", for: UIControlState.normal)
                topButton.layoutIfNeeded()
                topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
            } else {
                topButton.isUserInteractionEnabled = false
                topButton.backgroundColor = UIColor.customTitaniumLight()
                topButton.setTitle("Touch/Face ID not available", for: UIControlState.normal)
            }
        } else {
            topButton.isUserInteractionEnabled = false
            topButton.backgroundColor = UIColor.customTitaniumLight()
            topButton.setTitle("Touch/Face ID not available", for: UIControlState.normal)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? PinLoginViewController {
            nextController.restoreMode = true
            nextController.setPinMode = true
        }
    }

    @IBAction func bioAuthenticateClicked(_ sender: Any) {
        bioID.authenticateUser { (message) in
            if(message == nil) {
                let password = String.random(length: 14)
                let deviceid = String.random(length: 14)
                let mnemonics = getAppDelegate().getMnemonicWordsString()
                wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: password, device: deviceid) }
                    .done { (result: String?) in
                        guard result != nil else {
                            return
                        }
                        if(self.bioID.canEvaluatePolicy()) {
                            if(self.bioID.biometricType() == BiometricType.faceID) {
                                SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.FaceID)
                            } else if (self.bioID.biometricType() == BiometricType.touchID) {
                                SettingsStore.shared.setScreenLockSettings(screenLock: ScreenLock.TouchID)
                            }
                        }
                        let network = getNetworkSettings().network
                        KeychainHelper.savePassword(service: "bioPassword", account: network, data: password)
                        KeychainHelper.savePassword(service: "bioData", account: network, data: result!)
                        self.performSegue(withIdentifier: "mainMenu", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
            } else {
                //here?
            }
        }
    }

    @IBAction func setPinClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "pin", sender: nil)
    }

}
