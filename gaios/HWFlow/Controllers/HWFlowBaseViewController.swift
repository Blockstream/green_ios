import UIKit

class HWFlowBaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @MainActor
    func onError(_ err: Error) {
        stopLoader()
        let txt = BleHwManager.shared.toBleError(err, network: nil).localizedDescription
        DropAlert().error(message: txt.localized)
    }
}
