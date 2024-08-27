import UIKit
import core
import gdk

class ReEnable2faViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var btnLearnmore: UIButton!
    @IBOutlet weak var lblHint1: UILabel!
    @IBOutlet weak var lblHint2: UILabel!

    var obs: NSKeyValueObservation?

    var vm: ReEnable2faViewModel!
    private var selectedSubaccount: WalletItem?
    private var verifyOnDeviceViewController: VerifyOnDeviceViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Re-enable 2FA"
        setContent()
        setStyle()

        ["ReEnable2faAccountCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }

        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            self?.tableViewHeight.constant = table.contentSize.height
        }

        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "id_back".localized, style: .plain, target: nil, action: nil)
    }

    func setContent() {
        lblHint1.text = "Some coins in your wallet haven't move for a long time, so 2FA expired to keep you in control. To reactivate 2FA:".localized
        
        lblHint2.text = "\u{2022} " + "Send normally and refresh the 2FA on change coins (optimizes fees)".localized + "\n\u{2022} " + "Redeposit all your expired 2FA coins".localized
                                                        
        btnLearnmore.setTitle("id_learn_more".localized, for: .normal)
    }

    func setStyle() {
        [lblHint1, lblHint2].forEach {
            $0.setStyle(.txt)
        }
        btnLearnmore.setStyle(.inline)
    }

    @IBAction func btnLearnmore(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.reEnable2faLearnMore)
    }

    func send() async {
        do {
            try await vm.newAddress()
            await MainActor.run {
                if let viewModel = vm.sendVerifyOnDeviceViewModel() {
                    presentVerifyOnDeviceViewController(viewModel: viewModel)
                }
            }
            let res = try await vm.validateHW()
            await MainActor.run {
                verifyOnDeviceViewController?.dismiss()
                if res {
                    DropAlert().success(message: "id_the_address_is_valid".localized)
                    if let viewModel = vm.sendAmountViewModel() {
                        presentSendAmountViewController(sendViewModel: viewModel)
                    }
                } else {
                    DropAlert().error(message: "id_the_addresses_dont_match".localized)
                }
            }
        } catch {
            stopLoader()
            DropAlert().error(message: error.description()?.localized ?? "")
        }
    }

    @MainActor
    func presentVerifyOnDeviceViewController(viewModel: VerifyOnDeviceViewModel) {
        let storyboard = UIStoryboard(name: "VerifyOnDevice", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "VerifyOnDeviceViewController") as? VerifyOnDeviceViewController {
            vc.viewModel = viewModel
            verifyOnDeviceViewController = vc
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @MainActor
    func presentSendAmountViewController(sendViewModel: SendAmountViewModel) {
        let storyboard = UIStoryboard(name: "SendFlow", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "SendAmountViewController") as? SendAmountViewController {
            vc.viewModel = sendViewModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ReEnable2faViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return vm.expiredSubaccounts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let subaccount = vm.expiredSubaccounts[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: ReEnable2faAccountCell.identifier, for: indexPath) as? ReEnable2faAccountCell {
            cell.configure(subaccount: subaccount)
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subaccount = vm.expiredSubaccounts[indexPath.row]
        vm.subaccount = subaccount
        Task.detached() { [weak self] in await self?.send() }
    }
}
