// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-5485
// 孤猫聊天 · LLM 调用层：SSE 流式（OpenAI 兼容）+ 分层 system prompt + 资料检索
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'store.dart';

class LlmEvent {
  final String? content; // 正文增量
  final String? think;   // 深度思考增量
  final String? error;   // 错误（结束）
  final bool done;
  LlmEvent({this.content, this.think, this.error, this.done = false});
}

/// OpenAI 兼容地址归一化：/v1/chat/completions
/// 智谱 /api/paas/v4、豆包 /api/v3、Gemini /v1beta/openai 等已带版本号的地址
/// 直接拼 /chat/completions；DeepSeek 这类裸域名才补 /v1
String completionsUrl(String base) {
  var b = base.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  if (b.endsWith('/chat/completions')) return b;
  if (RegExp(r'/v\d+([^/]*)$').hasMatch(b) || b.endsWith('/openai')) {
    return '$b/chat/completions';
  }
  return '$b/v1/chat/completions';
}

/// 模型列表地址：把 .../chat/completions 换成 .../models
String modelsUrl(String base) {
  final c = completionsUrl(base);
  const tail = 'chat/completions';
  return c.replaceRange(c.length - tail.length, c.length, 'models');
}

/// 从接口实时拉取可用模型（OpenAI 兼容 GET /models）
/// 兼容 {data:[{id}]} / {data:[{name}]} / {models:[...]} 几种返回格式
Future<List<String>> fetchModels({String? baseUrl, String? apiKey}) async {
  final key = (apiKey ?? Store.I.cfg.apiKey).trim();
  if (key.isEmpty) throw Exception('先填 API Key 再刷新模型');
  final url = modelsUrl((baseUrl ?? Store.I.cfg.baseUrl).trim());
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} ${clip(text, 120)}');
    }
    final j = jsonDecode(text) as Map;
    final raw = (j['data'] ?? j['models'] ?? j['model_list'] ?? []) as List;
    final set = <String>{};
    for (final m in raw) {
      String id;
      if (m is Map) {
        id = (m['id'] ?? m['name'] ?? m['model'] ?? '').toString();
      } else {
        id = m.toString();
      }
      if (id.startsWith('models/')) id = id.substring(7);
      if (id.isNotEmpty && id != '[]') set.add(id);
    }
    final list = set.toList()..sort();
    if (list.isEmpty) throw Exception('接口没返回可用模型');
    return list;
  } finally {
    client.close();
  }
}

/// 带图消息转 wire 格式：img64 是 data:image/...;base64,xxx
Map<String, dynamic> wireMsg(Map<String, dynamic> m) {
  final img64 = m['img64'] as String?;
  if (img64 == null || img64.isEmpty) {
    return {'role': m['role'] as String, 'content': m['content'] as String};
  }
  return {
    'role': m['role'] as String,
    'content': [
      {'type': 'text', 'text': (m['content'] ?? '') as String},
      {'type': 'image_url', 'image_url': {'url': img64}},
    ],
  };
}

/// 流式对话；回调式接口，cancel 通过返回的订阅句柄控制
class StreamHandle {
  HttpClientRequest? _req;
  bool cancelled = false;
  void cancel() {
    cancelled = true;
    try { _req?.abort(); } catch (_) {}
  }
}

