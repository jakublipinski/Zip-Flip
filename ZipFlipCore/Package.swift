// swift-tools-version:5.9
// ZipFlipCore: everything in Zip Flip that touches neither SwiftUI nor the
// network. The watch app depends on it; `swift test` runs it on the Mac.
import PackageDescription

let package = Package(
    name: "ZipFlipCore",
    platforms: [.watchOS(.v10), .macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ZipFlipCore", targets: ["ZipFlipCore"]),
    ],
    targets: [
        .target(name: "ZipFlipCore"),
        .testTarget(
            name: "ZipFlipCoreTests",
            dependencies: ["ZipFlipCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
