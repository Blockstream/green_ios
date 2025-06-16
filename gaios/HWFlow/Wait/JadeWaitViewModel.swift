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
                         hint: "Hold the button on the bottom of Jade until it boots up".localized,
                         placeholderName: "il_jade_ph_1_power_on"),
            JadeWaitStep(riveModel: RiveModel.animationFrontBtn,
                         titleStep: "id_step".localized.uppercased() + " 2",
                         title: "id_follow_the_instructions_on_jade".localized,
                         hint: "id_select_initalize_to_create_a".localized,
                         placeholderName: "il_jade_ph_2_follow_instructions"),
            JadeWaitStep(riveModel: RiveModel.animationSideBtns,
                         titleStep: "id_step".localized.uppercased() + " 3",
                         title: "id_connect_with_bluetooth".localized,
                         hint: "id_choose_bluetooth_connection_on".localized,
                         placeholderName: "il_jade_ph_3_connect_ble")
        ]
    }
}
