import Foundation

/// Pure email/password checks for the post-name auth screen (M2-11 / M2-12).
enum AccountAuthValidator {
    static let minimumPasswordLength = 6
    static let otpLength = 6

    static func trimmedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = trimmedEmail(email)
        guard trimmed.contains("@") else { return false }
        let parts = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        return !local.isEmpty && domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }

    static func canSubmit(email: String, password: String) -> Bool {
        isValidEmail(email) && isValidPassword(password)
    }

    static func trimmedOTP(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
    }

    static func isValidOTP(_ code: String) -> Bool {
        let digits = trimmedOTP(code)
        return digits.count == otpLength
    }
}
