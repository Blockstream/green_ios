import Foundation
import core

enum PromoScreen: String {
    case walletOverview = "WalletOverview"
    case home = "Home"
}

protocol PromoManagerDelegate: AnyObject {
    func preloadDidEnd()
}

class PromoManager {
    static let shared = PromoManager()
    var promos: [Promo]?
    var sessionDismiss = false
    struct PromosConfig: Decodable {
        let promos: [Promo]
    }
    weak var delegate: PromoManagerDelegate?

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(remoteConfigIsReady), name: NSNotification.Name(rawValue: "remote_config_is_ready"), object: nil)
    }
    func promoCellModels(_ screen: PromoScreen) -> [PromoCellModel] {
        guard let promos else { return [] }
        if sessionDismiss == true {
            return []
        }

        if let promo = (promos.filter { $0.isVisible() == true && ($0.screens ?? []).contains(screen.rawValue)}).first {
            if (promo.image_small ?? "").isEmpty || promo.imgData != nil {
                return [PromoCellModel(promo: promo, source: screen)]
            } else {
                return []
            }
        }
        return []
    }
    func dismissedPromos() -> [String] {
        if let dismissedPromos: [String] = UserDefaults.standard.object(forKey: AppStorageConstants.dismissedPromos.rawValue) as? [String] {
            return dismissedPromos
        }
        return []
    }
    func dismissPromo(_ id: String) {
        var dismissed = dismissedPromos()
        if !dismissed.contains(id) {
            dismissed.append(id)
            UserDefaults.standard.set(dismissed, forKey: AppStorageConstants.dismissedPromos.rawValue)
            sessionDismiss = true
        }
    }
    func clearDismissed() {
        sessionDismiss = false
        UserDefaults.standard.removeObject(forKey: AppStorageConstants.dismissedPromos.rawValue)
    }
    func preloadThumbs() async {
        if let config: Any = AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigPromos) {
            let json = try? JSONSerialization.data(withJSONObject: config, options: .fragmentsAllowed)
            promos = try? JSONDecoder().decode([Promo].self, from: json ?? Data())
        }
        if let promos {
            for promo in promos {
                await promo.preload()
            }
        }
        delegate?.preloadDidEnd()
    }
    func promoView(promo: Promo, source: PromoScreen) {
        if let id = promo.id {
            AnalyticsManager.shared.promoImpression(account: AccountsRepository.shared.current, promoId: id, screen: source.rawValue)
        }
    }
    func onDismiss(promo: Promo, source: PromoScreen) {
        if let id = promo.id {
            dismissPromo(id)
            AnalyticsManager.shared.promoDismiss(account: AccountsRepository.shared.current, promoId: id, screen: source.rawValue)
        }
    }
    func promoOpen(promo: Promo, source: PromoScreen) {
        if let id = promo.id {
            AnalyticsManager.shared.promoOpen(account: AccountsRepository.shared.current, promoId: id, screen: source.rawValue)
        }
    }
    func promoAction(promo: Promo, source: PromoScreen) {
        if let id = promo.id {
            AnalyticsManager.shared.promoAction(account: AccountsRepository.shared.current, promoId: id, screen: source.rawValue)
        }
    }
    @objc func remoteConfigIsReady() {
        let appSettings = AppSettings.shared
        guard let gdkSettings = appSettings.gdkSettings else { return }
        let isTorOn = gdkSettings.tor == true
        if isTorOn { return }
        Task {
            do {
                await PromoManager.shared.preloadThumbs()
            }
        }
    }
}
