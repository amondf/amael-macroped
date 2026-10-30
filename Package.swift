// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AmaelMacroped",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AmaelMacroped", targets: ["AmaelMacroped"]),
        .executable(name: "macroped", targets: ["MacropedCLI"]),
        .library(name: "MacropedKit", targets: ["MacropedKit"]),
    ],
    targets: [
        .target(
            name: "MacropedKit",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]
        ),
        .executableTarget(name: "AmaelMacroped", dependencies: ["MacropedKit"]),
        .executableTarget(name: "MacropedCLI", dependencies: ["MacropedKit"]),
        .testTarget(name: "MacropedKitTests", dependencies: ["MacropedKit"]),
    ]
)
