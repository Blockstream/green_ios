import Foundation
import UIKit
import RiveRuntime

struct SetupJadeStep {
    let riveModel: RiveViewModel
    let titleStep: String
    let title: String
    let hint: String
    let placeholderName: String?
}

class SetupJadeViewModel {

    var steps: [SetupJadeStep]

    init() {

        self.steps = [
            SetupJadeStep(riveModel: RiveModel.animationFrontBtn,
                          titleStep: "id_step".localized.uppercased() + " 1",
                          title: "id_initialize_and_create_wallet".localized,
                          hint: "id_select_initialize_and_choose_to".localized,
                          placeholderName: nil),
            SetupJadeStep(riveModel: RiveModel.animationCheckList,
                          titleStep: "id_step".localized.uppercased() + " 2",
                          title: "id_backup_recovery_phrase".localized,
                          hint: "id_write_down_your_recovery_phrase".localized,
                          placeholderName: nil),
            SetupJadeStep(riveModel: RiveModel.animationFrontBtn,
                          titleStep: "id_step".localized.uppercased() + " 3",
                          title: "id_verify_recovery_phrase".localized,
                          hint: "id_use_the_jogwheel_to_select_the".localized,
                          placeholderName: nil)
        ]
    }
}
