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
                          title: "Set Up Jade and Create Wallet".localized,
                          hint: "Select Set Up Jade and choose to create a new wallet".localized,
                          placeholderName: nil
                         ),
            SetupJadeStep(riveModel: RiveModel.animationCheckList,
                          titleStep: "id_step".localized.uppercased() + " 2",
                          title: "id_back_up_recovery_phrase".localized,
                          hint: "id_write_down_your_recovery_phrase".localized,
                          placeholderName: nil
                         ),
            SetupJadeStep(riveModel: RiveModel.animationFrontBtn,
                          titleStep: "id_step".localized.uppercased() + " 3",
                          title: "id_verify_recovery_phrase".localized,
                          hint: "Use the navigation buttons to select the word that matches your recovery phrase".localized,
                          placeholderName: nil
                         )
        ]
    }
}
