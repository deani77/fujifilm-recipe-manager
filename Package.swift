// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FujifilmRecipeManager",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RecipeCore", targets: ["RecipeCore"]),
        .executable(name: "RecipeManager", targets: ["RecipeManagerApp"])
    ],
    targets: [
        .target(name: "RecipeCore"),
        .executableTarget(name: "RecipeManagerApp", dependencies: ["RecipeCore"]),
        .testTarget(name: "RecipeCoreTests", dependencies: ["RecipeCore"], resources: [.copy("Fixtures")])
    ]
)
