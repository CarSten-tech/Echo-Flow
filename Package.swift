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
        ),
        .executable(
            name: "EchoFlowEngine",
            targets: ["EchoFlowEngine"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "0.8.0"),
        .package(url: "https://github.com/google-gemini/generative-ai-swift", from: "0.5.4")
    ],
    targets: [
        .executableTarget(
            name: "EchoFlow",
            dependencies: [
                .target(name: "Shared"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ],
            path: ".",
            exclude: [
                "Sources/Services/WhisperKitService.swift" // Exclude the XPC specific part from Main App
            ],
            sources: [
                "Sources/UI",
                "Sources/Core",
                "Sources/Automation",
                "Sources/Services", // Gemini actions live here
                "EchoFlowApp.swift"
            ]
        ),
        .executableTarget(
            name: "EchoFlowEngine",
            dependencies: [
                .target(name: "Shared"),
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/Services",
            exclude: [
                "GeminiProvider.swift", // Exclude Main App parts from XPC
                "LocalInferenceService.swift",
                "STTProvider.swift",
                "WhisperService.swift"
            ]
        ),
        .target(
            name: "Shared",
            dependencies: [],
            path: "Sources/Shared"
        ),
        .testTarget(
            name: "EchoFlowTests",
            dependencies: ["EchoFlow", "Shared"],
            path: "Tests/EchoFlowTests"
        )
    ]
)
