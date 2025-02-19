import Foundation

// Section of settings
public enum SettingsSections: String, Codable, CaseIterable {
    case network = "Network"
    case account = "Account"
    case twoFactor = "Two Factor"
    case security = "Security"
    case advanced = "Advanced"
    case about = "About"
}

// Setting type in all sections
public enum SettingsType: String, Codable {
    case SetupPin
    case WatchOnly
    case Logout
    case BitcoinDenomination = "unit"
    case ReferenceExchangeRate = "pricing"
    case SetupTwoFactor
    case ThresholdTwoFactor
    case LockTimeRequest
    case SetRecoveryEmail
    case ResetTwoFactor
    case Mnemonic
    case Autolock
    case Pgp
    case Sweep
    case Version
    case TermsOfUse
    case PrivacyPolicy
    case CsvTime
}

// Type of priority of a fee for transaction
public enum TransactionPriority: Int, CaseIterable {
    case Low = 24
    case Medium = 12
    case High = 3
    case Custom = 0

    public static let strings = [TransactionPriority.Low: "id_slow", TransactionPriority.Medium: "id_medium", TransactionPriority.High: "id_fast", TransactionPriority.Custom: "id_custom"]

    public var text: String {
        return TransactionPriority.strings[self] ?? ""
    }
}

// Bitcoin denomination type
public enum DenominationType: String, CodingKey {
    case BTC = "btc"
    case MilliBTC = "mbtc"
    case MicroBTC = "ubtc"
    case Bits = "bits"
    case Sats = "sats"

    public static let denominationsBTC: [DenominationType: String] = [ .BTC: "BTC", .MilliBTC: "mBTC", .MicroBTC: "µBTC", .Bits: "bits", .Sats: "sats"]
    public static let denominationsLBTC: [DenominationType: String] = [ .BTC: "LBTC", .MilliBTC: "LmBTC", .MicroBTC: "LµBTC", .Bits: "Lbits", .Sats: "Lsats"]
    public static let denominationsTEST: [DenominationType: String] = [ .BTC: "TEST", .MilliBTC: "mTEST", .MicroBTC: "µTEST", .Bits: "bTEST", .Sats: "sTEST"]
    public static let denominationsLTEST: [DenominationType: String] = [ .BTC: "LTEST", .MilliBTC: "LmTEST", .MicroBTC: "LµTEST", .Bits: "LbTEST", .Sats: "LsTEST"]

    public static func denominations(for gdkNetwork: GdkNetwork) -> [DenominationType: String] {
        if gdkNetwork.liquid && gdkNetwork.mainnet {
            return DenominationType.denominationsLBTC
        } else if gdkNetwork.liquid && !gdkNetwork.mainnet {
            return DenominationType.denominationsLTEST
        } else if !gdkNetwork.liquid && gdkNetwork.mainnet {
            return DenominationType.denominationsBTC
        } else {
            return DenominationType.denominationsTEST
        }
    }

    public func string(for gdkNetwork: GdkNetwork) -> String {
        let denominations = DenominationType.denominations(for: gdkNetwork)
        if let denom = denominations.filter({ $0.key == self }).first?.value {
            return denom
        }
        return denominations[.BTC]!
    }

    public var digits: UInt8 {
        switch self {
        case .BTC:
            return 8
        case .MilliBTC:
            return 5
        case .MicroBTC, .Bits:
            return 2
        case .Sats:
            return 0
        }
    }

    public static func from(_ string: String, for gdkNetwork: GdkNetwork) -> DenominationType {
        let denominations = DenominationType.denominations(for: gdkNetwork)
        if let denom = denominations.filter({ $0.value == string }).first?.key {
            return denom
        }
        return .BTC
    }
}

// Autolock type in time unit
public enum AutoLockType: Int {
    case minute = 1
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10
    case sixtyMinutes = 60
}

// Screenlock time type
public enum ScreenLockType: Int {
    case None = 0
    case Pin = 1
    case TouchID = 2
    case FaceID = 3
    case All = 4
}

// Setting item
public struct SettingsItem {
    public var title: String
    public var subtitle: String
    public var section: SettingsSections
    public var type: SettingsType
}

public struct SettingsNotifications: Codable {
    public init(emailIncoming: Bool, emailOutgoing: Bool) {
        self.emailIncoming = emailIncoming
        self.emailOutgoing = emailOutgoing
    }

    enum CodingKeys: String, CodingKey {
        case emailIncoming = "email_incoming"
        case emailOutgoing = "email_outgoing"
    }
    public var emailIncoming: Bool
    public var emailOutgoing: Bool
}

// Main setting
public class Settings: Codable {

    enum CodingKeys: String, CodingKey {
        case requiredNumBlock = "required_num_blocks"
        case altimeout = "altimeout"
        case unit = "unit"
        case pricing = "pricing"
        case customFeeRate = "custom_fee_rate"
        case pgp = "pgp"
        case sound = "sound"
        case notifications = "notifications"
        case csvtime = "csvtime"
    }

    public var requiredNumBlock: Int
    public var altimeout: Int
    public var unit: String
    public var pricing: [String: String]
    public var customFeeRate: UInt64?
    public var pgp: String?
    public var sound: Bool
    public var notifications: SettingsNotifications?
    public var csvtime: Int?

    public var denomination: DenominationType {
        get {
            let denom = DenominationType.denominationsBTC.filter { $0.value == self.unit }.first
            return denom?.key ?? DenominationType.BTC
        }
        set {
            self.unit = DenominationType.denominationsBTC[newValue] ?? "BTC"
        }
    }

    public var transactionPriority: TransactionPriority {
        get { return TransactionPriority(rawValue: self.requiredNumBlock) ?? .Medium}
        set { self.requiredNumBlock = newValue.rawValue}
    }

    public var autolock: AutoLockType {
        get { return AutoLockType.init(rawValue: self.altimeout) ?? .fiveMinutes}
        set { self.altimeout = newValue.rawValue}
    }

    public func getCurrency() -> String {
        return self.pricing["currency"]!
    }


    public static func from(_ data: [String: Any]) -> Settings? {
        if let json = try? JSONSerialization.data(withJSONObject: data, options: []) {
            return try? JSONDecoder().decode(Settings.self, from: json)
        }
        return nil
    }
}

public enum CsvTime: Int {
    case Short
    case Medium
    case Long

    public static func all(for gdkNetwork: GdkNetwork) -> [CsvTime] {
        if gdkNetwork.liquid {
            return [Long]
        } else {
            return [Short, Medium, Long]
        }
    }

    public static func values(for gdkNetwork: GdkNetwork) -> [Int]? {
        return gdkNetwork.csvBuckets
    }

    public func value(for gdkNetwork: GdkNetwork) -> Int? {
        let csvBuckets = CsvTime.values(for: gdkNetwork)
        if gdkNetwork.liquid {
            return csvBuckets?[0]
        }
        switch self {
        case .Short:
            return csvBuckets?[0]
        case .Medium:
            return csvBuckets?[1]
        case .Long:
            return csvBuckets?[2]
        }
    }

}
