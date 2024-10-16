//
//  Crypto.swift
//  SWCryptoKit
//
//  Created by Sun on 2024/8/14.
//

import Foundation

import CommonCrypto
import Crypto
import secp256k1
import SWExtensions

// MARK: - Crypto

public enum Crypto {
    public static func hmacSha512(_ data: Data, key: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return Data(HMAC<SHA512>.authenticationCode(for: data, using: symmetricKey))
    }

    public static func deriveKey(password: String, salt: Data, iterations: Int = 2048, keyLength: Int = 64) -> Data? {
        let passwordData = password.data(using: .utf8)!
        return deriveKey(password: passwordData, salt: salt, iterations: iterations, keyLength: keyLength)
    }

    public static func deriveKey(password: Data, salt: Data, iterations: Int = 2048, keyLength: Int = 64) -> Data? {
        var derivedKey = Data(repeating: 0, count: keyLength)

        if
            derivedKey.withUnsafeMutableBytes({ derivedKeyBytes -> Int32 in
                salt.withUnsafeBytes { saltBytes -> Int32 in
                    guard let saltPointer = saltBytes.bindMemory(to: UInt8.self).baseAddress else {
                        return 1
                    }
                    guard let derivedKeyPointer = derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    else {
                        return 1
                    }

                    return password.withUnsafeBytes { unsafeBytes in
                        let bytes = unsafeBytes.bindMemory(to: CChar.self).baseAddress!

                        return CCKeyDerivationPBKDF(
                            CCPBKDFAlgorithm(kCCPBKDF2),
                            bytes, password.count,
                            saltPointer, salt.count,
                            CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512),
                            UInt32(iterations),
                            derivedKeyPointer, keyLength
                        )
                    }
                }
            }) != 0 {
            print("=> Can't derive key!")
            return nil
        }

        return derivedKey
    }

    public static func deriveKeyNonStandard(
        password: String,
        salt: Data,
        iterations: Int = 2048,
        keyLength: Int = 64
    )
        -> Data? {
        var derivedKey = Data(repeating: 0, count: keyLength)

        if
            derivedKey.withUnsafeMutableBytes({ derivedKeyBytes -> Int32 in
                salt.withUnsafeBytes { saltBytes -> Int32 in
                    guard let saltPointer = saltBytes.bindMemory(to: UInt8.self).baseAddress else {
                        return 1
                    }
                    guard let derivedKeyPointer = derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    else {
                        return 1
                    }

                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        password, password.count,
                        saltPointer, salt.count,
                        CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(iterations),
                        derivedKeyPointer, keyLength
                    )
                }
            }) != 0 {
            print("=> Can't derive key!")
            return nil
        }

        return derivedKey
    }

    public static func publicKey(_ publicKey: secp256k1_pubkey, compressed: Bool) -> Data {
        var outputLen: Int = compressed ? 33 : 65

        let context = secp256k1.Context.rawRepresentation

        var publicKey = publicKey
        var output = Data(count: outputLen)
        let compressedFlags = compressed ? UInt32(SECP256K1_EC_COMPRESSED) : UInt32(SECP256K1_EC_UNCOMPRESSED)
        output.withUnsafeMutableBytes { pointer in
            guard let p = pointer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            secp256k1_ec_pubkey_serialize(context, p, &outputLen, &publicKey, compressedFlags)
        }

        return output
    }

    public static func publicKey(privateKey: Data, curve: DerivationCurve = .secp256k1, compressed: Bool) -> Data {
        let privateKey = privateKey.sw.bytes
        switch curve {
        case .secp256k1:
            var pubKeyPoint = secp256k1_pubkey()

            let context = secp256k1.Context.rawRepresentation
            _ = SecpResult(secp256k1_ec_pubkey_create(context, &pubKeyPoint, privateKey))

            return publicKey(pubKeyPoint, compressed: compressed)

        case .ed25519:
            let privKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            let pubKey = privKey?.publicKey
            return pubKey?.rawRepresentation ?? Data()
            // TODO: not working
        }
    }

    public static func sign(data: Data, privateKey: Data, compact: Bool = false) throws -> Data {
        precondition(!data.isEmpty, "Data must be non-zero size")
        precondition(!privateKey.isEmpty, "PrivateKey must be non-zero size")

        let ctx = secp256k1.Context.rawRepresentation

        let signature = UnsafeMutablePointer<secp256k1_ecdsa_signature>.allocate(capacity: 1)
        let status = data.withUnsafeBytes { ptr in
            privateKey.withUnsafeBytes { secp256k1_ecdsa_sign(
                ctx,
                signature,
                ptr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                $0.baseAddress!.assumingMemoryBound(to: UInt8.self),
                nil,
                nil
            ) }
        }
        guard status == 1 else {
            throw SignError.signFailed
        }

        let normalizedsig = UnsafeMutablePointer<secp256k1_ecdsa_signature>.allocate(capacity: 1)
        defer {
            signature.deallocate()
            normalizedsig.deallocate()
        }

        secp256k1_ecdsa_signature_normalize(ctx, normalizedsig, signature)

        var length: size_t = compact ? 64 : 128
        var der = Data(count: length)
        guard
            der.withUnsafeMutableBytes({
                if compact {
                    secp256k1_ecdsa_signature_serialize_compact(
                        ctx,
                        $0.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        normalizedsig
                    )
                } else {
                    secp256k1_ecdsa_signature_serialize_der(
                        ctx,
                        $0.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        &length,
                        normalizedsig
                    )
                }
            }) == Int32(1)
        else {
            throw SignError.noEnoughSpace
        }
        der.count = length

        return der
    }

    public static func ellipticSign(_ hash: Data, privateKey: Data) throws -> Data {
        let encrypter = EllipticCurveEncrypterSecp256k1()
        guard var signatureInInternalFormat = encrypter.sign(hash: hash, privateKey: privateKey) else {
            throw SignError.signFailed
        }
        return encrypter.export(signature: &signatureInInternalFormat)
    }

    public static func ellipticIsValid(signature: Data, of hash: Data, publicKey: Data, compressed: Bool) -> Bool {
        guard let recoveredPublicKey = ellipticPublicKey(signature: signature, of: hash, compressed: compressed)
        else {
            return false
        }
        return recoveredPublicKey == publicKey
    }

    public static func ellipticPublicKey(signature: Data, of hash: Data, compressed: Bool) -> Data? {
        let encrypter = EllipticCurveEncrypterSecp256k1()
        var signatureInInternalFormat = encrypter.import(signature: signature)
        guard var publicKeyInInternalFormat = encrypter.publicKey(signature: &signatureInInternalFormat, hash: hash)
        else {
            return nil
        }
        return encrypter.export(publicKey: &publicKeyInInternalFormat, compressed: compressed)
    }

    public static func addEllipticCurvePoints(a: secp256k1_pubkey, b: secp256k1_pubkey) throws -> secp256k1_pubkey {
        var storage = ContiguousArray<secp256k1_pubkey>()
        let pointers = UnsafeMutablePointer<UnsafePointer<secp256k1_pubkey>?>.allocate(capacity: 2)
        defer {
            pointers.deinitialize(count: 2)
            pointers.deallocate()
        }
        storage.append(a)
        storage.append(b)

        for i in 0 ..< 2 {
            withUnsafePointer(to: &storage[i]) { ptr in
                pointers.advanced(by: i).pointee = ptr
            }
        }
        let immutablePointer = UnsafePointer(pointers)

        // Combine to points to found new point (new public Key)
        var combinedKey = secp256k1_pubkey()
        if
            withUnsafeMutablePointer(
                to: &combinedKey,
                { (combinedKeyPtr: UnsafeMutablePointer<secp256k1_pubkey>) -> Int32 in
                    secp256k1_ec_pubkey_combine(
                        secp256k1.Context.rawRepresentation,
                        combinedKeyPtr,
                        immutablePointer,
                        2
                    )
                }
            ) == 0 {
            throw SignError.additionError
        }

        return combinedKey
    }
}

