import UIKit
import core

class CoinSortViewController: UIViewController {
    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var closeButton: UIButton!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!

    var sorts: [CoinSort] = CoinSort.allCases
    var selectedSort: CoinSort = .defaultSort

    var obs: NSKeyValueObservation?

    weak var delegate: CoinSortDelegate?

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

        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            guard let self = self else { return }
            if self.tableViewHeightConstraint.constant != table.contentSize.height {
                self.tableViewHeightConstraint.constant = table.contentSize.height
            }
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
        lblTitle.text = "Sort".localized
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        closeButton.tintColor = .gGrayTxt()
        closeButton.backgroundColor = .gGrayCard()
        closeButton.cornerRadius = closeButton.bounds.height / 2
    }

    func registerTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false

        [CoinSortCell.identifier].forEach {
            let nib = UINib(nibName: $0, bundle: nil)
            tableView.register(nib, forCellReuseIdentifier: $0)
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

    @objc func didTapClose(gesture: UIGestureRecognizer) {
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
}

extension CoinSortViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sorts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: CoinSortCell.identifier, for: indexPath) as? CoinSortCell {
            let sort = sorts[indexPath.row]
            cell.configure(title: sort.title, isSelected: sort == selectedSort)
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sort = sorts[indexPath.row]
        selectedSort = sort
        tableView.reloadData()
        delegate?.didSelectSort(sort: sort)
        dismiss()
    }
}
