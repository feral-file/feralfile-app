//
//  Seed.swift
//  
//
//  Created by Ho Hien on 8/11/21.
//

import Foundation
import URKit

public class Seed: Codable {
    public let data: Data
    public let name: String
    public let creationDate: Date?
    public let passphrase: String?
    
    init(data: Data, name: String, creationDate: Date? = nil, passphrase: String? = "") {
        self.data = data
        self.name = name
        self.creationDate = creationDate
        self.passphrase = passphrase
    }
    
    convenience init(urString: String) throws {
        guard let ur = try? UR(urString: urString) else {
            throw LibAukError.other(reason: "ur:crypto-seed: Invalid UR data.")
        }

        let cbor = try CBOR(ur.cbor)
        try self.init(cbor: cbor)
    }

    convenience init(cbor: CBOR) throws {
        guard case let CBOR.map(map) = cbor else {
            throw LibAukError.other(reason: "ur:crypto-seed: CBOR doesn't contain a map.")
        }

        var seedData: Data?
        var creationDate: Date? = nil
        var name: String = ""
        var passphrase: String = ""

        for (indexElement, valueElement) in map {
            guard case let CBOR.unsigned(index) = indexElement else {
                throw LibAukError.other(reason: "ur:crypto-seed: CBOR contains invalid keys.")
            }

            switch index {
            case 1:
                guard let data = try? Data(cbor: valueElement) else {
                    throw LibAukError.other(reason: "ur:crypto-seed: CBOR doesn't contain data field.")
                }
                seedData = data
            case 2:
                guard let date = try? Date(cbor: valueElement) else {
                    throw LibAukError.other(reason: "ur:crypto-seed: CreationDate field doesn't contain a date.")
                }
                creationDate = date
            case 3:
                guard let s = try? String(cbor: valueElement) else {
                    throw LibAukError.other(reason: "ur:crypto-seed: Name field doesn't contain a string.")
                }
                name = s
            case 4:
                guard let s = try? String(cbor: valueElement) else {
                    throw LibAukError.other(reason: "ur:crypto-seed: Passphrase field doesn't contain a string.")
                }
                passphrase = s
            default:
                throw LibAukError.other(reason: "ur:crypto-seed: CBOR contains invalid keys.")
            }
        }

        guard let seedData else {
            throw LibAukError.other(reason: "ur:crypto-seed: missing seed data field.")
        }

        self.init(data: seedData, name: name, creationDate: creationDate, passphrase: passphrase)
    }
}

public enum LibAukError: Error {
    case initEncryptionError
    case keyCreationError
    case invalidMnemonicError
    case emptyKey
    case keyCreationExistingError(key: String)
    case keyDerivationError
    case other(reason: String)
}

extension LibAukError: LocalizedError {
    public var errorDescription: String? {
        errorMessage
    }

    public var failureReason: String? {
        errorMessage
    }

    public var recoverySuggestion: String? {
        errorMessage
    }

    var errorMessage: String {
        switch self {
        case .initEncryptionError:
            return "init encryption error"
        case .keyCreationError:
            return "create key error"
        case .invalidMnemonicError:
            return "invalid mnemonic error"
        case .emptyKey:
            return "empty Key"
        case .keyCreationExistingError:
            return "create key error: key exists"
        case .keyDerivationError:
            return "key derivation error"
        case .other(let reason):
            return reason
        }
    }
}
