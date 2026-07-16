import CryptoKit
import Foundation

/// Cryptographically random nonce + SHA256 helper for Sign in with Apple → Supabase.
enum AppleSignInNonce {
    /// Unhashed nonce string to send to Supabase with the identity token.
    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var byte: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
                if status != errSecSuccess {
                    byte = UInt8.random(in: 0 ... 255)
                }
                return byte
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// SHA256 hex digest of `input` — set on `ASAuthorizationAppleIDRequest.nonce`.
    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
