// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "TrueWeather",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .iOSApplication(
            name: "TrueWeather",
            targets: ["AppModule"],
            bundleIdentifier: "com.business.TrueWeather",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
