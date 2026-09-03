import Foundation
import UIKit
import core

class TwoFactorLimitViewController: KeyboardViewController {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var limitTextField: DecimalTextField!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var fiatButton: UIButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var convertedLabel: UILabel!
    @IBOutlet weak var limitButtonConstraint: NSLayoutConstraint!

    var viewModel: TFALimitViewModel
    weak var coordinator: SettingsCoordinator?

    init?(coder: NSCoder, viewModel: TFALimitViewModel) {
        self.viewModel = viewModel
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "id_twofactor_threshold".localized
        nextButton.setTitle("id_set_twofactor_threshold".localized, for: .normal)
        nextButton.addTarget(self, action: #selector(nextClick), for: .touchUpInside)
        limitTextField.maxDecimalsProvider = { [weak self] in
            guard let self else { return nil }
            return viewModel.isFiat ? 2 : Int(viewModel.denomination.digits)
        }
        limitTextField.becomeFirstResponder()
        limitTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        setStyle()
        reload()
    }

    func setStyle() {
        nextButton.setStyle(.primary)
        descriptionLabel.setStyle(.txtCard)
        bg.cornerRadius = 5.0
    }

    override func keyboardWillShow(notification: Notification) {
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        nextButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -keyboardFrame.height).isActive = true
    }

    func reload() {
        guard let limits = viewModel.limits else { return }
        if limits.isFiat {
            let (amount, denom) = Balance.fromFiat(limits.fiat ?? "0", assetId: AssetInfo.btcId)?.toValue() ?? ("", "")
            descriptionLabel.text = String(format: "id_your_twofactor_threshold_is_s".localized, "\(amount) \(denom)")
        } else {
            let denom = viewModel.denomination.rawValue
            let value: String? = limits.get(TwoFactorConfigLimits.CodingKeys(rawValue: denom)!)
//            let assetId = session.gdkNetwork.getFeeAsset()
//            let (amount, _) = Balance.fromDenomination(value ?? "0", assetId: assetId)?.toFiat() ?? ("", "")
            descriptionLabel.text = String(format: "id_your_twofactor_threshold_is_s".localized, "\(value ?? "0") \(denom)")
        }
        refresh()
    }

    func refresh() {
        if let balance = Balance.fromSatoshi(
            viewModel.satoshi ?? 0,
            assetId: viewModel.networkId.gdkNetwork.getFeeAsset()
        ) {
            let (amount, denom) = viewModel.isFiat ? balance.toDenom() : balance.toFiat()
            let denomination = viewModel.isFiat ? balance.toFiat().1 : balance.toDenom().1
            convertedLabel.text = "≈ \(amount) \(denom)"
            fiatButton.setTitle(denomination, for: UIControl.State.normal)
            fiatButton.backgroundColor = UIColor.clear
        }
        nextButton.setStyle(viewModel.satoshi == nil ? .primaryDisabled : .primary)
    }

    @objc func nextClick(_ sender: UIButton) {
        self.view.endEditing(true)
        guard viewModel.satoshi != nil else { return }
        if viewModel.isFiat {
            showError("Set 2FA limits in \(viewModel.denomination.rawValue)")
            return
        }
        self.startAnimating()
        Task { [weak self] in
            do {
                try await self?.viewModel.setTwoFactorLimit()
                self?.stopAnimating()
                if let coordinator = self?.coordinator {
                    coordinator.pop()
                } else {
                    self?.navigationController?.popViewController(animated: true)
                }
            } catch {
                self?.stopAnimating()
                self?.limitTextField.becomeFirstResponder()
                DropAlert().error(message: error.description().localized)
            }
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        viewModel.setSatoshi(amount: textField.text ?? "")
        refresh()
    }
}
