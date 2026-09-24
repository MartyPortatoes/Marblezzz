// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarblezzzCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "MarblezzzCore", targets: ["MarblezzzCore"])],
    targets: [
        .target(name: "MarblezzzCore"),
        .testTarget(name: "MarblezzzCoreTests", dependencies: ["MarblezzzCore"])
    ]
)
