// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import Foundation
import PackageDescription
import CompilerPluginSupport

let coreVersion = Version("13.17.0")
let cocoaVersion = Version("10.41.1")

let cxxSettings: [CXXSetting] = [
    .define("__cpp_coroutines", to: "0"),
    .define("REALM_SPM", to: "1"),
    .define("REALM_ENABLE_SYNC", to: "1"),
    .define("REALM_COCOA_VERSION", to: "@\"\(cocoaVersion)\""),
    .define("REALM_VERSION", to: "\"\(coreVersion)\""),
    .define("REALM_IOPLATFORMUUID", to: "@\"\("Playgrounds")\""),

    .define("REALM_DEBUG", .when(configuration: .debug)),
    .define("REALM_NO_CONFIG"),
    .define("REALM_INSTALL_LIBEXECDIR", to: ""),
    .define("REALM_ENABLE_ASSERTIONS", to: "1"),
    .define("REALM_ENABLE_ENCRYPTION", to: "1"),

    .define("REALM_VERSION_MAJOR", to: String(coreVersion.major)),
    .define("REALM_VERSION_MINOR", to: String(coreVersion.minor)),
    .define("REALM_VERSION_PATCH", to: String(coreVersion.patch)),
    .define("REALM_VERSION_EXTRA", to: "\"\(coreVersion.prereleaseIdentifiers.first ?? "")\""),
    .define("REALM_VERSION_STRING", to: "\"\(coreVersion)\""),
//    .define("CPPREALM_HAVE_GENERATED_BRIDGE_TYPES", to: "1")
]
let testCxxSettings: [CXXSetting] = cxxSettings + [
    // Command-line `swift build` resolves header search paths
    // relative to the package root, while Xcode resolves them
    // relative to the target root, so we need both.
    .headerSearchPath("Realm"),
    .headerSearchPath(".."),
]

let package = Package(
    name: "Realm",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
             name: "realmCxx",
             targets: ["realmCxx"]),
        .library(name: "Realm", targets: ["Realm"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jsflax/realm-cpp.git",
                 from: "0.5.1"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.2"),
    ],
    targets: [
        .target(
            name: "realmCxx",
            dependencies: [
                .product(name: "realm-cpp-sdk", package: "realm-cpp")
            ],
            path: "realmCxx",
            cxxSettings: cxxSettings,
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .macro(
            name: "RealmMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "RealmMacros"
        ),
        .target(name: "Realm",
                dependencies: ["RealmMacros", "realmCxx"],
                path: "Realm",
                cxxSettings: cxxSettings,
                swiftSettings: [
                    .interoperabilityMode(.Cxx)
                ]),
        .executableTarget(
            name: "RealmTests",
            dependencies: ["Realm"],
            path: "RealmTests",
            cxxSettings: cxxSettings,
            swiftSettings: [.interoperabilityMode(.Cxx)]),
    ],
    cxxLanguageStandard: .cxx20
)
