# Bekobox

Bekobox 是基于 Bettbox 的 Mihomo/Clash Meta 客户端分支，目标是在保留 Bettbox 主界面和运行逻辑的基础上，补上 NekoBox 风格的本地配置、节点粘贴导入和节点信息编辑流程。

## 功能

- 使用 Bettbox UI 和运行时作为主程序基础。
- 在“添加配置”面板中创建空白本地配置。
- 从剪贴板导入单节点或多节点。
- 自动识别并解码包含节点链接的 base64 订阅文本。
- 将节点链接转换为 Mihomo 兼容 YAML 配置。
- 在配置菜单中直接编辑生成的节点 YAML。
- 支持导出配置 YAML，方便备份或手动分享。

## 剪贴板节点格式

当前剪贴板导入支持以下协议：

- `vmess://`
- `vless://`
- `trojan://`
- `ss://`
- `hysteria2://` 和 `hy2://`
- `tuic://`

导入后会生成一个本地 Mihomo 配置，默认包含：

- `PROXY` 选择组
- 有节点时自动生成 `AUTO` url-test 组
- 默认规则 `MATCH,PROXY`

订阅 URL 仍然走原有 URL 导入流程。

## 构建

这是一个 Flutter 项目。构建 Android APK 前需要准备：

- 与 `pubspec.yaml` 匹配的 Flutter SDK
- Android SDK 和 Android build tools
- 与 Android Gradle 插件兼容的 JDK
- 如果需要重新构建内核或原生组件，还需要 Go/Rust 工具链

常用 Android 构建命令：

```bash
flutter pub get
flutter build apk --release
```

真实 APK 应该由 Flutter/Gradle 构建生成，并上传到 GitHub Release。不要把 `app/build/outputs/` 里的占位文件作为源码提交。

## 发布

当前源码版本：`1.18.9+2026078818`。

Android 分支安装身份：

- 应用显示名称：`bekobox`
- Android package/applicationId：`com.appshub.bekobox`
- 可与使用 `com.appshub.bettbox` 的原版 Bettbox 并存安装

发布建议：

- 仓库：`https://github.com/ZFXing-lite/Bekobox`
- Tag 格式：`v<version>`
- Release 资产：只上传真实构建得到的 APK 包，不手动上传源码 zip、源码包或其他附加资产。
- Release 说明：使用中文说明变更、安装身份、安装注意事项和 APK 校验信息。

## 说明

仓库中曾有一个 29 字节的 `app-release.apk` 占位文件，内容只是文本，不是可安装 APK。本分支已移除该占位文件，等待真实构建产物发布。

## 开源协议

本项目沿用上游 Bettbox、Mihomo/Clash Meta 以及相关开源组件的许可约束。
