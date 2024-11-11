import Foundation
import UIKit
class Promo: Decodable {
    let is_visible: Bool?
    let id: String?
    let title: String?
    let title_small: String?
    let image_small: String?
    let text_small: String?
    let cta_small: String?
    let link: String?
    let title_large: String?
    let image_large: String?
    let text_large: String?
    let cta_large: String?
    let screens: [String]?
    var imgData: Data?
    let is_small: Bool?

    var thumb: UIImage? {
        if let imgData {
            return UIImage(data: imgData)
        }
        return nil
    }

    func isVisible() -> Bool {
        if is_visible == true &&
            id?.isEmpty == false &&
            screens?.isEmpty == false {

            if let id {
                if !PromoManager.shared.dismissedPromos().contains(id) {
                    return true
                }
            }
        }
        return false
    }

    func preload() async {
        if let path = self.image_small, let imgUrl = URL(string: path) {
            let data = try? await downloadImageData(from: imgUrl)
            self.imgData = data
        }
    }

    func downloadImageData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
