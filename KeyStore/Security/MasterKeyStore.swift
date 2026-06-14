import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// Stores and retrieves the vault's 256-bit master key in the Keychain,
/// protected by a biometric access control.
///
/// Security design:
/// - The key is a generic password item bound to `[.biometryAny .or .devicePasscode]`,
///   so retrieving it triggers exactly one Touch ID prompt (with passcode fallback).
/// - `.biometryAny` (not `.biometryCurrentSet`) is used deliberately so that
///   re-enrolling Touch ID does NOT destroy the key and lock the user out of
///   their recovery codes.
/// - `WhenUnlockedThisDeviceOnly` keeps the key off iCloud and out of backups.
///
/// The retrieval call blocks while the system shows the biometric prompt, so it
/// must always be invoked off the main thread.
struct MasterKeyStore: Sendable {
    let service: String
    let account: String

    init(service: String = "ai.keystore.master", account: String = "vault-master-key") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // macOS defaults to the legacy file-based keychain, which does not
            // support SecAccessControl/biometrics/access groups. Opt into the
            // data protection keychain (TN3137) on all queries.
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// Returns whether a master key already exists, without prompting for auth.
    func keyExists() -> Bool {
        var query = baseQuery
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // An access-controlled item that exists returns interactionNotAllowed
        // when UI is skipped; not-found means it truly doesn't exist.
        return status != errSecItemNotFound
    }

    /// Loads the existing master key, or generates and stores one if none
    /// exists yet, then returns it via the authenticated read path so that
    /// every unlock (including first run) requires Touch ID/passcode.
    ///
    /// Blocking call — invoke off the main thread.
    func loadOrCreateKey(reason: String) throws -> SymmetricKey {
        if !keyExists() {
            try storeKey(SymmetricKey(size: .bits256))
        }
        // Always read back through the authenticated path so that every unlock,
        // including the very first one after setup, requires Touch ID/passcode.
        return try loadKey(reason: reason)
    }

    /// Retrieves the key, presenting the biometric prompt. Blocking.
    ///
    /// macOS grants the process that created a keychain item implicit access to
    /// it for the lifetime of that process, so a plain `SecItemCopyMatching`
    /// would not re-prompt within the same session (e.g. after "Lock Now").
    /// To make every unlock require authentication, we force a fresh
    /// `evaluateAccessControl` and reuse that authenticated context for the read.
    func loadKey(reason: String) throws -> SymmetricKey {
        let access = try makeAccessControl()

        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        try authenticate(context: context, accessControl: access, reason: reason)

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.dataConversionFailed
            }
            return SymmetricKey(data: data)
        default:
            throw KeychainError.fromStatus(status)
        }
    }

    /// Forces a fresh biometric/passcode evaluation. Blocking.
    private func authenticate(context: LAContext, accessControl: SecAccessControl, reason: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var authError: Error?
        context.evaluateAccessControl(accessControl, operation: .useItem, localizedReason: reason) { success, error in
            if !success { authError = error }
            semaphore.signal()
        }
        semaphore.wait()

        guard let authError else { return }
        switch (authError as? LAError)?.code {
        case .userCancel, .appCancel, .systemCancel:
            throw KeychainError.userCanceled
        default:
            throw KeychainError.authenticationFailed
        }
    }

    /// The access control used both when storing and when authenticating reads.
    private func makeAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryAny, .or, .devicePasscode],
            &error
        ) else {
            let detail = (error?.takeRetainedValue()).map { String(describing: $0) }
            throw KeychainError.accessControlCreationFailed(detail)
        }
        return access
    }

    /// Stores a freshly generated key with biometric access control.
    private func storeKey(_ key: SymmetricKey) throws {
        let access = try makeAccessControl()
        let keyData = key.withUnsafeBytes { Data($0) }

        // Add-or-replace.
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessControl as String] = access
        addQuery[kSecAttrSynchronizable as String] = kCFBooleanFalse

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.fromStatus(status)
        }
    }

    /// Removes the master key. Used for reset/testing.
    func deleteKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.fromStatus(status)
        }
    }
}
