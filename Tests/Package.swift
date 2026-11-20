// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DrawingboardTests",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .executable(
            name: "drawtest",
            targets: ["DrawingboardTestFlows"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "DrawingboardTestFlows",
            dependencies: [
                .product(name: "DrawingboardCore", package: "Drawingboard"),
                .product(name: "DrawingboardProtocol", package: "Drawingboard"),
                .product(name: "DrawingboardRendering", package: "Drawingboard"),
                .product(name: "DrawingboardTransport", package: "Drawingboard"),
                .product(name: "DrawingboardNetworkTransport", package: "Drawingboard"),
                .product(name: "DrawingboardPadNetworkRuntime", package: "Drawingboard"),
                .product(name: "DrawingboardHostRuntime", package: "Drawingboard"),
                .product(name: "DrawingboardPadRuntime", package: "Drawingboard"),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
