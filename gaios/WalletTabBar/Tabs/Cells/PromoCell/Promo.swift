import Foundation
import UIKit
import core

class Promo: Decodable {
    let is_visible: Bool?
    let id: String?
    var title: String?
    var title_small: String?
    let image_small: String?
    var text_small: String?
    var cta_small: String?
    let link: String?
    var title_large: String?
    let image_large: String?
    var text_large: String?
    var cta_large: String?
    let screens: [String]?
    var imgData: Data?
    let is_small: Bool?
    let layout_small: Int?
    let layout_large: Int?
    var overline_small: String?
    var overline_large: String?
    let video_large: String?
    let target: String?

    var thumb: UIImage? {
        if let imgData {
            return UIImage(data: imgData)
        }
        return nil
    }
    func preDecode() {
        title = title?.htmlDecoded
        title_small = title_small?.htmlDecoded
        text_small = text_small?.htmlDecoded
        cta_small = cta_small?.htmlDecoded
        title_large = title_large?.htmlDecoded
        text_large = text_large?.htmlDecoded
        cta_large = cta_large?.htmlDecoded
        overline_small = overline_small?.htmlDecoded
        overline_large = overline_large?.htmlDecoded
    }
    func isVisible() -> Bool {
        let hwVisibleWallets = AccountsRepository.shared.hwVisibleAccounts
        if let target {
            // jade plus users only
            if target == "jadeplus_user" {
                let v_2s = hwVisibleWallets.filter { ($0.boardType == .v2) }.count
                if v_2s == 0 {
                    return false
                }
            } else if target == "only_sww" {
                // if user has hw, don't show
                if hwVisibleWallets.count > 0 {
                    return false
                }
            } else if target == "jade_user" {
                // if user has v1 but not v2 dont' show
                let v_1s = hwVisibleWallets.filter { ($0.boardType == .v1 || $0.boardType == .v1_1) }.count
                let v_2s = hwVisibleWallets.filter { ($0.boardType == .v2) }.count
                if v_1s > 0 && v_2s == 0 {
                } else {
                    return false
                }
            }
        }
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
        if let path = self.video_large, let url = URL(string: path) {
            try? await saveRemoteVideo(url)
        }
    }

    func downloadImageData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    func getMediaURL() -> URL? {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let mediaURL = cachesURL.appendingPathComponent("media")
        if !FileManager.default.fileExists(atPath: mediaURL.path) {
            do {
                try FileManager.default.createDirectory(atPath: mediaURL.path, withIntermediateDirectories: true, attributes: nil)
                return mediaURL
            } catch {
                return nil
            }
        } else {
            return mediaURL
        }
    }

    func saveRemoteVideo(_ url: URL) async throws {

        guard let mediaURL = getMediaURL() else { return }

        let destinationURL = mediaURL.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("promodbg, video ready \(destinationURL)")
        } else {
            do {
                let request = URLRequest(url: url)
                print("promodbg, downloading: \(url)")
                let (data, _) = try await URLSession.shared.data(for: request)
                try data.write(to: destinationURL)
            } catch {
                print("promodbg, error saving file:", error)
            }
        }
    }

    func videoURL() -> URL? {
        if let path = self.video_large, let url = URL(string: path) {
            let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let mediaURL = cachesURL.appendingPathComponent("media")
            let videoURL: URL = mediaURL.appendingPathComponent(url.lastPathComponent)
            return URL(string: "file://" + videoURL.path)
        }
        return nil
    }
}
