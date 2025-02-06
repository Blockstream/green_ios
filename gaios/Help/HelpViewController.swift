import UIKit

enum HelpType {
    case version
    case support
    case privacy
    case terms
}

extension HelpType: CaseIterable {}

class HelpViewController: UIViewController {

    @IBOutlet weak var helpTableView: UITableView!

    private var helpItems = HelpType.allCases
    private var version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? CVarArg ?? ""
    private var releaseURLString: String {
        get {
            return String(format: "https://github.com/Blockstream/green_ios/releases/tag/release_%@", version)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        helpTableView.dataSource = self
        helpTableView.delegate = self
    }

    @IBAction func dismissButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension HelpViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return helpItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell") as? HelpCell {
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.customMatrixGreen(),
                .underlineColor: UIColor.customMatrixGreen(),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .font: UIFont.systemFont(ofSize: 16)
            ]
            let helpType = helpItems[indexPath.row]
            switch helpType {
            case .version:
                cell.titleLabel.text = "id_version".localized
                let versionString = String(format: "id_version_1s".localized, version)
                let whatsNewString = "id_whats_new".localized
                let detailString = String(format: "%@ %@", versionString, whatsNewString)
                let attributedDetailString = NSMutableAttributedString(string: detailString)
                attributedDetailString.setAttributes(linkAttributes, for: whatsNewString)
                cell.detailLabel.attributedText = attributedDetailString
            case .support:
                cell.titleLabel.text = "id_support".localized
                let supportPageString = "id_support_page".localized
                let supportDetailString = String(format: "id_read_more_at_our_s".localized, supportPageString)
                let attributedSupportString = NSMutableAttributedString(string: supportDetailString)
                attributedSupportString.setAttributes(linkAttributes, for: supportPageString)
                cell.detailLabel.attributedText = attributedSupportString
            case .privacy:
                cell.titleLabel.text = "id_privacy_policy".localized
                let hereString = "id_here".localized
                let privacyString = String(format: "id_see_our_privacy_policy_s".localized, hereString)
                let attributedPrivacyString = NSMutableAttributedString(string: privacyString)
                attributedPrivacyString.setAttributes(linkAttributes, for: hereString)
                cell.detailLabel.attributedText = attributedPrivacyString
            case .terms:
                cell.titleLabel.text = "id_terms_of_use".localized
                let hereString = "id_here".localized
                let termsDetailString = String(format: "id_see_our_terms_of_service_s".localized, hereString)
                let attributedTermsString = NSMutableAttributedString(string: termsDetailString)
                attributedTermsString.setAttributes(linkAttributes, for: hereString)
                cell.detailLabel.attributedText = attributedTermsString
            }
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var urlString: String = ""
        let helpType = helpItems[indexPath.row]
        switch helpType {
        case .version:
            urlString = releaseURLString
        case .support:
            urlString = "https://docs.blockstream.com/green/support.html"
        case .privacy:
            urlString = "https://blockstream.com/green/privacy/"
        case .terms:
            urlString = "https://blockstream.com/green/terms/"
        }
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                SafeNavigationManager.shared.navigate(url)
            }
        }
    }
}
