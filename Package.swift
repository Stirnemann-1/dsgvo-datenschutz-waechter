// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DatenschutzWaechter",
    platforms: [.macOS(.v13)],
    targets: [
        // Erkennung, Platzhalter, Einstellungen – gemeinsam für macOS und Windows
        .target(
            name: "DatenschutzKern",
            path: "Sources/DatenschutzKern"
        ),
        // Menüleisten-App für macOS
        .executableTarget(
            name: "DatenschutzWaechter",
            dependencies: ["DatenschutzKern"],
            path: "Sources/DatenschutzWaechter",
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("Carbon", .when(platforms: [.macOS])),
                .linkedFramework("ApplicationServices", .when(platforms: [.macOS])),
                .linkedFramework("NaturalLanguage", .when(platforms: [.macOS])),
                .linkedFramework("UserNotifications", .when(platforms: [.macOS])),
            ]
        ),
        // Infobereich-App für Windows
        .executableTarget(
            name: "DatenschutzWaechterWindows",
            dependencies: ["DatenschutzKern"],
            path: "Sources/DatenschutzWaechterWindows",
            linkerSettings: [
                .linkedLibrary("User32", .when(platforms: [.windows])),
                .linkedLibrary("Shell32", .when(platforms: [.windows])),
                .linkedLibrary("Advapi32", .when(platforms: [.windows])),
                .linkedLibrary("Kernel32", .when(platforms: [.windows])),
                // Ohne Konsolenfenster starten
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                             .when(platforms: [.windows])),
            ]
        ),
        .executableTarget(
            name: "Selbsttest",
            dependencies: ["DatenschutzKern"],
            path: "Sources/Selbsttest"
        ),
    ]
)
