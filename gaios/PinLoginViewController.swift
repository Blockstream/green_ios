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

    var views: Array<UIView> = Array<UIView>()
    var labels: Array<UILabel> = Array<UILabel>()
    var indicator: UIView? = nil
    var attemptsCount = 3

    override func viewDidLoad() {
        super.viewDidLoad()

        // show title
        if (setPinMode == true) {
            title = NSLocalizedString("id_set_a_new_pin", comment: "")
        } else {
            title = NSLocalizedString("id_enter_pin", comment: "")
        }

        // show pin label
        labels.append(contentsOf: [label0, label1, label2, label3, label4, label5])
        for label in labels {
            label.isHidden = true
        }
        attempts.isHidden = true

        // customize network image
        let network = getNetworkSettings().network
        let networkBarItem = UIBarButtonItem(image: UIImage(named: network)!, style: .plain, target: self, action: nil)
        navigationItem.rightBarButtonItem = networkBarItem

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(PinLoginViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton

        // show skip button
        if setPinMode || restoreMode {
            skipButton.isHidden = false
        }
    }

    fileprivate func startAnimation(message: String) -> Promise<Void> {
        return Promise<Void> { seal in
            let size = CGSize(width: 30, height: 30)
            self.startAnimating(size, message: message, messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            seal.fulfill(())
        }
    }

    fileprivate func loginWithPin(usingAuth: String, network: String, withPIN: String?) {
        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            startAnimation(message: "Logging in...")
        }.compactMap(on: bgq) {
            try AuthenticationTypeHandler.getAuth(method: usingAuth, forNetwork: network)
        }.map(on: bgq) {
            assert(withPIN != nil || usingAuth == AuthenticationTypeHandler.AuthKeyBiometric)

            let jsonData = try JSONSerialization.data(withJSONObject: $0)
            try getSession().loginWithPin(pin: withPIN ?? $0["plaintext_biometric"] as! String, pin_data: String(data: jsonData, encoding: .utf8)!)
        }.done {
            AccountStore.shared.initializeAccountStore()
            self.performSegue(withIdentifier: "main", sender: self)
        }.catch { error in
            let authError = error as? AuthenticationTypeHandler.AuthError
            if  authError == AuthenticationTypeHandler.AuthError.CanceledByUser {
                return
            }

            if let _ = withPIN {
                self.attemptsCount -= 1
                if self.attemptsCount == 0 {
                    AppDelegate.removePinKeychainData()
                    self.performSegue(withIdentifier: "entrance", sender: nil)
                }
                self.updateAttemptsLabel()
                self.resetEverything()
            }

            NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
        }.finally {
            self.stopAnimating()
        }
    }

    fileprivate func setPin() {
        let bgq = DispatchQueue.global(qos: .background)

        firstly {
            startAnimation(message: "Setting PIN...")
        }.compactMap(on: bgq) {
            let mnemonics = getAppDelegate().getMnemonicWordsString()
            return try getSession().setPin(mnemonic: mnemonics!, pin: self.pinCode, device: String.random(length: 14))
        }.map(on: bgq) { (data: [String: Any]) -> Void in
            let network = getNetworkSettings().network
            try AuthenticationTypeHandler.addPIN(data: data, forNetwork: network)
        }.done {
            if self.editPinMode {
                self.navigationController?.popViewController(animated: true)
            } else if self.restoreMode {
                self.performSegue(withIdentifier: "main", sender: nil)
            } else {
                self.performSegue(withIdentifier: "congrats", sender: self)
            }
        }.catch { error in
            NVActivityIndicatorPresenter.sharedInstance.setMessage("Setting PIN failed")
        }.finally {
            self.stopAnimating()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateView()
        if setPinMode || confirmPin {
            return
        }

        let network = getNetworkSettings().network
        let bioAuth = AuthenticationTypeHandler.findAuth(method: AuthenticationTypeHandler.AuthKeyBiometric, forNetwork: network)
        if bioAuth {
            loginWithPin(usingAuth: AuthenticationTypeHandler.AuthKeyBiometric, network: network, withPIN: nil)
        }
    }

    func updateAttemptsLabel() {
        attempts.text = String(format: "%d attempts remaining", attemptsCount)
        attempts.isHidden = false
    }

    func updatePinMismatch() {
        attempts.text = "PINs must match"
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
        pinAppend()
        if (pinCode.count < 6) {
            return
        }

        if (setPinMode == true) {
            if (confirmPin == true) {
                //set pin
                if(pinCode != pinConfirm) {
                    title = "Set a new PIN"
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
            //show confirm pin
            title = "Confirm PIN"
        } else {
            let network = getNetworkSettings().network
            loginWithPin(usingAuth: AuthenticationTypeHandler.AuthKeyPIN, network: network, withPIN: self.pinCode)
        }
    }

    func resetEverything() {
        confirmPin = false
        pinCode = ""
        updateView()
    }

    func updateView() {
        for label in labels {
            label.text = "*"
            label.isHidden = false
        }
        createIndicator(position: pinCode.count)
        for label in labels {
            label.isHidden = true
        }
    }

    func pinAppend() {
        let count = self.pinCode.count
        labels[count - 1].text = String(pinCode.last!)
        labels[count - 1].isHidden = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.labels[count - 1].text = "*"
            self.labels[count - 1].sizeToFit()
        }
        createIndicator(position: pinCode.count)
    }

    func createIndicator(position: Int) {
        if (position >= 6) {
            indicator?.isHidden = true
            return
        }
        indicator?.layer.removeAllAnimations()
        indicator?.removeFromSuperview()
        let labelP = labels[position]
        indicator = UIView()
        indicator?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        indicator?.backgroundColor = UIColor.customMatrixGreen()
        indicator?.translatesAutoresizingMaskIntoConstraints = false
        indicator?.alpha = 1.0;
        self.view.addSubview(indicator!)
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 0, constant: 2).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 0, constant: 21).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: labelP, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: indicator!, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: labelP, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: {

        self.indicator?.alpha = 0.0

        }, completion: nil)
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
