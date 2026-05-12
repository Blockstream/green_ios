import Foundation
import UIKit
import gdk
import greenaddress
import core
import lightning

class SendAddressViewController: KeyboardViewController {

    @IBOutlet weak var infoBg: UIView!
    @IBOutlet weak var textBg: UIView!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoIcon: UIImageView!
    @IBOutlet weak var lblInvalid: UILabel!
    @IBOutlet weak var btnClear: UIButton!
    @IBOutlet weak var lblPlaceholder: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var addressTextView: UITextView!
    @IBOutlet weak var btnQR: UIButton!
    @IBOutlet weak var btnPaste: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!

    private static let bip353Prefix = "\u{20BF}"
    private static let lightningAddressProviders = ["walletofsatoshi.com", "phoenixwallet.me"]

    private let viewModel: SendAddressViewModel

    init?(coder: NSCoder, viewModel: SendAddressViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        setupSuggestionBar()
        reload()
        viewModel.onStateChanged = { [weak self] in
            self?.reload()
        }
    }

    func setContent() {
        title = "id_send".localized
        lblSubtitle.text = "id_recipient".localized
        lblInvalid.text = "id_invalid_address".localized
        btnQR.setTitle("id_scan_qr_code".localized, for: .normal)
        btnPaste.setTitle("id_paste".localized, for: .normal)
        infoIcon.image = UIImage(named: "ic_lightning_info")!.maskWithColor(color: .white)
        btnPaste.setImage(UIImage(named: "ic_clipboard")?.maskWithColor(color: UIColor.gBlackBg()), for: .normal)
        btnNext.setTitle("id_next".localized, for: .normal)
        if viewModel.sweepPrivateKey {
            lblPlaceholder.text = "id_enter_a_private_key_to_sweep".localized
        } else if let subaccount = viewModel.subaccount {
            if let assetId = viewModel.assetId, assetId == AssetInfo.lbtcId || assetId == AssetInfo.lightningId {
                lblPlaceholder.text = "id_enter_an_address_or_invoice".localized
            } else {
                lblPlaceholder.text = "id_enter_an_address".localized
            }
        } else {
            lblPlaceholder.text = "id_enter_an_address_or_invoice".localized
        }
    }

    func setStyle() {
        infoBg.cornerRadius = 4.0
        textBg.setStyle(CardStyle.defaultStyle)
        lblInvalid.setStyle(.txt)
        btnQR.setStyle(.inline)
        btnPaste.setStyle(.primary)
        lblPlaceholder.setStyle(.txtCard)
        lblSubtitle.setStyle(.txtCard)
        addressTextView.textContainer.maximumNumberOfLines = 8
        addressTextView.textContainer.lineBreakMode = .byTruncatingTail
    }

    // Scrollable ₿ + curated LN domain chips above the keyboard.
    private func setupSuggestionBar() {
        let container = UIInputView(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44),
            inputViewStyle: .keyboard
        )

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center

        let titles = [Self.bip353Prefix] + Self.lightningAddressProviders.map { "@" + $0 }
        for title in titles {
            let button = makeChip(title: title)
            button.addTarget(self, action: #selector(didTapSuggestionChip(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        addressTextView.inputAccessoryView = container
    }

    private func makeChip(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        return button
    }

    @objc private func didTapSuggestionChip(_ sender: UIButton) {
        replaceText((addressTextView.text ?? "") + (sender.title(for: .normal) ?? ""))
    }

    private func replaceText(_ newText: String) {
        addressTextView.text = newText
        let end = addressTextView.endOfDocument
        addressTextView.selectedTextRange = addressTextView.textRange(from: end, to: end)
        reload()
        Task { [weak self] in await self?.validate(triggerNavigation: false) }
    }

    @MainActor
    @objc private func textChanged() {
        // Typing only refreshes state.
        Task { await self.validate(triggerNavigation: false) }
    }

    @MainActor
    private func reload() {
        // enable continuation
        btnNext.isEnabled = viewModel.canContinue
        btnNext.setStyle(viewModel.canContinue ? .primary : .primaryGray)
        // show error message
        if let error = viewModel.error {
            infoBg.backgroundColor = UIColor.gRedWarn()
            infoView.isHidden = false
            lblInvalid.text = error.description().localized
        } else {
            infoBg.backgroundColor = .clear
            infoView.isHidden = true
            lblInvalid.text = ""
        }
        // show/hide action buttons
        let emptyText = addressTextView.text?.isEmpty ?? true
        btnClear.isHidden = emptyText
        btnNext.isHidden = emptyText
        btnPaste.isHidden = !emptyText
        lblPlaceholder.isHidden = !emptyText
    }
    @IBAction func btnQR(_ sender: Any) {
        presentQrcodeScanner()
    }

    @IBAction func btnPaste(_ sender: Any) {
        if let text = UIPasteboard.general.string {
            addressTextView.text = text
            reload()
            Task { [weak self] in await self?.validate(triggerNavigation: true) }
        }
    }

    @IBAction func btnClear(_ sender: Any) {
        viewModel.canContinue = false
        viewModel.error = nil
        addressTextView.text = ""
        addressTextView.endEditing(true)
        reload()
    }

    @IBAction func btnNext(_ sender: Any) {
        Task { [weak self] in await self?.validate(triggerNavigation: true) }
    }

    func validate(triggerNavigation: Bool = false) async {
        if let text = addressTextView.text {
            await viewModel.validate(text: text, triggerNavigation: triggerNavigation)
        }
    }

    override func keyboardWillShow(notification: Notification) {
        super.keyboardWillShow(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            self.anchorBottom.constant = keyboardFrame.height - 20.0
            self.view.layoutIfNeeded()
        })
    }

    override func keyboardWillHide(notification: Notification) {
        super.keyboardWillHide(notification: notification)
        UIView.animate(withDuration: 0.5, animations: { [unowned self] in
            self.anchorBottom.constant = 20.0
            self.view.layoutIfNeeded()
        })
    }

    func presentQrcodeScanner() {
        let storyboard = UIStoryboard(name: "Dialogs", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "DialogScanViewController") as? DialogScanViewController {
            vc.modalPresentationStyle = .overFullScreen
            vc.index = nil
            vc.delegate = self
            present(vc, animated: false, completion: nil)
            AnalyticsManager.shared.scanQr(account: AccountsRepository.shared.current,
                                           screen: .send)
        }
    }  
}

extension SendAddressViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        lblPlaceholder.isHidden = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        lblPlaceholder.isHidden = !textView.text.isEmpty
    }

    func textViewDidChange(_ textView: UITextView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.textChanged), object: nil)
        perform(#selector(self.textChanged), with: nil, afterDelay: 0.3)
    }
}
extension SendAddressViewController: DialogScanViewControllerDelegate {
    func didScan(value: ScanResult, index: Int?) {
        var input = value.result
        if let psbt = value.bcur?.psbt {
            input = psbt
        }
        addressTextView.text = input
        reload()
        Task { [weak self] in
            await self?.validate(triggerNavigation: true)
        }
    }
    func didStop() {
    }
}

extension SendAddressViewController: SendFlowErrorDisplayable {
    func handleSendFlowError(_ error: Error?) {
        viewModel.canContinue = false
        viewModel.error = error
        reload()
    }
}
