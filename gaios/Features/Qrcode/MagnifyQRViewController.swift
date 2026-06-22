import Foundation
import UIKit
import gdk
import ScreenShield

protocol MagnifyQRViewControllerDelegate: AnyObject {
    func close()
    func next()
}

enum CloseButtonVariant {
    case topCross
    case bottomButton(title: String, style: ButtonStyle)
}

enum TextDisplayVariant {
    case none
    case formattedAddress(text: String)
}

struct MagnifyQRConfiguration {
    var qrTxt: String?
    var qrBcur: BcurEncodedData?
    var textDisplay: TextDisplayVariant = .none
    var closeButton: CloseButtonVariant = .topCross
    var customHeaderView: UIView?
    var customFooterView: UIView?
}

class MagnifyQRViewController: UIViewController {

    @IBOutlet weak var bgLayer: UIView!
    @IBOutlet weak var qrCodeView: QRCodeView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var bottomCloseBtn: UIButton!
    @IBOutlet weak var topCrossCloseBtn: UIButton!
    @IBOutlet weak var navView: UIView!
    @IBOutlet weak var groupedTxt: UITextView!

    @IBOutlet weak var headerContainerStack: UIStackView!
    @IBOutlet weak var footerContainerStack: UIStackView!

    private let configuration: MagnifyQRConfiguration

    weak var delegate: MagnifyQRViewControllerDelegate?
    private let videoCaptureDump = VideoCaptureDump()

    init?(coder: NSCoder, configuration: MagnifyQRConfiguration) {
        self.configuration = configuration
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setStyle()
        setContent()
        addObserverUserDidTakeScreenshot()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
        // Protect ScreenShot
        ScreenShield.shared.protect(view: self.qrCodeView)
        // ScreenShield.shared.protectFromScreenRecording()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let bcur = configuration.qrBcur {
            qrCodeView.configure(frames: bcur.parts)
        } else if let text = configuration.qrTxt {
            qrCodeView.configure(frames: [text])
        }
        videoCaptureDump.install(on: self)

    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObserverUserDidTakeScreenshot()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoCaptureDump.uninstall()
    }

    func setContent() {
        if let header = configuration.customHeaderView {
            headerContainerStack.addArrangedSubview(header)
            headerContainerStack.isHidden = false
        } else {
            headerContainerStack.isHidden = true
        }

        if let footer = configuration.customFooterView {
            footerContainerStack.addArrangedSubview(footer)
            footerContainerStack.isHidden = false
        } else {
            footerContainerStack.isHidden = true
        }

        switch configuration.textDisplay {
        case .none:
            groupedTxt.isHidden = true
        case .formattedAddress(let address):
            AddressDisplay.configure(
                address: address,
                textView: groupedTxt,
                style: .default,
                truncate: false,
                appearance: .light,
                wordsPerRow: 5
            )
            groupedTxt.isHidden = false
        }
        switch configuration.closeButton {
        case .topCross:
            bottomCloseBtn.isHidden = true
        case let .bottomButton(title, style):
            navView.isHidden = true
            bottomCloseBtn.setStyle(style)
            bottomCloseBtn.setTitle(title, for: .normal)
        }
    }

    func setStyle() {
        topCrossCloseBtn.setImage(UIImage(named: "cancel")!.maskWithColor(color: .black), for: .normal)
    }

    @objc func onTap(sender: UITapGestureRecognizer) {
        dismiss { [weak self] in
            self?.delegate?.close()
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: {
                completion()
            })
        })
    }

    @IBAction func btnClose(_ sender: Any) {
        dismiss { [weak self] in
            self?.delegate?.next()
        }
    }

    @IBAction func btnNavClose(_ sender: Any) {
        dismiss { [weak self] in
            self?.delegate?.close()
        }
    }
}
