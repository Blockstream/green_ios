import Foundation
import Countly
import gdk
import greenaddress

public enum AnalyticsConsent: Int {
    case notDetermined
    case denied
    case authorized
}

public enum AppStorageConstants: String {
    case dontShowTorAlert = "dont_show_tor_alert"
    case defaultTransactionPriority = "default_transaction_priority"
    case userAnalyticsPreference = "user_analytics_preference"
    case analyticsUUID = "analytics_uuid"
    case countlyOffset = "countly_offset"
    case alwaysAskPassphrase = "always_ask_passphrase"
    case storeReviewDate = "store_review_date"
    case hideBalance = "hide_balance"
    case acceptedTerms = "accepted_terms"
    case dismissedPromos = "dismissed_promos"
    case walletsToBackup = "wallets_to_backuo"
}

public protocol AnalyticsManagerDelegate: AnyObject {
    func remoteConfigIsReady()
}

public class AnalyticsManager {

    public static let shared = AnalyticsManager()

    public let host = (Bundle.main.infoDictionary?["COUNTLY_APP_HOST"] as? String ?? "")
        .replacingOccurrences(of: "\\", with: "")
    public let hostOnion = (Bundle.main.infoDictionary?["COUNTLY_APP_HOST_ONION"] as? String ?? "")
        .replacingOccurrences(of: "\\", with: "")
    public let appKey = (Bundle.main.infoDictionary?["COUNTLY_APP_KEY"] as? String ?? "")
    public var maxCountlyOffset: Int {
        if let offset = Bundle.main.infoDictionary?["COUNTLY_APP_MAX_OFFSET"] as? String,
           let number = Int(offset) {
            return number * 1000
        }
        return 1
    }
    public var eventSendThreshold: UInt? {
        if let offset = Bundle.main.infoDictionary?["COUNTLY_APP_EVENT_SEND_THRESHOLD"] as? String {
            return UInt(offset)
        }
        return nil
    }

    public var consent: AnalyticsConsent {
        get {
            return AnalyticsConsent(rawValue: UserDefaults.standard.integer(forKey: AppStorageConstants.userAnalyticsPreference.rawValue)) ?? .notDetermined
        }
        set {
            let prev = AnalyticsConsent(rawValue: UserDefaults.standard.integer(forKey: AppStorageConstants.userAnalyticsPreference.rawValue)) ?? .notDetermined
            UserDefaults.standard.set(newValue.rawValue, forKey: AppStorageConstants.userAnalyticsPreference.rawValue)

            if newValue == .denied {
                reset()
            }
            giveConsent()
        }
    }

    public var analyticsUUID: String {
        get {
            if let uuid = UserDefaults.standard.string(forKey: AppStorageConstants.analyticsUUID.rawValue) {
                logger.info("analyticsUUID \(uuid, privacy: .public)")
                return uuid
            } else {
                let uuid = UUID().uuidString
                logger.info("analyticsUUID \(uuid, privacy: .public)")
                UserDefaults.standard.setValue(uuid, forKey: AppStorageConstants.analyticsUUID.rawValue)
                return uuid
            }
        }
    }

    public let authorizedGroup = [CLYConsent.sessions,
                           CLYConsent.events,
                           CLYConsent.crashReporting,
                           CLYConsent.viewTracking,
                           CLYConsent.userDetails,
                           CLYConsent.location,
                           CLYConsent.remoteConfig,
                           CLYConsent.metrics,
                           CLYConsent.performanceMonitoring,
                           CLYConsent.feedback]

    public let deniedGroup = [CLYConsent.crashReporting,
                       CLYConsent.remoteConfig,
                       CLYConsent.metrics,
                       CLYConsent.feedback]

    // list of ignorable common error messages
    public let skipExceptionRecording = [
        "id_invalid_amount",
        "id_no_amount_specified",
        "id_invalid_address",
        "id_insufficient_funds",
        "id_invalid_private_key",
        "id_action_canceled",
        "id_login_failed"
    ]

    public var countlyFeedbackWidget: CountlyFeedbackWidget?

    public func invalidateAnalyticsUUID() {
        UserDefaults.standard.removeObject(forKey: AppStorageConstants.analyticsUUID.rawValue)
    }

    public func invalidateCountlyOffset() {
        UserDefaults.standard.removeObject(forKey: AppStorageConstants.countlyOffset.rawValue)
    }

    public var countlyOffset: UInt {
        get {
            if let offset = UserDefaults.standard.object(forKey: AppStorageConstants.countlyOffset.rawValue) as? UInt {
                logger.info("analyticsOFFSET \(offset)")
                return offset
            } else {
                let offset = secureRandom(max: maxCountlyOffset)
                logger.info("analyticsOFFSET \(offset)")
                UserDefaults.standard.setValue(offset, forKey: AppStorageConstants.countlyOffset.rawValue)
                return offset
            }
        }
    }

    public weak var delegate: AnalyticsManagerDelegate?

    public var activeNetworks: [NetworkSecurityCase]? {
        let wm = WalletManager.current
        return wm?.activeNetworks
            .filter { net in !(wm?.subaccounts.filter { !$0.hidden && $0.networkType == net }.isEmpty ?? false) }
    }

