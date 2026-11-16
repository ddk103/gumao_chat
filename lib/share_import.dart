// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-720F
// 孤猫聊天 · DeepSeek 分享链接导入
// 分享页有公开结构化接口，直接拿到 role/fragments，角色天然分明：
//   USER      → 我（右侧）
//   ASSISTANT → AI（左侧），只取 RESPONSE（思考过程 THINK、联网搜索结果 TOOL_SEARCH 一律丢弃）
import 'dart:convert';
import 'dart:io';

class SharedMsg {
  final String role; // user | assistant
  final String text;
  const SharedMsg(this.role, this.text);
}

class SharedConversation {
  final String title;
  final List<SharedMsg> msgs;
  const SharedConversation(this.title, this.msgs);
}

/// 从任意文本里找出 DeepSeek 分享 ID（支持整段粘贴带链接的文字）
String? shareIdOf(String text) {
  final m = RegExp(r'chat\.deepseek\.com/share/([A-Za-z0-9]+)').firstMatch(text);
  return m?.group(1);
}

/// 拉取并解析分享对话；失败抛异常（由调用方提示改用文本粘贴）
Future<SharedConversation> fetchDeepSeekShare(String id) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 20);
  try {
    final uri = Uri.parse('https://chat.deepseek.com/api/v0/share/content?share_id=$id');
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw '分享接口返回 HTTP ${resp.statusCode}（链接可能失效或已取消分享）';
    }
    final root = jsonDecode(body);
    final biz = (root is Map ? root['data'] : null)?['biz_data'];
    final rawMsgs = (biz is Map ? biz['messages'] : null);
    if (rawMsgs is! List || rawMsgs.isEmpty) throw '这条分享里没有对话内容';
    final title = (biz is Map ? (biz['title'] ?? '') : '').toString();
    final out = <SharedMsg>[];
    for (final m in rawMsgs) {
      if (m is! Map) continue;
      final role = (m['role'] ?? '').toString().toUpperCase();
      final frags = m['fragments'];
      if (frags is! List) continue;
      final buf = <String>[];
      for (final f in frags) {
        if (f is! Map) continue;
        final t = (f['type'] ?? '').toString().toUpperCase();
        // 只要正文：用户 REQUEST、AI RESPONSE；THINK / TOOL_SEARCH / TOOL_OPEN 全部丢弃
        final want = (role == 'USER' && t == 'REQUEST') || (role == 'ASSISTANT' && t == 'RESPONSE');
        if (!want) continue;
        final c = (f['content'] ?? '').toString().trim();
        if (c.isNotEmpty) buf.add(c);
      }
      final text = buf.join('\n\n').trim();
      if (text.isEmpty) continue;
      out.add(SharedMsg(role == 'USER' ? 'user' : 'assistant', text));
    }
    if (out.isEmpty) throw '解析后没有可导入的消息';
    // 去掉开头结尾重复的空轮次（有的分享里首条是系统开场）
    return SharedConversation(title.trim().isEmpty ? '分享对话' : title.trim(), out);
  } on SocketException {
    throw '网络连不上，请检查网络后重试';
  } finally {
    client.close(force: true);
  }
}
