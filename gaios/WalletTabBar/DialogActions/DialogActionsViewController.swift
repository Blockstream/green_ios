import Foundation
import UIKit
import gdk

enum DialogActions {
    case confirm
    case link
}

class DialogActionsViewController: UIViewController {
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var btnActionConfirm: UIButton!
    @IBOutlet weak var btnLink: UIButton!
    @IBOutlet weak var tappableBg: UIView!
    @IBOutlet weak var handle: UIView!
    @IBOutlet weak var anchorBottom: NSLayoutConstraint!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    var delegate: ((DialogActions) -> ())? = nil
    var viewModel: DialogActionsViewModel!
    
    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .dark)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.4)
        customBlurEffectView.frame = self.view.bounds

        let dimmedView = UIView()
        dimmedView.backgroundColor = .black.withAlphaComponent(0.3)
        dimmedView.frame = self.view.bounds
        containerView.addSubview(customBlurEffectView)
        containerView.addSubview(dimmedView)
        return containerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()
        
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        
        view.alpha = 0.0
        anchorBottom.constant = -cardView.frame.size.height
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
            swipeDown.direction = .down
            self.view.addGestureRecognizer(swipeDown)
        let tapToClose = UITapGestureRecognizer(target: self, action: #selector(didTap))
            tappableBg.addGestureRecognizer(tapToClose)
    }
    

    @objc func didSwipe(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .down:
                dismiss(nil)
            default:
                break
            }
        }
    }

    @objc func didTap(gesture: UIGestureRecognizer) {
        dismiss(nil)
    }
    
    func setContent() {
        lblTitle.text = viewModel.title
        lblDescription.text = viewModel.description
        btnActionConfirm.setTitle(viewModel.confirm, for: .normal)
        btnLink.setTitle(viewModel.link, for: .normal)
    }
    

    func setStyle() {
        lblTitle.setStyle(.txtBigger)
        lblDescription.setStyle(.txt)
        btnActionConfirm.isHidden = viewModel.confirm == nil
        btnLink.isHidden = viewModel.link == nil
        btnActionConfirm.setStyle(.primary)
        btnLink.setStyle(.underline(txt: viewModel.link ?? "", color: UIColor.gAccent()))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        anchorBottom.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
            self.view.layoutIfNeeded()
        }
    }
    func dismiss(_ action: DialogActions?) {
        anchorBottom.constant = -cardView.frame.size.height
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
            if let action = action {
                self.delegate?(action)
            }
        })
    }
    @IBAction func tapConfirm(_ sender: Any) {
        dismiss(.confirm)
    }
    @IBAction func tapLink(_ sender: Any) {
        dismiss(.link)
    }
}

