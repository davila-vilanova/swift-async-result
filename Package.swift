// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-async-result",
    products: [
        .library(
            name: "AsyncResult",
            targets: ["AsyncResult"]),
    ],
    targets: [
        .target(
            name: "AsyncResult"),
        .testTarget(
            name: "AsyncResultTests",
            dependencies: ["AsyncResult"]
        ),
    ]
)
