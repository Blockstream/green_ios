import Foundation
import core

protocol CoinControlDelegate: AnyObject {
    @MainActor
    func didSelectCoins(_ utxos: [UnspentOutput])
}

