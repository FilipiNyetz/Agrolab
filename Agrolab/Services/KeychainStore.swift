//
//  KeychainStore.swift
//  Agrolab
//

import Foundation
import Security

/// Armazena um único valor (refresh token) como Generic Password no Keychain,
/// acessível apenas com o aparelho desbloqueado e sem sincronização via iCloud.
nonisolated struct KeychainStore: Sendable {
    enum KeychainError: Error, LocalizedError {
        case unexpectedStatus(OSStatus)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Não foi possível acessar o armazenamento seguro (código \(status))."
            case .invalidData:
                return "Os dados salvos no armazenamento seguro estão corrompidos."
            }
        }
    }

    let service: String
    let account: String

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func save(_ value: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
