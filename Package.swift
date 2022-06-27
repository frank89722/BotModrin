// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BotModrin",
    platforms: [
        .macOS("12")
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/SketchMaster2001/Swiftcord", branch: "master"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.3"),
        .package(url: "https://github.com/egzonpllana/CodableFiles.git", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "BotModrin",
            dependencies: [
                "Swiftcord",
                "CodableFiles",
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Logging", package: "swift-log"),
            ]),
        .testTarget(
            name: "BotModrinTests",
            dependencies: ["BotModrin"]),
    ]
)
