import UIKit

enum MultiLabelStyle: Int, CaseIterable {
    case simple
    case amountIn
    case amountOut
    case unconfirmed
    case pending
    case swapInProgress
    case swapRefundable
    case swapFailure
}

struct MultiLabelViewModel {
    let txtLeft: String?
    let txtRight: String?
    let hideBalance: Bool?
    let style: MultiLabelStyle
}
