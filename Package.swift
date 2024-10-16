// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SWCryptoKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "SWCryptoKit",
            targets: ["SWCryptoKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMajor(from: "5.4.1")),
        .package(url: "https://github.com/sunimp/SWExtensions.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.8.1")),
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", .upToNextMajor(from: "0.17.0")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.54.6"),
    ],
    targets: [
        .target(
            name: "SWCryptoKitC",
            path: "Sources/SWCryptoKitC"
        ),
        .target(
            name: "SWCryptoKit",
            dependencies: [
                .target(name: "SWCryptoKitC"),
                "SWExtensions",
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "secp256k1", package: "swift-secp256k1"),
            ],
            path: "Sources/SWCryptoKit"
        ),
        .testTarget(
            name: "SWCryptoKitTests",
            dependencies: ["SWCryptoKit"]
        ),
    ]
)
