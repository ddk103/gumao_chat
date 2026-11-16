// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-143F
// 孤猫聊天 · 入口
// 一套代码构建 Android APK；底部两个 Tab：对话 / 我的。
import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'mine_page.dart';
import 'privacy.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.loadAll();
  runApp(const GumaoChatApp());
}

class GumaoChatApp extends StatelessWidget {
  const GumaoChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '孤猫聊天',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: const MaterialColor(0xFF2F7D5B, {
          50: Color(0xFFE9F3EE), 100: Color(0xFFC9E2D6), 200: Color(0xFFA0CDB8),
          300: Color(0xFF74B396), 400: Color(0xFF4C9677), 500: Color(0xFF2F7D5B),
          600: Color(0xFF297050), 700: Color(0xFF225F43), 800: Color(0xFF1B4D36),
          900: Color(0xFF143C29),
        }),
        useMaterial3: false,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    homeTab.addListener(_onTab);
    // 合规：首次启动（或隐私政策升版）先弹同意框，不同意就退出
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPrivacy());
  }

  Future<void> _askPrivacy() async {
    final ok = await ensurePrivacyAgreed(context);
    if (!ok && mounted) exitForPrivacy();
  }

  @override
  void dispose() {
    homeTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeTick,
      builder: (context, tv, _) => Scaffold(
        // 折叠屏展开 / 平板：内容限宽居中，避免一行排几十个字；直板机不受影响
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: IndexedStack(
            index: homeTab.value.clamp(0, 1),
            children: [
              ChatPage(key: ValueKey('ch_$tv')),
              MinePage(key: ValueKey('me_$tv')),
            ],
          ),
        )),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: homeTab,
          builder: (c, v, _) => _FancyNav(
              current: v.clamp(0, 1), onTap: (i) => homeTab.value = i),
        ),
      ),
    );
  }
}

/// 自定义底栏：选中胶囊渐变 + 顶部柔光 + 图标切换动画
class _FancyNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _FancyNav({required this.current, required this.onTap});

  static const _labels = ['对话', '我的'];
  static const _off = [Icons.chat_bubble_outline, Icons.person_outline];
  static const _on = [Icons.chat_bubble, Icons.person];

  @override
  Widget build(BuildContext context) {
    final p = pal();
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        boxShadow: [
          BoxShadow(
              color: p.isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : p.primaryD.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < 2; i++) Expanded(child: _item(p, i)),
          ]),
        ),
      ),
    );
  }

  Widget _item(Pal p, int i) {
    final on = i == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: on ? 20 : 14, vertical: 4),
          decoration: BoxDecoration(
            gradient: on
                ? LinearGradient(colors: [
                    p.grad.first.withValues(alpha: 0.16),
                    p.grad.last.withValues(alpha: 0.10),
                  ])
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(on ? _on[i] : _off[i],
              size: on ? 23 : 21, color: on ? p.primary : p.muted),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
              fontSize: on ? 11 : 10.5,
              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              color: on ? p.primary : p.muted),
          child: Text(_labels[i]),
        ),
      ]),
    );
  }
}
