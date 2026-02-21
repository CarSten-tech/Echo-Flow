// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EchoFlow",
    platforms: [
        .macOS("13.3")
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
        .package(url: "https://github.com/google-gemini/generative-ai-swift", from: "0.5.4"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.20.1"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.16.0")
    ],
    targets: [
        .executableTarget(
            name: "EchoFlow",
            dependencies: [
                .target(name: "Shared"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
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
                "Echo Flow/Echo_FlowApp.swift",
                "Echo Flow/ContentView.swift"
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
                "Providers", // Exclude Main App parts from XPC
                "GeminiProvider.swift", 
                "AnthropicProvider.swift",
                "LocalInferenceService.swift",
                "STTProvider.swift",
                "WhisperService.swift",
                "AppleSpeechService.swift"
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
