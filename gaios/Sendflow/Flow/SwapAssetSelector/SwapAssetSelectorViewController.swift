import Foundation
import UIKit

protocol SendSwapAssetSelectorViewControllerDelegate: AnyObject {
    @MainActor
    func didSelectAsset(_ selector: SwapAssetSelectorViewController, didSelect asset: SwapAssetType)
    @MainActor
    func didCancel(_ selector: SwapAssetSelectorViewController)
}

extension SendSwapAssetSelectorViewControllerDelegate {
    func didCancel(_ selector: SwapAssetSelectorViewController) {}
}

class SwapAssetSelectorViewController: UIViewController {
    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var closeBtn: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    
    let viewModel: SwapAssetSelectorViewModel
    private var obs: NSKeyValueObservation?
    weak var delegate: SendSwapAssetSelectorViewControllerDelegate?

    init?(coder: NSCoder, viewModel: SwapAssetSelectorViewModel) {
        self.viewModel = viewModel
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
        registerCells()
        setContent()
        setStyle()
        
        view.backgroundColor = .clear
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        view.alpha = 0.0
        
        tableView.dataSource = self
        tableView.delegate = self
        
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss()
    }

    func setContent() {
        lblTitle.text = viewModel.swapDirection.title.localized
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        closeBtn.tintColor = .gGrayTxt()
        closeBtn.backgroundColor = .gGrayCard()
        closeBtn.layer.cornerRadius = closeBtn.frame.height / 2
    }

    func registerCells() {
        [SwapAssetCell.identifier].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }
    }

    func dismiss(isCancel: Bool = true) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                if isCancel {
                    self.delegate?.didCancel(self)
                }
            })
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
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        dismiss()
    }
}

extension SwapAssetSelectorViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.assetTypes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: SwapAssetCell.identifier) as? SwapAssetCell {
            cell.selectionStyle = .none
            let type = viewModel.assetTypes[indexPath.row]
            let cellModel = SwapAssetCellModel(title: type.title, icon: type.icon)
            cell.configure(with: cellModel)
            
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedAsset = viewModel.assetTypes[indexPath.row]
        delegate?.didSelectAsset(self, didSelect: selectedAsset)
        dismiss(isCancel: false)
    }
}
