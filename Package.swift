// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FinanceCore",
    platforms: [.macOS(.v14), .iOS("27.0")],
    products: [.library(name: "FinanceCore", targets: ["FinanceCore"])],
    targets: [
        .target(name: "FinanceCore", path: "Sources/Core"),
        .target(name: "FinanceFixtures", dependencies: ["FinanceCore"], path: "Support"),
        .executableTarget(name: "FinanceBenchmarks", dependencies: ["FinanceCore", "FinanceFixtures"], path: "Benchmarks"),
        .testTarget(name: "FinanceCoreTests", dependencies: ["FinanceCore", "FinanceFixtures"], path: "Tests/CoreTests")
    ]
)
