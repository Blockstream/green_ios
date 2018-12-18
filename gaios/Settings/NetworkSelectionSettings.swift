import Foundation
import UIKit

class NetworkSelectionSettings: KeyboardViewController, UITextFieldDelegate {

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
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var socks5Hostname: UITextField!
    @IBOutlet weak var socks5Port: UITextField!

    private let topConstantNoProxy: CGFloat = 130
    private let topConstantWithProxy: CGFloat = 20

    var torLabelConstraint: NSLayoutConstraint!
    var torSwitchConstraint: NSLayoutConstraint!

    var currentNetworkSelection: String? = nil
    var onSave: (() -> Void)? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupView()
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

    @IBAction func proxySwitchAction(_ sender: Any) {
        guard let switcher = sender as? UISwitch else {
            return
        }
        proxySettings.isHidden = !switcher.isOn
        torLabelConstraint.isActive = !switcher.isOn
        torSwitchConstraint.isActive = !switcher.isOn
        topConstraint.constant = !switcher.isOn ? topConstantNoProxy : topConstantWithProxy
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
        topConstraint.constant = proxySettings.isHidden ? topConstantNoProxy : topConstantWithProxy
        torLabelConstraint = NSLayoutConstraint(item: torLabel, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: proxyLabel, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 16)
        torSwitchConstraint = NSLayoutConstraint(item: torSwitch, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: proxySwitch, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 16)
        torLabelConstraint.isActive = proxySettings.isHidden
        torSwitchConstraint.isActive = proxySettings.isHidden

        proxySwitch.isOn = defaults?["proxy"] as? Bool ?? false
        socks5Hostname.text = defaults?["socks5_hostname"] as? String ?? ""
        socks5Port.text = defaults?["socks5_hostname"] as? String ?? ""
        torSwitch.isOn = defaults?["tor"] as? Bool ?? false

        saveButton.applyHorizontalGradient(colours: [UIColor.customMatrixGreenDark(), UIColor.customMatrixGreen()])
    }
}
