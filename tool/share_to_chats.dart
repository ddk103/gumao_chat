// 开发脚本：把真实分享对话落成 App 的 chats.json（与 App 内导入结果一致）
// 运行： dart run tool/share_to_chats.dart <share_id或链接> [输出文件]
import 'dart:convert';
import 'dart:io';

import 'package:gumao_chat/share_import.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('用法： dart run tool/share_to_chats.dart <share_id或链接> [输出文件]');
    return;
  }
  final id = shareIdOf(args.first) ?? args.first;
  final outPath = args.length > 1 ? args[1] : 'share_chats.json';
  final conv = await fetchDeepSeekShare(id);
  final now = DateTime.now().millisecondsSinceEpoch;
  var ts = now - conv.msgs.length * 60000;
  final msgs = <Map<String, dynamic>>[];
  for (final m in conv.msgs) {
    msgs.add({'role': m.role, 'content': m.text, 'ts': ts});
    ts += 60000;
  }
  final sid = 'c$now';
  final data = {
    'chats': [
      {
        'id': sid,
        'title': '${conv.title} · 分享',
        'created': now,
        'updated': now,
        'msgs': msgs,
      }
    ],
    'active': sid,
    'memEnabled': true,
    'deepThink': false,
  };
  File(outPath).writeAsStringSync(jsonEncode(data));
  print('title=${conv.title}  msgs=${msgs.length}  -> $outPath');
}
