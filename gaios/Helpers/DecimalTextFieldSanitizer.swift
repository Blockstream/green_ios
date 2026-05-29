import Foundation

struct DecimalInputSanitizer {
    static var separator: String { Locale.current.decimalSeparator ?? "." }
    
    static func sanitize(text: String, maxDecimals: Int? = nil) -> String {
        var result = normalize(text)
        if let max = maxDecimals {
            result = limitDecimals(result, maxDecimals: max)
        }
        return result
    }
    
    private static func limitDecimals(_ text: String, maxDecimals: Int) -> String {
        guard let separatorIndex = text.firstIndex(of: Character(separator)) else { 
            return maxDecimals == 0 ? String(text.filter { $0.isNumber }) : text 
        }
        
        if maxDecimals == 0 { return String(text[..<separatorIndex]) }
        
        let decimals = text[text.index(after: separatorIndex)...]
        return decimals.count > maxDecimals 
            ? String(text[...separatorIndex]) + decimals.prefix(maxDecimals) 
            : text
    }
    
    private static func normalize(_ text: String) -> String {
        let localSeparator = separator
        let alternateSeparator = localSeparator == "." ? "," : "."
        
        var result = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        
        result = resolveSeparators(in: result, localSeparator: localSeparator, alternateSeparator: alternateSeparator)
        
        var isSeparatorFound = false
        result = result.filter { char in
            if String(char) == localSeparator {
                if isSeparatorFound { return false }
                isSeparatorFound = true
                return true
            }
            return char.isNumber
        }

        if result.hasPrefix(localSeparator) { result = "0" + result }

        return removeLeadingZeros(from: result, separator: localSeparator)
    }
    
    private static func resolveSeparators(in text: String, localSeparator: String, alternateSeparator: String) -> String {
        let hasLocalSeparator = text.contains(localSeparator)
        let alternateSeparatorCount = text.filter { String($0) == alternateSeparator }.count
        
        if hasLocalSeparator && alternateSeparatorCount > 0 {
            let isLocalDecimal = text.lastIndex(of: Character(localSeparator))! > text.lastIndex(of: Character(alternateSeparator))!
            let groupingSeparator = isLocalDecimal ? alternateSeparator : localSeparator
            
            return text
                .replacingOccurrences(of: groupingSeparator, with: "")
                .replacingOccurrences(of: alternateSeparator, with: localSeparator)
        }
        
        if alternateSeparatorCount > 1 {
            let alternateParts = text.components(separatedBy: alternateSeparator)
            let isValidGrouping = alternateParts.dropFirst().allSatisfy { $0.count == 3 }
            
            if isValidGrouping {
                return text.replacingOccurrences(of: alternateSeparator, with: "")
            } else if let firstRange = text.range(of: alternateSeparator) {
                return text
                    .replacingCharacters(in: firstRange, with: localSeparator)
                    .replacingOccurrences(of: alternateSeparator, with: "")
            }
        }
        
        let localSeparatorCount = text.filter { String($0) == localSeparator }.count
        if localSeparatorCount > 1 {
            let localParts = text.components(separatedBy: localSeparator)
            let isValidGrouping = localParts.dropFirst().allSatisfy { $0.count == 3 }
            
            if isValidGrouping {
                return text.replacingOccurrences(of: localSeparator, with: "")
            }
        }
        
        if alternateSeparatorCount == 1 {
            return text.replacingOccurrences(of: alternateSeparator, with: localSeparator)
        }
        
        return text
    }

    private static func removeLeadingZeros(from string: String, separator: String) -> String {
        guard !string.isEmpty else { return "" }
        
        let parts = string.split(separator: Character(separator), maxSplits: 1, omittingEmptySubsequences: false)
        guard let firstPart = parts.first else { return string }
        
        let trimmedInteger = firstPart.drop(while: { $0 == "0" })
        let finalIntegerPart = trimmedInteger.isEmpty ? "0" : String(trimmedInteger)
        
        return parts.count > 1 ? finalIntegerPart + separator + parts[1] : finalIntegerPart
    }
}
