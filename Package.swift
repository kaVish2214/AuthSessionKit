// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AuthSessionKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AuthSession",
            targets: ["AuthSession"]
        ),
        .library(
            name: "AuthSessionInterface",
            targets: ["AuthSessionInterface"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kaVish2214/BiometricAuthKit", branch: "main"),
        .package(url: "https://github.com/kaVish2214/UtilityKit", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AuthSessionInterface",
            dependencies: [
                .product(name: "BiometricAuthInterface", package: "BiometricAuthKit"),
                .product(name: "MultiCastDelegate", package: "UtilityKit")
            ],
            path: "Sources/AuthSessionInterface"
        ),
        .target(
            name: "AuthSession",
            dependencies: [
                "AuthSessionInterface",
                .product(name: "BiometricAuth", package: "BiometricAuthKit"),
                .product(name: "MultiCastDelegate", package: "UtilityKit")
            ],
            path: "Sources/AuthSession"
        ),
        .testTarget(
            name: "AuthSessionKitTests",
            dependencies: [
                "AuthSessionInterface",
                "AuthSession",
                .product(name: "BiometricAuth", package: "BiometricAuthKit")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
