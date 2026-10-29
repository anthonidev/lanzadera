// swift-tools-version: 6.2
import PackageDescription

/// Ajustes comunes: Swift 6 estricto + "Approachable Concurrency".
let strictConcurrency: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("ExistentialAny"),
]

/// Los módulos de interfaz y de sistema viven en el main actor por defecto.
let mainActorByDefault: [SwiftSetting] = strictConcurrency + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "LanzaderaKit",
    defaultLocalization: "es",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "LanzaderaCore", targets: ["LanzaderaCore"]),
        .library(name: "LanzaderaConfig", targets: ["LanzaderaConfig"]),
        .library(name: "LanzaderaSystem", targets: ["LanzaderaSystem"]),
        .library(name: "LanzaderaUI", targets: ["LanzaderaUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.2"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
    ],
    targets: [
        // Dominio puro: sin AppKit, sin Yams.
        .target(name: "LanzaderaCore", swiftSettings: strictConcurrency),
        .target(
            name: "LanzaderaConfig",
            dependencies: ["LanzaderaCore", "Yams"],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "LanzaderaSystem",
            dependencies: ["LanzaderaCore", "LanzaderaConfig", "KeyboardShortcuts"],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "LanzaderaUI",
            dependencies: ["LanzaderaCore", "LanzaderaConfig", "LanzaderaSystem", "KeyboardShortcuts"],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(name: "LanzaderaCoreTests", dependencies: ["LanzaderaCore"], swiftSettings: strictConcurrency),
        .testTarget(
            name: "LanzaderaConfigTests",
            dependencies: ["LanzaderaConfig"],
            resources: [.copy("Fixtures")],
            swiftSettings: strictConcurrency
        ),
        .testTarget(name: "LanzaderaUITests", dependencies: ["LanzaderaUI"], swiftSettings: mainActorByDefault),
    ]
)