StreamHandle streamChat({
  required List<Map<String, dynamic>> messages,
  required String system,
  required bool deep,
  required void Function(String) onContent,
  required void Function(String) onThink,
  required void Function(String) onError,
  required void Function() onDone,
}) {
  final cfg = Store.I.cfg;
  final h = StreamHandle();
  () async {
    HttpClient? client;
    try {
      final url = completionsUrl(cfg.baseUrl);
      final base = <String, dynamic>{
        'model': deep ? cfg.deepModel : cfg.model,
        'messages': [
          {'role': 'system', 'content': system},
          ...messages.map(wireMsg),
        ],
        'stream': true,
      };
      // 没开「深度思考」时，让 DeepSeek 家族直接返回答案、不生成思维链；
      // 中转站不认 thinking 参数会 400，第二组自动去掉。
      final thinkOff = !deep &&
          isDeepSeekFamily(cfg.baseUrl, deep ? cfg.deepModel : cfg.model);
      final variants = <Map<String, dynamic>>[
        <String, dynamic>{
          if (thinkOff) 'thinking': {'type': 'disabled'},
          'max_tokens': 3000,
        },
        <String, dynamic>{'max_tokens': 3000},
        <String, dynamic>{'max_completion_tokens': 3000},
        <String, dynamic>{},
      ];
      HttpClientResponse? resp;
      Object? lastErr;
      for (final extra in variants) {
        if (h.cancelled) {
          onDone();
          return;
        }
        client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
        final req = await client.openUrl('POST', Uri.parse(url));
        h._req = req;
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${cfg.apiKey}');
        final bytes = utf8.encode(jsonEncode({...base, ...extra}));
        req.contentLength = bytes.length; // 显式长度，部分网关不接受 chunked
        req.add(bytes);
        final r = await req.close();
        if (r.statusCode == 400) {
          final t = await r.transform(utf8.decoder).join();
          final msg = _serverMessage(t);
          if (_isParamError(ApiError(400, msg, url))) {
            lastErr = ApiError(400, msg, url);
            client.close();
            client = null;
            continue;
          }
          onError('HTTP 400 $msg');
          onDone();
          return;
        }
        if (r.statusCode != 200) {
          final err = await r.transform(utf8.decoder).join();
          onError('HTTP ${r.statusCode} ${clip(err, 200)}');
          onDone();
          return;
        }
        resp = r;
        break;
      }
      if (resp == null) {
        onError(lastErr?.toString() ?? '接口没有返回流式响应');
        onDone();
        return;
      }
      final lines = resp.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (h.cancelled) break;
        final l = line.trim();
        if (l.isEmpty || !l.startsWith('data:')) continue;
        final data = l.substring(5).trim();
        if (data == '[DONE]') break;
        try {
          final j = jsonDecode(data) as Map;
          final choices = (j['choices'] ?? []) as List;
          if (choices.isEmpty) continue;
          final delta = ((choices[0] as Map)['delta'] ?? {}) as Map;
          final rc = delta['reasoning_content'];
          if (rc is String && rc.isNotEmpty) onThink(rc);
          final c = delta['content'];
          if (c is String && c.isNotEmpty) onContent(c);
        } catch (_) {}
      }
      onDone();
    } catch (e) {
      if (!h.cancelled) onError(e.toString());
      onDone();
    } finally {
      client?.close();
    }
  }();
  return h;
}

// ---------------- 非流式调用（编辑器 AI 动作 / 工具生成用） ----------------

/// 保留服务端状态码与原始错误，界面才能给出可操作的提示
class ApiError implements Exception {
  final int status;
  final String message;
  final String url;
  ApiError(this.status, this.message, this.url);
  @override
  String toString() => 'HTTP $status $message';
}

/// 提炼各家接口的错误文本（error.message / error 字符串 / message / 纯文本）
String _serverMessage(String body) {
  try {
    final j = jsonDecode(body);
    if (j is Map) {
      final e = j['error'];
      if (e is Map) return (e['message'] ?? e['code'] ?? e.toString()).toString();
      if (e is String) return e;
      if (j['message'] != null) return j['message'].toString();
    }
  } catch (_) {}
  return clip(body.replaceAll(RegExp(r'\s+'), ' '), 220);
}

/// 把底层异常翻译成用户知道该怎么做的中文提示
String friendlyApiError(Object e) {
  var s = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (Store.I.cfg.apiKey.trim().isEmpty) {
    return '还没填 API Key，到「我的 → API 与模型」填好再试';
  }
  if (s.contains('HTTP 401') || s.contains('HTTP 403')) {
    return 'API Key 不对或没权限（401/403），到设置里检查';
  }
  if (s.contains('HTTP 402') || s.contains('余额不足') || s.toLowerCase().contains('insufficient')) {
    return '账户余额不足或额度用完，充值后再试';
  }
  if (s.contains('HTTP 404')) return '接口地址不对（404），检查设置里的接口网址';
  if (s.contains('HTTP 429')) return '请求太频繁或额度限流（429），稍后再试';
  if (RegExp(r'HTTP 5\d\d').hasMatch(s)) return '模型服务暂时不可用，稍后再试';
  final low = s.toLowerCase();
  if (low.contains('model') && (low.contains('not exist') || low.contains('not found') ||
      low.contains('invalid') || low.contains('does not') || low.contains('unknown'))) {
    return '模型名不被这个接口支持，去设置里点「刷新模型」选一个真实模型';
  }
  if (low.contains('unsupported') || low.contains('not support') ||
      low.contains('max_tokens') || low.contains('response_format')) {
    return '接口不支持请求参数（已自动重试仍失败）：${clip(s, 100)}';
  }
  if (s.contains('Failed host lookup') || low.contains('socketexception') ||
      low.contains('connection refused') || low.contains('timed out') ||
      low.contains('handshake') || low.contains('certificate')) {
    return '连不上接口服务器，检查网络、接口地址与系统时间';
  }
  if (s.contains('返回为空') || low.contains('empty_content')) {
    return '模型没返回正文（思考模型或长度限制），换个模型或把生成数量调小再试';
  }
  return clip(s, 140);
}

