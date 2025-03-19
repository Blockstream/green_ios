import Foundation
import core
import UIKit

protocol DialogAboutViewControllerDelegate: AnyObject {
    func openContactUs()
}

enum DialogAboutAction {
    case contactUs
    case close
}
class DialogAboutViewController: KeyboardViewController {

    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var lblCopy: UILabel!

    weak var delegate: DialogAboutViewControllerDelegate?

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

        setContent()
        setStyle()

        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)

        ["DialogListCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: nil), forCellReuseIdentifier: $0)
        }

        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTapToClose))
            tappableBg.addGestureRecognizer(tapToClose)

        obs = tableView.observe(\UITableView.contentSize, options: .new) { [weak self] table, _ in
            self?.tableViewHeight.constant = table.contentSize.height
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(multiTap))
        tap.numberOfTapsRequired = 5

        cardView.subviews.forEach {
            $0.subviews.forEach { view in
                if let logo = view as? UIImageView {
                    if Bundle.main.dev {
                        logo.isUserInteractionEnabled = true
                        logo.addGestureRecognizer(tap)
                    }
                }
            }
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

    @objc func didTapToClose(gesture: UIGestureRecognizer) {

        dismiss(.close)
    }

    func setContent() {
        lblTitle.text = Common.versionString
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        lblCopy.text = "© \(formatter.string(from: Date())) Blockstream Corporation Inc."
    }

    func setStyle() {
        cardView.setStyle(.bottomsheet)
        handle.cornerRadius = 1.5
        [lblTitle, lblCopy].forEach {
            $0.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
            $0.textColor = .white.withAlphaComponent(0.6)
        }
    }

    func dismiss(_ action: DialogAboutAction) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: { [weak self] in
                switch action {
                case .contactUs:
                    self?.delegate?.openContactUs()
                default:
                    break
                }
            })
        })
    }

    @objc func didSwipe(gesture: UIGestureRecognizer) {

        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(.close)
            default:
                break
            }
        }
    }

    func navigate(_ url: URL) {
        SafeNavigationManager.shared.navigate(url)
    }

    func openContactUs() {
        dismiss(.contactUs)
    }

    func openFeedback() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogFeedbackViewController") as? DialogFeedbackViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.delegate = self
            present(vc, animated: false, completion: nil)
        }
    }

    func handleDebugID() {
        var msg = "ID not available"
        if let uuid = UserDefaults.standard.string(forKey: AppStorageConstants.analyticsUUID.rawValue) {
            UIPasteboard.general.string = uuid
            msg = "UUID copied to clipboard".localized
        }
        DropAlert().info(message: msg, delay: 1.0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @objc func multiTap() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "Debug", type: .debugPrefs, items: DebugPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    @IBAction func didTap(_ sender: UIButton) {

        switch sender.tag {
        case 1: // web
            navigate(ExternalUrls.aboutBlockstreamGreenWebSite)
        case 2: // tw
            navigate(ExternalUrls.aboutBlockstreamTwitter)
        case 3: // in
            navigate(ExternalUrls.aboutBlockstreamLinkedIn)
        case 4: // fb
            navigate(ExternalUrls.aboutBlockstreamFacebook)
        case 5: // tel
            navigate(ExternalUrls.aboutBlockstreamTelegram)
        case 6: // git
            navigate(ExternalUrls.aboutBlockstreamGitHub)
        case 7: // you
            navigate(ExternalUrls.aboutBlockstreamYouTube)
        default:
            break
        }
    }
}

extension DialogAboutViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "DialogListCell") as? DialogListCell {
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0:
                cell.configure(model: DialogListCellModel(type: .list, icon: nil, title: "id_give_us_your_feedback".localized))
            case 1:
                cell.configure(model: DialogListCellModel(type: .list, icon: nil, title: "Get Support".localized))
            case 2:
                cell.configure(model: DialogListCellModel(type: .list, icon: nil, title: "id_visit_the_blockstream_help".localized))
            case 3:
                cell.configure(model: DialogListCellModel(type: .list, icon: nil, title: "id_terms_of_service".localized))
            case 4:
                cell.configure(model: DialogListCellModel(type: .list, icon: nil, title: "id_privacy_policy".localized))
            default:
                break
            }
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            openFeedback()
        case 1:
            openContactUs()
        case 2:
            navigate(ExternalUrls.aboutHelpCenter)
        case 3:
            navigate(ExternalUrls.aboutTermsOfService)
        case 4:
            navigate(ExternalUrls.aboutPrivacyPolicy)
        default:
            break
        }
    }
}

extension DialogAboutViewController: DialogFeedbackViewControllerDelegate {

    func didCancel() {
        //
    }

    func didSend(rating: Int, email: String?, comment: String) {
        AnalyticsManager.shared.recordFeedback(rating: rating, email: email, comment: comment)
        DropAlert().success(message: "id_thank_you_for_your_feedback".localized)
    }
}

extension DialogAboutViewController: DialogListViewControllerDelegate {
    func didSwitchAtIndex(index: Int, isOn: Bool, type: DialogType) {}

    func selectNetwork() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogListViewController") as? DialogListViewController {
            vc.delegate = self
            vc.viewModel = DialogListViewModel(title: "id_select_network".localized, type: .networkPrefs, items: NetworkPrefs.getItems())
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: false, completion: nil)
        }
    }

    func didSelectIndex(_ index: Int, with type: DialogType) {
        switch DebugPrefs(rawValue: index) {
        case .deviceId:
            handleDebugID()
        case .promos:
            PromoManager.shared.clearDismissed()
            PromoManager.shared.resetVideoCache()
        case .cleanup:
            MigratorManager.shared.removeAll()
            DropAlert().success(message: "Wallet list deleted")
        case .none:
            break
        }
    }
}
