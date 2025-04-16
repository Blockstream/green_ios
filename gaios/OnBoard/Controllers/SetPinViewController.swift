import UIKit
import core
import gdk
import greenaddress

enum ActionPin {
    case set
    case verify
}

enum PinFlow {
    case create
    case restore
    case settings
}

class SetPinViewController: UIViewController {
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet var keyButton: [UIButton]?
    @IBOutlet var pinLabel: [UILabel]?
    @IBOutlet weak var btnNext: UIButton!
    
    private var pinCodeToVerify = ""
    private var pinCode = ""
    private var actionPin = ActionPin.set
    
    var pinFlow = PinFlow.create
    var viewModel: OnboardViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setContent()
        setStyle()
        customBack()
        setActions()
        
        view.accessibilityIdentifier = AccessibilityIdentifiers.SetPinScreen.view
        keyButton![0].accessibilityIdentifier = AccessibilityIdentifiers.SetPinScreen.btn1
        keyButton![1].accessibilityIdentifier = AccessibilityIdentifiers.SetPinScreen.btn2
        btnNext.accessibilityIdentifier = AccessibilityIdentifiers.SetPinScreen.nextBtn
        
        if actionPin == .set {
            switch self.pinFlow {
            case .settings:
                AnalyticsManager.shared.recordView(.walletSettingsChangePIN, sgmt: AnalyticsManager.shared.sessSgmt(AccountsRepository.shared.current))
            case .create:
                AnalyticsManager.shared.recordView(.onBoardPin, sgmt: AnalyticsManager.shared.onBoardSgmtUnified(flow: AnalyticsManager.OnBoardFlow.strCreate))
            case .restore:
                AnalyticsManager.shared.recordView(.onBoardPin, sgmt: AnalyticsManager.shared.onBoardSgmtUnified(flow: AnalyticsManager.OnBoardFlow.strRestore))
            }
        }
    }
    
    func customBack() {
        let view = UIView()
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.setTitle("id_back".localized, for: .normal)
        button.addTarget(self, action: #selector(SetPinViewController.back(sender:)), for: .touchUpInside)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
        button.sizeToFit()
        view.addSubview(button)
        view.frame = button.bounds
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: view)
        navigationItem.hidesBackButton = true
    }
    
    @objc func back(sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }
    
    func setContent() {
        title = ""
        
        switch actionPin {
        case .set:
            lblTitle.text = "id_set_a_pin".localized
        case .verify:
            lblTitle.text = "id_verify_your_pin".localized
        }
        
        lblHint.text = "id_youll_need_your_pin_to_log_in".localized
        btnNext.setTitle("id_continue".localized, for: .normal)
    }
    
    func setStyle() {
        btnNext.cornerRadius = 4.0
    }
    
    func setActions() {
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        pinCode = ""
        cancelButton.addTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        for button in keyButton!.enumerated() {
            button.element.addTarget(self, action: #selector(keyClick(sender:)), for: .touchUpInside)
        }
        reload()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: EventType.Tor.rawValue), object: nil)
        
        cancelButton.removeTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        deleteButton.removeTarget(self, action: #selector(click(sender:)), for: .touchUpInside)
        for button in keyButton!.enumerated() {
            button.element.removeTarget(self, action: #selector(keyClick(sender:)), for: .touchUpInside)
        }
    }
    
    @objc func keyClick(sender: UIButton) {
        
        if pinCode.count == 6 { return }
        
        pinCode += (sender.titleLabel?.text)!
        reload()
        guard pinCode.count == 6 else {
            return
        }
        
        switch actionPin {
        case .set:
            moveToNext()
        case .verify:
            verifyPins()
        }
    }
    
    func verifyPins() {
        if pinCode == pinCodeToVerify {
            nextSetEnabled(true)
        } else {
            DropAlert().error(message: "id_pins_do_not_match_please_try".localized)
            navigationController?.popViewController(animated: true)
        }
    }
    
    func reload() {
        pinLabel?.enumerated().forEach {(index, label) in
            if index < pinCode.count {
                label.textColor = UIColor.gAccent()
            } else {
                label.textColor = UIColor.black
            }
        }
        switch actionPin {
        case .set:
            nextSetEnabled(pinCode.count == 6)
        case .verify:
            nextSetEnabled(pinCode.count == 6 && (pinCode == pinCodeToVerify))
        }
    }
    
    func nextSetEnabled(_ isEnabled: Bool) {
        btnNext.backgroundColor = ( isEnabled ? UIColor.gAccent() : UIColor.customBtnOff())
        btnNext.isEnabled = isEnabled
        btnNext.setTitleColor(( isEnabled ? UIColor.white : UIColor.customGrayLight()), for: .normal)
    }
    
    @objc func click(sender: UIButton) {
        if sender == deleteButton {
            if pinCode.count > 0 {
                pinCode.removeLast()
            }
        } else if sender == cancelButton {
            pinCode = ""
        }
        reload()
    }
    
    func moveToNext() {
        switch actionPin {
        case .set:
            let storyboard = UIStoryboard(name: "OnBoard", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "SetPinViewController") as? SetPinViewController {
                vc.pinCodeToVerify = pinCode
                vc.actionPin = .verify
                vc.pinFlow = pinFlow
                vc.viewModel = viewModel
                navigationController?.pushViewController(vc, animated: true)
            }
        case .verify:
            let pin = self.pinCode
            Task { [weak self] in
                await self?.setPin(pin)
            }
        }
    }
    
    @IBAction func btnNext(_ sender: Any) {
        moveToNext()
    }
    
    fileprivate func setPin(_ pin: String) async {
        let pinFlow = self.pinFlow
        let task = Task.detached { [weak self] in
            switch pinFlow {
            case .settings:
                await self?.startLoader(message: "id_setting_up_your_wallet".localized, isRive: true)
                guard let credentials = try await WalletManager.current?.prominentSession?.getCredentials(password: "") else {
                    throw LoginError.failed("")
                }
                return try await self?.viewModel.setupPinWallet(credentials: credentials, pin: pin)
            case .restore:
                await self?.startLoader(message: "id_restoring_your_wallet".localized, isRive: true)
                guard let credentials = OnboardViewModel.credentials else {
                    throw LoginError.failed("")
                }
                return try await self?.viewModel.restoreWallet(credentials: credentials, pin: pin)
            case .create:
                await self?.startLoader(message: "id_finishing_up".localized, isRive: true)
                return try await self?.viewModel.createWallet(pin: pin)
            }
        }
        switch await task.result {
        case .success(let wallet):
            stopLoader()
            switch pinFlow {
            case .settings:
                navigationController?.popToRootViewController(animated: true)
            case .restore:
                if let account = wallet?.account {
                    AccountsRepository.shared.current = account
                    AccountNavigator.goLogged(accountId: account.id, isFirstLoad: false)
                }
            case .create:
                if let account = wallet?.account {
                    AccountsRepository.shared.current = account
                    AccountNavigator.goLogged(accountId: account.id, isFirstLoad: true)
                }
            }
        case .failure(let error):
            stopLoader()
            showError(error)
        }
    }
}
