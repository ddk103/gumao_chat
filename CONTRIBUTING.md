# 参与贡献

感谢你愿意改进孤猫聊天。提 PR 前请先读一遍下面几条，能省下不少来回。

## 开发环境

- Flutter 3.27+（验证版本 3.44 / Dart 3.12）
- JDK 17、Android SDK（`flutter doctor` 无 Android 工具链错误即可）
- 提交前请在仓库根目录执行：

```bash
flutter pub get
flutter analyze     # 必须 0 issue
flutter build apk --debug
```

## 提交规范

- 提交信息用一句话说清「改了什么」，中英文都行，例如：
  - `修复：导入超长聊天记录时界面卡顿`
  - `feat: 支持自定义 TTS 音色`
- 一个 PR 只做一件事，不要顺手格式化整个文件。
- 新增用户可见文案请用简体中文，语气保持简洁。

## 代码约定

- 状态与持久化统一走 `lib/store.dart`，不要在页面里直接读写文件。
- 新增网络请求放在 `lib/llm.dart`，保持 OpenAI 兼容；不要写死任何厂商密钥或代理地址。
- 涉及平台能力（语音等）时，Dart 侧走 `speech.dart` 的 `gumao/speech` 通道，原生实现放在 `android/app/src/main/kotlin/com/gumao/chat/`。
- 不要提交 `android/local.properties`、`.gradle/`、`build/`、任何 keystore 或 API Key。

## 贡献的许可

本项目采用 [PolyForm Noncommercial 1.0.0](LICENSE)（个人 / 研究 / 非营利免费，商业使用需授权）。

提交 PR 即表示你同意：你的贡献以同样的许可授权给本项目，并允许维护者将包含你贡献的代码
用于商业授权（如向企业发放商业许可）。如果你代表公司贡献，请确保你有权这样做。

## 报告问题

请附上：

1. 手机型号与 Android 版本；
2. 复现步骤（尽量最短）；
3. 报错截图或应用内提示原文；
4. 如果和某个接口有关，说明是哪家服务 / 是否自定义接口（**不要贴 API Key**）。
