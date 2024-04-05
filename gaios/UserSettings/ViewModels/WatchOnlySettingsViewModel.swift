import Foundation
import UIKit
import core
import gdk
import greenaddress

class WatchOnlySettingsViewModel {

    // load wallet manager for current logged session
    var wm: WalletManager { WalletManager.current! }

    // settings cell models
    var sections = WOSection.allCases
    var items = [WOSection: [UserSettingsItem]]()
    var multisigCellModels = [WatchOnlySettingsCellModel]()
    var singlesigCellModels = [WatchOnlySettingsCellModel]()

    func getCellModel(at indexPath: IndexPath) -> WatchOnlySettingsCellModel? {
        let section = sections[indexPath.section]
        return (section == .Multisig ? multisigCellModels : singlesigCellModels)[indexPath.row]
    }

    func getCellModelsForSection(at indexSection: Int) -> [WatchOnlySettingsCellModel]? {
        let section = sections[indexSection]
        return section == .Multisig ? multisigCellModels : singlesigCellModels
    }

    func load() async {
        // Multisig watchonly with username / password
        self.multisigCellModels = []
        for session in wm.activeMultisigSessions {
            if let model = try? await self.loadWOMultisig(session) {
                multisigCellModels += [model]
            }
        }
        // Singlesig watchonly with extended pub keys
        let cellHeaderPubKeys = WatchOnlySettingsCellModel(
            title: "id_extended_public_keys".localized,
            subtitle: "id_tip_you_can_use_the".localized,
            network: nil)
        self.singlesigCellModels = [cellHeaderPubKeys]
        for session in wm.activeSinglesigSessions {
            if let models = try? await self.loadWOSinglesigExtendedPubKeys(session) {
                singlesigCellModels += models
            }
        }
        
        // Singlesig watchonly with core output descriptors
        let cellHeaderCoreDesc = WatchOnlySettingsCellModel(
            title: "id_output_descriptors".localized,
            subtitle: "",
            network: nil)
        self.singlesigCellModels += [cellHeaderCoreDesc]
        for session in wm.activeSinglesigSessions {
            if let models = try? await self.loadWOSinglesigCoreDescriptors(session) {
                singlesigCellModels += models
            }
        }
    }

    func loadWOMultisig(_ session: SessionManager) async throws -> WatchOnlySettingsCellModel? {
        let subaccounts = try? await session.subaccounts().filter { !$0.hidden }
        if subaccounts?.isEmpty ?? true {
            return nil
        }
        let username = try await session.getWatchOnlyUsername()
        guard let username = username else { throw GaError.GenericError()}
        return WatchOnlySettingsCellModel(
            title: session.gdkNetwork.name,
            subtitle: username.isEmpty ? "id_set_up_watchonly_credentials".localized : String(format: "id_enabled_1s".localized, username),
            network: session.gdkNetwork.network)
    }

    func readSubaccounts(_ session: SessionManager) async throws -> [WalletItem] {
        let allSubaccounts = try? await session.subaccounts().filter { !$0.hidden }
        var subaccounts = [WalletItem]()
        for subaccount in allSubaccounts ?? [] {
            if let account = try? await session.subaccount(subaccount.pointer) {
                subaccounts += [account]
            }
        }
        return subaccounts
    }

    func loadWOSinglesigExtendedPubKeys(_ session: SessionManager) async throws -> [WatchOnlySettingsCellModel] {
        return try await readSubaccounts(session)
            .filter { $0.extendedPubkey != nil }
            .compactMap {
                WatchOnlySettingsCellModel(
                    title: $0.localizedName,
                    subtitle: $0.extendedPubkey ?? "",
                    network: $0.gdkNetwork.network,
                    isExtended: true)
            }
    }

    func loadWOSinglesigCoreDescriptors(_ session: SessionManager) async throws -> [WatchOnlySettingsCellModel] {
        return try await readSubaccounts(session)
            .filter { $0.coreDescriptors != nil }
            .compactMap {
                WatchOnlySettingsCellModel(
                    title: $0.localizedName,
                    subtitle: $0.coreDescriptors?.joined(separator: "\n") ?? "",
                    network: $0.gdkNetwork.network)
            }
    }
}
