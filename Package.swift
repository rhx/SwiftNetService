import PackageDescription

let package = Package(
    name: "NetService",
    dependencies: [
        .Package(url: "https://github.com/rhx/CDNS_SD.git", majorVersion: 1),
    ]
)
