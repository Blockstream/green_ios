import Foundation
import UIKit

class SelectCountryViewModel {
    var title = "Billing"
    var hint = "Please select your correct billing location to complete the checkout successfully."

    private var countries = Country.allMeld()
    var filteredCountries = Country.allMeld()

    func searchCountries(_ searchText: String) {
        let query = searchText
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .folding(options: .diacriticInsensitive, locale: .current);

        guard !query.isEmpty else { filteredCountries = Country.allMeld(); return }

        filteredCountries = countries.filter {
            $0.code.lowercased().contains(query) || $0.name.lowercased().contains(query)
        }
    }
}
