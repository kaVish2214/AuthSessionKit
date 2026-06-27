// swift-tools-version: 6.3
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// swiftSettings
let swiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=100",
        "-Xfrontend", "-warn-long-expression-type-checking=100"
    ])
]

/// Package
let package = Package(
    name: "AuthSessionKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15)
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
        .package(url: "https://github.com/kaVish2214/BiometricAuthKit", .upToNextMajor(from: "0.1.0")),
        .package(url: "https://github.com/kaVish2214/UtilityKit", .upToNextMajor(from: "0.1.0"))
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
                .product(name: "MultiCastDelegate", package: "UtilityKit"),
                .product(name: "SwiftConcurrency", package: "UtilityKit")
            ],
            path: "Sources/AuthSession",
            swiftSettings: swiftSettings
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
