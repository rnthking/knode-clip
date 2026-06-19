// swift-tools-version:5.7
import PackageDescription

// KNode 划线小工具（macOS 菜单栏 App）。
// 构建：在本目录执行  ./build.sh  生成 KnodeClip.app
let package = Package(
    name: "KnodeClip",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "KnodeClip", path: "Sources/KnodeClip")
    ]
)
