// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-AA25
// 孤猫聊天 · 隐私政策同意（上架合规）
// 首次启动 / 政策版本升级时弹窗；未同意不进主界面（华为市场审核要求）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemNavigator;

import 'store.dart';
import 'ui.dart';

/// 隐私政策版本：改动 policy 文本时 +1，会重新向老用户征求同意
const int kPrivacyVersion = 1;

Future<String> loadPrivacyText() async {
  try {
    return await rootBundle.loadString('assets/privacy_policy.txt');
  } catch (_) {
    return '隐私政策加载失败，请重装应用或联系开发者。';
  }
}

/// 是否已经同意过当前版本的隐私政策
bool privacyAccepted() {
  final c = Store.I.cfg;
  return c.privacyAgreed && c.privacyVersion >= kPrivacyVersion;
}

/// 弹出隐私政策同意框；返回 true 表示已同意
Future<bool> ensurePrivacyAgreed(BuildContext context) async {
  if (privacyAccepted()) return true;
  final text = await loadPrivacyText();
  if (!context.mounted) return false;
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('隐私政策'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('孤猫聊天 是本地 AI 对话客户端：',
                style: TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 6),
            const Text(
              '· 你的对话与资料全部保存在本机，我们不设服务器、不收集你的内容；\n'
              '· 只有你发送消息时，文本才会发送到你自行配置的第三方大模型接口；\n'
              '· 语音输入需要麦克风权限，可随时拒绝，不影响其它功能；\n'
              '· 朗读默认使用系统语音合成，在本地完成。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.push(c, MaterialPageRoute(
                      builder: (_) => PrivacyPage(text: text, embedded: true)));
                },
                child: const Text('查看完整隐私政策 →'),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('不同意并退出'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('同意并继续', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
  if (agreed == true) {
    Store.I.cfg.privacyAgreed = true;
    Store.I.cfg.privacyVersion = kPrivacyVersion;
    await Store.I.saveCfg();
    return true;
  }
  return false;
}

/// 拒绝后退出应用（华为审核要求：不同意的，不得强制使用）
void exitForPrivacy() {
  SystemNavigator.pop();
}

class PrivacyPage extends StatelessWidget {
  final String? text;
  final bool embedded;
  const PrivacyPage({super.key, this.text, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<String>(
      future: text != null ? Future.value(text!) : loadPrivacyText(),
      builder: (c, snap) {
        final t = snap.data ?? '加载中…';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(t, style: const TextStyle(fontSize: 13, height: 1.75)),
        );
      },
    );
    if (embedded) {
      return Scaffold(appBar: AppBar(title: const Text('隐私政策')), body: body);
    }
    return SubPage(title: '隐私政策', body: body);
  }
}
