import UIKit

extension UITextView {

    func addDoneButtonToKeyboard(myAction: Selector?) {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        doneToolbar.barStyle = UIBarStyle.default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "id_done".localized, style: UIBarButtonItem.Style.done, target: self, action: myAction)
        done.accessibilityIdentifier = AccessibilityIdentifiers.KeyboardView.done

        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(done)

        doneToolbar.items = items
        doneToolbar.sizeToFit()

        self.inputAccessoryView = doneToolbar
    }
    @objc func keyboardPaste() {
        let notification = NSNotification.Name(rawValue: "KeyboardPaste")
        NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
    }
    func addDoneAndPasteButtonOnKeyboard(myAction: Selector?) {
        let multiToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        multiToolbar.barStyle = UIBarStyle.default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let doneBtnItem: UIBarButtonItem = UIBarButtonItem(title: "id_done".localized, style: UIBarButtonItem.Style.done, target: self, action: myAction)
        doneBtnItem.accessibilityIdentifier = AccessibilityIdentifiers.KeyboardView.done

        let pasteBtn = UIButton(type: .system)
        pasteBtn.contentEdgeInsets = UIEdgeInsets(top: 7.0, left: 7.0, bottom: 7.0, right: 7.0)
        pasteBtn.setImage(UIImage(named: "ic_paste")?.maskWithColor(color: UIView().tintColor!), for: .normal)

        pasteBtn.addTarget(self, action: #selector(keyboardPaste), for: .touchUpInside)

        let pasteBtnItem = UIBarButtonItem(customView: pasteBtn)
        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(pasteBtnItem)
        items.append(doneBtnItem)
        multiToolbar.items = items
        multiToolbar.sizeToFit()

        self.inputAccessoryView = multiToolbar
   }
}
