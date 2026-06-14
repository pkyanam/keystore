import Foundation
import LocalAuthentication

/// Pre-flight biometric availability checks, used only for UI decisions
/// (e.g. labeling the unlock button). Never used as a security gate — the
/// actual gate is the Keychain access control on the master key.
enum Biometrics {
    enum Availability {
        case touchID
        case opticID
        case passcodeOnly   // no biometric hardware/enrollment, but passcode set
        case unavailable    // no passcode set or restricted
    }

    static func availability() -> Availability {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .touchID:
                return .touchID
            case .opticID:
                return .opticID
            default:
                return .passcodeOnly
            }
        }

        // Biometrics unavailable; can we still fall back to the device passcode?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            return .passcodeOnly
        }
        return .unavailable
    }

    /// A short label describing the unlock mechanism for the UI.
    static func unlockLabel() -> String {
        switch availability() {
        case .touchID: return "Unlock with Touch ID"
        case .opticID: return "Unlock with Optic ID"
        case .passcodeOnly: return "Unlock with Password"
        case .unavailable: return "Unlock"
        }
    }
}
