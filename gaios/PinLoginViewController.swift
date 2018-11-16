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

    var pinCode: String = ""
    var pinData: String = ""
    var pinConfirm: String = ""
    var bioData: String = ""
    var password: String = ""

    var setPinMode: Bool = false
    var editPinMode: Bool = false
    var removePinMode: Bool = false
    var restoreMode: Bool = false

    var confirmPin: Bool = false
    var bioAuth: Bool = false
    let bioID = BiometricIDAuth()


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
        let network = getNetwork()
        if let data = KeychainHelper.loadPassword(service: "pinData", account: network.rawValue) {
            pinData = data
        }

        // show pin label
        labels.append(contentsOf: [label0, label1, label2, label3, label4, label5])
        for label in labels {
            label.isHidden = true
        }
        attempts.isHidden = true

        // customize network image
        let networkBarItem = UIBarButtonItem(image: network == Network.MainNet ? UIImage(named: "mainnet")! : UIImage(named: "testnet")!, style: .plain, target: self, action: nil)
        navigationItem.rightBarButtonItem = networkBarItem

        // customize back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(image: UIImage.init(named: "backarrow"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(PinLoginViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateView()
        if (bioAuth) {
            bioID.authenticateUser { (message) in
                if(message == nil) {
                    let size = CGSize(width: 30, height: 30)
                    self.startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
                    DispatchQueue.global(qos: .background).async {
                        wrap { return try getSession().loginWithPin(pin: self.password, pin_data: self.bioData) }.done { _ in
                            DispatchQueue.main.async {
                                self.stopAnimating()
                                AccountStore.shared.initializeAccountStore()
                                self.performSegue(withIdentifier: "main", sender: self)
                            }
                            }.catch { error in
                                print("incorrect PIN ", error)
                                DispatchQueue.main.async {
                                    NVActivityIndicatorPresenter.sharedInstance.setMessage("Bio Login Failed")
                                }
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                                    self.stopAnimating()
                                }
                        }
                    }
                } else {
                    //error
                }
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
        updateView()
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
                        .done { (result: String?) in
                            guard result != nil else {
                                self.stopAnimating()
                                return
                            }
                            DispatchQueue.main.async {
                                self.stopAnimating()
                                let network = getNetworkSettings().network
                                KeychainHelper.savePassword(service: "pinData", account: network, data: result!)
                                //pinPassword used when removing the pin, not used for login(user input is used)
                                KeychainHelper.savePassword(service: "pinPassword", account: network, data: self.pinCode)
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
        } else if (removePinMode == true) {
            let network = getNetworkSettings().network
            let pass = KeychainHelper.loadPassword(service: "pinPassword", account: network)
            if (pass == pinCode) {
                AppDelegate.removePinKeychainData()
                SettingsStore.shared.setScreenLockSettings()
            }
            self.navigationController?.popViewController(animated: true)
            return
        } else {
            let size = CGSize(width: 30, height: 30)
            startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            DispatchQueue.global(qos: .background).async {
                wrap { return try getSession().loginWithPin(pin: self.pinCode, pin_data: self.pinData) }.done { _ in
                    DispatchQueue.main.async {
                        self.stopAnimating()
                        AccountStore.shared.initializeAccountStore()
                        self.performSegue(withIdentifier: "main", sender: self)
                    }
                    }.catch { error in
                        print("incorrect PIN ", error)
                        self.attemptsCount -= 1
                        if(self.attemptsCount == 0) {
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

                }
            }
        }
    }

    func resetEverything() {
        confirmPin = false
        pinCode = ""
        updateView()
    }

    func updateView() {
        let count = min(labels.count, pinCode.count)
        for (i, c) in zip(0..<count, pinCode) {
            labels[i].text = String(c)
            labels[i].isHidden = false
        }
        createIndicator(position: pinCode.count)
        for i in count..<labels.count {
            labels[i].isHidden = true
        }
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
