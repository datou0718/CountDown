// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountDown",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CountDown", targets: ["CountDown"])],
    targets: [
        .target(name: "CountdownCore"),
        .executableTarget(name: "CountDown", dependencies: ["CountdownCore"]),
        .testTarget(name: "CountdownCoreTests", dependencies: ["CountdownCore"])
    ]
)
