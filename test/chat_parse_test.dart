// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-D3CE
import 'package:flutter_test/flutter_test.dart';
import 'package:gumao_chat/chat_parse.dart';

/// DeepSeek 网页版导出（【用户】/【DeepSeek】+ 轮次分隔线 + 元信息）
const deepseekLog = '''【标题】 少女乐队模拟器
【模型】 deepseek-reasoner
【轮数】 3492
【接口时间戳范围】 2026-11-13 05:09:19 — 2026-11-13 10:32:55
===== 第 1 轮 =====
【用户】 [附件] 少女乐队模拟器 (1).docx
【DeepSeek】 欢迎你来到少女乐队模拟器！
===== 第 2 轮 =====
【用户】 1
【DeepSeek】 你选择了商业团队。
===== 第 3 轮 =====
【用户】 就叫母鸡卡
【DeepSeek】 好的，乐队名已确定为「母鸡卡」。
''';

/// 「名字：内容」带时间戳的格式
const colonLog = '''[2026-11-13 05:09:19] 我：今天写哪段？
[2026-11-13 05:09:40] DeepSeek：写母鸡卡第一次登台那一幕。
[2026-11-13 05:10:02] 我：好，那先铺垫一下紧张感。
注意：这里不要写太长。
[2026-11-13 05:10:30] DeepSeek：明白。
''';

/// 没有对话结构的普通正文
const plainText = '''第一章 雨夜
林小雨推开门，雨水顺着伞骨滴下来。
她看见桌上放着一封没有署名的信。
窗外的雷声滚过，她握紧了信封。
''';

void main() {
  test('识别 DeepSeek 导出：去掉元信息、分清双方', () {
    final p = parseChatLog(deepseekLog);
    expect(p.isChat, isTrue);
    expect(p.speakers.length, 2);
    expect(p.meSpeaker, '用户');
    expect(p.aiSpeaker, 'DeepSeek');
    expect(p.msgs.length, 6);
    expect(p.msgs.every((m) => m.speaker == '用户' || m.speaker == 'DeepSeek'),
        isTrue);
    // 元信息不能被当成正文
    expect(p.msgs.any((m) => m.content.contains('轮数')), isFalse);
    expect(p.msgs.any((m) => m.content.contains('接口时间戳')), isFalse);
  });

  test('识别「名字：内容」格式，多行正文不断开', () {
    final p = parseChatLog(colonLog);
    expect(p.isChat, isTrue);
    expect(p.meSpeaker, '我');
    expect(p.speakers.length, 2);
    expect(p.msgs.length, 4);
    // 没有发言人的续行应并入上一条消息
    expect(p.msgs[2].content, contains('注意：这里不要写太长。'));
  });

  test('普通正文不会被误判成对话', () {
    final p = parseChatLog(plainText);
    expect(p.isChat, isFalse);
  });
}
