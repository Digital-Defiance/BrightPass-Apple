// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BrightPassApple",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "BrightPassKit", targets: ["BrightPassKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.18.0")
    ],
    targets: [
        // Shared library: API client, data models, state management
        // No UIKit or AppKit dependencies — Foundation and platform-agnostic Swift only
        .target(
            name: "BrightPassKit",
            dependencies: [
                .product(name: "secp256k1", package: "swift-secp256k1")
            ],
            path: "Sources/BrightPassKit",
            resources: [
                .process("Resources")
            ]
        ),
        // iOS app target
        .executableTarget(
            name: "BrightPassiOS",
            dependencies: ["BrightPassKit"],
            path: "Sources/BrightPassiOS"
        ),
        // macOS app target
        .executableTarget(
            name: "BrightPassmacOS",
            dependencies: ["BrightPassKit"],
            path: "Sources/BrightPassmacOS"
        ),
        // AutoFill Credential Provider extension target
        .executableTarget(
            name: "BrightPassAutoFill",
            dependencies: ["BrightPassKit"],
            path: "Sources/BrightPassAutoFill"
        ),
        // Test target with property-based tests using SwiftCheck
        .testTarget(
            name: "BrightPassKitTests",
            dependencies: [
                "BrightPassKit",
                .product(name: "SwiftCheck", package: "SwiftCheck")
            ],
            path: "Tests/BrightPassKitTests"
        )
    ]
)
