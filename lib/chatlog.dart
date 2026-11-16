// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-1455
// 孤猫聊天 · 聊天记录解析 + 时间格式化 + 导入导出
// 解析本体已抽到 chat_parse.dart（纯 Dart，可单独跑测试）；这里只保留时间与导入导出。
import 'dart:convert';

import 'store.dart';

export 'chat_parse.dart';

// ---------------- 时间显示（微信式） ----------------

String two(int n) => n < 10 ? '0$n' : '$n';

String fmtChatTime(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final hm = '${two(d.hour)}:${two(d.minute)}';
  final diff = today.difference(that).inDays;
  if (diff == 0) return hm;
  if (diff == 1) return '昨天 $hm';
  if (d.year == now.year) return '${d.month}月${d.day}日 $hm';
  return '${d.year}年${d.month}月${d.day}日 $hm';
}

bool needDivider(int prevTs, int ts) =>
    prevTs <= 0 || ts - prevTs > 5 * 60 * 1000;

// ---------------- 导出 ----------------

String exportChatJson(Session s) {
  final out = <Map<String, dynamic>>[];
  for (final m in s.msgs) {
    if (m.role != 'user' && m.role != 'assistant') continue;
    out.add({'role': m.role, 'content': m.content, 'ts': m.ts});
  }
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'gumao-novel-assistant',
    'type': 'chat',
    'title': s.title,
    'exported': DateTime.now().millisecondsSinceEpoch,
    'msgs': out,
  });
}

String exportChatTxt(Session s) {
  final now = DateTime.now();
  final sb = StringBuffer();
  sb.write('【${s.title}】 导出自 孤猫聊天 · '
      '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}\n\n');
  for (final m in s.msgs) {
    if (m.role != 'user' && m.role != 'assistant') continue;
    final who = m.role == 'user' ? '我' : Store.I.cfg.aiName;
    sb.write('[${fmtChatTime(m.ts)}] $who：${m.content}\n\n');
  }
  return sb.toString();
}
