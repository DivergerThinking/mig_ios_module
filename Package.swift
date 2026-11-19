// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MadridInGameiOSModule",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "MadridInGameiOSModule", targets: ["MadridInGameiOSModule"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ArtSabintsev/FontBlaster.git", from: "5.3.0"),
    ],
    targets: [
        .target(
            name: "MadridInGameiOSModule",
            dependencies: ["FontBlaster"],
            path: ".",
            exclude: [
                "MadridInGameiOSModule.podspec",
                "README.md",
                "LICENSE",
                // Huérfano no distribuido por CocoaPods (resource_bundles solo
                // empaqueta Resources/ de la raíz); se excluye para mantener paridad.
                "Sources/Resources",
                "Tests",
            ],
            sources: ["Sources"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MadridInGameiOSModuleTests",
            dependencies: ["MadridInGameiOSModule"],
            path: "Tests/MadridInGameiOSModuleTests"
        ),
    ]
)
