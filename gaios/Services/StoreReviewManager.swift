import Foundation
import core
import StoreKit
import gdk

class StoreReviewHelper {

    static let shared = StoreReviewHelper()

    var months = 4

    var appReview: Int?

    private func isReviewDateValid() -> Bool {

        let now = Date()

        if let storeReviewDate = UserDefaults.standard.object(forKey: AppStorageConstants.storeReviewDate.rawValue) as? Date {

            if let appReview = appReview, appReview > months {
                months = appReview
            }

            if now - storeReviewDate > Double( months * 30 * 86400 ) {
                UserDefaults.standard.set(now, forKey: AppStorageConstants.storeReviewDate.rawValue)
                return true
            } else {
                print("SKIP")
                return false
            }
        } else {
            UserDefaults.standard.set(now, forKey: AppStorageConstants.storeReviewDate.rawValue)
            return true
        }
    }

    private func requestReview() {

        SKStoreReviewController.requestReview()
    }
}

extension StoreReviewHelper {
    func request(isSendAll: Bool, account: Account?, walletItem: WalletItem?) {

        appReview = AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigAppReview) as? Int

        if isSendAll { return }
        if appReview == 0 { return }

        if !isReviewDateValid() { return }

        AnalyticsManager.shared.appReview(account: account, walletItem: walletItem)
        requestReview()
    }
}
