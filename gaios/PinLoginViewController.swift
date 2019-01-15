import Foundation
import UIKit
import NVActivityIndicatorView
import PromiseKit

class PinLoginViewController: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var label0: UILabel!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    @IBOutlet weak var label5: UILabel!
    @IBOutlet weak var attempts: UILabel!
    @IBOutlet weak var skipButton: UIButton!

    var pinCode = String()
    var pinConfirm = String()

    var setPinMode: Bool = false
    var editPinMode: Bool = false
    var restoreMode: Bool = false

    var confirmPin: Bool = false
    var labels = [UILabel]()
    var attemptsCount = 3

    override func viewDidLoad() {
        super.viewDidLoad()

        // show title
        if (setPinMode == true) {
            title = NSLocalizedString("id_create_a_pin_to_access_your", comment: "")
        } else {
            title = NSLocalizedString("id_enter_pin", comment: "")
        }

        // show pin label
        labels.append(contentsOf: [label0, label1, label2, label3, label4, label5])

        // customize network image
        let network = getNetwork()
        let networkImage = network == "Mainnet".lowercased() ? "btc" : "btc_testnet"
        let networkBarItem = UIBarButtonItem(image: UIImage(named: networkImage)!, style: .plain, target: self, action: nil)
        navigationItem.rightBarButtonItem = networkBarItem

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(PinLoginViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton

        // show skip button
        if (setPinMode || restoreMode) && !editPinMode {
            skipButton.isHidden = false
            skipButton.setTitle(NSLocalizedString("id_skip", comment: ""), for: .normal)
        }
    }

    fileprivate func loginWithPin(usingAuth: String, network: String, withPIN: String?) {
        let bgq = DispatchQueue.global(qos: .background)
        let appDelegate = getAppDelegate()
        let isBiometricLogin = usingAuth == AuthenticationTypeHandler.AuthKeyBiometric

        firstly {
            startAnimating(message: !isBiometricLogin ? NSLocalizedString("id_logging_in", comment: "") : "")
            return Guarantee()
        }.compactMap(on: bgq) {
            try appDelegate.disconnect()
        }.compactMap(on: bgq) {
            try appDelegate.connect()
        }.get { _ in
            if isBiometricLogin {
                self.stopAnimating()
            }
        }.compactMap(on: bgq) {
            try AuthenticationTypeHandler.getAuth(method: usingAuth, forNetwork: network)
        }.get { _ in
            if isBiometricLogin {
                self.startAnimating(message: NSLocalizedString("id_logging_in", comment: ""))
            }
        }.map(on: bgq) {
            assert(withPIN != nil || isBiometricLogin)

            let jsonData = try JSONSerialization.data(withJSONObject: $0)
            try getSession().loginWithPin(pin: withPIN ?? $0["plaintext_biometric"] as! String, pin_data: String(data: jsonData, encoding: .utf8)!)
        }.ensure {
            self.stopAnimating()
        }.done {
            self.performSegue(withIdentifier: "main", sender: self)
        }.catch { error in
            let message: String
            if let authError = error as? AuthenticationTypeHandler.AuthError {
                if authError == AuthenticationTypeHandler.AuthError.CanceledByUser {
                    return
                } else {
                    message = NSLocalizedString("id_login_failed", comment: "")
                }
            } else {
                guard let error = error as? GaError else { return }
                if error == .GenericError, let _ = withPIN {
                    self.attemptsCount -= 1
                    if self.attemptsCount == 0 {
                        removeKeychainData()
                        self.stopAnimating()
                        self.performSegue(withIdentifier: "entrance", sender: nil)
                        return
                    }
                    message = NSLocalizedString("id_login_failed", comment: "")
                } else {
                    message = NSLocalizedString("id_you_are_not_connected_to_the", comment: "")
                }
            }
            self.updateAttemptsLabel()
            self.resetEverything()
            self.startAnimating(message: message)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                self.stopAnimating()
            }
        }
    }

    fileprivate func setPin() {
        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            startAnimating(message: "")
            return Guarantee()
        }.compactMap(on: bgq) {
            let mnemonics = getAppDelegate().getMnemonicWordsString()
            return try getSession().setPin(mnemonic: mnemonics!, pin: self.pinCode, device: String.random(length: 14))
        }.map(on: bgq) { (data: [String: Any]) -> Void in
            let network = getNetwork()
            try AuthenticationTypeHandler.addPIN(data: data, forNetwork: network)
        }.ensure {
            self.stopAnimating()
        }.done {
            if self.editPinMode {
                self.navigationController?.popViewController(animated: true)
            } else if self.restoreMode {
                self.performSegue(withIdentifier: "main", sender: nil)
            } else {
                self.performSegue(withIdentifier: "congrats", sender: self)
            }
        }.catch { error in
            let message: String
            if let err = error as? GaError, err != GaError.GenericError {
                message = NSLocalizedString("id_you_are_not_connected_to_the", comment: "")
            } else {
                message = NSLocalizedString("id_operation_failure", comment: "")
            }
            self.startAnimating(message: message)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                self.stopAnimating()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetEverything()
        updateView()
        updateAttemptsLabel()
        if setPinMode || confirmPin {
            return
        }

        let network = getNetwork()
        let bioAuth = AuthenticationTypeHandler.findAuth(method: AuthenticationTypeHandler.AuthKeyBiometric, forNetwork: network)
        if bioAuth {
            loginWithPin(usingAuth: AuthenticationTypeHandler.AuthKeyBiometric, network: network, withPIN: nil)
        }
    }

    func updateAttemptsLabel() {
        attempts.text = String(format: NSLocalizedString("id_d_attempts_remaining", comment: ""), attemptsCount)
        attempts.isHidden = attemptsCount == 3
    }

    func updatePinMismatch() {
        attempts.text = NSLocalizedString("id_pins_do_not_match_please_try", comment: "")
        attempts.isHidden = false
    }

    @IBAction func skipButtonClicked(_ sender: UIButton) {
        if self.restoreMode {
            self.performSegue(withIdentifier: "main", sender: nil)
        } else {
            self.performSegue(withIdentifier: "congrats", sender: self)
        }
    }

    @IBAction func numberClicked(_ sender: UIButton) {
        pinCode += (sender.titleLabel?.text)!
        updateView()
        if (pinCode.count < 6) {
            return
        }

        if (setPinMode == true) {
            if (confirmPin == true) {
                //set pin
                if(pinCode != pinConfirm) {
                    title = NSLocalizedString("id_set_a_new_pin", comment: "")
                    resetEverything()
                    updatePinMismatch()
                    skipButton.isHidden = true
                    return
                }
                setPin()
                return
            }
            confirmPin = true
            pinConfirm = pinCode
            pinCode = ""
            updateView()
            updateAttemptsLabel()
            //show confirm pin
            title = NSLocalizedString("id_verify_your_pin", comment: "")
        } else {
            let network = getNetwork()
            loginWithPin(usingAuth: AuthenticationTypeHandler.AuthKeyPIN, network: network, withPIN: self.pinCode)
        }
    }

    func resetEverything() {
        confirmPin = false
        pinCode = ""
        updateView()
    }

    func updateView() {
        for (i, label) in labels.enumerated() {
            if i < pinCode.count {
                label.text = "*"
                label.isHidden = false
            } else {
                label.isHidden = true
            }
        }
    }

    @IBAction func deleteClicked(_ sender: UIButton) {
        if(pinCode.count > 0) {
            pinCode.removeLast()
            updateView()
        }
    }

    @objc func back(sender: UIBarButtonItem) {
        if(setPinMode || editPinMode) {
            self.navigationController?.popViewController(animated: true)
        } else {
            self.performSegue(withIdentifier: "entrance", sender: nil)
        }
    }
}
