import Foundation
import core

private enum AmpSectionType {
    case v2
    case legacy

    var createType: CreateAmpType {
        switch self {
        case .v2:
            return .v2
        case .legacy:
            return .legacy
        }
    }

    var title: String {
        switch self {
        case .v2:
            return "AMP".localized
        case .legacy:
            return "AMP Legacy".localized
        }
    }
}

@MainActor
class DialogAmpViewModel: Sendable {

    var service: AmpService?
    var onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)?

    init(onUpdate: (@MainActor @Sendable (RefreshAmpFeature?) -> Void)? = nil) {
        self.onUpdate = onUpdate
        self.service = AmpService(onUpdate: {[weak self] feature in
            self?.onUpdate?(feature)
        })
    }

    func getAmpAccounts() -> [Account] {
        return service?.getAmpAccounts() ?? []
    }
    func getLegacyAmpAccounts() -> [Account] {
        return service?.getLegacyAmpAccounts() ?? []
    }

    var isJade: Bool {
        return service?.mainWallet?.isJade ?? false
    }

    private var hasAnyAmpAccount: Bool {
        return (getAmpAccounts().count + getLegacyAmpAccounts().count) > 0
    }

    private var sectionTypes: [AmpSectionType] {
        if isJade {
            return getLegacyAmpAccounts().isEmpty ? [] : [.legacy]
        }
        return hasAnyAmpAccount ? [.v2, .legacy] : []
    }

    var sectionCount: Int {
        return sectionTypes.count
    }

    var title: String {
        hasAnyAmpAccount ?
        "AMP Account".localized :
        "Create an AMP Account".localized
    }
    var btnCreateTitle: String {
        return "Create AMP Account".localized
    }
    var hint: String {
        hasAnyAmpAccount ? "Share your AMP ID with your security token issuer for authorization to move funds.".localized : "AMP accounts allow you to send, receive and store managed assets issued on the Liquid Network.".localized
    }
    func cellAmpModels() -> [DialogAmpCellModel] {
        if getAmpAccounts().count + getLegacyAmpAccounts().count == 0 {
            return []
        } else if getAmpAccounts().count == 0 {
            return [DialogAmpCellModel(name: "AMP Liquid".localized, hash: nil)]
        } else {
            var list = [DialogAmpCellModel]()
            getAmpAccounts().forEach {
                list
                    .append(
                        DialogAmpCellModel(name: $0.name, hash: $0.receivingId)
                    )
            }
            return list
        }
    }
    func cellAmpLegacyModels() -> [DialogAmpCellModel] {
        if getAmpAccounts().count + getLegacyAmpAccounts().count == 0 {
            return []
        } else if getLegacyAmpAccounts().count == 0 {
            return [DialogAmpCellModel(name: "AMP Liquid (Legacy)".localized, hash: nil)]
        } else {
            var list = [DialogAmpCellModel]()
            getLegacyAmpAccounts().forEach {
                list
                    .append(
                        DialogAmpCellModel(name: $0.name, hash: $0.receivingId)
                    )
            }
            return list
        }
    }

    private func sectionType(at section: Int) -> AmpSectionType? {
        guard section >= 0, section < sectionTypes.count else {
            return nil
        }
        return sectionTypes[section]
    }

    func numberOfRows(in section: Int) -> Int {
        switch sectionType(at: section) {
        case .v2:
            return cellAmpModels().count
        case .legacy:
            return cellAmpLegacyModels().count
        case .none:
            return 0
        }
    }

    func sectionTitle(_ section: Int) -> String {
        return sectionType(at: section)?.title ?? ""
    }

    func cellModel(_ indexPath: IndexPath) -> DialogAmpCellModel {
        switch sectionType(at: indexPath.section) {
        case .v2:
            let models = cellAmpModels()
            return models[indexPath.row]
        case .legacy:
            let models = cellAmpLegacyModels()
            return models[indexPath.row]
        case .none:
            let models = cellAmpLegacyModels()
            return models[indexPath.row]
        }
    }

    func createType(_ indexPath: IndexPath) -> CreateAmpType {
        return sectionType(at: indexPath.section)?.createType ?? .legacy
    }
    func onCreate(_ type: CreateAmpType) {
        service?.onCreate(type)
    }
}
