import Foundation
import UIKit
import core

@MainActor
class TabViewModel {
    let walletDataModel: WalletDataModel
    let wallet: WalletManager
    var mainAccount: Account
    var state = WalletState()
    @MainActor var onUpdate: ((RefreshFeature?) -> Void)?
    var observationTask: Task<Void, Never>?

    init(walletDataModel: WalletDataModel, wallet: WalletManager, mainAccount: Account) {
        self.walletDataModel = walletDataModel
        self.wallet = wallet
        self.mainAccount = mainAccount
        startObserving()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let self = self else { return }
            // Subscribe to the Actor's multi-subscriber AsyncStream which yields
            // `SubscriberUpdate` (state + optional set of refresh features).
            for await update in await walletDataModel.states() {
                guard !Task.isCancelled else { break }
                await MainActor.run { [weak self] in
                    self?.state = update.state
                    self?.onUpdate?(update.feature)
                }
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
