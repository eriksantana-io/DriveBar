// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "DriveBar", platforms: [.macOS(.v13)], products: [.executable(name: "DriveBar", targets: ["DriveBar"])], targets: [.executableTarget(name: "DriveBar")])
