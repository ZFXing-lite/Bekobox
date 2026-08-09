# Bekobox v1.18.9-bekobox.1

本版本完成 Bekobox 第一阶段功能融合，重点补齐本地配置、节点粘贴导入和节点信息编辑流程。

## 新增

- 添加“空白配置”入口，可直接创建本地 Mihomo YAML 配置。
- 剪贴板导入支持单节点、多节点和 base64 订阅文本。
- 支持识别 `vmess://`、`vless://`、`trojan://`、`ss://`、`hysteria2://`、`hy2://`、`tuic://`。
- 节点导入会自动生成 `PROXY` 选择组、`AUTO` 测速组和 `MATCH,PROXY` 默认规则。
- 配置菜单新增“编辑节点配置”，可直接修改当前配置 YAML。
- 二维码导入支持节点链接，不再只接受普通订阅 URL。

## 修复

- 移除仓库中 29 字节的假 `app-release.apk` 占位文件，避免误导为可安装包。
- 清理仅描述功能但没有实际逻辑的旧注释。
- 更新 README，说明真实功能、构建方式和发布注意事项。

## 验证

- 已通过 `git diff --check` 空白检查。
- 已添加 `test/common/node_importer_test.dart` 覆盖节点导入逻辑。
- 当前机器缺少 `flutter`/`dart`，暂未能执行 `flutter test` 或真实 APK 构建。

## 发布资产

当前环境无法构建真实 APK。请在具备 Flutter/Android SDK 的环境中运行：

```bash
flutter pub get
flutter build apk --release
```

构建成功后，将真实 `app-release.apk` 上传到 GitHub Release。
