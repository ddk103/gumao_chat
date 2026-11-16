// 开发脚本：用真实分享链接验证 share_import 的解析效果
// 运行： dart run tool/check_share.dart <share_id 或分享链接>
import 'package:gumao_chat/share_import.dart';

Future<void> main(List<String> args) async {
  final input = args.isNotEmpty ? args.first : 'mzz14vhl5mkxjrb1sc';
  final id = shareIdOf(input) ?? input;
  print('share_id = $id');
  final sw = Stopwatch()..start();
  try {
    final conv = await fetchDeepSeekShare(id);
    sw.stop();
    print('title = ${conv.title}');
    print('msgs = ${conv.msgs.length}，耗时 ${sw.elapsedMilliseconds}ms');
    final roles = conv.msgs.map((m) => m.role).toList();
    print('roles 顺序 = ${roles.take(10).join(" → ")}${roles.length > 10 ? " …" : ""}');
    print('user=${roles.where((r) => r == 'user').length} '
        'assistant=${roles.where((r) => r == 'assistant').length}');
    final empty = conv.msgs.where((m) => m.text.trim().isEmpty).length;
    print('空消息 = $empty，首条角色 = ${conv.msgs.first.role}，末条角色 = ${conv.msgs.last.role}');
    for (final m in conv.msgs.take(3)) {
      final t = m.text.replaceAll('\n', ' ');
      print('[${m.role}] ${t.length > 60 ? t.substring(0, 60) : t}…');
    }
    // 校验：不能把 THINK 思考内容混进正文
    final thinkLeak = conv.msgs.any((m) => m.text.contains('用户提供了几个分享链接，要求我根据这些链接的内容'));
    print('思考内容是否混入正文 = $thinkLeak');
  } catch (e) {
    print('FAILED: $e');
  }
}