    public var analyticsNetworks: AnalyticsManager.NtwTypeDescriptor? {
        if let activeNetworks = activeNetworks {
            let bitcoinNtws = activeNetworks.filter { $0 == .bitcoinSS || $0 == .bitcoinMS || $0.lightning }
            let liquidNtws = activeNetworks.filter { $0 == .liquidSS || $0 == .liquidMS }
            let testnetNtws = activeNetworks.filter { $0 == .testnetSS || $0 == .testnetMS }
            let testnetLiquidNtws = activeNetworks.filter { $0 == .testnetLiquidSS || $0 == .testnetLiquidMS }

            if bitcoinNtws.count > 0 && liquidNtws.count > 0 { return AnalyticsManager.NtwTypeDescriptor.mainnetMixed }
            if bitcoinNtws.count > 0 { return AnalyticsManager.NtwTypeDescriptor.mainnet }
            if liquidNtws.count > 0 { return AnalyticsManager.NtwTypeDescriptor.liquid }
            if testnetNtws.count > 0 && testnetLiquidNtws.count > 0 { return AnalyticsManager.NtwTypeDescriptor.testnetMixed }
            if testnetNtws.count > 0 { return AnalyticsManager.NtwTypeDescriptor.testnet }
            if testnetLiquidNtws.count > 0 { return AnalyticsManager.NtwTypeDescriptor.testnetLiquid }
        }
        return nil
    }

    public var analyticsSecurity: [SecTypeDescriptor]? {
        if let activeNetworks = activeNetworks {
            let hasSinglesig = activeNetworks.filter { [.bitcoinSS, .liquidSS, .testnetSS, .testnetLiquidSS].contains($0) }.count > 0
            let hasMultisig = activeNetworks.filter { [.bitcoinMS, .liquidMS, .testnetMS, .testnetLiquidMS].contains($0) }.count > 0
            let hasLightning = activeNetworks.filter { [.lightning, .testnetLightning].contains($0) }.count > 0
            var security = [SecTypeDescriptor]()
            if hasSinglesig {
                security += [hasMultisig || hasLightning ? .single : .singlesig]
            }
            if hasMultisig {
                security += [hasSinglesig || hasLightning ? .multi : .multisig]
            }
            if hasLightning {
                security += [hasSinglesig || hasMultisig ? .light : .lightning]
            }
            return security
        }
        return nil
    }

    public func secureRandom(max: Int) -> UInt {
        // SystemRandomNumberGenerator is automatically seeded, is safe to use in multiple threads
        // and uses a cryptographically secure algorithm whenever possible.
        var gen = SystemRandomNumberGenerator()
        return UInt(Int.random(in: 1...max, using: &gen))
    }

    public func countlyStart() {

        let config: CountlyConfig = CountlyConfig()
        config.appKey = appKey
        config.host = getHost()
        config.offset = countlyOffset
        config.deviceID = analyticsUUID
        config.features = [.crashReporting]
        config.enablePerformanceMonitoring = true
        config.enableDebug = false
        config.requiresConsent = true
        config.enableRemoteConfig = true
        if let threshold = eventSendThreshold {
            config.eventSendThreshold = threshold
        }
        config.urlSessionConfiguration = getSessionConfiguration(session: nil)

        if consent == .authorized {
            config.consents = authorizedGroup
        } else {
            config.consents = deniedGroup
        }

        config.remoteConfigCompletionHandler = { error in
            if error == nil {
                logger.info("Remote Config is ready to use!")
                self.delegate?.remoteConfigIsReady()
                let notification = NSNotification.Name(rawValue: "remote_config_is_ready")
                NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
            } else {
                logger.error("There was an error while fetching Remote Config:\n\(error!.localizedDescription)")
            }
        }
        Countly.sharedInstance().start(with: config)

        giveConsent()
    }

    private func reset() {
        Countly.sharedInstance().cancelConsentForAllFeatures()
        // change the deviceID
        invalidateAnalyticsUUID()
        invalidateCountlyOffset()
        Countly.sharedInstance().changeDeviceIDWithoutMerge(analyticsUUID)
        Countly.sharedInstance().setNewOffset(countlyOffset)
        Countly.sharedInstance().disableLocationInfo()
    }

    private func giveConsent() {
        logger.info("giving consent: \(self.consent.rawValue)")
        switch consent {
        case .notDetermined:
            break
        case .denied:
            Countly.sharedInstance().giveConsent(forFeatures: deniedGroup)
            updateUserProperties()
        case .authorized:
            Countly.sharedInstance().giveConsent(forFeatures: authorizedGroup)
            updateUserProperties()
        }
    }

    public func setupSession(session: GDKSession?) {
        let host = getHost()
        let conf = getSessionConfiguration(session: session)
        Countly.sharedInstance().setNewHost(host)
        Countly.sharedInstance().setNewURLSessionConfiguration(conf)
        /*URLSession(configuration: conf).dataTask(with: URL(string: host+"/i")!) {
                data, response, error in
                print (data)
                print (response)
                print (error)
        }.resume()*/
    }

