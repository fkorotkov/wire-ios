// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Scripts",
    targets: [
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/realm/SwiftLint/releases/download/0.53.0/SwiftLintBinary-macos.artifactbundle.zip",
            checksum: "03416a4f75f023e10f9a76945806ddfe70ca06129b895455cc773c5c7d86b73e"
        )
    ]
)
