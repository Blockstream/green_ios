import Foundation
import UIKit

struct DecimalInputSanitizer {
    static var separator: String {
        Locale.current.decimalSeparator ?? "."
    }

    static func sanitize(text: String, maxDecimals: Int? = nil) -> String {
        sanitize(text: text, maxDecimals: maxDecimals, decimalSeparator: separator)
    }

    static func sanitize(
        text: String,
        maxDecimals: Int? = nil,
        decimalSeparator: String
    ) -> String {
        let outputSeparator = decimalSeparator.first ?? "."
        let characters = normalizedCharacters(in: text, outputSeparator: outputSeparator)
        return sanitizedValue(
            from: characters,
            maxDecimals: maxDecimals,
            outputSeparator: outputSeparator
        )
    }

    static func sanitizePastedText(
        _ text: String,
        maxDecimals: Int? = nil,
        decimalSeparator: String = separator
    ) -> String {
        let outputSeparator = decimalSeparator.first ?? "."
        var characters = normalizedCharacters(in: text, outputSeparator: outputSeparator)

        if isGroupedInteger(characters) {
            characters.removeAll { isSeparator($0, outputSeparator: outputSeparator) }
        }

        return sanitizedValue(
            from: characters,
            maxDecimals: maxDecimals,
            outputSeparator: outputSeparator
        )
    }

    private static func sanitizedValue(
        from characters: [Character],
        maxDecimals: Int?,
        outputSeparator: Character
    ) -> String {
        let decimalIndex = decimalSeparatorIndex(
            in: characters,
            outputSeparator: outputSeparator
        )
        let integerEnd = decimalIndex ?? characters.endIndex
        let integerDigits = String(characters[..<integerEnd].filter(\.isNumber))

        guard !integerDigits.isEmpty || decimalIndex != nil else { return "" }

        let normalizedInteger = removingLeadingZeros(from: integerDigits)
        guard let decimalIndex else { return normalizedInteger }

        let decimalLimit = maxDecimals.map { max(0, $0) }
        guard decimalLimit != 0 else { return normalizedInteger }

        var fractionalDigits = String(characters[(decimalIndex + 1)...].filter(\.isNumber))
        if let decimalLimit {
            fractionalDigits = String(fractionalDigits.prefix(decimalLimit))
        }

        return normalizedInteger + String(outputSeparator) + fractionalDigits
    }

    private static func normalizedCharacters(
        in text: String,
        outputSeparator: Character
    ) -> [Character] {
        return text.compactMap { character in
            if isSeparator(character, outputSeparator: outputSeparator) {
                return character
            }
            if let value = character.wholeNumberValue, (0...9).contains(value) {
                return Character(String(value))
            }
            return nil
        }
    }

    private static func decimalSeparatorIndex(
        in characters: [Character],
        outputSeparator: Character
    ) -> Int? {
        let separatorIndices = characters.indices.filter {
            isSeparator(characters[$0], outputSeparator: outputSeparator)
        }
        guard !separatorIndices.isEmpty else { return nil }

        if outputSeparator != ".", outputSeparator != ",",
           let localIndex = separatorIndices.first(where: {
               characters[$0] == outputSeparator
           }) {
            return localIndex
        }

        let lastDot = characters.lastIndex(of: ".")
        let lastComma = characters.lastIndex(of: ",")

        if let lastDot, let lastComma {
            return max(lastDot, lastComma)
        }

        return separatorIndices.first
    }

    private static func isGroupedInteger(_ characters: [Character]) -> Bool {
        // A single separator is ambiguous, so only repeated three-digit groups count as grouping.
        let separators = characters.filter { !$0.isNumber }
        guard separators.count > 1,
              Set(separators).count == 1,
              let groupingSeparator = separators.first else {
            return false
        }

        let groups = String(characters).split(
            separator: groupingSeparator,
            omittingEmptySubsequences: false
        )
        guard let firstGroup = groups.first, (1...3).contains(firstGroup.count) else {
            return false
        }
        return groups.dropFirst().allSatisfy { $0.count == 3 }
    }

    private static func isSeparator(
        _ character: Character,
        outputSeparator: Character
    ) -> Bool {
        character == outputSeparator || character == "." || character == ","
    }

    private static func removingLeadingZeros(from digits: String) -> String {
        let trimmed = digits.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }
}

final class DecimalTextField: UITextField, UITextFieldDelegate {
    var maxDecimalsProvider: () -> Int? = { nil }

    override func awakeFromNib() {
        super.awakeFromNib()
        delegate = self
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let currentText = textField.text ?? ""
        guard let range = Range(range, in: currentText) else { return false }

        let proposedValue = currentText.replacingCharacters(in: range, with: string)
        let sanitizedValue = DecimalInputSanitizer.sanitize(
            text: proposedValue,
            maxDecimals: maxDecimalsProvider()
        )

        guard sanitizedValue != proposedValue else { return true }
        guard sanitizedValue != currentText else { return false }

        replaceText(with: sanitizedValue)
        return false
    }

    override func paste(_ sender: Any?) {
        guard let pastedText = UIPasteboard.general.string else {
            super.paste(sender)
            return
        }
        insertSanitizedText(pastedText)
    }

    private func insertSanitizedText(_ text: String) {
        let currentText = self.text ?? ""
        guard let selection = selectedTextRange else { return }

        let selectionStart = offset(
            from: beginningOfDocument,
            to: selection.start
        )
        let selectionEnd = offset(
            from: beginningOfDocument,
            to: selection.end
        )
        let selectedRange = NSRange(
            location: selectionStart,
            length: selectionEnd - selectionStart
        )
        guard let range = Range(selectedRange, in: currentText) else { return }

        let proposedValue = currentText.replacingCharacters(in: range, with: text)
        let replacesEntireValue = range.lowerBound == currentText.startIndex &&
            range.upperBound == currentText.endIndex
        let maxDecimals = maxDecimalsProvider()
        let sanitizedValue: String
        if replacesEntireValue {
            sanitizedValue = DecimalInputSanitizer.sanitizePastedText(
                text,
                maxDecimals: maxDecimals
            )
        } else {
            sanitizedValue = DecimalInputSanitizer.sanitize(
                text: proposedValue,
                maxDecimals: maxDecimals
            )
        }

        if sanitizedValue == proposedValue {
            super.insertText(text)
        } else if sanitizedValue != currentText {
            replaceText(with: sanitizedValue)
        }
    }

    private func replaceText(with text: String) {
        selectedTextRange = textRange(
            from: beginningOfDocument,
            to: endOfDocument
        )
        super.insertText(text)
    }
}
