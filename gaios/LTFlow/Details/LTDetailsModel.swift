import Foundation
import core
import GreenlightSDK

enum LTDetailsCellType: CaseIterable {
    case nodeId
}

class LTDetailsViewModel {
    var nodeInfo: NodeState?

    init(lightningSession: LightningSessionManager) {
        self.nodeInfo = lightningSession.nodeState()
    }

    var cellTypes: [LTDetailsCellType] {
        return LTDetailsCellType.allCases
    }
    
    var nodeId: String {
        return nodeInfo?.id ?? ""
    }

    func cellModelByType(_ cellType: LTDetailsCellType) -> LTDetailsCellModel {
        switch cellType {
        case .nodeId:
            return LTDetailsCellModel(
                title: "Lightning Node",
                value: "\(nodeId.prefix(13))...\(nodeId.suffix(13))",
            )
        }
    }
}

