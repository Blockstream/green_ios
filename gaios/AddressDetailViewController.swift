
import Foundation
import UIKit
import AVFoundation

class AddressDetailViewController: UIViewController {

    var wallet: WalletItem? = nil
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var qrImageView: UIImageView!
    @IBOutlet weak var receiveAddressLabel: UILabel!
    @IBOutlet weak var sweepButton: UIButton!

    var amount: Double = 0
    var qrCodeFrameView: UIView?
    var QRCodeReader = UIView()
    var QRBackgroundView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("id_address", comment: "")
        receiveAddressLabel.text = wallet?.getAddress()
        updateQRCode()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        backgroundView.addGestureRecognizer(tap)
        sweepButton.isHidden = AccountStore.shared.isWatchOnly
    }

    @IBAction func sweepButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "sweep", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcViewController {
            nextController.wallet = wallet
            nextController.sweepTransaction = true
        }
    }

    @IBAction func shareButtonClicked(_ sender: Any) {
        let activityViewController = UIActivityViewController(activityItems: [wallet?.getAddress() as Any] , applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)
    }

    @IBAction func copyButtonClicked(_ sender: Any) {
        UIPasteboard.general.string = receiveAddressLabel.text
    }

    func updateQRCode() {
        if (amount == 0) {
            let uri = bip21Helper.btcURIforAddress(address: (wallet?.getAddress())!)
            qrImageView.image = QRImageGenerator.imageForTextWhite(text: uri, frame: qrImageView.frame)
        } else {
            let uri = bip21Helper.btcURIforAmount(address: (wallet?.getAddress())!, amount: amount)
            qrImageView.image = QRImageGenerator.imageForTextWhite(text: uri, frame: qrImageView.frame)
        }
    }

    @IBAction func generateNewAddress(_ sender: Any) {
        do {
            let address = try getSession().getReceiveAddress(subaccount: (wallet?.pointer)!)
            wallet?.receiveAddress = address
            receiveAddressLabel.text = wallet?.getAddress()
            updateQRCode()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: EventType.AddressChanged.rawValue), object: nil, userInfo: ["pointer" : wallet?.pointer])
        } catch {
            print("unable to get receive address")
        }
    }

    @objc func dismiss(recognizer: UITapGestureRecognizer) {
        navigationController?.popViewController(animated: true)
    }
}
