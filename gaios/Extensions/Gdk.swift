import core
import gdk

extension TransactionPriority {
    
    public static func from(_ string: String) -> TransactionPriority {
        let priority = TransactionPriority.strings.filter { $0.value.localized == string }.first
        return priority?.key ?? .Medium
    }

    public func time(isLiquid: Bool) -> String {
        let blocksPerHour = isLiquid ? 60 : 6
        let blocks = self.rawValue
        let n = (blocks % blocksPerHour) == 0 ? blocks / blocksPerHour : blocks * (60 / blocksPerHour)
        let time = (blocks % blocksPerHour) == 0 ? (blocks == blocksPerHour ? "id_hour".localized : "id_hours".localized) : "id_minutes".localized
        return String(format: "%d %@", n, time)
    }

    public func description(isLiquid: Bool) -> String {
        let confirmationInBlocks = String(format: "id_confirmation_in_d_blocks".localized, self.rawValue)
        return confirmationInBlocks + ", " + time(isLiquid: isLiquid) + " " + "id_on_average".localized
    }
}

extension ScreenLockType {

    public func toString() -> String? {
        switch self {
        case .None:
            return ""
        case .Pin:
            return "id_pin".localized
        case .TouchID:
            return "id_touch_id".localized
        case .FaceID:
            return "id_face_id".localized
        default:
            return ""
        }
    }
}
extension AutoLockType {
    
    public static func from(_ value: String) -> AutoLockType {
        switch value {
        case AutoLockType.minute.string:
            return .minute
        case AutoLockType.twoMinutes.string:
            return .twoMinutes
        case AutoLockType.fiveMinutes.string:
            return .fiveMinutes
        case AutoLockType.sixtyMinutes.string:
            return .sixtyMinutes
        default:
            return .tenMinutes
        }
    }
    public var string: String {
        let number = String(format: "%d", self.rawValue)
        let localized = self == .minute ? "id_minute".localized : "id_minutes".localized
        return "\(number) \(localized)"
    }
}

extension CsvTime {
    
    public func label() -> String {
        switch self {
        case .Short:
            return "id_6_months_25920_blocks".localized
        case .Medium:
            return "id_12_months_51840_blocks".localized
        case .Long:
            return "id_15_months_65535_blocks".localized
        }
    }
    
    public func description() -> String {
        switch self {
        case .Short:
            return "id_optimal_if_you_spend_coins".localized
        case .Medium:
            return "id_wallet_coins_will_require".localized
        case .Long:
            return "id_optimal_if_you_rarely_spend".localized
        }
    }
}
