// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DatenschutzWaechter",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DatenschutzKern",
            path: "Sources/DatenschutzKern"
        ),
        .executableTarget(
            name: "DatenschutzWaechter",
            dependencies: ["DatenschutzKern"],
            path: "Sources/DatenschutzWaechter",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("NaturalLanguage"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .executableTarget(
            name: "Selbsttest",
            dependencies: ["DatenschutzKern"],
            path: "Sources/Selbsttest"
        ),
    ]
)
