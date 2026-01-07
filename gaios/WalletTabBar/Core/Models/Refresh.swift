import Foundation

enum RefreshFeature: Sendable, Hashable {
    case subaccounts
    case balance
    case txs(reset: Bool)
    case priceChart
    case discover
    case alertCards
    case promos
    case settings
    case security
    case nestedTxs(subaccount: String, assetId: String)
}

// New type delivered to subscribers: current state + optional set of refresh features
struct SubscriberUpdate {
    let state: WalletState
    let feature: RefreshFeature?
}
