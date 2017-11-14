//
//  PINViewController.swift
//  gaios
//

import UIKit

class PINButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)

        initView()
        initActions()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        initView()
        initActions()
    }

    private func initView() {
        layer.borderWidth = 1
        layer.cornerRadius = 30
        layer.borderColor = UIColor.black.cgColor
    }

    private func initActions() {
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchDragOutside, .touchCancel])
    }

    @objc func touchDown() {
        doAnimate(.black)
    }

    @objc func touchUp() {
        doAnimate(.clear)
    }

    func doAnimate(_ color: UIColor) {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.backgroundColor = color
            },
            completion: nil
        )
    }
}

class PinViewController: UIViewController {

    @IBAction func buttonPress(_ sender: PINButton) {
        print("Button Press")
    }
}
