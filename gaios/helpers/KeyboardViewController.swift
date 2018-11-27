import Foundation
import UIKit

class KeyboardViewController : UIViewController {
    var keyboardDismissGesture: UIGestureRecognizer?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if keyboardDismissGesture == nil {
            keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(KeyboardViewController.dismissKeyboard))
            view.addGestureRecognizer(keyboardDismissGesture!)
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if keyboardDismissGesture != nil {
            view.removeGestureRecognizer(keyboardDismissGesture!)
            keyboardDismissGesture = nil
        }
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
