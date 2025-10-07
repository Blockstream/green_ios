import Foundation
import UIKit
import gdk
import greenaddress
import core
import LocalAuthentication
import ScreenShield
class ShowMnemonicsViewController: UIViewController {

    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var btnShowQR: UIButton!

    var prefilledCredentials: Credentials?
    var showBip85: Bool = false
    private var isHW: Bool { AccountsRepository.shared.current?.isHW ?? false }
    private var items: [String] = []
    private var bip39Passphrase: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setContent()
        setStyle()
        btnShowQR.setStyle(.primary)
        btnShowQR.setTitle("id_show_qr_code".localized, for: .normal)
        items = prefilledCredentials?.mnemonic?.split(separator: " ").map(String.init) ?? []
        collectionView.reloadData()
        if prefilledCredentials != nil {
            return
        }
        authenticated {
            Task {
                await self.reload(showLightning: self.showBip85)
            }
        }
        addObserverUserDidTakeScreenshot()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Protect ScreenShot
        ScreenShield.shared.protect(view: self.collectionView)
        ScreenShield.shared.protectFromScreenRecording()
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObserverUserDidTakeScreenshot()
    }

    func getCredentials() async -> Credentials? {
        return try? await WalletManager.current?.prominentSession?.getCredentials(password: "")
    }

    func getLightningCredentials() -> Credentials? {
        guard let account = AccountsRepository.shared.current else {
            return nil
        }
        return try? AuthenticationTypeHandler.getCredentials(method: .AuthKeyLightning, for: account.keychainLightning)
    }

    func reload(showLightning: Bool) async {
        let task = Task.detached { [weak self] in
            if showLightning {
                return await self?.getLightningCredentials()
            } else {
                return await self?.getCredentials()
            }
        }
        switch await task.result {
        case .success(let credentials):
            items = credentials?.mnemonic?.split(separator: " ").map(String.init) ?? []
            collectionView.reloadData()
        case .failure(let err):
            showError(err)
        }
    }

    func setContent() {
        // title = "id_recovery_phrase".localized
        lblInfo.text = "id_recovery_method".localized.uppercased()
        lblTitle.text = "id_recovery_phrase_check".localized
        lblHint.text = "id_make_sure_to_be_in_a_private".localized
    }
    func setStyle() {
        lblInfo.setStyle(.txtSmaller)
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtCard)
        btnShowQR.setStyle(.primary)
    }
    func magnifyQR() {
        let stb = UIStoryboard(name: "Utility", bundle: nil)
        if let vc = stb.instantiateViewController(withIdentifier: "MagnifyQRViewController") as? MagnifyQRViewController {
            vc.qrTxt = self.items.joined(separator: " ")
            vc.isMnemonic = true
            vc.showClose = true
            vc.modalPresentationStyle = .overFullScreen
            self.present(vc, animated: false, completion: nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    @IBAction func btnShowQR(_ sender: Any) {
        magnifyQR()
    }

    func authenticated(successAction: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authentication" ) { success, _ in
                DispatchQueue.main.async { [weak self] in
                    if success {
                        successAction()
                    } else {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }
}

extension ShowMnemonicsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WordCell", for: indexPath) as? WordCell {
            cell.configure(num: indexPath.item, word: items[indexPath.item])
            return cell
        }
        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
      switch kind {
      case UICollectionView.elementKindSectionFooter:
          if let fView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                         withReuseIdentifier: "FooterQrCell",
                                                                         for: indexPath) as? FooterQrCell {
              if showBip85 {
                  fView.configureBip85(mnemonic: self.items.joined(separator: " "))
                  return fView
              } else {
                  fView.configure(mnemonic: self.items.joined(separator: " "), bip39Passphrase: self.bip39Passphrase)
                  return fView
              }
          }
          return UICollectionReusableView()
      default:
          return UICollectionReusableView()
      }
    }
}

extension ShowMnemonicsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width) / 3.0
        let height = 50.0

        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}
