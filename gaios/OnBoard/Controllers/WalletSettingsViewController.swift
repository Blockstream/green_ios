import UIKit
import core

protocol WalletSettingsViewControllerDelegate: AnyObject {
    func didSet(tor: Bool)
    func didSet(testnet: Bool)
}

class WalletSettingsViewController: KeyboardViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!

    @IBOutlet weak var cardTor: UIView!
    @IBOutlet weak var lblTorTitle: UILabel!
    @IBOutlet weak var lblTorHint: UILabel!
    @IBOutlet weak var switchTor: UISwitch!

    @IBOutlet weak var cardAnalytics: UIView!
    @IBOutlet weak var lblAnalyticsTitle: UILabel!
    @IBOutlet weak var lblAnalyticsHint: UILabel!
    @IBOutlet weak var btnAnalytics: UIButton!
    @IBOutlet weak var switchAnalytics: UISwitch!

    @IBOutlet weak var cardExperimental: UIView!
    @IBOutlet weak var lblExperimentalTitle: UILabel!
    @IBOutlet weak var lblExperimentalHint: UILabel!
    @IBOutlet weak var switchExperimental: UISwitch!

    @IBOutlet weak var cardDiscountFees: UIView!
    @IBOutlet weak var lblDiscountFeesTitle: UILabel!
    @IBOutlet weak var lblDiscountFeesHint: UILabel!
    @IBOutlet weak var switchDiscountFees: UISwitch!

    @IBOutlet weak var cardProxy: UIView!
    @IBOutlet weak var lblProxyTitle: UILabel!
    @IBOutlet weak var lblProxyHint: UILabel!
    @IBOutlet weak var cardProxyDetail: UIView!
    @IBOutlet weak var switchProxy: UISwitch!
    @IBOutlet weak var fieldProxyIp: UITextField!

    @IBOutlet weak var cardRememberHW: UIView!
    @IBOutlet weak var lblRememberHWTitle: UILabel!
    @IBOutlet weak var lblRememberHWHint: UILabel!
    @IBOutlet weak var switchRememberHW: UISwitch!

    @IBOutlet weak var cardTestnet: UIView!
    @IBOutlet weak var lblTestnetTitle: UILabel!
    @IBOutlet weak var lblTestnetHint: UILabel!
    @IBOutlet weak var switchTestnet: UISwitch!
    @IBOutlet weak var cardSPV: UIView!
    @IBOutlet weak var lblSPVTitle: UILabel!

    @IBOutlet weak var cardSPVPersonalNode: UIView!
    @IBOutlet weak var lblSPVPersonalNodeTitle: UILabel!
    @IBOutlet weak var lblSPVPersonalNodeHint: UILabel!
    @IBOutlet weak var switchPSPVPersonalNode: UISwitch!
    @IBOutlet weak var cardSPVPersonalNodeDetails: UIView!

    @IBOutlet weak var cardSPVbtcServer: UIView!
    @IBOutlet weak var lblSPVbtcServer: UILabel!
    @IBOutlet weak var fieldSPVbtcServer: UITextField!

    @IBOutlet weak var cardSPVliquidServer: UIView!
    @IBOutlet weak var lblSPVliquidServer: UILabel!
    @IBOutlet weak var fieldSPVliquidServer: UITextField!

    @IBOutlet weak var cardSPVtestnetServer: UIView!
    @IBOutlet weak var lblSPVtestnetServer: UILabel!
    @IBOutlet weak var fieldSPVtestnetServer: UITextField!

    @IBOutlet weak var cardSPVliquidTestnetServer: UIView!
    @IBOutlet weak var lblSPVliquidTestnetServer: UILabel!
    @IBOutlet weak var fieldSPVliquidTestnetServer: UITextField!

    @IBOutlet weak var cardElectrumGapLimit: UIView!
    @IBOutlet weak var lblElectrumGapLimit: UILabel!
    @IBOutlet weak var fieldElectrumGapLimit: UITextField!
    @IBOutlet weak var lblDescElectrumGapLimit: UILabel!

    @IBOutlet weak var cardTxCheck: UIView!
    @IBOutlet weak var lblTxCheckTitle: UILabel!
    @IBOutlet weak var lblTxCheckHint: UILabel!
    @IBOutlet weak var switchTxCheck: UISwitch!

    @IBOutlet weak var cardMulti: UIView!
    @IBOutlet weak var lblMultiTitle: UILabel!
    @IBOutlet weak var lblMultiHint: UILabel!

    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnSave: UIButton!

    @IBOutlet weak var lblElectrumTls: UILabel!
    @IBOutlet weak var switchElectrumTls: UISwitch!

    weak var delegate: WalletSettingsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        cardExperimental.isHidden = false
        cardDiscountFees.isHidden = true

        fieldProxyIp.delegate = self
        fieldSPVbtcServer.delegate = self
        fieldSPVliquidServer.delegate = self
        fieldSPVtestnetServer.delegate = self
        fieldSPVliquidTestnetServer.delegate = self

        setContent()
        setStyle()
        reload()

        view.accessibilityIdentifier = AccessibilityIdentifiers.WalletSettingsScreen.view
        switchTor.accessibilityIdentifier = AccessibilityIdentifiers.WalletSettingsScreen.torSwitch
        btnSave.accessibilityIdentifier = AccessibilityIdentifiers.WalletSettingsScreen.saveBtn
        btnCancel.accessibilityIdentifier = AccessibilityIdentifiers.WalletSettingsScreen.cancelBtn
        switchTestnet.accessibilityIdentifier = AccessibilityIdentifiers.WalletSettingsScreen.testnetSwitch
        switchAnalytics.isOn = AnalyticsManager.shared.consent == .authorized

        AnalyticsManager.shared.recordView(.appSettings)
    }

    func setContent() {
        title = ""
        lblTitle.text = NSLocalizedString("id_app_settings", comment: "")
        lblHint.text = NSLocalizedString("id_these_settings_apply_for_every", comment: "")
        lblTorTitle.text = NSLocalizedString("id_connect_with_tor", comment: "")
        lblTorHint.text = NSLocalizedString("id_private_but_less_stable", comment: "")
        lblTestnetTitle.text = NSLocalizedString("id_enable_testnet", comment: "")
        lblTestnetHint.text = ""
        lblAnalyticsTitle.text = NSLocalizedString("id_help_green_improve", comment: "")
        lblAnalyticsHint.text = NSLocalizedString("id_enable_limited_usage_data", comment: "")
        btnAnalytics.setTitle(NSLocalizedString("id_more_info", comment: ""), for: .normal)
        lblExperimentalTitle.text = "id_enable_experimental_features".localized
        lblExperimentalHint.text = "id_experimental_features_might".localized
        lblDiscountFeesTitle.text = "Discount Fees".localized
        lblDiscountFeesHint.text = "".localized
        lblProxyTitle.text = NSLocalizedString("id_connect_through_a_proxy", comment: "")
        lblProxyHint.text = ""
        fieldProxyIp.placeholder = NSLocalizedString("id_server_ip_and_port_ipport", comment: "")
        lblRememberHWTitle.text = "id_remember_hardware_devices".localized
        lblRememberHWHint.text = ""
        lblSPVTitle.text = NSLocalizedString("id_custom_servers_and_validation", comment: "")
        lblSPVPersonalNodeTitle.text = NSLocalizedString("id_personal_electrum_server", comment: "")
        lblSPVPersonalNodeHint.text = NSLocalizedString("id_choose_the_electrum_servers_you", comment: "")
        lblSPVbtcServer.text = NSLocalizedString("id_bitcoin_electrum_server", comment: "")
        lblSPVliquidServer.text = NSLocalizedString("id_liquid_electrum_server", comment: "")
        lblSPVliquidTestnetServer.text = NSLocalizedString("id_liquid_testnet_electrum_server", comment: "")
        lblSPVtestnetServer.text = NSLocalizedString("id_testnet_electrum_server", comment: "")
        lblElectrumGapLimit.text = NSLocalizedString("id_electrum_server_gap_limit", comment: "")
        fieldSPVbtcServer.placeholder = NSLocalizedString("id_server_ip_and_port_ipport", comment: "")
        fieldSPVliquidServer.placeholder = NSLocalizedString("id_server_ip_and_port_ipport", comment: "")
        fieldSPVtestnetServer.placeholder = NSLocalizedString("id_server_ip_and_port_ipport", comment: "")
        lblElectrumTls.text = NSLocalizedString("id_enable_tls", comment: "")
        lblTxCheckTitle.text = NSLocalizedString("id_spv_verification", comment: "")
        lblTxCheckHint.text = NSLocalizedString("id_verify_your_bitcoin", comment: "")
        lblMultiTitle.text = NSLocalizedString("id_multiserver_validation", comment: "")
        lblMultiHint.text = NSLocalizedString("id_double_check_spv_with_other", comment: "")
        lblDescElectrumGapLimit.text = "id_number_of_consecutive_empty".localized
        btnCancel.setTitle(NSLocalizedString("id_cancel", comment: ""), for: .normal)
        btnSave.setTitle(NSLocalizedString("id_save", comment: ""), for: .normal)
        fieldSPVbtcServer.placeholder = GdkSettings.btcElectrumSrvDefaultEndPoint
        fieldSPVliquidServer.placeholder = GdkSettings.liquidElectrumSrvDefaultEndPoint
        fieldSPVtestnetServer.placeholder = GdkSettings.testnetElectrumSrvDefaultEndPoint
        fieldSPVliquidTestnetServer.placeholder = GdkSettings.liquidTestnetElectrumSrvDefaultEndPoint
    }

    func setStyle() {
        btnCancel.cornerRadius = 4.0
        btnSave.cornerRadius = 4.0
        let fields = [fieldProxyIp, fieldSPVbtcServer, fieldSPVliquidServer, fieldSPVtestnetServer, fieldSPVliquidTestnetServer, fieldElectrumGapLimit]
        fields.forEach {
            $0?.setLeftPaddingPoints(10.0)
            $0?.setRightPaddingPoints(10.0)
        }
        cardMulti.alpha = 0.5
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txtBigger)
        [lblTorTitle, lblTestnetTitle, lblAnalyticsTitle, lblExperimentalTitle, lblDiscountFeesTitle, lblProxyTitle, lblRememberHWTitle, lblSPVPersonalNodeTitle, lblMultiTitle, lblTxCheckTitle].forEach { $0?.setStyle(.txtBigger)}
        [lblTorHint, lblTestnetHint, lblAnalyticsHint, lblExperimentalHint, lblDiscountFeesHint, lblProxyHint, lblRememberHWHint, lblSPVPersonalNodeHint, lblMultiHint, lblTxCheckHint].forEach { $0?.setStyle(.txtCard)}
        btnAnalytics.setStyle(.inline)
        lblSPVTitle.setStyle(.subTitle)
    }

    @objc func donePressed() {
        navigationController?.popViewController(animated: true)
    }

    func reload() {
        let appSettings = AppSettings.shared
        guard let gdkSettings = appSettings.gdkSettings else { return }
        switchTor.setOn(gdkSettings.tor ?? false, animated: true)
        switchProxy.setOn(gdkSettings.proxy ?? false, animated: true)
        if let socks5 = gdkSettings.socks5Hostname,
           let port = gdkSettings.socks5Port,
           !socks5.isEmpty && !port.isEmpty {
            fieldProxyIp.text = "\(socks5):\(port)"
        }
        switchRememberHW.setOn(!appSettings.rememberHWIsOff, animated: true)
        cardExperimental.isHidden = false
        switchExperimental.setOn(appSettings.experimental, animated: true)
        switchDiscountFees.setOn(gdkSettings.discountFees ?? false, animated: true)

        switchTestnet.setOn(appSettings.testnet, animated: true)
        switchTxCheck.setOn(gdkSettings.spvEnabled ?? false, animated: true)
        switchPSPVPersonalNode.setOn(gdkSettings.personalNodeEnabled ?? false, animated: true)
        switchElectrumTls.setOn(gdkSettings.electrumTls ?? true, animated: true)

        if let uri = gdkSettings.btcElectrumSrv, !uri.isEmpty {
            fieldSPVbtcServer.text = uri
        }
        if let uri = gdkSettings.liquidElectrumSrv, !uri.isEmpty {
            fieldSPVliquidServer.text = uri
        }
        if let uri = gdkSettings.testnetElectrumSrv, !uri.isEmpty {
            fieldSPVtestnetServer.text = uri
        }
        if let uri = gdkSettings.liquidTestnetElectrumSrv, !uri.isEmpty {
            fieldSPVliquidTestnetServer.text = uri
        }
        if let gap = gdkSettings.gapLimit {
            fieldElectrumGapLimit.text = "\(gap)"
        }
        switchPSPVPersonalNode(switchPSPVPersonalNode)
        switchProxyChange(switchProxy)

    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)

        guard let userInfo = notification.userInfo else { return }
        // swiftlint:disable force_cast
        var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)

        var contentInset: UIEdgeInsets = self.scrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 20
        scrollView.contentInset = contentInset
    }

    override func keyboardWillHide(notification: Notification) {
        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInset
        super.keyboardWillHide(notification: notification)
    }

    @IBAction func switchProxyChange(_ sender: UISwitch) {
        cardProxyDetail.isHidden = !sender.isOn
    }

    @IBAction func switchRememberHWChange(_ sender: UISwitch) { }

    @IBAction func switchExperimentalChange(_ sender: UISwitch) { }

    @IBAction func switchPSPVPersonalNode(_ sender: UISwitch) {
        cardSPVPersonalNodeDetails.isHidden = !sender.isOn
        cardSPVtestnetServer.isHidden = !switchTestnet.isOn
        cardSPVliquidTestnetServer.isHidden = !switchTestnet.isOn
    }

    @IBAction func switchTestnet(_ sender: Any) {
        cardSPVtestnetServer.isHidden = !switchTestnet.isOn
        cardSPVliquidTestnetServer.isHidden = !switchTestnet.isOn
    }

    @IBAction func btnCancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func btnSave(_ sender: Any) {
        let socks5 = fieldProxyIp.text ?? ""
        if switchProxy.isOn && socks5.isEmpty {
            showAlert(title: NSLocalizedString("id_warning", comment: ""),
                      message: NSLocalizedString("id_socks5_proxy_and_port_must_be", comment: ""))
            return
        }
        let gdkSettings = AppSettings.shared.gdkSettings
        var gapLimit: Int? = nil
        if let gapText = fieldElectrumGapLimit.text, !gapText.isEmpty {
            gapLimit = Int(gapText)
        }
        let newSettings = GdkSettings(
            tor: switchTor.isOn,
            proxy: switchProxy.isOn,
            socks5Hostname: String(socks5.split(separator: ":").first ?? ""),
            socks5Port: String(socks5.split(separator: ":").last ?? ""),
            spvEnabled: switchTxCheck.isOn,
            personalNodeEnabled: switchPSPVPersonalNode.isOn,
            btcElectrumSrv: fieldSPVbtcServer.text,
            liquidElectrumSrv: fieldSPVliquidServer.text,
            testnetElectrumSrv: fieldSPVtestnetServer.text,
            liquidTestnetElectrumSrv: fieldSPVliquidTestnetServer.text,
            electrumTls: switchPSPVPersonalNode.isOn && switchElectrumTls.isOn,
            gapLimit: gapLimit,
            discountFees: switchDiscountFees.isOn
        )
        AppSettings.shared.testnet = switchTestnet.isOn
        AppSettings.shared.experimental = switchExperimental.isOn
        AppSettings.shared.rememberHWIsOff = !switchRememberHW.isOn
        AppSettings.shared.gdkSettings = newSettings

        switch AnalyticsManager.shared.consent { // current value
        case .authorized:
            if switchAnalytics.isOn {
                // no change
            } else {
                AnalyticsManager.shared.consent = .denied
            }
        case .notDetermined:
            if switchAnalytics.isOn {
                AnalyticsManager.shared.consent = .authorized
            } else {
//                AnalyticsManager.shared.consent = .denied
            }
        case .denied:
            if switchAnalytics.isOn {
                AnalyticsManager.shared.consent = .authorized
            } else {
                // no change
            }
        }
        let session = WalletManager.current?.prominentSession?.session
        AnalyticsManager.shared.setupSession(session: session)
        delegate?.didSet(tor: switchTor.isOn)
        delegate?.didSet(testnet: switchTestnet.isOn)
        navigationController?.popViewController(animated: true)
    }

    @IBAction func btnAnalytics(_ sender: Any) {

        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogCountlyViewController") as? DialogCountlyViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.disableControls = true
            self.present(vc, animated: false, completion: nil)
        }
    }
}

extension WalletSettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}
