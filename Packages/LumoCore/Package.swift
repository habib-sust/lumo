// swift-tools-version: 6.0
import PackageDescription

// LumoCore is deliberately Foundation-only.
//
// It holds the reconciler, the spend journal, the wallet, bucket partitioning and the
// pricing math — i.e. everything whose failure modes are expensive — with ZERO Screen
// Time frameworks. That is what lets it compile and test on macOS, because Family
// Controls does not exist in the iOS Simulator at all and never will.
//
// The rule that keeps this true: if a type from ManagedSettings, DeviceActivity,
// ManagedSettingsUI, FamilyControls, SwiftUI or SwiftData appears in this package,
// the package has lost its purpose. Screen Time adapters belong in LumoShieldKit.
//
// Static, not dynamic: the DeviceActivityMonitor extension has a 6 MB high-watermark
// and dies instantly past it, so we do not pay for a dynamic framework load.

let package = Package(
    name: "LumoCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14), // test host only — not a shipping platform
    ],
    products: [
        .library(name: "LumoCore", type: .static, targets: ["LumoCore"]),
    ],
    targets: [
        .target(
            name: "LumoCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .testTarget(
            name: "LumoCoreTests",
            dependencies: ["LumoCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
