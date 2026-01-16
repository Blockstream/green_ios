import Foundation
import UIKit
import core

@MainActor
class TabViewModel {
    let walletDataModel: WalletDataModel
    let wallet: WalletManager
    var mainAccount: Account
    var state = WalletState()
    var onUpdate: ((RefreshFeature?) -> Void)?
    var observationTask: Task<Void, Never>?

    init(walletDataModel: WalletDataModel, wallet: WalletManager, mainAccount: Account) {
        self.walletDataModel = walletDataModel
        self.wallet = wallet
        self.mainAccount = mainAccount
        startObserving()
    }

    private func startObserving() {
        observationTask = Task {
            // Subscribe to the Actor's multi-subscriber AsyncStream which yields
            // `SubscriberUpdate` (state + optional set of refresh features).
            for await update in await walletDataModel.states() {
                self.state = update.state
                self.onUpdate?(update.feature )
            }
        }
    }

    func refresh(features: Set<RefreshFeature>) {
        Task {
            await walletDataModel.triggerRefresh(features: features)
        }
    }

    deinit {
        observationTask?.cancel()
    }
}
