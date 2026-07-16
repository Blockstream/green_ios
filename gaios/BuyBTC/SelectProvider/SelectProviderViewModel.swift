import Foundation
import UIKit

class SelectProviderViewModel {

    var title = "id_change_exchange".localized
    var quotes = [MeldQuoteItem]()

    init(quotes: [MeldQuoteItem]) {
        self.quotes = quotes
    }
}
