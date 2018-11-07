import Foundation
import UIKit

class CongratsViewController: UIViewController {

    @IBOutlet weak var topButton: UIButton!
    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var topLabel: UILabel!
    let bioID = BiometricIDAuth()

    override func viewDidLoad() {
        super.viewDidLoad()
        topLabel.text = NSLocalizedString("id_congratulationsnyou_are_now_the", comment: "")
        if(bioID.canEvaluatePolicy()){
            if(bioID.biometricType() == BiometricType.faceID) {
                topButton.setTitle(NSLocalizedString("id_enable_face_id", comment: ""), for: UIControlState.normal)
            } else if (bioID.biometricType() == BiometricType.touchID) {
                topButton.setTitle(NSLocalizedString("id_enable_touch_id", comment: ""), for: UIControlState.normal)
            } else {
                topButton.isUserInteractionEnabled = false
                topButton.backgroundColor = UIColor.customTitaniumLight()
                topButton.setTitle(NSLocalizedString("id_touchface_id_not_available", comment: ""), for: UIControlState.normal)
            }
        } else {
            topButton.isUserInteractionEnabled = false
            topButton.backgroundColor = UIColor.customTitaniumLight()
            topButton.setTitle(NSLocalizedString("id_touchface_id_not_available", comment: ""), for: UIControlState.normal)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topButton.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let pinController = segue.destination as? PinLoginViewController {
            pinController.setPinMode = true
        }
    }

    @IBAction func EnableBioClicked(_ sender: Any) {
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
                        SettingsStore.shared.setScreenLockSettings()
                        let network = getNetworkSettings().network
                        KeychainHelper.savePassword(service: "bioPassword", account: network, data: password)
                        KeychainHelper.savePassword(service: "bioData", account: network, data: result!)
                        self.performSegue(withIdentifier: "improveSecurity", sender: self)
                    }.catch { error in
                        print("setPin failed")
                }
            } else {
                //here?
            }
        }
    }
}
