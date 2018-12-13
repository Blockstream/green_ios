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

    @objc func incomingTransaction(_ notification: NSNotification) {
        print(notification.userInfo ?? "")
        if let dict = notification.userInfo as NSDictionary? {
            if let accounts = dict["subaccounts"] as? NSArray {
                print(accounts)
                for acc in accounts {
                    let pointer = acc as! Int
                    let p = UInt32(pointer)
                    DispatchQueue.global(qos: .background).async {
                        wrap {
                            try getSession().getReceiveAddress(subaccount: p)
                        }.done { address in
                            DispatchQueue.main.async {
                                // FIXME: out of bounds access
                                self.wallets[pointer].receiveAddress = address
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addressChanged"), object: nil, userInfo: ["pointer" : pointer])
                            }
                        }
                    }
                }
            }
        }
    }

    func initializeAccountStore() {
        NotificationStore.shared.initializeNotificationStore()
        NotificationCenter.default.addObserver(self, selector: #selector(self.incomingTransaction(_:)), name: NSNotification.Name(rawValue: "incomingTX"), object: nil)
    }
}
