import UIKit
import core
import gdk
enum AccountDescriptorSection: Int, CaseIterable {
    case card
    case descriptor
}
protocol AccountDescriptorViewControllerDelegate: AnyObject {
    // func archiveDidChange()
}
class AccountDescriptorViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var sectionHeaderH: CGFloat = 54.0
    weak var delegate: AccountDescriptorViewControllerDelegate?
    var viewModel: AccountDescriptorViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Watch-only".localized
        register()
        setContent()
    }
    func register() {
        ["AlertCardCell", "AccountDescriptorCell"].forEach {
            tableView?.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    @MainActor
    func reloadSections(_ sections: [AccountArchiveSection], animated: Bool) {
        if animated {
            tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
        } else {
            UIView.performWithoutAnimation {
                tableView.reloadSections(IndexSet(sections.map { $0.rawValue }), with: .none)
            }
        }
    }
    func setContent() {
        Task {
//            try? await viewModel.loadSubaccounts()
//            reloadSections([.account], animated: false)
        }
    }
    func onClipboard(_ descriptor: String) {
        if !descriptor.isEmpty {
            UIPasteboard.general.string = descriptor
            DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 2.0)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    func onQR(_ qrInfo: QRDialogInfo) {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogQRViewController") as? DialogQRViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.qrDialogInfo = qrInfo
            present(vc, animated: false, completion: nil)
        }
    }
}

extension AccountDescriptorViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return AccountDescriptorSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case AccountDescriptorSection.card.rawValue:
            return viewModel.cardCellModels.count
        case AccountDescriptorSection.descriptor.rawValue:
            return viewModel.descriptorCellModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.section {
        case AccountDescriptorSection.card.rawValue:
            let model = viewModel.cardCellModels[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AlertCardCell") as? AlertCardCell {
                cell.configure(model, onLeft: nil, onRight: nil, onDismiss: nil)
                cell.selectionStyle = .none
                return cell
            }
        case AccountDescriptorSection.descriptor.rawValue:
            let model = viewModel.descriptorCellModels[indexPath.row]
            if let cell = tableView.dequeueReusableCell(withIdentifier: "AccountDescriptorCell") as? AccountDescriptorCell {
                cell.configure(model: model,
                               onClipboard: {[weak self] item in
                    self?.onClipboard(item)
                }, onQR: {[weak self] item in
                    self?.onQR(item)
                })
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case AccountDescriptorSection.card.rawValue:
            return 0.1
        case AccountDescriptorSection.descriptor.rawValue:
            return sectionHeaderH
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch AccountDescriptorSection(rawValue: section) {
        default:
            return 0.1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
        case AccountDescriptorSection.card.rawValue:
            return nil
        case AccountDescriptorSection.descriptor.rawValue:
            return sectionHeader("Output Descriptor".localized)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch AccountDescriptorSection(rawValue: section) {
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { }
}
extension AccountDescriptorViewController {
    func sectionHeader(_ txt: String) -> UIView {

        guard let tView = tableView else { return UIView(frame: .zero) }
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tView.frame.width, height: sectionHeaderH))
        section.backgroundColor = UIColor.clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtSectionHeader)
        title.text = txt
        title.textColor = UIColor.gGrayTxt()
        title.numberOfLines = 0

        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 10.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 20)
        ])

        return section
    }
}
