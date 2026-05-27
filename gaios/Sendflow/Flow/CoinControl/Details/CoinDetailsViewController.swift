import UIKit
import core

class CoinDetailsViewController: UIViewController {
    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var closeButton: UIButton!

    @IBOutlet weak var tableView: SelfSizedTableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var viewInExplorerButton: UIButton!

    var viewModel: CoinDetailsViewModel!

    var viewInExplorerPreference: Bool {
        get {
            guard let key = viewModel.explorerPreferenceKey else { return false }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            guard let key = viewModel.explorerPreferenceKey else { return }
            UserDefaults.standard.set(newValue, forKey: key)
        }
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
        registerTableView()
        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        view.alpha = 0.0

        anchorBottom.constant = -UIScreen.main.bounds.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
        swipeDown.direction = .down
        self.view.addGestureRecognizer(swipeDown)

        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTapClose))
        tappableBg.addGestureRecognizer(tapToClose)

        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        viewInExplorerButton.addTarget(self, action: #selector(didTapViewInExplorer), for: .touchUpInside)

        viewModel.onUpdate = { [weak self] in
            self?.tableView.reloadData()
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
        lblTitle.text = "Coin Details".localized
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        closeButton.tintColor = .gGrayTxt()
        closeButton.backgroundColor = .gGrayCard()
        closeButton.cornerRadius = closeButton.bounds.height / 2
        viewInExplorerButton.setStyle(.underline(txt: "View in Explorer", color: .gAccent()))
        viewInExplorerButton.setImage(UIImage(named: "ic_squared_out_small")?.maskWithColor(color: .gAccent()), for: .normal)
        viewInExplorerButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
    }

    func registerTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.register(UINib(nibName: CoinDetailsRowCell.identifier, bundle: nil), forCellReuseIdentifier: CoinDetailsRowCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 20
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

    @objc func didSwipe() {
        dismiss()
    }

    @objc func didTapClose() {
        dismiss()
    }

    @objc func didTapViewInExplorer() {
        guard let url = viewModel.urlForExplorer else { return }

        let host = url.host?.starts(with: "www.") == true ? String(url.host!.dropFirst(4)) : (url.host ?? "")

        if viewInExplorerPreference {
            SafeNavigationManager.shared.navigate(url)
            return
        }

        let message = String(format: "id_are_you_sure_you_want_to_view".localized, host)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "id_cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "id_only_this_time".localized, style: .default) { _ in
            SafeNavigationManager.shared.navigate(url)
        })
        alert.addAction(UIAlertAction(title: "id_always".localized, style: .default) { [weak self] _ in
            self?.viewInExplorerPreference = true
            SafeNavigationManager.shared.navigate(url)
        })

        present(alert, animated: true)
    }
}

extension CoinDetailsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.rows.count ?? 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CoinDetailsRowCell.identifier, for: indexPath) as? CoinDetailsRowCell else {
            return UITableViewCell()
        }
        guard let rowType = viewModel?.rows[indexPath.row] else { return cell }
        cell.configure(title: rowType.title, view: rowType.view)
        cell.selectionStyle = .none
        return cell
    }
}
