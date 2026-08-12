// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeorgianIME",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "GeorgianIME", targets: ["GeorgianIME"]),
    ],
    targets: [
        .target(
            name: "GeorgianIME",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GeorgianIMETests",
            dependencies: ["GeorgianIME"]
        )
    ]
)
