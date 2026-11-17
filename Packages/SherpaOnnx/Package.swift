// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SherpaOnnx",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SherpaOnnx", targets: ["SherpaOnnx"]),
    ],
    targets: [
        .binaryTarget(name: "SherpaOnnxC", path: "SherpaOnnxC.xcframework"),
        .binaryTarget(name: "onnxruntime", path: "onnxruntime.xcframework"),
        .target(
            name: "SherpaOnnx",
            dependencies: [
                "SherpaOnnxC",
                "onnxruntime",
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),
    ]
)
