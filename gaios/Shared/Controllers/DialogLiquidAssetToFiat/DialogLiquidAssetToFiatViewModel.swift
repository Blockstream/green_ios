import Foundation


class DialogLiquidAssetToFiatViewModel {

    var assetName: String
    var assetAmountTxt: String
    var fiatAmountTxt: String
    var isFiat = false

    init(assetName: String,
         assetAmountTxt: String,
         fiatAmountTxt: String,
         isFiat: Bool
    ) {
        self.assetName = assetName
        self.assetAmountTxt = assetAmountTxt
        self.fiatAmountTxt = fiatAmountTxt
        self.isFiat = isFiat
    }
}
