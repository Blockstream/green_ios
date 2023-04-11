import UIKit
import RxBluetoothKit
import RxSwift
import RiveRuntime

class JadeWaitViewController: HWFlowBaseViewController {

    @IBOutlet weak var lblStepNumber: UILabel!
    @IBOutlet weak var lblStepTitle: UILabel!
    @IBOutlet weak var lblStepHint: UILabel!
    @IBOutlet weak var lblLoading: UILabel!
    @IBOutlet weak var infoBox: UIView!
    @IBOutlet weak var loaderPlaceholder: UIView!
    @IBOutlet weak var animateView: UIView!

    let viewModel = JadeWaitViewModel()
    var timer: Timer?
    var idx = 0

    private var activeToken, resignToken: NSObjectProtocol?

    let loadingIndicator: ProgressView = {
        let progress = ProgressView(colors: [UIColor.customMatrixGreen()], lineWidth: 2)
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        loadNavigationBtns()
        update()
        animateView.alpha = 0.0
    }

    deinit {
        print("Deinit")
    }

    override func viewDidAppear(_ animated: Bool) {
        activeToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: applicationDidBecomeActive)
        resignToken = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: applicationWillResignActive)
        timer = Timer.scheduledTimer(timeInterval: Constants.jadeAnimInterval, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        BLEViewModel.shared.scan(jade: true,
                                 completion: self.next,
                                 error: self.error)
        update()
        UIView.animate(withDuration: 0.3) {
            self.animateView.alpha = 1.0
        }
        start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = activeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = resignToken {
            NotificationCenter.default.removeObserver(token)
        }
        stop()
        timer?.invalidate()
        BLEViewModel.shared.scanDispose?.dispose()
    }

    @objc func fireTimer() {
        refresh()
    }

    func setContent() {
        lblLoading.text = "id_looking_for_device".localized
    }

    func refresh() {

        UIView.animate(withDuration: 0.25, animations: {
            [self.lblStepNumber, self.lblStepTitle, self.lblStepHint, self.animateView].forEach {
                $0?.alpha = 0.0
            }}, completion: { _ in
                if self.idx < 2 { self.idx += 1 } else { self.idx = 0}
                self.update()
                UIView.animate(withDuration: 0.4, animations: {
                    [self.lblStepNumber, self.lblStepTitle, self.lblStepHint, self.animateView].forEach {
                        $0?.alpha = 1.0
                    }
                })
            })
    }

    func update() {
        animateView.subviews.forEach({ $0.removeFromSuperview() })
        let riveView = viewModel.steps[idx].riveModel.createRiveView()
        animateView.addSubview(riveView)
        riveView.frame = CGRect(x: 0.0, y: 0.0, width: animateView.frame.width, height: animateView.frame.height)
        self.lblStepNumber.text = self.viewModel.steps[idx].titleStep
        self.lblStepTitle.text = self.viewModel.steps[idx].title
        self.lblStepHint.text = self.viewModel.steps[idx].hint
    }

    func loadNavigationBtns() {
        let settingsBtn = UIButton(type: .system)
        settingsBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        settingsBtn.tintColor = UIColor.gGreenMatrix()
        settingsBtn.setTitle("id_setup_guide".localized, for: .normal)
        settingsBtn.addTarget(self, action: #selector(setupBtnTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: settingsBtn)
    }

    func setStyle() {
        infoBox.cornerRadius = 5.0
        lblStepNumber.font = UIFont.systemFont(ofSize: 12.0, weight: .black)
        lblStepTitle.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        lblStepHint.font = UIFont.systemFont(ofSize: 12.0, weight: .regular)
        lblLoading.font = UIFont.systemFont(ofSize: 12.0, weight: .bold)
        lblStepNumber.textColor = UIColor.gGreenMatrix()
        lblStepTitle.textColor = .white
        lblStepHint.textColor = .white.withAlphaComponent(0.6)
        lblLoading.textColor = .white
    }

    @objc func setupBtnTapped() {
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "SetupJadeViewController") as? SetupJadeViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func start() {
        loaderPlaceholder.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor
                .constraint(equalTo: loaderPlaceholder.centerXAnchor),
            loadingIndicator.centerYAnchor
                .constraint(equalTo: loaderPlaceholder.centerYAnchor),
            loadingIndicator.widthAnchor
                .constraint(equalToConstant: loaderPlaceholder.frame.width),
            loadingIndicator.heightAnchor
                .constraint(equalTo: loaderPlaceholder.widthAnchor)
        ])

        loadingIndicator.isAnimating = true
    }

    func stop() {
        loadingIndicator.isAnimating = false
    }

    func next(peripherals: [Peripheral]) {
        if peripherals.isEmpty { return }
        let hwFlow = UIStoryboard(name: "HWFlow", bundle: nil)
        if let vc = hwFlow.instantiateViewController(withIdentifier: "ListDevicesViewController") as? ListDevicesViewController {
            vc.isJade = true
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        start()
    }

    func applicationWillResignActive(_ notification: Notification) {
        stop()
    }
}
