// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitIssues",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GitIssues",
            targets: ["GitIssues"])
    ],
    dependencies: [
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "GitIssues",
            dependencies: [
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        )
    ]
)
