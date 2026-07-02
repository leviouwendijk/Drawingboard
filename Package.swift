// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Drawingboard",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Drawingboard",
            targets: ["Drawingboard"]
        ),
        .library(
            name: "DrawingboardCore",
            targets: ["DrawingboardCore"]
        ),
        .library(
            name: "DrawingboardProtocol",
            targets: ["DrawingboardProtocol"]
        ),
        .library(
            name: "DrawingboardRendering",
            targets: ["DrawingboardRendering"]
        ),
        .library(
            name: "DrawingboardTransport",
            targets: ["DrawingboardTransport"]
        ),
        .library(
            name: "DrawingboardHostRuntime",
            targets: ["DrawingboardHostRuntime"]
        ),
        .library(
            name: "DrawingboardPadRuntime",
            targets: ["DrawingboardPadRuntime"]
        ),
        .library(
            name: "DrawingboardPadUI",
            targets: ["DrawingboardPadUI"]
        ),
        .library(
            name: "DrawingboardNetworkTransport",
            targets: ["DrawingboardNetworkTransport"]
        ),
        .library(
            name: "DrawingboardPadNetworkRuntime",
            targets: ["DrawingboardPadNetworkRuntime"]
        ),
        .executable(
            name: "drawtest",
            targets: ["DrawingboardTestFlows"]
        ),
        .executable(
            name: "drawhost",
            targets: ["DrawingboardHostProbe"]
        ),
        .executable(
            name: "drawreplay",
            targets: ["DrawingboardReplayProbe"]
        ),
        .executable(
            name: "drawhostnet",
            targets: ["DrawingboardHostNetworkProbe"]
        ),
        .executable(
            name: "drawpadnet",
            targets: ["DrawingboardPadNetworkProbe"]
        ),
    ],
    dependencies: [
        // .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Version.git", branch: "master"),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "DrawingboardCore",
            dependencies: [
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
            ]
        ),
        .target(
            name: "DrawingboardProtocol",
            dependencies: [
                "DrawingboardCore",
                .product(
                    name: "Version",
                    package: "Version"
                ),
            ]
        ),
        .target(
            name: "DrawingboardRendering",
            dependencies: [
                "DrawingboardCore",
            ]
        ),
        .target(
            name: "DrawingboardTransport",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
            ]
        ),
        .target(
            name: "DrawingboardHostRuntime",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
                "DrawingboardTransport",
            ]
        ),
        .target(
            name: "DrawingboardPadRuntime",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardTransport",
            ]
        ),
        .target(
            name: "DrawingboardPadUI",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
                "DrawingboardPadRuntime",
            ]
        ),
        .target(
            name: "Drawingboard",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
                "DrawingboardTransport",
                "DrawingboardHostRuntime",
                "DrawingboardPadRuntime",
            ]
        ),
        .target(
            name: "DrawingboardNetworkTransport",
            dependencies: [
                "DrawingboardProtocol",
            ]
        ),
        .executableTarget(
            name: "DrawingboardPadNetworkProbe",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardPadNetworkRuntime",
            ]
        ),
        .target(
            name: "DrawingboardPadNetworkRuntime",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardPadRuntime",
                "DrawingboardNetworkTransport",
            ]
        ),
        .executableTarget(
            name: "DrawingboardTestFlows",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
                "DrawingboardTransport",
                "DrawingboardNetworkTransport",
                "DrawingboardPadNetworkRuntime",
                "DrawingboardHostRuntime",
                "DrawingboardPadRuntime",
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
        .executableTarget(
            name: "DrawingboardHostProbe",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
                "DrawingboardTransport",
                "DrawingboardHostRuntime",
                "DrawingboardPadRuntime",
            ]
        ),
        .executableTarget(
            name: "DrawingboardReplayProbe",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
            ]
        ),
        .executableTarget(
            name: "DrawingboardHostNetworkProbe",
            dependencies: [
                "DrawingboardCore",
                "DrawingboardProtocol",
                "DrawingboardRendering",
                "DrawingboardHostRuntime",
                "DrawingboardNetworkTransport",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
