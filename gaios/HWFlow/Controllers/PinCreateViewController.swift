import UIKit
import gdk
import hw
import core

class PinCreateViewController: HWFlowBaseViewController {

    @IBOutlet weak var imgDevice: UIImageView!

    @IBOutlet weak var lblStepNumber: UILabel!
    @IBOutlet weak var lblStepTitle: UILabel!
    @IBOutlet weak var lblStepHint: UILabel!
    @IBOutlet weak var lblWarn: UILabel!
    @IBOutlet weak var btnContinue: UIButton!

    var remember = false
    var testnet = false
    var bleHwManager: BleHwManager?
    var scanViewModel: ScanViewModel?
    var account: Account?

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        loadNavigationBtns()
    }

    deinit {
        print("Deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        //loadingIndicator.isAnimating = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        //stop()
    }

    func setContent() {
        imgDevice.image = JadeAsset.img(.selectDual, nil)
        lblStepNumber.text = "id_setup_your_jade".localized.uppercased()
        lblStepTitle.text = "id_create_a_pin".localized
        lblStepHint.text = "id_enter_and_confirm_a_unique_pin".localized
        lblWarn.text = "id_if_you_forget_your_pin_you_will".localized
        btnContinue.setTitle("id_continue".localized, for: .normal)
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gAccent()
        settingsBtn.setTitle("id_setup_guide".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    func setStyle() {
        lblStepNumber.setStyle(.subTitle)
        lblStepTitle.setStyle(.title)
        lblStepHint.setStyle(.subTitle)
        lblWarn.setStyle(.subTitle)
        btnContinue.setStyle(.primary)
    }


    @IBAction func continueBtnTapped(_ sender: Any) {
        btnContinue.isHidden = true
    }

    @objc func setupBtnTapped() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "SetupJadeViewController") as? SetupJadeViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @MainActor
    func onCheckFirmware(version: JadeVersionInfo, lastFirmware: Firmware) {
        let storyboard = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "UpdateFirmwareViewController") as? UpdateFirmwareViewController {
            vc.firmware = lastFirmware
            vc.version = version.jadeVersion
            vc.delegate = self
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
        }
    }

    @MainActor
    func next() {
        account?.hidden = !remember
        if let account = account {
            AccountsRepository.shared.current = account
            AnalyticsManager.shared.loginWalletEnd(account: account, loginType: .hardware)
            AccountNavigator.navLogged(accountId: account.id)
        }
    }

    @MainActor
    override func onError(_ err: Error) {
        btnContinue.isHidden = false
        let txt = bleHwManager?.toBleError(err, network: nil).localizedDescription
        showError(txt?.localized ?? "")
        Task { try? await bleHwManager?.disconnect() }
    }
}

extension PinCreateViewController: UpdateFirmwareViewControllerDelegate {
    @MainActor
    func didUpdate(version: String, firmware: Firmware) {
        Task {
            do {
                startLoader(message: "id_updating_firmware".localized)
                let binary = try await bleHwManager?.fetchFirmware(firmware: firmware)
                let hash = bleHwManager?.jade?.jade.sha256(binary ?? Data())
                let hashHex = hash?.hex.separated(by: " ", every: 8)
                let text = progressLoaderMessage(title: "id_updating_firmware".localized,
                                                 subtitle: "Hash: \(hashHex ?? "")")
                startLoader(message: text)
                let res = try await bleHwManager?.updateFirmware(firmware: firmware, binary: binary ?? Data())
                try await bleHwManager?.disconnect()
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                self.stopLoader()
                await MainActor.run {
                    btnContinue.isHidden = false
                    if let res = res, res {
                        DropAlert().success(message: "id_firmware_update_completed".localized)
                        connectViewController()
                    } else {
                        DropAlert().error(message: "id_operation_failure".localized)
                    }
                }
            } catch {
                onError(error)
            }
        }
    }

    func connectViewController() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "ConnectViewController") as? ConnectViewController {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func didSkip() {
        self.next()
    }
}
