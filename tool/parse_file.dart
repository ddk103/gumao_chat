// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-19E8
// 开发脚本：拿真实导出文件跑一遍解析，看结果对不对（不参与打包）
// 运行： dart run tool/parse_file.dart "C:\path\to\对话记录.txt"
import 'dart:io';

import 'package:gumao_chat/chat_parse.dart';

void main(List<String> argv) {
  if (argv.isEmpty) {
    print('用法： dart run tool/parse_file.dart <聊天记录文件路径>');
    return;
  }
  final path = argv.first;
  final f = File(path);
  if (!f.existsSync()) {
    print('找不到文件：$path');
    return;
  }
  final sw = Stopwatch()..start();
  final text = f.readAsStringSync();
  final p = parseChatLog(text);
  sw.stop();

  print('文件：${f.lengthSync()} 字节 / ${text.length} 字符');
  print('解析耗时：${sw.elapsedMilliseconds} ms');
  print('isChat=${p.isChat}  msgs=${p.msgs.length}  speakers=${p.speakers}');
  print('我=${p.meSpeaker}  AI=${p.aiSpeaker}  meIndex=${p.meIndex}  '
      '我条数=${p.mineCount}  AI条数=${p.aiCount}');
  final top = p.counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('说话人条数：${top.take(10).map((e) => '${e.key}=${e.value}').join(', ')}');

  print('\n--- 前 4 条 ---');
  for (final m in p.msgs.take(4)) {
    final who = m.speaker == p.meSpeaker ? '我' : 'AI';
    final c = m.content.replaceAll('\n', ' / ');
    print('[$who] ${m.speaker}: ${c.length > 90 ? '${c.substring(0, 90)}…' : c}');
  }
  print('\n--- 后 4 条 ---');
  for (final m in p.msgs.skip(p.msgs.length - 4)) {
    final who = m.speaker == p.meSpeaker ? '我' : 'AI';
    final c = m.content.replaceAll('\n', ' / ');
    print('[$who] ${m.speaker}: ${c.length > 90 ? '${c.substring(0, 90)}…' : c}');
  }

  // 体检：有没有把正文行误当说话人 / 有没有超长消息
  final ks = p.counts.keys.where((k) => !p.speakers.contains(k)).toList();
  print('\n未计入说话人的候选：${ks.take(10)}');
  final long = p.msgs.where((m) => m.content.length > 4000).length;
  final empty = p.msgs.where((m) => m.content.trim().isEmpty).length;
  print('超长(>4000字)消息=$long  空消息=$empty');
  final lens = p.msgs.map((m) => m.content.length).toList()..sort();
  if (lens.isNotEmpty) {
    print('消息长度 中位=${lens[lens.length ~/ 2]} 最大=${lens.last}');
  }
  final trimmed = p.msgs.where((m) => m.content.contains('===== 第')).length;
  print('仍带轮次分隔线的消息=$trimmed');
}
