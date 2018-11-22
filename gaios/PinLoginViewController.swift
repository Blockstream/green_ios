import Foundation
import UIKit
import NVActivityIndicatorView

class PinLoginViewController: UIViewController, NVActivityIndicatorViewable {

    @IBOutlet weak var label0: UILabel!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    @IBOutlet weak var label5: UILabel!
    @IBOutlet weak var attempts: UILabel!

    var pinCode = String()
    var pinConfirm = String()

    var setPinMode: Bool = false
    var editPinMode: Bool = false
    var restoreMode: Bool = false

    var confirmPin: Bool = false
    var bioAuth: Bool = false
    let bioID = BiometricAuthentication()


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

        // load data
        let network = getNetworkSettings().network
        bioAuth = KeychainHelper.findAuth(method: KeychainHelper.AuthKeyBiometric, forNetwork: network)

        // show pin label
        labels.append(contentsOf: [label0, label1, label2, label3, label4, label5])
        for label in labels {
            label.isHidden = true
        }
        attempts.isHidden = true

        // customize network image
        let networkBarItem = UIBarButtonItem(image: UIImage(named: network)!, style: .plain, target: self, action: nil)
        navigationItem.rightBarButtonItem = networkBarItem

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(PinLoginViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateView()
        if setPinMode || confirmPin {
            return
        }
        if bioAuth {
            let size = CGSize(width: 30, height: 30)
            self.startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            DispatchQueue.global(qos: .background).async {
                defer {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                        self.stopAnimating()
                    }
                }
                let network = getNetworkSettings().network
                let bioData = KeychainHelper.getAuth(method: KeychainHelper.AuthKeyBiometric, forNetwork: network)
                guard bioData != nil else {
                    return
                }
                getGAService().loginWithPin(pin: bioData!["plaintext_biometric"] as! String, pinData: bioData!,
                    completionHandler: completion(
                        onResult: { _ in
                            DispatchQueue.main.async {
                                AccountStore.shared.initializeAccountStore()
                                self.performSegue(withIdentifier: "main", sender: self)
                            }
                        }, onError: { _ in
                            DispatchQueue.main.async {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Bio Login Failed")
                            }
                        }))
            }
        }
    }

    func updateAttemptsLabel() {
        attempts.text = String(format: "%d attempts remaining", attemptsCount)
        attempts.isHidden = false
    }

    func updatePinMissmatch() {
        attempts.text = "PINs must match"
        attempts.isHidden = false
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
                    updatePinMissmatch()
                    return
                }
                let mnemonics = getAppDelegate().getMnemonicWordsString()
                let size = CGSize(width: 30, height: 30)
                startAnimating(size, message: "Setting pin...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
                DispatchQueue.global(qos: .background).async {
                    wrap { return try getSession().setPin(mnemonic: mnemonics!, pin: self.pinCode, device: String.random(length: 10)) }
                    .done { result in
                        guard result != nil else {
                            self.stopAnimating()
                            return
                        }
                        DispatchQueue.main.async {
                            self.stopAnimating()
                            let network = getNetworkSettings().network
                            let succeeded = KeychainHelper.addPIN(data: result!, forNetwork: network)
                            guard succeeded else {
                                return
                            }
                            SettingsStore.shared.setScreenLockSettings()
                            if(self.editPinMode == true) {
                                self.navigationController?.popViewController(animated: true)
                            } else if (self.restoreMode == true) {
                                self.performSegue(withIdentifier: "main", sender: nil)
                            } else {
                                self.performSegue(withIdentifier: "congrats", sender: self)
                            }
                        }
                    }.catch { error in
                            print("setPin failed")
                            DispatchQueue.main.async {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Setting pin failed")
                            }
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
                                self.stopAnimating()
                            }
                    }
                }
                return
            }
            confirmPin = true
            pinConfirm = pinCode
            pinCode = ""
            updateView()
            //show confirm pin
            title = "Confirm PIN"
        } else {
            let size = CGSize(width: 30, height: 30)
            startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            DispatchQueue.global(qos: .background).async {
                let network = getNetworkSettings().network
                let pinData = KeychainHelper.getAuth(method: KeychainHelper.AuthKeyPIN, forNetwork: network)
                guard pinData != nil else {
                    self.stopAnimating()
                    return
                }
                getGAService().loginWithPin(pin: self.pinCode, pinData: pinData!,
                                            completionHandler: completion(
                                                onResult: { _ in
                                                    DispatchQueue.main.async {
                                                        self.stopAnimating()
                                                        AccountStore.shared.initializeAccountStore()
                                                        self.performSegue(withIdentifier: "main", sender: self)
                                                    }
                                            }, onError: { error in
                                                print("incorrect PIN ", error)
                                                self.attemptsCount -= 1
                                                if self.attemptsCount == 0 {
                                                    AppDelegate.removeKeychainData()
                                                    self.performSegue(withIdentifier: "entrance", sender: nil)
                                                }
                                                self.updateAttemptsLabel()
                                                DispatchQueue.main.async {
                                                    NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                                                    self.stopAnimating()
                                                    self.resetEverything()
                                                }
                                            }))
            }
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
            print(pinCode)
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
