import Foundation
import PromiseKit

class AccountStore {

    static let shared = AccountStore()
    var wallets = [WalletItem]()
    var blockHeight: UInt32 = 0
    var isWatchOnly: Bool = false

    func getSubaccounts() -> Promise<[WalletItem]> {
        let bgq = DispatchQueue.global(qos: .background)
        return Guarantee().compactMap(on: bgq) {
            try getSession().getSubaccounts()
        }.compactMap(on: bgq) { data in
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let accounts = try JSONDecoder().decode(Wallets.self, from: jsonData)
            self.wallets = accounts.array
            return self.wallets
        }
    }

    func getWallets(cached: Bool) -> Promise<[WalletItem]> {
        // FIXME: should this be cached == true?
        if wallets.count > 0 && cached == false {
            return Promise<[WalletItem]> { seal in
                seal.fulfill(wallets)
            }
        }
        return getSubaccounts()
    }

    func getBlockheight() -> UInt32 {
        return blockHeight
    }

    func setBlockHeight(height: UInt32) {
        blockHeight = height
    }
}
