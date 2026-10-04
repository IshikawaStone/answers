// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnswersWatch",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AnswersWatchCore",
            targets: ["AnswersWatchCore"]
        ),
        .executable(
            name: "AnswersWatchApp",
            targets: ["AnswersWatchApp"]
        )
    ],
    targets: [
        .target(
            name: "AnswersWatchCore",
            path: "Sources",
            exclude: ["App/AnswersWatchApp.swift"]
        ),
        .executableTarget(
            name: "AnswersWatchApp",
            dependencies: ["AnswersWatchCore"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AnswersWatchTests",
            dependencies: ["AnswersWatchCore"],
            path: "Tests"
        )
    ]
)
