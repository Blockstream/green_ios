import Foundation
import UIKit

protocol SelectCountryViewControllerDelegate: AnyObject {
    func didSelectCountry(_ country: Country)
}

enum SelectCountrySection: CaseIterable {
    // case common
    case all
}
class SelectCountryViewController: UIViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: SelectCountryViewControllerDelegate?

    var viewModel: SelectCountryViewModel!

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

        ["SelectCountryCell" ].forEach {
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
                dismiss(nil)
            default:
                break
            }
        }
    }

    @objc func didTap(gesture: UIGestureRecognizer) {

        dismiss(nil)
    }

    func setContent() {
        lblTitle.text = viewModel?.title ?? ""
        lblHint.text = viewModel?.hint ?? ""
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        lblHint.setStyle(.txtCard)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }

    func dismiss(_ indexPath: IndexPath?) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            if let indexPath = indexPath {
                self.delegate?.didSelectCountry(self.viewModel.countries[indexPath.row])
            }
        })
    }
    func didSelect(_ indexPath: IndexPath?) {
        dismiss(indexPath)
    }
}

extension SelectCountryViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SelectCountrySection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.countries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: SelectCountryCell.identifier, for: indexPath) as? SelectCountryCell {
            let model = SelectCountryCellModel(country: viewModel.countries[indexPath.row])
            cell.configure(model: model, onTap: { [weak self] in
                self?.didSelect(indexPath)
            })
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
}
