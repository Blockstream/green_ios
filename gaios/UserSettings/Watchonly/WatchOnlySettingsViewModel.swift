import Foundation
import UIKit
import core

import greenaddress

class WatchOnlySettingsViewModel {

    // load wallet manager for current logged session
    var wm: WalletManager { WalletManager.current! }

    // settings cell models
    var sections: [WOSection] {
        if wm.hasMultisig {
            WOSection.allCases
        } else {
            [WOSection.Singlesig]
        }
    }
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
        for backend in wm.activeGdkMultisigBackends {
            if let model = try? await self.loadWOMultisig(backend) {
                multisigCellModels += [model]
            }
        }
        // Singlesig watchonly with extended pub keys
        let cellHeaderPubKeys = WatchOnlySettingsCellModel(
            title: "id_extended_public_keys".localized,
            subtitle: "id_tip_you_can_use_the".localized,
            network: nil)
        self.singlesigCellModels = [cellHeaderPubKeys]
        for backend in wm.activeGdkSinglesigBackends {
            if let models = try? await self.loadWOSinglesigExtendedPubKeys(backend) {
                singlesigCellModels += models
            }
        }

        // Singlesig watchonly with core output descriptors
        let cellHeaderCoreDesc = WatchOnlySettingsCellModel(
            title: "id_output_descriptors".localized,
            subtitle: "",
            network: nil)
        self.singlesigCellModels += [cellHeaderCoreDesc]
        for backend in wm.activeGdkSinglesigBackends {
            if let models = try? await self.loadWOSinglesigCoreDescriptors(backend) {
                singlesigCellModels += models
            }
        }
    }

    func loadWOMultisig(_ backend: GdkNetworkBackend) async throws -> WatchOnlySettingsCellModel? {
        let subaccounts = try? await backend.getAccounts(refresh: false).filter { !$0.hidden }
        if subaccounts?.isEmpty ?? true {
            return nil
        }
        let username = try await backend.session.getWatchOnlyUsername()
        guard let username = username else { throw GaError.GenericError()}
        return WatchOnlySettingsCellModel(
            title: backend.gdkNetwork.name,
            subtitle: username.isEmpty ? "id_set_up_watchonly_credentials".localized : String(format: "id_enabled_1s".localized, username),
            network: backend.gdkNetwork.network)
    }

    func readSubaccounts(_ backend: GdkNetworkBackend) async throws -> [Account] {
        let allSubaccounts = try? await backend.getAccounts(refresh: false).filter {
            !$0.hidden
        }
        var subaccounts = [Account]()
        for subaccount in allSubaccounts ?? [] {
            if let account = try? await backend.getAccount(account: subaccount) {
                subaccounts += [account]
            }
        }
        return subaccounts
    }

    func loadWOSinglesigExtendedPubKeys(_ backend: GdkNetworkBackend) async throws -> [WatchOnlySettingsCellModel] {
        return try await readSubaccounts(backend)
            .filter { $0.extendedPubkey != nil }
            .compactMap {
                WatchOnlySettingsCellModel(
                    title: $0.localizedName,
                    subtitle: $0.extendedPubkey ?? "",
                    network: $0.gdkNetwork.network,
                    isExtended: true)
            }
    }

    func loadWOSinglesigCoreDescriptors(_ backend: GdkNetworkBackend) async throws -> [WatchOnlySettingsCellModel] {
        return try await readSubaccounts(backend)
            .filter { $0.coreDescriptors != nil }
            .compactMap {
                WatchOnlySettingsCellModel(
                    title: $0.localizedName,
                    subtitle: $0.coreDescriptors?.joined(separator: "\n") ?? "",
                    network: $0.gdkNetwork.network)
            }
    }
}
