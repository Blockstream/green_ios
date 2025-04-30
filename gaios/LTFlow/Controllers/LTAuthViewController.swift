import Foundation
import UIKit
import BreezSDK
import greenaddress
import lightning
import core

class LTAuthViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var btnAuth: UIButton!
    @IBOutlet weak var hintFrame: UIView!
    @IBOutlet weak var squareSliderView: SquareSliderView!

    var requestData: LnUrlAuthRequestData?

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        btnAuth.isHidden = true
        squareSliderView.delegate = self
    }

    func setContent() {
        title = "LNURL Auth"
        lblTitle.text = "id_you_can_use_your_wallet_to".localized
        lblInfo.text = "id_no_personal_data_will_be_shared".localized
        btnAuth.setTitle("id_authenticate".localized, for: .normal)
        reloadData()
    }

    func setStyle() {
        lblTitle.setStyle(.txtBigger)
        lblHint.setStyle(.txtBigger)
        lblInfo.setStyle(.txtCard)
        btnAuth.setStyle(.primary)
        hintFrame.borderWidth = 1.0
        hintFrame.borderColor = UIColor.gAccent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hintFrame.layer.cornerRadius = hintFrame.frame.size.height / 2.0
    }

    func reloadData() {
        lblHint.text = requestData?.domain
    }

    @IBAction func btnAuth(_ sender: Any) {
        if let requestData = requestData {
            lnAuth(requestData: requestData)
        }
    }

    func lnAuth(requestData: LnUrlAuthRequestData) {
        startAnimating()
        Task {
            do {
                let lightBridge = WalletManager.current?.lightningSession?.lightBridge
                guard let res = try lightBridge?.authLnUrl(requestData: requestData) else {
                    throw GaError.GenericError()
                }
                switch res {
                case .ok:
                    DropAlert().success(message: "Authentication successful")
                    self.next()
                case .errorStatus(let data):
                    DropAlert().error(message: data.reason)
                }
            } catch {
                self.showError(error)
            }
            stopAnimating()
            squareSliderView.reset()
        }
    }

    @MainActor
    func next() {
        let avc = navigationController?.viewControllers.filter { $0 is AccountViewController }.first
        if avc != nil {
            navigationController?.popToViewController(ofClass: AccountViewController.self)
        } else {
            navigationController?.popToViewController(ofClass: WalletViewController.self)
        }
    }
}

extension LTAuthViewController: SquareSliderViewDelegate {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView) {
        //
    }

    func sliderThumbDidStopMoving(_ position: Int) {
        if position == 1 {
            if let requestData = requestData {
                lnAuth(requestData: requestData)
            }
        }
    }
}
