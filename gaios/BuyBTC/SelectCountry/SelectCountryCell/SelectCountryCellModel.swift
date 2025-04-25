import UIKit

class SelectCountryCellModel {
    var country: Country
    var title: String { country.name }
    var hint: String { country.code.uppercased() }
    var icon: UIImage? {
        UIImage(named: country.flag)
    }
    init(country: Country) {
        self.country = country
    }
}
