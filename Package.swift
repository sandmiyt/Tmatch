// swift-tools-version: 5.9
import PackageDescription

// Runs the actual Foundation-only production sources on macOS; no app/Keychain required.
let package = Package(name: "TijingLearningCore", platforms: [.macOS(.v14)], targets: [
    .target(name: "TijingLearningCore", path: "Tijing", sources: [
        "Core/APIClient.swift", "Core/PracticeOutbox.swift", "Models/User.swift",
        "Models/Question.swift"
    ]),
    .testTarget(name: "TijingLearningCoreTests", dependencies: ["TijingLearningCore"], path: "Tests/LearningCoreTests", resources: [.process("Fixtures")])
])
