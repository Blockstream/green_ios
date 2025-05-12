import UIKit

enum GenuineCheckEndAction {
    case diy
    case support
    case `continue`
    case cancel
    case retry
    case error(_ err: Error?)
}

protocol GenuineCheckEndViewControllerDelegate: AnyObject {
    func onTap(_ action: GenuineCheckEndAction)
}

class GenuineCheckEndViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var iconState: UIImageView!

    @IBOutlet weak var btnDiy: UIButton!
    @IBOutlet weak var btnSupport: UIButton!
    @IBOutlet weak var btnContinue: UIButton!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnRetry: UIButton!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var progressView: ProgressView!
    @IBOutlet weak var imageJade: UIImageView!
    private var activeToken, resignToken: NSObjectProtocol?

    var model: GenuineCheckEndViewModel!
    weak var delegate: GenuineCheckEndViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        setContent()
        setStyle()
        reload()
        Task.detached(priority: .background) { [weak self] in
            await self?.run()
        }
    }

    func reload() {
        lblTitle.text = model.title
        lblHint.text = model.hint
        lblInfo.text = model.lblInfo
        iconState.image = model.icon
        [btnCancel, btnRetry, btnContinue, btnDiy, btnSupport, lblInfo, progressView].forEach {
            $0?.isHidden = true
        }
        imageJade.image = UIImage(named: "ic_genuine_check_jade")
        switch model.state {
        case .notGenuine:
            [btnDiy, btnSupport].forEach {
                $0?.isHidden = false
            }
        case .genuine:
            btnContinue.isHidden = false
        case .cancel:
            [btnCancel, btnRetry].forEach {
                $0?.isHidden = false
            }
        case .progress:
            imageJade.image = UIImage(named: "ic_genuine_check_jade_vertical")
            [lblInfo, progressView].forEach {
                $0?.isHidden = false
            }
        case .exit:
            break
        }
    }

    deinit {
        print("Deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activeToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: applicationDidBecomeActive)
        resignToken = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: applicationWillResignActive)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = activeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = resignToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progressView.isAnimating = true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        progressView.isAnimating = true
    }

    func applicationWillResignActive(_ notification: Notification) {
    }

    func setContent() {
        lblTitle.text = model.title
        lblHint.text = model.hint
        lblInfo.text = model.lblInfo
        btnDiy.setTitle(model.btnDIY, for: .normal)
        btnSupport.setTitle(model.btnSupport, for: .normal)
        btnContinue.setTitle(model.btnContinue, for: .normal)
        btnCancel.setTitle(model.btnCancel, for: .normal)
        btnRetry.setTitle(model.btnRetry, for: .normal)
    }

    func setStyle() {
        lblTitle.setStyle(.title)
        lblHint.setStyle(.txt)
        lblInfo.setStyle(.txt)
        [btnSupport, btnContinue, btnRetry].forEach {
            $0?.setStyle(.primary)
        }
        [btnDiy, btnCancel].forEach {
            $0?.setStyle(.outlinedWhite)
            $0?.setTitleColor(.white, for: .normal)
        }
        progressView.isAnimating = true
    }

    func dismiss(_ action: GenuineCheckEndAction) {
        self.dismiss(animated: true) {
            self.delegate?.onTap(action)
        }
    }

    @IBAction func btnDiy(_ sender: Any) {
        dismiss(.diy)
    }
    @IBAction func btnSupport(_ sender: Any) {
        dismiss(.support)
    }
    @IBAction func btnContinue(_ sender: Any) {
        dismiss(.continue)
    }
    @IBAction func btnCancel(_ sender: Any) {
        dismiss(.cancel)
    }
    @IBAction func btnRetry(_ sender: Any) {
        dismiss(.retry)
    }

    func run() async {
        await model.run()
        reload()
        if model.state == .exit {
            dismiss(.error(model.error))
        }
    }
}
