import Foundation
import UIKit

class SelectCountryViewModel {

    var title = "Billing"
    var hint = "Please select your correct billing location to complete the checkout successfully."
    var countries = Country.allMeld()
    init() {
    }
}