extension Crypto {
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    public static func ripeMd160(_ data: Data) -> Data {
        RIPEMD160.hash(data)
    }

    public static func doubleSha256(_ data: Data) -> Data {
        sha256(sha256(data))
    }

    public static func ripeMd160Sha256(_ data: Data) -> Data {
        ripeMd160(sha256(data))
    }

    public static func sha3(_ data: Data) -> Data {
        Sha3.keccak256(data)
    }
}

// MARK: - SecpResult

enum SecpResult {
    case success
    case failure

    // MARK: Lifecycle

    init(_ result: Int32) {
        switch result {
        case 1:
            self = .success
        default:
            self = .failure
        }
    }
}

// MARK: - SignError

public enum SignError: Error {
    case signFailed
    case noEnoughSpace
    case additionError
}

// MARK: - DerivationCurve

public enum DerivationCurve {
    case secp256k1
    case ed25519

    // MARK: Computed Properties

    public var bip32SeedSalt: Data {
        switch self {
        case .secp256k1: "Bitcoin seed".data(using: .ascii)!
        case .ed25519: "ed25519 seed".data(using: .ascii)!
        }
    }

    public var supportNonHardened: Bool {
        switch self {
        case .secp256k1: true
        case .ed25519: false
        }
    }

    // MARK: Functions

    public func publicKey(privateKey: Data, compressed: Bool) -> Data {
        Crypto.publicKey(privateKey: privateKey, curve: self, compressed: compressed)
    }

    public func applyParameters(parentPrivateKey: Data, childKey: Data) throws -> Data {
        switch self {
        case .secp256k1:
            let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
            defer {
                secp256k1_context_destroy(context)
            }

            var rawVariable = parentPrivateKey
            if
                rawVariable.withUnsafeMutableBytes({ privateKeyBytes -> Int32 in
                    childKey.withUnsafeBytes { factorBytes -> Int32 in
                        guard let factorPointer = factorBytes.bindMemory(to: UInt8.self).baseAddress else {
                            return 0
                        }
                        guard
                            let privateKeyPointer = privateKeyBytes.baseAddress?
                                .assumingMemoryBound(to: UInt8.self)
                        else {
                            return 0
                        }
                        return secp256k1_ec_seckey_tweak_add(context, privateKeyPointer, factorPointer)
                    }
                }) == 0 {
                throw DerivationError.invalidCombineTweak
            }
            return Data(rawVariable)

        case .ed25519:
            return childKey
        }
    }
}

// MARK: DerivationCurve.DerivationError

extension DerivationCurve {
    public enum DerivationError: Error {
        case invalidCombineTweak
    }
}
