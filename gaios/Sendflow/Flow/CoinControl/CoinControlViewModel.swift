import Foundation
import core
import LiquidWalletKit
import greenaddress

class CoinControlViewModel {
    let subaccount: Account?
    let assetId: String
    let denomination: DenominationType?
    let isFiat: Bool

    var utxos: [UnspentOutput] = []
    var selectedUtxos: [UnspentOutput] = []
    var filteredUtxos: [UnspentOutput] = []
    var isLoading = false
    var error: Error?
    
    var selectedFilters: Set<CoinFilter> = [] {
        didSet {
            applyFilters()
        }
    }
    
    var selectedSort: CoinSort = .defaultSort {
        didSet {
            applySorting()
        }
    }
   
    init(subaccount: Account?, assetId: String, selectedUtxos: [UnspentOutput]? = nil, denomination: DenominationType? = nil, isFiat: Bool = false) {
        self.subaccount = subaccount
        self.assetId = assetId
        self.selectedUtxos = selectedUtxos ?? []
        self.denomination = denomination
        self.isFiat = isFiat
    }
    
    private func isDust(_ utxo: UnspentOutput) -> Bool {
        let isLiquid = subaccount?.gdkNetwork.liquid == true
        return utxo.isDust(isLiquid: isLiquid)
    }
    
    private func isExpired(_ utxo: UnspentOutput) -> Bool {
        guard subaccount?.type != .twoOfThree,
              subaccount?.type != .ampAccount,
              let expiryHeight = utxo.expiryHeight,
              let blockHeight = subaccount?.gdkSession?.blockHeight else { return false }
        return expiryHeight <= blockHeight
    }
    
    func loadUtxos() async throws {
        if isLoading { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let params = GetUnspentOutputsParams(subaccount: subaccount?.pointer ?? 0, numConfs: 0)
        let response = try await subaccount?.gdkSession?.getUtxos(params)
        utxos = response?.unspentOutputs[assetId] ?? []
        
        applyFilters()
    }
    
    func applyFilters() {
        filteredUtxos = utxos.filter { utxo in
            if utxo.isLocked { return false }

            if selectedFilters.isEmpty { return true }
            
            for filter in selectedFilters {
                switch filter {
                case .dust: if isDust(utxo) { return true }
                case .legacyRecovery: if utxo.addressType != "csv" { return true }
                case .expired: if isExpired(utxo) { return true }
                }
            }
            return false
        }
        
        applySorting()
    }
    
    func applySorting() {
        filteredUtxos.sort(by: compareUtxos)
    }
    
    func toggleSelection(_ utxo: UnspentOutput) {
        if let index = selectedUtxos.firstIndex(where: { $0.txhash == utxo.txhash && $0.ptIdx == utxo.ptIdx }) {
            selectedUtxos.remove(at: index)
        } else {
            selectedUtxos.append(utxo)
        }
    }

    func isSelected(_ utxo: UnspentOutput) -> Bool {
        selectedUtxos.contains { $0.txhash == utxo.txhash && $0.ptIdx == utxo.ptIdx }
    }

    func selectAllFiltered() {
        let selectedIds = Set(selectedUtxos.compactMap { "\($0.txhash ?? ""):\($0.ptIdx ?? 0)" })
        let newUtxos = filteredUtxos.filter { !selectedIds.contains("\($0.txhash ?? ""):\($0.ptIdx ?? 0)") }
        selectedUtxos.append(contentsOf: newUtxos)
    }

    func unselectAllFiltered() {
        let filteredIds = Set(filteredUtxos.compactMap { "\($0.txhash ?? ""):\($0.ptIdx ?? 0)" })
        selectedUtxos.removeAll { filteredIds.contains("\($0.txhash ?? ""):\($0.ptIdx ?? 0)") }
    }

    private func compareUtxos(left: UnspentOutput, right: UnspentOutput) -> Bool {
        switch selectedSort {
        case .amountDescending:
            let lAmount = left.satoshi ?? 0
            let rAmount = right.satoshi ?? 0
            if lAmount == rAmount {
                if left.isUnconfirmed && !right.isUnconfirmed { return false }
                if right.isUnconfirmed && !left.isUnconfirmed { return true }
                return (left.blockHeight ?? 0) < (right.blockHeight ?? 0)
            }
            return lAmount > rAmount

        case .amountAscending:
            let lAmount = left.satoshi ?? 0
            let rAmount = right.satoshi ?? 0
            if lAmount == rAmount {
                if left.isUnconfirmed && !right.isUnconfirmed { return false }
                if right.isUnconfirmed && !left.isUnconfirmed { return true }
                return (left.blockHeight ?? 0) < (right.blockHeight ?? 0)
            }
            return lAmount < rAmount

        case .dateDescending: // Newest
            if left.isUnconfirmed && !right.isUnconfirmed { return true }
            if right.isUnconfirmed && !left.isUnconfirmed { return false }

            let lHeight = left.blockHeight ?? 0
            let rHeight = right.blockHeight ?? 0
            if lHeight == rHeight {
                return (left.satoshi ?? 0) > (right.satoshi ?? 0)
            }
            return lHeight > rHeight

        case .dateAscending: // Oldest
            if left.isUnconfirmed && !right.isUnconfirmed { return false }
            if right.isUnconfirmed && !left.isUnconfirmed { return true }

            let lHeight = left.blockHeight ?? 0
            let rHeight = right.blockHeight ?? 0
            if lHeight == rHeight {
                return (left.satoshi ?? 0) > (right.satoshi ?? 0)
            }
            return lHeight < rHeight
        }
    }
}
