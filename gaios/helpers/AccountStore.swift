import Foundation
import PromiseKit

class AccountStore {

    static let shared = AccountStore()
    var blockHeight: UInt32 = 0
    var isWatchOnly: Bool = false

    func getBlockheight() -> UInt32 {
        return blockHeight
    }

    func setBlockHeight(height: UInt32) {
        blockHeight = height
    }
}
