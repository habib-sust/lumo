// swift-tools-version: 6.0
import PackageDescription

// LumoShieldKit is the thin iOS-only adapter layer over the Screen Time frameworks.
// It exists so LumoCore can stay portable and macOS-testable; everything here is the
// part that genuinely cannot be tested without a physical device.
//
// Two hard rules:
//
// 1. This package must NEVER expose a UIKit type in its public API. ShieldConfiguration
//    is built from UIColor/UIImage/UIBlurEffect.Style, so the shield-config extension
//    imports UIKit — but if that leaked through here, the DeviceActivityMonitor
//    extension would inherit a UIKit link against a 6 MB high-watermark it dies past.
//
// 2. Keep it thin. Logic belongs in LumoCore where it can be tested. An adapter here
//    should be a translation, not a decision.

let package = Package(
    name: "LumoShieldKit",
    platforms: [
        .iOS(.v18),
        // Declared only so dependency resolution against LumoCore (macOS 14) is
        // coherent and `swift build` works at the workspace root. There is no macOS
        // functionality here: the sources are behind `#if canImport(ManagedSettings)`,
        // so on macOS this compiles to an empty module. Real builds go through
        // `xcodebuild -sdk iphoneos`.
        .macOS(.v14),
    ],
    products: [
        .library(name: "LumoShieldKit", type: .static, targets: ["LumoShieldKit"]),
    ],
    dependencies: [
        .package(path: "../LumoCore"),
    ],
    targets: [
        .target(
            name: "LumoShieldKit",
            dependencies: [
                .product(name: "LumoCore", package: "LumoCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
