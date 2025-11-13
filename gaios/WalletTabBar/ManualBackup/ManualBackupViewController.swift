import Foundation
import UIKit
import LocalAuthentication
import core
import greenaddress

class ManualBackupViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblInfo1: UILabel!
    @IBOutlet weak var lblInfo2: UILabel!
    @IBOutlet weak var lblInfo3: UILabel!
    @IBOutlet weak var btnNext: UIButton!
    var showBip85: Bool = false

    weak var subAccountCreateDelegate: AccountCreateRecoveryKeyDelegate?
    var viewModel: ManualBackupViewModel!

    var wm: WalletManager { WalletManager.current! }

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        title = viewModel.navTitle
        navigationItem.backButtonTitle = "id_back".localized
    }

    func setContent() {
        lblTitle.text = viewModel.title
        lblInfo1.text = viewModel.info1
        lblInfo2.text = viewModel.info2
        lblInfo3.text = viewModel.info3
        btnNext.setTitle(viewModel.btnTitle, for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblInfo1.setStyle(.txt)
        lblInfo2.setStyle(.txt)
        lblInfo3.setStyle(.txt)
        btnNext.setStyle(.primary)
    }

    func next(_ length: MnemonicLengthOption) {
        var mnemonic: String?
        if length == MnemonicLengthOption._24 {
            mnemonic = try? generateMnemonic()
        } else {
            mnemonic = try? generateMnemonic12()
        }
        if let mnemonic, let vc = AccountNavigator.phraseNoteDown(phrase: mnemonic,
        subAccountCreateDelegate: subAccountCreateDelegate) {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func selectLength() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: viewModel.chooselengthTitle, type: .phrasePrefs, items: PhrasePrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }

    }
    @IBAction func btnNext(_ sender: Any) {
        switch viewModel.flowType {
        case .phrase:
            if let vc = AccountNavigator.mnemonic() {
                navigationController?.pushViewController(vc, animated: true)
            }
        case .quiz:
            Task {
                if let credentials = try? await wm.prominentSession?.getCredentials(password: "") {
                    if let mnemonic = credentials.mnemonic {
                        if let vc = AccountNavigator.phraseNoteDown(phrase: mnemonic) {
                            navigationController?.pushViewController(vc, animated: true)
                        }
                    }
                }
            }
        case .addSubaccount:
            selectLength()
        }
    }
}
extension ManualBackupViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch PhrasePrefs(rawValue: index) {
        case ._12:
            next(._12)
        case ._24:
            next(._24)
        case .none:
            break
        }
    }
}
