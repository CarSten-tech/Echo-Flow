// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EchoFlow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "EchoFlow",
            targets: ["EchoFlow"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EchoFlow",
            dependencies: [],
            path: ".",
            sources: [
                "Sources",
                "EchoFlowApp.swift"
            ]
        )
    ]
)
