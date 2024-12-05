import Foundation
import AVFoundation
import UIKit

enum PromoLayoutLarge {
    case _0 // image
    case _1 // video
}
class PromoViewController: UIViewController {

    @IBOutlet weak var lblTitleLayout0: UILabel!
    @IBOutlet weak var lblHintLayout0: UILabel!
    @IBOutlet weak var lblOverline: UILabel!
    @IBOutlet weak var lblTitleLayout1: UILabel!
    @IBOutlet weak var lblHintLayout1: UILabel!
    @IBOutlet weak var stackLayout1: UIStackView!
    @IBOutlet weak var btnAction: UIButton!
    @IBOutlet weak var imgWrap: UIView!
    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var btnDismiss: UIButton!
    @IBOutlet weak var videoView: UIView!
    var player: AVPlayer?
    private var activeToken, resignToken: NSObjectProtocol?

    var promo: Promo?
    var source: PromoScreen?
    var promoLayout = PromoLayoutLarge._0

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.alpha = 0.0

        if promo?.layout_large == 1 {
            promoLayout = ._1
        }
        setContent()
        setStyle()

        indicator.isHidden = true
        if promoLayout == ._0 {
            stackLayout1.isHidden = true
            if let path = promo?.image_large, let imgUrl = URL(string: path) {
                Task {
                    indicator.isHidden = false
                    indicator.startAnimating()
                    do {
                        let data = try await downloadImageData(from: imgUrl)
                        if let image = UIImage(data: data) {
                            self.img.image = image
                            self.img.isHidden = false
                        }
                        indicator.isHidden = true
                        self.indicator.stopAnimating()
                    } catch {}
                }
            } else {
                imgWrap.isHidden = true
            }
        } else {
            scrollView.isHidden = true
        }
    }

    func setContent() {
        if let promo = promo {
            title = promo.title
            lblTitleLayout0.text = promo.title_large
            lblHintLayout0.text = promo.text_large
            btnAction.setTitle(promo.cta_large, for: .normal)
            lblOverline.text = promo.overline_large
            lblTitleLayout1.text = promo.title_large
            lblHintLayout1.text = promo.text_large
        }
    }

    func setStyle() {
        lblTitleLayout0.setStyle(.subTitle)
        lblHintLayout0.setStyle(.txt)
        btnAction.setStyle(.primary)
        lblOverline.setStyle(.txtSmaller)
        lblTitleLayout1.setStyle(.subTitle24)
        lblHintLayout1.setStyle(.txt)
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

        activeToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: applicationDidBecomeActive)
        resignToken = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: applicationWillResignActive)

        UIView.animate(withDuration: 1.0) {
            self.view.alpha = 1.0
        }
        if promoLayout == ._1 {
            loadVideo()
        }
    }

    func loadVideo() {
        if let url = promo?.videoURL() {
            configureAudio()
            player = AVPlayer(url: url)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = self.videoView.bounds
            playerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill

            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: nil) { (_) in
                self.player?.seek(to: CMTime.zero)
                self.player?.play()
            }

            self.videoView.layer.addSublayer(playerLayer)
            player?.play()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let token = activeToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = resignToken {
            NotificationCenter.default.removeObserver(token)
        }
        player?.pause()
        player = nil
    }

    deinit {
        print("deinit")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if promoLayout == ._1 {
            player?.play()
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
        if promoLayout == ._1 {
            player?.pause()
        }
    }

    func configureAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
    }

    @IBAction func btnAction(_ sender: Any) {
        if let promo, let source {
            PromoManager.shared.promoAction(promo: promo, source: source)
        }
        if let url = URL(string: promo?.link ?? "") {
            SafeNavigationManager.shared.navigate(url, exitApp: true)
            self.dismiss(animated: false, completion: nil)
        }
    }

    @IBAction func btnDismiss(_ sender: Any) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
}

//    func next() {
//        for future usage
//        if step > 2 {
//            if let promo, let source {
//                PromoManager.shared.promoAction(promo: promo, source: source)
//            }
//            if let url = URL(string: promo?.link ?? "") {
//                SafeNavigationManager.shared.navigate(url)
//            }
//            return
//        }
//        let playerTimescale = self.player?.currentItem?.asset.duration.timescale ?? 1
//        let start = offset[step]
//        let stop = offset[step + 1]
//        let time =  CMTime(seconds: start, preferredTimescale: playerTimescale)
//        self.player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
//            let cmTimeTo =  CMTime(seconds: stop, preferredTimescale: playerTimescale)
//            self.player?.currentItem?.forwardPlaybackEndTime = cmTimeTo
//            self.player?.play()
//            self.step += 1
//        }
//    }
