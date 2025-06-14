import UIKit

protocol SquareSliderViewDelegate: AnyObject {
    func sliderThumbIsMoving(_ sliderView: SquareSliderView)
    func sliderThumbDidStopMoving(_ position: Int)
}

class SquareSliderView: UIView {

    weak var delegate: SquareSliderViewDelegate?
    var slideLbl = UILabel()
    var slideThumb = UIView()

    var slideStr = "id_slide_to_send".localized
    var sendingStr = "id_sending".localized

    func commonInit() {
        self.translatesAutoresizingMaskIntoConstraints = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        self.addGestureRecognizer(pan)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    @objc private func onPan(_ sender: UIPanGestureRecognizer) {

        let translation: CGPoint = sender.translation(in: self)
        delegate?.sliderThumbIsMoving(self)

        let thumbBoxC: CGPoint = CGPoint(x: self.slideThumb.center.x + translation.x, y: self.slideThumb.center.y)

        self.slideLbl.alpha = self.tag == 0 ? 1 - self.slideThumb.frame.origin.x / 100.0 : 1 - (self.frame.size.width - (self.slideThumb.frame.origin.x + self.slideThumb.frame.size.width)) / 100.0

        if self.slideThumb.frame.origin.x >= 0 && self.slideThumb.frame.origin.x <= self.frame.size.width - self.slideThumb.frame.size.width {
            self.slideThumb.center = thumbBoxC
        }

        switch sender.state {
        case .ended:
            if thumbBoxC.x > self.frame.size.width / 2.0 {
                UIView.animate(withDuration: 0.15, animations: {
                    self.slideThumb.center = CGPoint(x: self.frame.size.width - self.slideThumb.frame.size.width/2, y: self.slideThumb.center.y)
                }, completion: { _ in
                    self.delegate?.sliderThumbDidStopMoving(1)
                    self.slideLbl.alpha = 1.0
                    self.slideLbl.text = self.sendingStr
                })
            } else {
                UIView.animate(withDuration: 0.15, animations: {
                    self.slideThumb.center = CGPoint(x: self.bounds.origin.x + self.slideThumb.frame.size.width/2, y: self.slideThumb.center.y)
                }, completion: { _ in
                    self.delegate?.sliderThumbDidStopMoving(0)
                    self.slideLbl.alpha = 1.0
                    self.slideLbl.text = self.slideStr
                })
            }
        default:
            break
        }
        sender.setTranslation(.zero, in: self)
    }

    override func draw(_ rect: CGRect) {

        let fH: CGFloat = self.frame.size.height

        self.subviews.forEach { e in e.removeFromSuperview() }

        let bg = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.frame.size.width, height: self.frame.size.height))
        bg.backgroundColor = .black
        bg.layer.cornerRadius = 4.0
        self.addSubview(bg)

        self.slideLbl = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: self.frame.size.width, height: self.frame.size.height))
        self.slideLbl.textAlignment = .center
        self.slideLbl.font = .systemFont(ofSize: 16.0, weight: .semibold)
        self.slideLbl.text = self.slideStr
        self.slideLbl.textColor = .white
        self.addSubview(self.slideLbl)

        self.slideThumb = UIView(frame: CGRect(x: self.bounds.origin.x, y: self.bounds.origin.y, width: fH, height: fH))
        self.slideThumb.layer.cornerRadius = 4.0

        let offset: CGFloat = 12
        let iconView = UIImageView(frame: CGRect(x: offset, y: offset, width: fH - (2 * offset), height: fH - (2 * offset)))
        iconView.image = UIImage(named: "ic_square_slider")

        self.slideThumb.backgroundColor = UIColor.gAccent()
        self.slideThumb.addSubview(iconView)
        self.addSubview(self.slideThumb)
    }

    func reset() {
        UIView.animate(withDuration: 0.3, animations: {
            self.slideThumb.center = CGPoint(x: self.bounds.origin.x + self.slideThumb.frame.size.width / 2.0, y: self.slideThumb.center.y)
        }, completion: { _ in
            self.delegate?.sliderThumbDidStopMoving(0)
            self.slideLbl.alpha = 1.0
            self.slideLbl.text = self.slideStr
        })
    }

    func isActive(_ isActive: Bool) {
        isUserInteractionEnabled = isActive
        self.slideThumb.backgroundColor = isActive ? UIColor.gAccent() : UIColor.gW40()
    }
}
