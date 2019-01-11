import Foundation
import UIKit

class NetworkSelectionSettings: KeyboardViewController, UITextFieldDelegate, UIScrollViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var bitcoin: UIView!
    @IBOutlet weak var testnet: UIView!
    @IBOutlet weak var localtest: UIView!
    @IBOutlet weak var regtest: UIView!
    @IBOutlet weak var proxySettings: UIView!
    @IBOutlet weak var proxyLabel: UILabel!
    @IBOutlet weak var proxySwitch: UISwitch!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var torSwitch: UISwitch!
    @IBOutlet weak var torLabel: UILabel!
    @IBOutlet weak var socks5Hostname: UITextField!
    @IBOutlet weak var socks5Port: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var proxySettingsLabel: UILabel!

    var torLabelConstraint: NSLayoutConstraint!
    var torSwitchConstraint: NSLayoutConstraint!

    var currentNetworkSelection: String? = nil
    var onSave: (() -> Void)? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
        socks5Hostname.delegate = self
        socks5Port.delegate = self

        bitcoin.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector (handleBitcoinSelection(_:))))
        testnet.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector (handleTestnetSelection(_:))))
        #if DEBUG
        localtest.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector (handleLocaltestSelection(_:))))
        regtest.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector (handleRegtestSelection(_:))))
        #else
        NSLayoutConstraint(item: proxyLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: testnet, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 20).isActive = true
        NSLayoutConstraint(item: proxySwitch, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: testnet, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 15).isActive = true
        localtest.isHidden = true
        regtest.isHidden = true
        #endif

        socks5Hostname.attributedPlaceholder = NSAttributedString(string: "Socks5 Hostname",
                                                               attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        socks5Port.attributedPlaceholder = NSAttributedString(string: "Socks5 Port",
                                                                 attributes: [NSAttributedStringKey.foregroundColor: UIColor.customTitaniumLight()])
        titleLabel.text = NSLocalizedString("id_choose_your_network", comment: "")
        proxyLabel.text = NSLocalizedString("id_connect_through_a_proxy", comment: "")
        proxySettingsLabel.text = NSLocalizedString("id_proxy_settings", comment: "")
        socks5Hostname.text = NSLocalizedString("id_socks5_hostname", comment: "")
        socks5Port.text = NSLocalizedString("id_socks5_port", comment: "")
        torLabel.text = NSLocalizedString("id_connect_with_tor", comment: "")
        saveButton.setTitle(NSLocalizedString("id_save", comment: ""), for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        saveButton.updateGradientLayerFrame()
    }

    private func setBorderColor(_ view: UIView, _ color: UIColor = UIColor.customMatrixGreen()) {
        view.borderColor = color
    }

    private func resetBorderColor() {
        let color = UIColor.customTitaniumLight()
        setBorderColor(bitcoin, color)
        setBorderColor(testnet, color)
        setBorderColor(localtest, color)
        setBorderColor(regtest, color)
    }

    private func handleSelection(_ view: UIView, _ title: String) {
        resetBorderColor()
        setBorderColor(view)
        currentNetworkSelection = title
    }

    @objc func handleBitcoinSelection(_ sender: UITapGestureRecognizer) {
        handleSelection(bitcoin, "Mainnet")
    }

    @objc func handleTestnetSelection(_ sender: UITapGestureRecognizer) {
        handleSelection(testnet, "Testnet")
    }

    @objc func handleLocaltestSelection(_ sender: UITapGestureRecognizer) {
        handleSelection(localtest, "Localtest")
    }

    @objc func handleRegtestSelection(_ sender: UITapGestureRecognizer) {
        handleSelection(regtest, "Regtest")
    }

    @objc override func keyboardWillShow(notification: NSNotification) {
        super.keyboardWillShow(notification: notification)

        let userInfo = notification.userInfo
        let keyboardFrame = userInfo?[UIKeyboardFrameEndUserInfoKey] as! CGRect
        let contentInset = UIEdgeInsetsMake(0.0, 0.0, keyboardFrame.height + socks5Port.frame.height, 0.0)
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }

    @objc override func keyboardWillHide(notification: NSNotification) {
        let contentInset = UIEdgeInsets.zero
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset

        super.keyboardWillHide(notification: notification)
    }

    @IBAction func proxySwitchAction(_ sender: Any) {
        guard let switcher = sender as? UISwitch else {
            return
        }
        proxySettings.isHidden = !switcher.isOn
        torLabelConstraint.isActive = !switcher.isOn
        torSwitchConstraint.isActive = !switcher.isOn
    }

    @IBAction func saveButtonClicked(_ sender: Any) {
        UserDefaults.standard.set(["network": currentNetworkSelection!, "proxy": proxySwitch.isOn, "tor": torSwitch.isOn, "socks5_hostname": socks5Hostname.text ?? "", "socks5_port": socks5Port.text ?? ""], forKey: "network_settings")
        onSave!()
        dismiss(animated: true, completion: nil)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }

    func setupView() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let defaults = getUserNetworkSettings()
        if defaults == nil {
            handleSelection(bitcoin, "Mainnet")
        } else {
            let networkName = defaults!["network"] as! String
            switch networkName {
            case "Mainnet":
                handleSelection(bitcoin, networkName)
            case "Testnet":
                handleSelection(testnet, networkName)
            case "Localtest":
                handleSelection(localtest, networkName)
            case "Regtest":
                handleSelection(regtest, networkName)
            default:
                precondition(false)
            }
        }

        proxySettings.isHidden = !(defaults?["proxy"] as? Bool ?? false)
        torLabelConstraint = NSLayoutConstraint(item: torLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: proxyLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 16)
        torSwitchConstraint = NSLayoutConstraint(item: torSwitch, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: proxySwitch, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 16)
        torLabelConstraint.isActive = proxySettings.isHidden
        torSwitchConstraint.isActive = proxySettings.isHidden

        proxySwitch.isOn = defaults?["proxy"] as? Bool ?? false
        socks5Hostname.text = defaults?["socks5_hostname"] as? String ?? ""
        socks5Port.text = defaults?["socks5_port"] as? String ?? ""
        torSwitch.isOn = defaults?["tor"] as? Bool ?? false

        saveButton.enableWithGradient(true)
    }
}
