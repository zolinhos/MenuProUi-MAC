// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuProUI-MAC",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MenuProUI-MAC",
            targets: ["MenuProUI-MAC"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MenuProUI-MAC",
            path: ".",
            exclude: [
                "README.md",
                "RELEASE_CHECKLIST.md",
                "MenuProUi-Bridging-Header.h",
                "main.swift",
                "dist"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)

