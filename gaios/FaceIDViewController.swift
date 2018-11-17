import Foundation
import UIKit
import NVActivityIndicatorView

class FaceIDViewController: UIViewController, NVActivityIndicatorViewable {

    var password = String()
    var pinData = [String: Any]()
    let bioAuth = BiometricAuthentication()
    @IBOutlet weak var networkIndicator: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let net = getNetwork()
        if (net == Network.MainNet) {
            networkIndicator.image = UIImage(named: "mainnet")
        } else if (net == Network.TestNet) {
            networkIndicator.image = UIImage(named: "testnet")
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        self.performSegue(withIdentifier: "entrance", sender: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.layoutIfNeeded()
        self.view.applyGradient(colours: [UIColor.customMatrixGreen(), UIColor.customMatrixGreenDark()])
    }

    func authenticate() {
        if(!getAppDelegate().finishedConnecting) {
            retryAuthLater(time: 0.5)
        } else {
            let size = CGSize(width: 30, height: 30)
            self.startAnimating(size, message: "Logging in...", messageFont: nil, type: NVActivityIndicatorType.ballRotateChase)
            DispatchQueue.global(qos: .background).async {
                getGAService().loginWithPin(pin: self.password, pinData: self.pinData,
                    completionHandler: completion(
                        onResult: { _ in
                            DispatchQueue.main.async {
                                self.stopAnimating()
                                AccountStore.shared.initializeAccountStore()
                                self.performSegue(withIdentifier: "main", sender: self)
                            }
                        }, onError: { error in
                            print("incorrect PIN ", error)
                            DispatchQueue.main.async {
                                NVActivityIndicatorPresenter.sharedInstance.setMessage("Login Failed")
                            }
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                                self.stopAnimating()
                            }
                        }))
            }
        }
    }

    func retryAuthLater(time: Double) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + time) {
            if (self.isViewLoaded && (self.view.window != nil)) {
                self.authenticate()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        authenticate()
    }
}
