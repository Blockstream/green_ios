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

        title = "id_reenable_2fa".localized
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
        lblHint1.text = "id_some_coins_in_your_wallet".localized
        lblHint2.text = ""
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

    func send() {
        if let viewModel = vm.sendAmountViewModel() {
            presentSendAmountViewController(sendViewModel: viewModel)
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
        send()
    }
}