    private func getHost() -> String {
        GdkSettings.read()?.tor ?? false ? hostOnion : host
    }

    private func getSessionConfiguration(session: Session?) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        let settings = GdkSettings.read()
        // set explicit proxy
        if settings?.proxy ?? false {
            configuration.connectionProxyDictionary = [
                kCFStreamPropertySOCKSProxyHost: settings?.socks5Hostname ?? "",
                kCFStreamPropertySOCKSProxyPort: settings?.socks5Port ?? ""
            ]
        }
        // set implicit tor proxy
        if settings?.tor ?? false {
            let proxySettings = try? session?.getProxySettings()
            let proxy = proxySettings?["proxy"] as? String ?? ""
            let parser = proxy.split(separator: ":").map { $0.replacingOccurrences(of: "/", with: "") }
            if parser.first == "socks5" && parser.count == 3 {
                configuration.connectionProxyDictionary = [
                    kCFStreamPropertySOCKSProxyHost: parser[1],
                    kCFStreamPropertySOCKSProxyPort: Int(parser[2]) ?? 0,
                    kCFProxyTypeKey: kCFProxyTypeSOCKS
                ]
            }
        }
        return configuration
    }

    private func updateUserProperties() {
        let accounts = AccountsRepository.shared.swAccounts

        let bitcoin_wallets = accounts.filter { !$0.gdkNetwork.liquid }
        let liquid_wallets = accounts.filter { $0.gdkNetwork.liquid }

        var props: [String: String] = [:]
        props[AnalyticsManager.strUserPropertyTotalWallets] = "\((bitcoin_wallets + liquid_wallets).count)"

        Countly.user().custom = props as CountlyUserDetailsNullableDictionary
        Countly.user().save()
    }

    public func appLoadingFinished() {
        guard consent != .notDetermined else { return }
        Countly.sharedInstance().appLoadingFinished()
    }

    public  func userPropertiesDidChange() {
        guard consent != .notDetermined else { return }
        updateUserProperties()
    }

    public func getSurvey(completion: @escaping (CountlyWidget?) -> Void) {
        guard consent != .notDetermined else {
            completion(nil)
            return
        }
        Countly.sharedInstance().getFeedbackWidgets({ [weak self] widgets, error in
            if error == nil, let widget = (widgets?.filter { $0.type == .NPS || $0.type == .survey })?.first {
                widget.getData { wData, error in

                    if error == nil, let data = wData {
                        let w = CountlyWidget.build(data)
                        self?.countlyFeedbackWidget = widget
                        completion(w)
                    } else {
                        completion(nil)
                    }
                }
            } else {
                completion(nil)
            }
        })
    }

    public func submitSurvey(_ result: [AnyHashable: Any]) {
        guard let widget = countlyFeedbackWidget else { return }
        widget.recordResult(result)
    }

    public func submitNPS(_ result: [AnyHashable: Any]) {
        guard let widget = countlyFeedbackWidget else { return }
        widget.recordResult(result)
    }

    public func submitExclude() {
        guard let widget = countlyFeedbackWidget else { return }
        widget.recordResult(nil)
    }

    public func recordEvent(_ key: AnalyticsEventName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().recordEvent(key.rawValue)
    }

    public func recordEvent(_ key: AnalyticsEventName, sgmt: [String: String]) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().recordEvent(key.rawValue, segmentation: sgmt, count: 1, sum: 0.0)
    }

    public func cancelEvent(_ key: AnalyticsEventName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().cancelEvent(key.rawValue)
    }

    public func startEvent(_ key: AnalyticsEventName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().startEvent(key.rawValue)
    }

    public func endEvent(_ key: AnalyticsEventName, sgmt: [String: String]) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().endEvent(key.rawValue, segmentation: sgmt, count: 1, sum: 0.0)
    }

    public func startTrace(_ key: AnalyticsEventName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().startCustomTrace(key.rawValue)
    }

    public func endTrace(_ key: AnalyticsEventName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().endCustomTrace(key.rawValue, metrics: [:])
    }

    public func cancelTrace(_ key: AnalyticsEventName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().cancelCustomTrace(key.rawValue)
    }

    public func recordView(_ name: AnalyticsViewName) {
        guard consent == .authorized else { return }
        Countly.sharedInstance().recordView(name.rawValue)
    }

    public func recordView(_ name: AnalyticsViewName, sgmt: [String: String]?) {
        guard consent == .authorized else { return }
        guard let s = sgmt else { return }
        Countly.sharedInstance().recordView(name.rawValue, segmentation: s)
    }

    public func getRemoteConfigValue(key: String) -> Any? {
        return Countly.sharedInstance().remoteConfigValue(forKey: key)
    }

    public func recordFeedback(rating: Int, email: String?, comment: String) {
        Countly.sharedInstance()
            .recordRatingWidget(withID: AnalyticsManager.ratingWidgetId,
                                rating: rating,
                                email: email,
                                comment: comment,
                                userCanBeContacted: true)
    }

    public var emptiedAccount: WalletItem?
}
