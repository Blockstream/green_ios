import Foundation
import UIKit

class PromoCellModel {

    var promo: Promo
    var source: PromoScreen

    init(promo: Promo, source: PromoScreen) {
        self.promo = promo
        self.source = source

        self.promo.preDecode()
    }
}
