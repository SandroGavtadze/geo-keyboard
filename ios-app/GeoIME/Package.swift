// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoIME",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)  // enables `swift test` on a Mac without a simulator
    ],
    products: [
        .library(name: "GeoIME", targets: ["GeoIME"]),
    ],
    targets: [
        .target(
            name: "GeoIME",
            resources: [
                .copy("Resources/ka_words_freq.tsv"),
                .copy("Resources/ka_bigrams.tsv"),
            ]
        ),
        .testTarget(
            name: "GeoIMETests",
            dependencies: ["GeoIME"]
        ),
    ]
)
