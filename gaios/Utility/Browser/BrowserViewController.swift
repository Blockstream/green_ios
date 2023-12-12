import Foundation
import UIKit
import WebKit

enum BrowserAction {
    case close
}

class BrowserViewController: UIViewController {

    @IBOutlet weak var btnClose: UIButton!
    @IBOutlet weak var webView: WKWebView!
    
    var url: URL?
    var onClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.alpha = 0.0
        
        if let url = url {
            webView.load(URLRequest(url: url))
        }
    }

    deinit {
        print("deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }

    func dismiss(_ action: BrowserAction) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: {
                self?.onClose?()
            })
        })
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss(.close)
    }
}
