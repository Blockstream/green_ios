import Foundation
import UIKit
import WebKit

enum BrowserAction {
    case close
}

class BrowserViewController: UIViewController {

    @IBOutlet weak var btnClose: UIButton!
    @IBOutlet weak var layoutView: UIView!

    var url: URL?
    var onClose: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.alpha = 0.0
    }

    deinit {
        print("deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let url = url {
            let frame = CGRect(x: 0.0, y: 0.0, width: layoutView.frame.size.width, height: layoutView.frame.size.height)
            let webView = WKWebView(frame: frame, configuration: webViewConfiguration)
            self.layoutView.addSubview(webView)
            webView.load(URLRequest(url: url))
        }
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

    lazy var webViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        return configuration
    }()

    @IBAction func btnClose(_ sender: Any) {
        dismiss(.close)
    }
}
