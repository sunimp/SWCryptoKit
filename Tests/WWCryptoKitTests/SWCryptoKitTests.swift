//
//  SWCryptoKitTests.swift
//  SWCryptoKitTest
//
//  Created by Sun on 2024/8/14.
//

@testable import SWCryptoKit
import XCTest

final class CryptoKitTests: XCTestCase {
    func testKeccak() throws {
        let input = "cc".sw.hexData!
        let result = "eead6dbfc7340a56caedc044696a168870549a6a7f6f56961e84a54bd9970b8a".sw.hexData!

        XCTAssertEqual(Crypto.sha3(input), result)
    }

    func testKeccak2() throws {
        let input = "9f2fcc7c90de090d6b87cd7e9718c1ea6cb21118fc2d5de9f97e5db6ac1e9c10".sw.hexData!
        let result = "24dd2ee02482144f539f810d2caa8a7b75d0fa33657e47932122d273c3f6f6d1".sw.hexData!

        XCTAssertEqual(Crypto.sha3(input), result)
    }
}
