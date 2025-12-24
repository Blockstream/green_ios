import Foundation
import UIKit

class SelectCountryViewModel {
    var title = "id_billing".localized
    var hint = "id_please_select_your_correct".localized

    private var countries = Country.allMeld()
    var searchedCountries = Country.allMeld()

    func searchCountries(_ searchText: String) {
        let query = searchText
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .folding(options: .diacriticInsensitive, locale: .current)

        guard !query.isEmpty else { searchedCountries = Country.allMeld(); return }

        searchedCountries = countries.filter {
            $0.name.lowercased().contains(query)
        }
    }
}
