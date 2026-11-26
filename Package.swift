// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShotKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShotCore", targets: ["ShotCore"]),
        .library(name: "ShotCapture", targets: ["ShotCapture"]),
        .library(name: "ShotEditor", targets: ["ShotEditor"]),
        .library(name: "ShotTools", targets: ["ShotTools"]),
        .library(name: "ShotExport", targets: ["ShotExport"]),
        .library(name: "ShotSettings", targets: ["ShotSettings"]),
        .library(name: "ShotRecording", targets: ["ShotRecording"]),
        .library(name: "ShotScrolling", targets: ["ShotScrolling"]),
        .library(name: "ShotPin", targets: ["ShotPin"]),
        .library(name: "ShotBackdrop", targets: ["ShotBackdrop"]),
        .library(name: "ShotHistory", targets: ["ShotHistory"]),
        .library(name: "ShotMeasure", targets: ["ShotMeasure"]),
        .library(name: "ShotUpload", targets: ["ShotUpload"]),
        .library(name: "ShotWorkflow", targets: ["ShotWorkflow"]),
        .library(name: "ShotVideoEditor", targets: ["ShotVideoEditor"]),
        .library(name: "ShotCombine", targets: ["ShotCombine"]),
        .executable(name: "ssfm", targets: ["ShotCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
    ],
    targets: [
        .target(name: "ShotCore", resources: [.process("Resources")]),
        .target(name: "ShotCapture", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotEditor", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotTools", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotExport", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotRecording", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotScrolling", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotPin", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotBackdrop", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotHistory", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotMeasure", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotUpload", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotVideoEditor", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(name: "ShotCombine", dependencies: ["ShotCore"], resources: [.process("Resources")]),
        .target(
            name: "ShotWorkflow",
            dependencies: ["ShotCore", .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "ShotCLI"),
        .target(
            name: "ShotSettings",
            dependencies: ["ShotCore", .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")],
            resources: [.process("Resources")]
        ),

        // MARK: Tests

        .target(name: "ShotTestSupport", path: "Tests/ShotTestSupport"),
        .testTarget(name: "ShotCoreTests", dependencies: ["ShotCore"]),
        .testTarget(name: "ShotToolsTests", dependencies: ["ShotTools", "ShotCore"]),
        .testTarget(name: "ShotExportTests", dependencies: ["ShotExport", "ShotCore", "ShotTestSupport"]),
        .testTarget(name: "ShotEditorTests", dependencies: ["ShotEditor", "ShotCore", "ShotTestSupport"]),
        .testTarget(name: "ShotUploadTests", dependencies: ["ShotUpload", "ShotCore"]),
        .testTarget(name: "ShotWorkflowTests", dependencies: ["ShotWorkflow", "ShotCore"]),
        .testTarget(name: "ShotCLITests", dependencies: ["ShotCLI"]),
        .testTarget(name: "ShotCombineTests", dependencies: ["ShotCombine", "ShotTestSupport"]),
        .testTarget(name: "ShotBackdropTests", dependencies: ["ShotBackdrop", "ShotTestSupport"]),
        .testTarget(name: "ShotHistoryTests", dependencies: ["ShotHistory", "ShotCore"]),
        .testTarget(name: "ShotScrollingTests", dependencies: ["ShotScrolling", "ShotTestSupport"]),
        .testTarget(name: "ShotMeasureTests", dependencies: ["ShotMeasure", "ShotTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
