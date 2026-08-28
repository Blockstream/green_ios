import Foundation
import UIKit
import core

protocol SendDialogFeeViewControllerProtocol {
    func select(transactionPriority: TransactionPriority, feeRate: UInt64?)
}

class SendDialogFeeViewController: KeyboardViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnClose: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var btnCustom: UIButton!
    @IBOutlet weak var btnLearnMore: UIButton!

    var viewModel: SendDialogFeeViewModel!
    var delegate: SendDialogFeeViewControllerProtocol?
    private var obs: NSKeyValueObservation?

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

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)

        register()
        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            self?.tableViewHeight.constant = table.contentSize.height
        }

        Task { [weak self] in
            await self?.viewModel.loadTxs()
            await MainActor.run { self?.tableView.reloadData() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func setContent() {
        lblTitle.text = "id_network_fee".localized
        btnCustom.setTitle("Custom Fee".localized, for: .normal)
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        btnClose.tintColor = .gGrayTxt()
        btnClose.backgroundColor = .gGrayCard()
        btnClose.cornerRadius = btnClose.bounds.height / 2
        
        btnCustom.setStyle(.outlined)
        
        btnLearnMore.setStyle(.underline(txt: "id_learn_more".localized, color: .gAccent()))
        btnLearnMore.tintColor = .gAccent()
        btnLearnMore.setImage(UIImage(named: "ic_squared_out_small")?.maskWithColor(color: .gAccent()), for: .normal)
    }

    func register() {
        tableView.register(UINib(nibName: SendFeeCell.identifier, bundle: nil), forCellReuseIdentifier: SendFeeCell.identifier)
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

    func presentDialogCustomFeeViewController() {
        let storyboard = UIStoryboard(name: "Shared", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogCustomFeeViewController") as? DialogCustomFeeViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            vc.minFeeRate = viewModel.feeEstimator?.defaultMinFee
            if viewModel.transaction.txType == .bumpFee {
                vc.feeRate = (viewModel.transaction.previousTransaction?["fee_rate"] as? UInt64 ?? 0) + (viewModel.feeEstimator?.defaultMinFee ?? 1)
            } else if viewModel.transaction.feeRate > 0 {
                vc.feeRate = viewModel.transaction.feeRate
            } else {
                vc.feeRate = viewModel.feeEstimator?.defaultMinFee ?? 1
            }
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func tapCustomFee(_ sender: Any) {
        presentDialogCustomFeeViewController()
    }

    @IBAction func btnLearmore(_ sender: Any) {
        SafeNavigationManager.shared.navigate( ExternalUrls.feesInfo )
    }

    @IBAction func closeButtonTapped(_ sender: Any) {
        dismiss()
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

    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss()
    }
}

extension SendDialogFeeViewController: DialogCustomFeeViewControllerDelegate {
    func didSave(fee: UInt64?) {
        delegate?.select(transactionPriority: .Custom, feeRate: fee)
        dismiss()
    }
}

extension SendDialogFeeViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.cellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: SendFeeCell.identifier) as? SendFeeCell {
            cell.selectionStyle = .none
            let model = viewModel.cellModels[indexPath.row]
             cell.configure(model: model)
             return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = viewModel.cellModels[indexPath.row]
        delegate?.select(transactionPriority: model.transactionPriority, feeRate: model.feeRate)
        dismiss()
    }
}
