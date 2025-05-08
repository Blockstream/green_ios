import Foundation
import UIKit
import WebKit
import core

enum BrowserAction {
    case close
}

class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    @IBOutlet weak var btnClose: UIButton!
    @IBOutlet weak var layoutView: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    private var webView: WKWebView?

    var url: URL?
    var onClose: (() -> Void)?
    var titleStr: String?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.alpha = 0.0
        lblTitle.setStyle(.titleDialog)
        lblTitle.text = titleStr ?? ""
    }

    deinit {
        print("deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let url = url {
            let frame = CGRect(x: 0.0, y: 0.0, width: layoutView.frame.size.width, height: layoutView.frame.size.height)
            webView = WKWebView(frame: frame, configuration: webViewConfiguration)
            webView?.uiDelegate = self
            if let webView = webView {
                self.layoutView.addSubview(webView)
            }
            logger.info("BrowserViewController url: \(url)")
            webView?.load(URLRequest(url: url))
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

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = url {
            logger.info("BrowserViewController url: \(url)")
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
