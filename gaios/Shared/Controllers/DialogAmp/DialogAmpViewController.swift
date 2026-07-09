import Foundation
import UIKit

protocol DialogAmpViewControllerDelegate: AnyObject {
//    func didSelectInput(denomination: DenominationType)
//    func didSelectFiat()
}

class DialogAmpViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var btnCreate: UIButton!
    @IBOutlet weak var btnLearnMore: UIButton!
    @IBOutlet weak var btnDismiss: UIButton!

    var vm: DialogAmpViewModel!
    let hHeader = 44.0
    var obs: NSKeyValueObservation?
    weak var delegate: DialogAmpViewControllerDelegate?

    init?(coder: NSCoder, model: DialogAmpViewModel) {
        self.vm = model
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }

    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        register()
        bind()
        configureUI()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
        swipeDown.direction = .down
        self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
        tappableBg.addGestureRecognizer(tapToClose)

        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            guard let self = self else { return }
            guard table.numberOfSections > 0 else {
                self.tableViewHeight.constant = 0
                return
            }
            self.updateBottomSheetTableViewHeight(table,
                                                  heightConstraint: self.tableViewHeight,
                                                  inside: self.cardView)
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onUpdate()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }
    func onUpdate(_ feature: RefreshAmpFeature? = nil) {
        lblTitle.text = vm.title
        lblHint.text = vm.hint
        btnCreate.setStyle(.primary)
        btnCreate.setTitle(vm.btnCreateTitle, for: .normal)
        btnCreate.isHidden = vm.sectionCount != 0
        if vm.sectionCount == 0 {
            tableViewHeight.constant = 0
        }
        switch feature {
        case .success:
            tableView.reloadData()
        case .error(let msg):
            DropAlert().error(message: msg)
            tableView.reloadData()
        default:
            break
        }
    }
    func bind() {
        vm.onUpdate = { [weak self] feature in
            self?.onUpdate(feature)
        }
    }
    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss()
    }

    func configureUI() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txtCard)
        btnLearnMore.setStyle(.underline(txt: "id_learn_more".localized, color: UIColor.gAccent()))
        btnDismiss.backgroundColor = UIColor.gGrayCard()
        btnDismiss.cornerRadius = btnDismiss.frame.size.height / 2
        tableView.backgroundColor = UIColor.gGrayPanel()
    }

    func register() {
        ["DialogAmpCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }
    func dismiss() {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss()
            default:
                break
            }
        }
    }
    @IBAction func btnDismiss(_ sender: Any) {
        dismiss()
    }
    @IBAction func btnCreate(_ sender: Any) {
        btnCreate.setStyle(.primaryLoading)
        btnCreate.setTitle("Creating AMP Account...".localized, for: .normal)
        vm.onCreate(vm.defaultCreateType)
    }
    @IBAction func btnLearnMore(_ sender: Any) {
        SafeNavigationManager.shared.navigate(ExternalUrls.ampCreateInfo)
    }
}

extension DialogAmpViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return vm.sectionCount
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return vm.numberOfRows(in: section)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: DialogAmpCell.identifier) as? DialogAmpCell {
            cell.selectionStyle = .none
            let model = vm.cellModel(indexPath)
            let type = vm.createType(indexPath)
            cell.configure(model: model,
                           onCreate: { [weak self] in
                self?.vm.onCreate(type)
            }, onCopy: {
                if let hash = model.hash {
                    UIPasteboard.general.string = hash
                    DropAlert().info(message: "id_copied_to_clipboard".localized, delay: 2.0)
                }
            })
            return cell
        }
        return UITableViewCell()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        delegate?.didSelectInput(denomination: viewModel.denominations[indexPath.row])
//        dismiss()
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return hHeader
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionHeader(vm.sectionTitle(section))
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.5
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func sectionHeader(_ txt: String) -> UIView {

        guard let tView = tableView else { return UIView(frame: .zero) }
        let section = UIView(frame: CGRect(x: 0, y: 0, width: tView.frame.width, height: hHeader))
        section.backgroundColor = .clear
        let title = UILabel(frame: .zero)
        title.setStyle(.txtSectionHeader)
        title.text = txt
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(title)

        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: section.centerYAnchor, constant: 0.0),
            title.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 25),
            title.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: 20)
        ])

        return section
    }
}
