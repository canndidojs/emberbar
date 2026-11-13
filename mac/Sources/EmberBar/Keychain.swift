import Foundation
import Security

/// Minimal generic-password Keychain wrapper (replaces DPAPI-encrypted auth.dat on Windows).
enum Keychain {
    private static let service = "EmberBar"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// Replaces the item. Device-only (never synced to iCloud or included in backups restored elsewhere).
    @discardableResult
    static func save(_ data: Data, account: String) -> Bool {
        let update: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query(account) as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        var attrs = query(account)
        attrs.merge(update) { _, new in new }
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func delete(account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}
