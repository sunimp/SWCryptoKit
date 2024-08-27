// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WWCryptoKit.Swift",
    platforms: [
        .macOS(.v12),
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "WWCryptoKit",
            targets: ["WWCryptoKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/sunimp/WWExtensions.Swift.git", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/sunimp/secp256k1-swift.git", .upToNextMajor(from: "0.17.2")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.54.0"),
    ],
    targets: [
        .target(
            name: "WWCryptoKitC",
            path: "Sources/WWCryptoKitC"
        ),
        .target(
            name: "WWCryptoKit",
            dependencies: [
                .target(name: "WWCryptoKitC"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "WWExtensions", package: "WWExtensions.Swift"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "secp256k1", package: "secp256k1-swift"),
            ],
            path: "Sources/WWCryptoKit"
        ),
        .testTarget(
            name: "WWCryptoKitTests",
            dependencies: ["WWCryptoKit"]),
    ]
)
