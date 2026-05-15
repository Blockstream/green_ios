import UIKit

class LTDetailsViewController: UIViewController {
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnLearnMore: UIButton!
    
    var viewModel: LTDetailsViewModel!
    private var nodeCellTypes: [LTDetailsCellType] { viewModel.cellTypes }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerTableView()
        setContent()
        setStyle()
        setupAlertCard()
    }

    func registerTableView() {
        tableView.register(UINib(nibName: "LTDetailsCell", bundle: nil), forCellReuseIdentifier: LTDetailsCell.identifier)
    }

    func setContent() {
        lblTitle.text = "Lightning Network".localized
        lblDescription.text = "A scaling solution for faster, cheaper Bitcoin payments.".localized
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblTitle.textAlignment = .center

        lblDescription.setStyle(.txtSectionHeader)
        lblDescription.textAlignment = .center

        btnLearnMore.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
    }

    func setupAlertCard() {
        let nib = UINib(nibName: "AlertCardCell", bundle: nil)
        guard let cell = nib.instantiate(withOwner: nil, options: nil).first as? AlertCardCell else { return }
        cell.configure(AlertCardCellModel(type: .lightningBeta), onLeft: nil, onRight: nil, onDismiss: nil)
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cell)
        
        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -5),
            cell.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 5),
            cell.bottomAnchor.constraint(equalTo: btnLearnMore.topAnchor, constant: -12),
            cell.contentView.topAnchor.constraint(equalTo: cell.topAnchor),
            cell.contentView.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            cell.contentView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            cell.contentView.trailingAnchor.constraint(equalTo: cell.trailingAnchor)
        ])
    }
    
    @IBAction func tapLearnMore(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.understandingLightningSupport)
    }
}

extension LTDetailsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nodeCellTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: LTDetailsCell.identifier) as? LTDetailsCell {
            cell.selectionStyle = .none
            let cellType = nodeCellTypes[indexPath.row]
            let cellModel = viewModel.cellModelByType(cellType)
            cell.configure(model: cellModel)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellType = nodeCellTypes[indexPath.row]
        switch cellType {
        case .nodeId:
            UIPasteboard.general.string = viewModel.nodeId
            DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 1.0)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
