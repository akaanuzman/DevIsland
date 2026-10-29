// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevIsland",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DevIsland", targets: ["DevIslandApp"]),
        .executable(name: "dev-island-bridge", targets: ["DevIslandBridge"])
    ],
    targets: [
        .target(name: "CDevIsland"),
        .target(name: "DevIslandCore", dependencies: ["CDevIsland"]),
        .executableTarget(name: "DevIslandApp", dependencies: ["DevIslandCore", "CDevIsland"]),
        .executableTarget(name: "DevIslandBridge", dependencies: ["DevIslandCore", "CDevIsland"]),
        .testTarget(name: "DevIslandCoreTests", dependencies: ["DevIslandCore"]),
        .testTarget(name: "DevIslandAppTests", dependencies: ["DevIslandApp"])
    ],
    swiftLanguageModes: [.v5]
)