/// 一次 POST：显式 Content-Length（不少中转网关拒绝 chunked）+ 读取超时
Future<String> _postChat(String url, String key, Map<String, dynamic> body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client.openUrl('POST', Uri.parse(url));
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final bytes = utf8.encode(jsonEncode(body));
    req.contentLength = bytes.length;
    req.add(bytes);
    final resp = await req.close().timeout(const Duration(seconds: 120));
    final text = await resp.transform(utf8.decoder).join().timeout(const Duration(seconds: 120));
    if (resp.statusCode >= 400) {
      throw ApiError(resp.statusCode, _serverMessage(text), url);
    }
    return text;
  } finally {
    client.close();
  }
}

/// 从各家返回里取正文：兼容数组 content、reasoning_content、老式 text
String _messageContent(Map j) {
  final choices = (j['choices'] ?? []) as List;
  if (choices.isEmpty) return '';
  final first = (choices[0] as Map);
  final msg = (first['message'] ?? const {}) as Map;
  Object? c = msg['content'];
  if (c is List) {
    c = c.map((e) => e is Map ? (e['text'] ?? '').toString() : e.toString()).join();
  }
  if (c == null || c.toString().trim().isEmpty) {
    c = msg['reasoning_content'] ?? msg['reasoning'] ?? first['text'] ?? j['text'];
  }
  return c?.toString() ?? '';
}

/// DeepSeek V4 默认开思考模式（思维链走 reasoning_content，正文走 content）。
/// 工具型生成（灵感/大纲/正文）不需要思考，显式关掉能避免思考 token 吃满 max_tokens
/// 导致正文为空；中转站若不认这个参数，下面的降级组合会自动去掉。
bool isDeepSeekFamily(String url, String model) =>
    url.toLowerCase().contains('deepseek') ||
    model.toLowerCase().contains('deepseek');

/// 参数组合：不同模型/中转站对 thinking、temperature、response_format、max_tokens
/// 支持不同，收到「不支持的参数」类 400 就依次降级，直到能通。
List<Map<String, dynamic>> _paramVariants(int maxTokens, bool jsonMode,
    {bool thinkOff = false}) => [
      <String, dynamic>{
        if (thinkOff) 'thinking': {'type': 'disabled'},
        'temperature': 0.85,
        'max_tokens': maxTokens,
        if (jsonMode) 'response_format': {'type': 'json_object'},
      },
      <String, dynamic>{
        if (thinkOff) 'thinking': {'type': 'disabled'},
        'max_tokens': maxTokens,
      },
      <String, dynamic>{'max_tokens': maxTokens},
      <String, dynamic>{'max_completion_tokens': maxTokens},
      <String, dynamic>{},
    ];

bool _isParamError(ApiError e) {
  if (e.status != 400) return false;
  final m = e.message.toLowerCase();
  return m.contains('unsupported') || m.contains('not support') ||
      m.contains('temperature') || m.contains('max_tokens') ||
      m.contains('max_completion_tokens') || m.contains('response_format') ||
      m.contains('parameter') || m.contains('invalid_request');
}

bool _isModelError(ApiError e) {
  final m = e.message.toLowerCase();
  return m.contains('model') && (m.contains('not exist') || m.contains('not found') ||
      m.contains('invalid') || m.contains('does not') || m.contains('unknown'));
}

String _cleanContent(String raw) => stripThink(raw).trim();

/// 去掉模型把思考过程写进正文的 <think>…</think> 块。
/// 流式输出时标签可能还没闭合，此时连后面的内容一起隐藏，等闭合后再放正文出来。
String stripThink(String s) {
  // Dart RegExp 不支持 (?s) 内联标志（会抛 FormatException: Invalid group），
  // 用 [\s\S] 匹配换行，等价 dotAll
  var out = s.replaceAll(RegExp(r'<think[^>]*>[\s\S]*?</think>'), '');
  final i = out.indexOf('<think');
  if (i >= 0) out = out.substring(0, i);
  return out;
}

