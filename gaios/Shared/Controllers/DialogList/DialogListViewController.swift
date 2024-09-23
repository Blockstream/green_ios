import Foundation
import UIKit

protocol DialogListViewControllerDelegate: AnyObject {
    func didSelectIndex(_ index: Int, with type: DialogType)
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType)
}

class DialogListViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var lblTitle: UILabel!

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeight: NSLayoutConstraint!

    weak var delegate: DialogListViewControllerDelegate?

    var viewModel: DialogListViewModel?

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

        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        ["DialogListCell", "DialogEnable2faCell" ].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {

        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(-1)
            default:
                break
            }
        }
    }

    @objc func didTap(gesture: UIGestureRecognizer) {

        dismiss(-1)
    }

    func setContent() {
        lblTitle.text = viewModel?.title ?? ""
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tableHeight.constant = CGFloat( tableView.contentSize.height )
        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func dismiss(_ index: Int) {
        guard let vm = viewModel else { return }
        if let item = vm.items[safe: index] as? DialogListCellModel {
            if item.switchState != nil {
                // prevent tap on cells with the switch
                return
            }
        }
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            if index > -1 {
                self.delegate?.didSelectIndex(index, with: vm.type)
            }
        })
    }

    func switchAndDismiss(idx: Int, isOn: Bool, type: DialogType) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [self] in
            self.anchorBottom.constant = -cardView.frame.size.height
            UIView.animate(withDuration: 0.3, animations: {
                self.view.alpha = 0.0
                self.view.layoutIfNeeded()
            }, completion: { _ in
                self.dismiss(animated: false, completion: {
                    if idx > -1 {
                        self.delegate?.didSwitchAtIndex(index: idx,
                                                        isOn: isOn,
                                                        type: type)
                    }
                })
            })
        }
    }
}

extension DialogListViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let vm = viewModel else { return 0 }
        return vm.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let modeType = viewModel?.items[indexPath.row].type
        switch modeType {
        case .list:
            if let cell = tableView.dequeueReusableCell(withIdentifier: DialogListCell.identifier, for: indexPath) as? DialogListCell, let vm = viewModel {
                cell.configure(model: vm.items[indexPath.row],
                               index: indexPath.row) { [weak self] (idx, isOn) in
                    self?.switchAndDismiss(idx: idx, isOn: isOn, type: vm.type)
                }
                cell.selectionStyle = .none
                return cell
            }
        case.enable2fa:
            if let cell = tableView.dequeueReusableCell(withIdentifier: DialogEnable2faCell.identifier, for: indexPath) as? DialogEnable2faCell, let vm = viewModel {
                cell.configure(vm.items[indexPath.row])
                cell.selectionStyle = .none
                return cell
            }
        case .none:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(indexPath.row)
    }
}
