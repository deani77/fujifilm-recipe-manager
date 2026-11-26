// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FujifilmRecipeManager",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RecipeCore", targets: ["RecipeCore"]),
        .executable(name: "RecipeManager", targets: ["RecipeManagerApp"]),
        .executable(name: "RecipeCameraImport", targets: ["RecipeCameraImport"])
    ],
    targets: [
        .target(name: "RecipeCore"),
        .executableTarget(name: "RecipeManagerApp", dependencies: ["RecipeCore"]),
        .executableTarget(name: "RecipeCameraImport", dependencies: ["RecipeCore"]),
        .testTarget(name: "RecipeCoreTests", dependencies: ["RecipeCore"], resources: [.copy("Fixtures")])
    ]
)
