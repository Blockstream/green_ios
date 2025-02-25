import Foundation
import UIKit

class TxDetailsMoreInfoViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!

    var vm: TxDetailsMoreInfoViewModel!
    var obs: NSKeyValueObservation?

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
        setContent()
        setStyle()

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
            self?.tableViewHeight.constant = table.contentSize.height
        }
    }

    deinit {
        print("deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc func didTap(gesture: UIGestureRecognizer) {

        dismiss()
    }

    func setContent() {
        lblTitle.text = "More Details".localized
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
    }

    func register() {
        ["TxDetailsMoreInfoCell"].forEach {
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
}

extension TxDetailsMoreInfoViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return vm.txDetailsMoreInfoCellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: TxDetailsMoreInfoCell.identifier) as? TxDetailsMoreInfoCell {
            cell.selectionStyle = .none
            let model = vm.txDetailsMoreInfoCellModels[indexPath.row]
            cell.configure(model: model)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let m = vm.txDetailsMoreInfoCellModels[indexPath.row]
        UIPasteboard.general.string = m.hint
        let msg = "\(m.title) copied to clipboard".localized
        DropAlert().info(message: msg, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
