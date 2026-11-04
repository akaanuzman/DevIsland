// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevIsland",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DevIsland", targets: ["DevIslandApp"]),
        .executable(name: "dev-island-bridge", targets: ["DevIslandBridge"])
    ],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .target(name: "CDevIsland"),
        .target(name: "DevIslandCore", dependencies: ["CDevIsland"]),
        .executableTarget(name: "DevIslandApp", dependencies: ["DevIslandCore", "CDevIsland", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .executableTarget(name: "DevIslandBridge", dependencies: ["DevIslandCore", "CDevIsland"]),
        .testTarget(name: "DevIslandCoreTests", dependencies: ["DevIslandCore"]),
        .testTarget(name: "DevIslandAppTests", dependencies: ["DevIslandApp"])
    ],
    swiftLanguageModes: [.v5]
)
