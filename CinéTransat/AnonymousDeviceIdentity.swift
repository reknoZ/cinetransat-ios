//
//  AnonymousDeviceIdentity.swift
//  CinéTransat
//
//  Random UUID stored in the Keychain — not tied to Apple ID, email, or hardware IDs
//  (IMEI/UDID are unavailable to App Store apps). Used only to avoid double-counting
//  watch list stats when the same install adds/removes a screening.
//

import Foundation
import Security

enum AnonymousDeviceIdentity {
    private static let service = "ch.heewhack.CineTransat.anonymousDeviceId"
    private static let account = "default"

    /// Stable per install; may persist across reinstall on the same device (Keychain).
    static var deviceID: String {
        if let existing = readKeychain() {
            return existing
        }
        let id = UUID().uuidString
        saveKeychain(id)
        return id
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            let match: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemUpdate(match as CFDictionary, update as CFDictionary)
        }
    }
}
