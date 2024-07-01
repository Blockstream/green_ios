import Foundation
import UIKit

class PromoViewController: UIViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var btnAction: UIButton!
    @IBOutlet weak var imgWrap: UIView!
    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!

    var promo: Promo?

    override func viewDidLoad() {
        super.viewDidLoad()

        setContent()
        setStyle()

        indicator.isHidden = true
        if let path = promo?.image_large, let imgUrl = URL(string: path) {
            Task {
                indicator.isHidden = false
                indicator.startAnimating()
                do {
                    let data = try await downloadImageData(from: imgUrl)
                    if let image = UIImage(data: data) {
                        self.img.image = image
                    }
                    indicator.isHidden = true
                    self.indicator.stopAnimating()
                } catch {}
            }
        } else {
            imgWrap.isHidden = true
        }
    }

    func setContent() {
        if let promo = promo {
            title = promo.title?.htmlDecoded
            lblTitle.text = promo.title_large?.htmlDecoded
            lblHint.text = promo.text_large?.htmlDecoded
            btnAction.setTitle(promo.cta_large?.htmlDecoded, for: .normal)
        }
    }

    func setStyle() {
        lblTitle.setStyle(.subTitle)
        lblHint.setStyle(.txt)
        btnAction.setStyle(.primary)
    }

    func downloadImageData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    @IBAction func btnAction(_ sender: Any) {
        if let promo {
            PromoManager.shared.promoOpen1(promo)
        }
        if let url = URL(string: promo?.link ?? "") {
            SafeNavigationManager.shared.navigate(url)
        }
    }
}
