// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CalendarPeek",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CalendarPeek", targets: ["CalendarPeek"])
    ],
    targets: [
        .target(
            name: "CalendarCore",
            path: "Sources/CalendarCore"
        ),
        .executableTarget(
            name: "CalendarPeek",
            dependencies: ["CalendarCore"],
            path: "Sources/CalendarPeek",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CalendarCoreTests",
            dependencies: ["CalendarCore"],
            path: "Tests/CalendarCoreTests"
        ),
        .executableTarget(
            name: "CalendarCoreChecks",
            dependencies: ["CalendarCore"],
            path: "Tests/CalendarCoreChecks"
        )
    ],
    swiftLanguageModes: [.v5]
)
