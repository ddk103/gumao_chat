// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-0674
// 孤猫聊天 · 我的页
// 结构：身份卡片 → 设置与管理行列表 → 版本号
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'decor.dart';
import 'memory_page.dart';
import 'privacy.dart';
import 'settings_page.dart';
import 'store.dart';
import 'trace.dart';
import 'ui.dart';
import 'voice_page.dart';

/// 版本号：与 pubspec.yaml 保持一致
const String kAppVersion = '0.1.0';

class MinePage extends StatefulWidget {
  const MinePage({super.key});
  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  /// 隐藏入口：连点身份卡片 7 次打开来源校验（普通用户不会误触）
  int _secretTaps = 0;
  DateTime? _lastTap;

  void _onHeaderTap() {
    final now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _secretTaps = 0;
    }
    _lastTap = now;
    _secretTaps++;
    if (_secretTaps >= 7) {
      _secretTaps = 0;
      showTraceDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal();
    final s = Store.I;
    var msgCount = 0;
    for (final c in s.chats) {
      msgCount += c.msgs.length;
    }
    final aiName = s.cfg.aiName;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: fancyAppBar('我的', autoLeading: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // —— 身份卡片（渐变 + 光晕）——
        // 隐藏入口：连点 7 次卡片打开「来源校验」
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onHeaderTap,
          child: Container(
          height: 116,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: p.grad),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: p.grad.last.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ]),
          child: Stack(children: [
            GlowDecor(colors: p.grad),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Builder(builder: (c2) {
                    final path = s.cfg.aiAvatar;
                    final hasImg = path.isNotEmpty && File(path).existsSync();
                    return Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7), width: 2),
                          color: Colors.white.withValues(alpha: 0.22)),
                      clipBehavior: Clip.antiAlias,
                      child: hasImg
                          ? Image.file(File(path), fit: BoxFit.cover)
                          : Image.asset('assets/black_cat.png', fit: BoxFit.cover),
                    );
                  }),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(aiName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 5),
                        Text('${s.chats.length} 个会话 · $msgCount 条消息',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.88))),
                        const SizedBox(height: 4),
                        Text('${s.docs.length} 份记忆资料',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.72))),
                      ])),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/black_cat.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.85)),
                  ),
                ])),
          ]),
        ),
        ),
        const SizedBox(height: 16),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('设置与管理',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.line.withValues(alpha: 0.7), width: 0.7),
              boxShadow: [
                BoxShadow(
                    color: p.isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : p.primaryD.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ]),
          child: Column(children: [
            for (var i = 0; i < _rows.length; i++) ...[
              _row(_rows[i], i),
              if (i < _rows.length - 1)
                Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 12,
                    endIndent: 12,
                    color: p.line),
            ],
          ]),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
                child: Text('孤猫聊天 · 源码开放版 $kAppVersion',
                    style: TextStyle(fontSize: 11, color: p.muted)))),
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
                child: Text('本应用不提供模型服务，请自备 OpenAI 兼容接口',
                    style: TextStyle(fontSize: 10.5, color: p.muted)))),
      ]),
    );
  }

  static const _rows = <List<String>>[
    ['接', 'API 与模型', '接口地址、密钥、主模型', 'api'],
    ['思', '深度思考模型', '填你账号支持的推理模型名', 'deepmodel'],
    ['色', 'UI 皮肤', '当前：雅致绿 · 点这里换', 'theme'],
    ['大', '显示大小 / 对话间距', '宽松微信风 / 标准 / 紧凑', 'density'],
    ['像', '全局 AI 与头像', '身份、资料、人设、双方头像', 'ai'],
    ['忆', '长期记忆与资料', '导入资料 / 聊天记录作为背景知识', 'memory'],
    ['史', '历史对话', '查看 / 切换 / 删除会话', 'sessions'],
    ['声', '语音与朗读', '多款音色 / 语音输入 / 在线朗读', 'voice'],
    ['备', '备份数据', '导出全部配置、对话与资料', 'backup'],
    ['私', '隐私政策', '我们如何收集与使用信息', 'privacy'],
    ['开', '关于与许可', '版本、许可、商业授权说明', 'about'],
  ];

  Widget _row(List<String> r, int idx) {
    final p = pal();
    final s = Store.I;
    var name = r[1], sub = r[2];
    if (r[3] == 'theme') {
      sub = '当前：${_themeName(s.cfg.theme)} · ${THEME_KEYS.length} 套皮肤任选';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openRow(r[3]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          gradientIcon(
            Text(r[0],
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            ROW_GRADIENTS[idx % ROW_GRADIENTS.length],
            size: 34,
            radius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 14.5, color: p.ink)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11.5, color: p.muted)),
          ])),
          Text('›', style: TextStyle(fontSize: 18, color: p.muted)),
        ]),
      ),
    );
  }

  String _themeName(String k) => THEME_NAMES[k] ?? '雅致绿';

  Future<void> _openRow(String key) async {
    final s = Store.I;
    switch (key) {
      case 'api':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsPage()));
        break;
      case 'deepmodel':
        final c = TextEditingController(text: s.cfg.deepModel);
        final v = await showDialog<String>(context: context, builder: (c2) {
          final p = pal();
          return AlertDialog(
            backgroundColor: p.surface,
            title: Text('深度思考模型', style: TextStyle(color: p.ink, fontSize: 16)),
            content: TextField(
              controller: c,
              style: TextStyle(color: p.ink),
              decoration: InputDecoration(
                  hintText: '如 deepseek-v4-pro',
                  hintStyle: TextStyle(color: p.muted)),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c2),
                  child: Text('取消', style: TextStyle(color: p.muted))),
              TextButton(
                  onPressed: () => Navigator.pop(c2, c.text.trim()),
                  child: Text('保存',
                      style: TextStyle(
                          color: p.primary, fontWeight: FontWeight.bold))),
            ],
          );
        });
        if (v != null) {
          s.cfg.deepModel = v.isEmpty ? 'deepseek-v4-pro' : v;
          await s.saveCfg();
        }
        break;
      case 'theme':
        final k = await showThemePicker(context);
        if (k != null) {
          setTheme(k);
          if (mounted) {
            snackbar(context, '已换上「${THEME_NAMES[k]}」皮肤',
                icon: Icons.palette_outlined);
          }
        }
        break;
      case 'density':
        final labels = ['宽松微信风', '标准', '紧凑'];
        final v = await pickItem(context, '显示大小 / 对话间距', labels);
        if (v != null) {
          s.cfg.density = v;
          await s.saveCfg();
          if (mounted) snackbar(context, '已设为${labels[v]}');
        }
        break;
      case 'ai':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsPage()));
        break;
      case 'memory':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MemoryPage()));
        break;
      case 'sessions':
        _sessionsDialog();
        break;
      case 'voice':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VoicePage()));
        break;
      case 'backup':
        _backupDialog();
        break;
      case 'privacy':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PrivacyPage()));
        break;
      case 'about':
        _aboutDialog();
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _sessionsDialog() async {
    final s = Store.I;
    final p = pal();
    await showDialog<void>(context: context, builder: (c) {
      return AlertDialog(
        backgroundColor: p.surface,
        title: Text('历史对话（${s.chats.length}）',
            style: TextStyle(color: p.ink, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: s.chats.isEmpty
              ? Center(child: Text('还没有会话', style: TextStyle(color: p.muted)))
              : ListView.builder(
                  itemCount: s.chats.length,
                  itemBuilder: (c2, i) {
                    final ch = s.chats[i];
                    final on = ch.id == s.activeId;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                          on ? Icons.check_circle : Icons.chat_bubble_outline,
                          size: 20,
                          color: on ? p.primary : p.muted),
                      title: Text(ch.title.isEmpty ? '新会话' : ch.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              color: on ? p.primary : p.ink,
                              fontWeight:
                                  on ? FontWeight.bold : FontWeight.normal)),
                      trailing: InkWell(
                        onTap: () {
                          s.chats.removeAt(i);
                          if (s.activeId == ch.id) {
                            s.activeId =
                                s.chats.isNotEmpty ? s.chats.first.id : '';
                          }
                          s.saveChats();
                          Navigator.pop(c);
                          setState(() {});
                        },
                        child: Icon(Icons.delete_outline,
                            size: 18, color: p.danger),
                      ),
                      onTap: () {
                        s.activeId = ch.id;
                        s.saveChats();
                        Navigator.pop(c);
                        setState(() {});
                        snackbar(context, '已切换会话');
                      },
                    );
                  }),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('关闭', style: TextStyle(color: p.muted))),
        ],
      );
    });
  }

  Future<void> _backupDialog() async {
    final p = pal();
    await showDialog<void>(context: context, builder: (c) {
      return AlertDialog(
        backgroundColor: p.surface,
        title: Text('备份数据', style: TextStyle(color: p.ink, fontSize: 16)),
        content: Text(
            '把全部配置、对话记录和记忆资料导出成一份 JSON 文件，方便换机或留底。\n'
            '导出文件不含 API Key 以外的任何个人信息，请妥善保管。',
            style: TextStyle(color: p.muted, fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
              onPressed: () async {
                Navigator.pop(c);
                await _backupAll();
              },
              child: Text('导出全部',
                  style: TextStyle(
                      color: p.primary, fontWeight: FontWeight.bold))),
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('关闭', style: TextStyle(color: p.muted))),
        ],
      );
    });
  }

  Future<void> _backupAll() async {
    try {
      final dir = await Store.I.dir();
      final d = DateTime.now();
      final name =
          'gumao_chat_backup_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.json';
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      await f.writeAsString(Store.I.backupJson(), encoding: utf8);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (c) {
        final p = pal();
        return AlertDialog(
          backgroundColor: p.surface,
          title: Text('备份完成', style: TextStyle(color: p.ink)),
          content: Text(f.path, style: TextStyle(color: p.muted, fontSize: 12)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text('好的', style: TextStyle(color: p.primary))),
          ],
        );
      });
    } catch (e) {
      if (mounted) snackbar(context, '备份失败：$e');
    }
  }

  Future<void> _aboutDialog() async {
    final p = pal();
    await showDialog<void>(context: context, builder: (c) {
      return AlertDialog(
        backgroundColor: p.surface,
        title: Text('关于孤猫聊天', style: TextStyle(color: p.ink, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onLongPress: () => showTraceDialog(context),
                  child: Text('版本 $kAppVersion',
                      style: TextStyle(color: p.ink, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Text(
                    '孤猫聊天 是一个源码开放、极简的 AI 对话客户端：\n'
                    '· 支持任意 OpenAI 兼容接口，也可以配置多个自定义接口；\n'
                    '· 对话保存在本机，可导入分享链接 / 文本 / 备份文件；\n'
                    '· 记忆资料按关键词检索后注入上下文，省 token；\n'
                    '· 内置语音输入与多音色朗读。\n\n'
                    '本应用不提供模型服务，也不收集你的对话内容；'
                    '所有数据只保存在你自己的设备上。',
                    style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.65)),
                const SizedBox(height: 10),
                Text(
                    '许可：PolyForm Noncommercial 1.0.0\n'
                    '个人学习 / 研究 / 非营利组织免费使用；\n'
                    '商业使用需取得作者书面授权（见项目 LICENSE）。',
                    style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('关闭', style: TextStyle(color: p.primary))),
        ],
      );
    });
  }
}
