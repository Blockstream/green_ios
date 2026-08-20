import Foundation
import core

struct SafePromo: Decodable {
    let promo: Promo?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.promo = try? container.decode(Promo.self)
    }
}

class PromoManager {
    static let shared = PromoManager()
    static let promosDidLoad = Notification.Name("promos_did_load")

    var promos: [Promo]?
    private var trackedImpressions = Set<String>()

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchPromosOnConfigReady), name: NSNotification.Name(rawValue: "remote_config_is_ready"), object: nil)
    }

    func getPromos() -> [PromoCellModel] {
        guard let promos else { return [] }
        let dismissedPromos = getDismissedPromos()
        let eligiblePromos = promos.filter { $0.isVisible && !dismissedPromos.contains($0.id) }
        return eligiblePromos.map { PromoCellModel(promo: $0) }
    }

    func getDismissedPromos() -> [String] {
        if let dismissedPromos: [String] = UserDefaults.standard.object(forKey: AppStorageConstants.dismissedPromos.rawValue) as? [String] {
            return dismissedPromos
        }
        return []
    }

    func dismissPromo(for id: String) {
        var dismissed = getDismissedPromos()
        if !dismissed.contains(id) {
            dismissed.append(id)
            UserDefaults.standard.set(dismissed, forKey: AppStorageConstants.dismissedPromos.rawValue)
        }
    }

    func clearDismissedPromos() {
        UserDefaults.standard.removeObject(forKey: AppStorageConstants.dismissedPromos.rawValue)
    }

    func loadPromos() async {
        guard let config: Any = AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigPromos) else { return }
        let json = try? JSONSerialization.data(withJSONObject: config, options: .fragmentsAllowed)
        if let data = json, let safePromos = try? JSONDecoder().decode([SafePromo].self, from: data) {
            promos = safePromos.compactMap { $0.promo }
        } else {
            promos = []
        }
        NotificationCenter.default.post(name: Self.promosDidLoad, object: nil)
    }

    func trackPromoImpression(promo: Promo) {
        guard !trackedImpressions.contains(promo.id) else { return }
        trackedImpressions.insert(promo.id)
        AnalyticsManager.shared.promoImpression(wallet: WalletsStorage.shared.current, promoId: promo.id, screen: "HomeTab")
    }

    func trackPromoDismiss(promo: Promo) {
        dismissPromo(for: promo.id)
        AnalyticsManager.shared.promoDismiss(wallet: WalletsStorage.shared.current, promoId: promo.id, screen: "HomeTab")
    }

    func trackPromoAction(promo: Promo) {
        AnalyticsManager.shared.promoAction(wallet: WalletsStorage.shared.current, promoId: promo.id, screen: "HomeTab")
    }

    @objc func fetchPromosOnConfigReady() {
        let appSettings = AppSettings.shared
        guard let gdkSettings = appSettings.gdkSettings else { return }
        let isTorOn = gdkSettings.tor == true
        if isTorOn { return }
        Task {
            do {
                await PromoManager.shared.loadPromos()
            }
        }
    }
}
