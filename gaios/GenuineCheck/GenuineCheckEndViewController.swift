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
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var imageJade: UIImageView!
    
    var model: GenuineCheckEndViewModel!
    weak var delegate: GenuineCheckEndViewControllerDelegate?
    
    let loadingIndicator: ProgressView = {
        let progress = ProgressView(colors: [UIColor.customMatrixGreen()], lineWidth: 2)
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        lblTitle.setStyle(.subTitle24)
        lblHint.setStyle(.txtCard)
        [btnSupport, btnContinue, btnRetry].forEach {
            $0?.setStyle(.primary)
        }
        [btnDiy, btnCancel].forEach {
            $0?.setStyle(.outlinedWhite)
            $0?.setTitleColor(.white, for: .normal)
        }
        lblInfo.setStyle(.txtBigger)
        
        progressView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor
                .constraint(equalTo: progressView.centerXAnchor),
            loadingIndicator.centerYAnchor
                .constraint(equalTo: progressView.centerYAnchor),
            loadingIndicator.widthAnchor
                .constraint(equalToConstant: progressView.frame.width),
            loadingIndicator.heightAnchor
                .constraint(equalTo: progressView.widthAnchor)
        ])
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
    
    @MainActor
    func start() {
        loadingIndicator.isAnimating = true
    }
    
    @MainActor
    func stop() {
        loadingIndicator.isAnimating = false
    }
    
    func run() async {
        start()
        await model.run()
        stop()
        reload()
        if model.state == .exit {
            dismiss(.error(model.error))
        }
    }
}
