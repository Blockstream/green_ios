import Foundation
import UIKit
import RiveRuntime

struct JadeWaitStep {
    let riveModel: RiveViewModel
    let titleStep: String
    let title: String
    let hint: String
    let placeholderName: String?
}

class JadeWaitViewModel {

    var steps: [JadeWaitStep]

    init() {

        self.steps = [
            JadeWaitStep(riveModel: RiveModel.animationSideBtns,
                         titleStep: "id_step".localized.uppercased() + " 1",
                         title: "id_power_on_jade".localized,
                         hint: "Hold the button until Jade turns on. (For Jade Core, plug in the provided USB-C cable.)".localized,
                         placeholderName: "il_jade_ph_1_power_on"),
            JadeWaitStep(riveModel: RiveModel.animationFrontBtn,
                         titleStep: "id_step".localized.uppercased() + " 2",
                         title: "id_follow_the_instructions_on_jade".localized,
                         hint: "Select Set Up Jade to create a new wallet, then back up and verify your recovery phrase.".localized,
                         placeholderName: "il_jade_ph_2_follow_instructions"),
            JadeWaitStep(riveModel: RiveModel.animationSideBtns,
                         titleStep: "id_step".localized.uppercased() + " 3",
                         title: "id_connect_with_bluetooth".localized,
                         hint: "Choose Bluetooth connection on Jade after verifying your recovery phrase.".localized,
                         placeholderName: "il_jade_ph_3_connect_ble")
        ]
    }
}
