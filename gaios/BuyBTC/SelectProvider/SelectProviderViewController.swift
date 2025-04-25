import Foundation
import UIKit

protocol SelectProviderViewControllerDelegate: AnyObject {
    func didSelectIndexQuoteAtIndex(_ index: Int)
}
enum SelectProviderSection: Int, CaseIterable {
    case best
    case other
}
class SelectProviderViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    weak var delegate: SelectProviderViewControllerDelegate?

    var viewModel: SelectProviderViewModel!

    var sectionHeaderH: CGFloat = 54.0

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        ["SelectProviderCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    func setContent() {
        title = "Change Provider".localized
    }

    func setStyle() {

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    func didSelectProvider(_ indexPath: IndexPath) {
        delegate?.didSelectIndexQuoteAtIndex(indexPath.section + indexPath.row)
        navigationController?.popViewController(animated: true)
    }
}

extension SelectProviderViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SelectProviderSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SelectProviderSection(rawValue: section) {
        case .best:
            return 1
        case .other:
            return viewModel.quotes.count - 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch SelectProviderSection(rawValue: indexPath.section) {
        case .best:
            if let cell = tableView.dequeueReusableCell(withIdentifier: SelectProviderCell.identifier, for: indexPath) as? SelectProviderCell {
                cell.configure(model: SelectProviderCellModel(quote: viewModel.quotes[0]), isBest: true, onTap: { [weak self] in
                    self?.didSelectProvider(indexPath)
                })
                cell.selectionStyle = .none
                return cell
            }
        case .other:
            if let cell = tableView.dequeueReusableCell(withIdentifier: SelectProviderCell.identifier, for: indexPath) as? SelectProviderCell {
                cell.configure(model: SelectProviderCellModel(quote: viewModel.quotes[indexPath.row + 1]), onTap: { [weak self] in
                    self?.didSelectProvider(indexPath)
                })
                cell.selectionStyle = .none
                return cell
            }
        default:
            break
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeaderH
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch SelectProviderSection(rawValue: section) {
        case .best:
            return headerView("Best")
        case .other:
            return headerView("Others")
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
}

extension SelectProviderViewController {
    func headerView(_ txt: String) -> UIView {
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