/// 一次性补全：返回正文（自动剥 <think> 块）。灵感/工具/黄金三章等共用。
/// jsonMode=true 会请接口直接输出 JSON 对象；接口不支持会自动去掉该参数。
Future<String> aiComplete(String prompt, String system, int maxTokens,
    {bool jsonMode = false}) async {
  try {
    return await _aiCompleteCore(prompt, system, maxTokens, jsonMode: jsonMode);
  } catch (e) {
    throw Exception(friendlyApiError(e));
  }
}

Future<String> _aiCompleteCore(String prompt, String system, int maxTokens,
    {bool jsonMode = false}) async {
  final cfg = Store.I.cfg;
  final key = cfg.apiKey.trim();
  if (key.isEmpty) throw Exception('先去设置里填 API Key');
  final url = completionsUrl(cfg.baseUrl);
  // 404 时给一次机会：部分中转站把 chat/completions 挂在根路径而非 /v1 下
  final urls = <String>[url];
  if (url.contains('/v1/chat/completions')) {
    urls.add(url.replaceFirst('/v1/chat/completions', '/chat/completions'));
  }
  final messages = [
    {'role': 'system', 'content': system},
    {'role': 'user', 'content': prompt},
  ];
  ApiError? apiLast;
  var lengthRetried = false;
  // 工具型生成一律关掉思考：要的是 JSON / 正文，不是思维链
  final thinkOff = isDeepSeekFamily(cfg.baseUrl, cfg.model);
  for (final u in urls) {
    for (final extra in _paramVariants(maxTokens, jsonMode, thinkOff: thinkOff)) {
      final body = <String, dynamic>{
        'model': cfg.model, 'messages': messages, ...extra,
      };
      final text = await _postChatOnce(u, key, body, onParamError: (e) => apiLast = e);
      if (text == null) {
        if (apiLast != null && apiLast!.status == 404) break; // 换备用地址
        continue;                                           // 换下一组参数
      }
      final j = _decodeJson(text);
      final content = _cleanContent(_messageContent(j));
      if (content.isNotEmpty) return content;
      // 思考模型把 token 用在推理上导致正文为空：加倍长度预算再试一次
      if (!lengthRetried) {
        lengthRetried = true;
        final body2 = <String, dynamic>{
          'model': cfg.model, 'messages': messages,
          if (thinkOff) 'thinking': {'type': 'disabled'},
          'max_tokens': (maxTokens * 2).clamp(1000, 8000),
        };
        final t2 = await _postChatOnce(u, key, body2, onParamError: (e) => apiLast = e);
        if (t2 != null) {
          final c2 = _cleanContent(_messageContent(_decodeJson(t2)));
          if (c2.isNotEmpty) return c2;
        }
      }
      break;
    }
  }
  throw apiLast ?? Exception('返回为空');
}

/// 返回响应文本；参数类 400 交给上层换组合，404 交给上层换地址，其它错误直接抛
Future<String?> _postChatOnce(String url, String key, Map<String, dynamic> body,
    {required void Function(ApiError) onParamError}) async {
  try {
    return await _postChat(url, key, body);
  } on ApiError catch (e) {
    if (_isModelError(e)) rethrow;
    if (e.status == 404 || _isParamError(e)) {
      onParamError(e);
      return null;
    }
    rethrow;
  }
}

Map<String, dynamic> _decodeJson(String text) {
  try {
    final j = jsonDecode(text);
    if (j is Map) return j.cast<String, dynamic>();
  } catch (_) {}
  throw Exception('接口返回的不是 JSON：${clip(text, 120)}');
}

/// 从模型输出里抠 JSON 对象（容忍 markdown 围栏/前后废话/尾逗号/被截断）
Map<String, dynamic>? extractJson(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'```(?:json|JSON)?'), '').trim();
  final a = s.indexOf('{');
  if (a < 0) return null;
  s = s.substring(a);
  final direct = _tryJson(s);
  if (direct != null) return direct;
  // 输出被 max_tokens 截断时，从后往前找可补全的位置，尽量救回已生成条目
  for (var i = s.length - 1; i > 0; i--) {
    if (s[i] != '}') continue;
    final m = _tryJson(_repairJson(s.substring(0, i + 1)));
    if (m != null) return m;
  }
  return null;
}

