import PackageDescription

let package = Package(
    name: "GreenAddress",
    dependencies: [
        .Package(url: "https://github.com/mxcl/PromiseKit", majorVersion: 6)
    ]
)
