import Foundation
import UIKit
import core

@MainActor
class TabViewModel {
    let walletDataModel: WalletDataModel
    let wm: WalletManager
    var mainWallet: Wallet
    var state = WalletState()
    @MainActor var onUpdate: ((RefreshFeature?) -> Void)?
    var observationTask: Task<Void, Never>?

    init(walletDataModel: WalletDataModel, wm: WalletManager, mainWallet: Wallet) {
        self.walletDataModel = walletDataModel
        self.wm = wm
        self.mainWallet = mainWallet
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