Map<String, dynamic>? _tryJson(String s) {
  try {
    final j = jsonDecode(s);
    if (j is Map) return j.cast<String, dynamic>();
  } catch (_) {}
  return null;
}

/// 补全被截断的 JSON：去掉尾逗号、闭合未收尾的字符串与括号
String _repairJson(String s) {
  s = s.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m.group(1)!);
  final stack = <String>[];
  var inStr = false, esc = false;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (ch == '\\') {
        esc = true;
      } else if (ch == '"') {
        inStr = false;
      }
      continue;
    }
    if (ch == '"') {
      inStr = true;
    } else if (ch == '{') {
      stack.add('}');
    } else if (ch == '[') {
      stack.add(']');
    } else if ((ch == '}' || ch == ']') && stack.isNotEmpty) {
      stack.removeLast();
    }
  }
  if (inStr) s = '$s"';
  return s + stack.reversed.join();
}

// ---------------- system prompt（分层记忆，硬预算省 token） ----------------

String buildSystem(String query) {
  final s = Store.I;
  final cfg = s.cfg;
  final sb = StringBuffer();
  sb.write('【身份】你是「孤猫聊天」内置的 AI 助手，名字叫「${cfg.aiName}」，'
      '定位是通用智能助手。'
      '不要用虚构人物的口吻或第一人称代入剧情说话。\n');
  sb.write('始终用简体中文回答。\n');
  if (cfg.persona.trim().isNotEmpty) {
    sb.write('\n【风格设定】${clip(cfg.persona.trim(), 400)}\n');
  }
  sb.write('【回答长度】默认简洁直接：日常问答控制在几句话内，'
      '只有用户明确要求详细、展开或进行创作时才写长文。\n');
  if (cfg.profile.trim().isNotEmpty) {
    sb.write('\n【AI 资料 · 用户在设定面板填写】\n${clip(cfg.profile.trim(), 600)}\n');
  }
  if (s.memEnabled && s.docs.isNotEmpty) {
    final docs = retrieveDocs(query, cfg.memBudget);
    if (docs.isNotEmpty) {
      sb.write('\n【参考记忆资料 · 只作背景，不必复述】\n$docs\n');
    }
  }
  return sb.toString();
}

/// 简单关键词检索：CJK 二字组 + 英文单词，分片打分取高分队，总预算封顶
String retrieveDocs(String query, int budget) {
  final terms = queryTerms(query);
  final sb = StringBuffer();
  var used = 0;
  for (final doc in Store.I.docs) {
    if (doc.chunks.isEmpty) continue;
    final scored = <MapEntry<int, double>>[];
    for (var i = 0; i < doc.chunks.length; i++) {
      var sc = 0.0;
      final c = doc.chunks[i];
      if (terms.isEmpty) {
        sc = i == 0 ? 1 : 0; // 没有查询词时偏向开头
      } else {
        for (final t in terms) {
          var idx = c.indexOf(t);
          while (idx >= 0) {
            sc += 1;
            idx = c.indexOf(t, idx + t.length);
          }
        }
        sc /= (1 + c.length / 500.0);
      }
      if (sc > 0) scored.add(MapEntry(i, sc));
    }
    if (scored.isEmpty) continue;
    scored.sort((a, b) => b.value.compareTo(a.value));
    sb.write('\n《${doc.name}》片段：\n');
    for (var k = 0; k < scored.length && k < 4; k++) {
      final frag = clip(doc.chunks[scored[k].key], 500);
      if (used + frag.length > budget) break;
      used += frag.length;
      sb.write('· $frag\n');
    }
  }
  return sb.toString();
}

List<String> queryTerms(String q) {
  final out = <String>[];
  final latin = RegExp(r'[A-Za-z0-9_]{2,}').allMatches(q);
  for (final m in latin) {
    out.add(m.group(0)!.toLowerCase());
  }
  final cjk = RegExp(r'[\u4e00-\u9fff]');
  for (var i = 0; i + 1 < q.length; i++) {
    if (cjk.hasMatch(q[i]) && cjk.hasMatch(q[i + 1])) {
      out.add(q.substring(i, i + 2));
    }
  }
  return out.toSet().toList();
}
