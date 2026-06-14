import Foundation
import Security

/// Errors surfaced by the security layer.
enum KeychainError: Error, LocalizedError {
    case accessControlCreationFailed(String?)
    case unexpectedStatus(OSStatus)
    case userCanceled
    case authenticationFailed
    case dataConversionFailed

    /// Maps an `OSStatus` to a meaningful error case.
    static func fromStatus(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecUserCanceled:
            return .userCanceled
        case errSecAuthFailed:
            return .authenticationFailed
        default:
            return .unexpectedStatus(status)
        }
    }

    var errorDescription: String? {
        switch self {
        case .accessControlCreationFailed(let detail):
            return "Could not create Keychain access control. \(detail ?? "")"
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain error \(status): \(message)"
        case .userCanceled:
            return "Authentication was canceled."
        case .authenticationFailed:
            return "Authentication failed."
        case .dataConversionFailed:
            return "Could not read data from the Keychain."
        }
    }
}
