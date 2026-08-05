import Foundation

import core
import greenaddress

struct SwapRescanService {
    let wm: WalletManager

    func rescan() async throws {
        guard let swapMonitor = wm.swapMonitor else {
            throw GaError.GenericError("Invalid swap session")
        }

        await swapMonitor.stop()
        do {
            let liquidAddress = try await getAddress(subaccount: wm.liquidSubaccounts.first)
            let bitcoinAddress = try await getAddress(subaccount: wm.bitcoinSubaccounts.first)
            try await swapMonitor.restoreSwaps(
                bitcoinAddress: bitcoinAddress,
                liquidAddress: liquidAddress
            )
        } catch {
            try? await swapMonitor.start()
            throw error
        }
        try await swapMonitor.start()
    }

    private func getAddress(subaccount: Account?) async throws -> String {
        guard let subaccount else {
            throw GaError.GenericError("id_invalid_subaccount".localized)
        }
        let response = try await wm.accountBackend(subaccount).getReceiveAddress()
        guard let address = response.address else {
            throw GaError.GenericError("Unable to derive swap recovery address")
        }
        return address
    }
}
