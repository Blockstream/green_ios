import UIKit
import core

class CoinFilterViewController: UIViewController {
    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var closeButton: UIButton!

    @IBOutlet weak var sectionLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var applyButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!

    var filters: [CoinFilter] = CoinFilter.allCases
    var selectedFilters: Set<CoinFilter> = []
    
    var obs: NSKeyValueObservation?

    weak var delegate: CoinFilterDelegate?

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
        
        applyButton.addTarget(self, action: #selector(didTapApply), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
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
        lblTitle.text = "Filter".localized
        applyButton.setTitle("Apply".localized, for: .normal)
        resetButton.setTitle("Reset".localized, for: .normal)
        updateFilterSectionLabel()
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblTitle.setStyle(.subTitle)
        closeButton.tintColor = .gGrayTxt()
        closeButton.backgroundColor = .gGrayCard()
        closeButton.cornerRadius = closeButton.bounds.height / 2
        sectionLabel.setStyle(.txtSectionHeader)
        applyButton.setStyle(.primary)
        resetButton.setStyle(.outlined)
    }

    func registerTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        
        [CoinFilterCell.identifier].forEach {
            let nib = UINib(nibName: $0, bundle: nil)
            tableView.register(nib, forCellReuseIdentifier: $0)
        }
    }
    
    func updateFilterSectionLabel() {
        let appliedFilters = filters.count
        if appliedFilters > 0 {
            sectionLabel.text = "Coin Type • \(selectedFilters.count) of \(appliedFilters)".localized
        } else {
            sectionLabel.text = "Coin Type".localized
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

    @objc func didTapApply() {
        delegate?.didSelectFilter(filters: selectedFilters)
        dismiss()
    }

    @objc func didTapReset() {
        selectedFilters.removeAll()
        delegate?.didSelectFilter(filters: selectedFilters)
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

extension CoinFilterViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filters.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: CoinFilterCell.identifier, for: indexPath) as? CoinFilterCell {
            let filter = filters[indexPath.row]
            cell.configure(iconImage: filter.icon, title: filter.title, isSelected: selectedFilters.contains(filter))
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let filter = filters[indexPath.row]
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
        updateFilterSectionLabel()
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
