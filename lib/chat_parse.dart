// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-CF14
// 孤猫聊天 · 聊天记录解析（纯 Dart，不依赖 Flutter，方便单独测试）
//
// 解决的核心问题：导入「用户 / DeepSeek」这类对话时，以前只会把「第一个说话人」
// 当成我，于是整段记录全挤在 AI 一侧，还带着【用户】【DeepSeek】的前缀。
//
// 现在分三步：
//   1. 先丢掉导出工具的元信息行（【轮数】3492、【接口时间戳范围】…、===== 第 1 轮 =====）
//   2. 两遍扫描 —— 先确认哪些名字是真的说话人（避免把「注意：」这类正文当成人名）
//   3. 按别名判断哪一边是我（用户/我/User…）、哪一边是 AI（DeepSeek/GPT/助手…）

/// 说话人归类结果
const String kMe = 'me';       // 我
const String kAi = 'ai';       // AI / 模型
const String kOther = 'other'; // 其他角色

class ChatMsg {
  final String speaker, content, time;
  ChatMsg(this.speaker, this.content, this.time);

  @override
  String toString() => '[$speaker] $content';
}

/// 解析结果
class ParsedChatLog {
  bool isChat = false;
  List<ChatMsg> msgs = [];

  /// 真正的说话人（已去掉元信息标签），按首次出现顺序
  List<String> speakers = [];
  Map<String, int> counts = {};

  /// 判定为「我」的说话人，空字符串表示判断不出来（UI 再问用户）
  String meSpeaker = '';

  /// 判定为 AI 的说话人
  String aiSpeaker = '';

  /// 「我」在 speakers 里的下标，-1 = 未确定
  int get meIndex {
    if (meSpeaker.isEmpty) return -1;
    final i = speakers.indexOf(meSpeaker);
    if (i >= 0) return i;
    return speakers.isEmpty ? -1 : 0;
  }

  bool get hasTwoSides => speakers.length == 2;

  /// 判断已经明确（可以直接分左右）
  bool get rolesKnown => meSpeaker.isNotEmpty;

  int get mineCount => meIndex < 0 ? 0 : (counts[speakers[meIndex]] ?? 0);
  int get aiCount => meIndex < 0
      ? msgs.length
      : msgs.where((m) => m.speaker != speakers[meIndex]).length;
}

// ---------------------------------------------------------------- 别名表

/// 导出记录里表示「我 / 用户」的常见说法
const Set<String> meAliases = {
  '我', '本人', '用户', '用户我', '我方', '我方用户', '提问', '提问者', '提问人',
  '我提问', '玩家', '人类', 'user', 'users', 'me', 'myself', 'you', 'client', 'i',
};

/// 表示「AI / 模型」的常见说法
const Set<String> aiAliases = {
  'ai', 'ai助手', '助手', '人工智能', '模型', '大模型', '语言模型', '机器人', 'bot', 'chatbot',
  'assistant', 'llm', 'deepseek', '深度求索', 'deepseekai', 'deepseekr1', 'deepseekv3',
  'gpt', 'gpt4', 'gpt4o', 'chatgpt', 'openai', 'claude', 'anthropic', 'gemini', 'bard',
  'kimi', 'moonshot', '豆包', 'doubao', '通义', '通义千问', 'qwen', '千问',
  '文心', '文心一言', 'ernie', '星火', '讯飞星火', '智谱', 'glm', 'chatglm',
  '小婉', '猫猫', '孤猫', 'ai小助手',
};

/// 导出工具写在正文里的元信息标签 —— 不是说话人
const Set<String> metaLabels = {
  '轮数', '轮次', '总轮数', '总轮次', '轮', '消息数', '总消息数', '条数',
  '接口时间戳范围', '接口时间戳', '时间戳', '时间范围', '起止时间', '开始时间', '结束时间',
  '导出时间', '导出日期', '导出工具', '导出者', '导出', '生成时间',
  '会话', '会话标题', '会话名称', '会话id', '对话标题', '对话名', '标题',
  '模型', '模型名', '接口', '接口地址', '来源', '来源地址', '链接', '网址', 'url',
  '格式', '类型', '编号', '序号', '序号id', '统计', '字数', '总字数', '备注', '说明',
};

// ---------------------------------------------------------------- 名字清洗

final _edgeJunk = RegExp(
    r'''^[\s\*_`"'《》〈〉\[\]【】()（）<>·•#,，、：:]+|[\s\*_`"'《》〈〉\[\]【】()（）<>·•#,，、：:]+$''');

/// 去掉包裹符号、空白，让「【用户】」「**用户**」「用户：」「用户(我)」都归一成「用户」
String cleanName(String s) {
  var t = s.trim();
  for (var i = 0; i < 3; i++) {
    final n = t.replaceAll(_edgeJunk, '');
    if (n == t) break;
    t = n;
  }
  t = t.replaceAll(RegExp(r'\s+'), '');
  t = t.replaceAll(RegExp(r'^[：:]+|[：:]+$'), '');
  return t;
}

/// 名字是否像一个说话人（不是句子、不是整段正文、不是时间戳）
bool isSpeakerName(String? s) {
  if (s == null) return false;
  final t = cleanName(s);
  if (t.isEmpty || t.length > 18) return false;
  if (RegExp(r'[。！？!?，,；;、…~～—：:]').hasMatch(t)) return false;
  if (RegExp(r'^第.{1,6}[章卷节回]').hasMatch(t)) return false;
  if (RegExp(r'^\d+$').hasMatch(t)) return false;
  if (RegExp(r'\d{2}:\d{2}').hasMatch(t)) return false;
  if (RegExp(r'\d{4}[-/年]\d{1,2}').hasMatch(t)) return false;
  if (RegExp(r'^(https?|www)').hasMatch(t.toLowerCase())) return false;
  return true;
}

/// 兼容旧接口
bool isSpeaker(String? s) => isSpeakerName(s);

/// 名字属于哪一边
String speakerKind(String? name) {
  final t = cleanName(name ?? '').toLowerCase();
  if (t.isEmpty) return kOther;
  if (meAliases.contains(t)) return kMe;
  if (aiAliases.contains(t)) return kAi;
  // 「DeepSeek-V3」「GPT-4o」「Claude 3.5」这类带版本号的写法
  if (RegExp(r'^(deepseek|gpt|chatgpt|claude|gemini|bard|qwen|kimi|moonshot|doubao|glm|chatglm|ernie|llama|copilot|grok|ollama)')
      .hasMatch(t)) {
    return kAi;
  }
  if (RegExp(r'(ai助手|助手ai|机器人|大模型)$').hasMatch(t)) return kAi;
  return kOther;
}

bool isMetaLabel(String? s) {
  final t = cleanName(s ?? '').toLowerCase();
  if (t.isEmpty) return false;
  if (metaLabels.contains(t)) return true;
  // 「接口时间戳范围」「本轮消息数」这类组合标签
  if (t.length <= 12 && RegExp(r'(时间|轮数|轮次|时间戳)').hasMatch(t)) return true;
  if (t.length <= 12 && RegExp(r'^(接口|导出|会话|消息|统计).{1,8}$').hasMatch(t)) return true;
  return false;
}

// ---------------------------------------------------------------- 行识别

/// 分隔线 / 轮次标记：===== 第 1 轮 =====、----、****、=== Round 3 ===
bool _isRule(String line) {
  if (RegExp(r'^[-=＝—_*·~#.]{4,}$').hasMatch(line)) return true;
  if (RegExp(r'^[=\-—＝*·_~\s]{0,8}第\s*[0-9一二三四五六七八九十百千零]+\s*[轮次级回合段篇][=\-—＝*·_~\s]{0,8}$')
      .hasMatch(line)) {
    return true;
  }
  if (RegExp(r'^[=\-—＝*·_~\s]{0,8}(round|turn)\s*\d+[=\-—＝*·_~\s]{0,8}$',
      caseSensitive: false).hasMatch(line)) {
    return true;
  }
  return false;
}

bool _isMeta(String line) {
  final m = RegExp(r'^【(.{1,20}?)】').firstMatch(line);
  if (m != null && isMetaLabel(m.group(1))) return true;
  final m2 = RegExp(r'^([^：:]{1,20}?)\s*[：:]').firstMatch(line);
  if (m2 != null && isMetaLabel(m2.group(1))) return true;
  return false;
}

bool _looksTime(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 40) return false;
  return RegExp(r'^(\d{4}[-/年]\d{1,2}[-/月]\d{1,2}日?)?[\sT]*\d{1,2}:\d{2}(:\d{2})?$')
          .hasMatch(t) ||
      RegExp(r'\d{1,2}:\d{2}').hasMatch(t);
}

final _reBracketTime = RegExp(r'^\[([^\]]{2,40})\]\s*(.*)$');
final _reBr = RegExp(r'^【(.{1,18}?)】\s*[：:]?\s*(.*)$');
final _reColon = RegExp(r'^(.{1,18}?)\s*[：:]\s*(.*)$');
final _reTrailTime =
    RegExp(r'^(.{1,18}?)\s+((?:\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+)?\d{1,2}:\d{2}(?::\d{2})?)\s*$');
final _reArrow = RegExp(r'^(.{1,18}?)\s*[>＞]\s*(.*)$');

class _Hit {
  final String name, body, time;
  _Hit(this.name, this.body, this.time);
}

/// 拆一行：返回「谁 + 说了什么」，拆不出来返回 null
_Hit? _splitLine(String line0) {
  var line = line0.trim();
  var time = '';
  final mt = _reBracketTime.firstMatch(line);
  if (mt != null && _looksTime(mt.group(1)!)) {
    time = mt.group(1)!.trim();
    line = (mt.group(2) ?? '').trim();
  }
  if (line.isEmpty) return null;

  var m = _reBr.firstMatch(line);
  if (m != null) {
    final n = cleanName(m.group(1)!);
    if (isSpeakerName(n)) return _Hit(n, (m.group(2) ?? '').trim(), time);
  }
  // 「用户 2026-11-13 05:09:19」这种名字后面跟时间的写法要先试，
  // 否则会被下面的冒号规则切出「用户2026-11-13 05」这种怪名字
  m = _reTrailTime.firstMatch(line);
  if (m != null && !m.group(1)!.contains(RegExp(r'[：:]'))) {
    final n = cleanName(m.group(1)!);
    if (isSpeakerName(n)) return _Hit(n, '', m.group(2)!.trim());
  }
  m = _reColon.firstMatch(line);
  if (m != null) {
    final n = cleanName(m.group(1)!);
    if (isSpeakerName(n)) return _Hit(n, (m.group(2) ?? '').trim(), time);
  }
  m = _reArrow.firstMatch(line);
  if (m != null) {
    final n = cleanName(m.group(1)!);
    if (isSpeakerName(n)) return _Hit(n, (m.group(2) ?? '').trim(), time);
  }
  // DeepSeek 分享页/网页复制出来的格式：说话人单独占一行，正文在下面几行
  //   我
  //   你好呀
  //   DeepSeek
  //   你好！……
  final bare = cleanName(line);
  if (bare.length <= 10 && isSpeakerName(bare) && speakerKind(bare) != kOther) {
    return _Hit(bare, '', time);
  }
  return null;
}

// ---------------------------------------------------------------- 主解析

ParsedChatLog parseChatLog(String text) {
  final res = ParsedChatLog();
  final lines = <String>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    lines.add(l);
  }

  // —— 第一遍：统计每个「疑似名字」出现了几次 ——
  // 只把重复出现（或本身是 我/用户/AI 别名）的名字当真说话人，
  // 这样正文里的「注意：」「温馨提示：」不会被误切成人名。
  final seen = <String, int>{};
  var valid = 0;
  for (final l in lines) {
    if (_isRule(l) || _isMeta(l)) continue;
    valid++;
    final hit = _splitLine(l);
    if (hit != null) seen[hit.name] = (seen[hit.name] ?? 0) + 1;
  }

  // 谁是真正的说话人
  final cands = seen.keys.toList();
  final aliasCands = cands.where((n) => speakerKind(n) != kOther).toList();
  final known = <String>{};
  if (aliasCands.length >= 2) {
    // 已经认出「我」和「AI」两边了（【用户】/【DeepSeek】这种），
    // 就只认这几个名字 —— 否则 AI 正文里的面板行「压力值：3386」「【当前面板】」
    // 会被切成一堆假说话人，一条回复碎成几百条。
    known.addAll(aliasCands.take(6));
  } else if (aliasCands.length == 1) {
    // 只认出一边，另一边多半是一个角色名：补出现次数最多的那个
    known.add(aliasCands.first);
    final rest = cands
        .where((n) => n != aliasCands.first && (seen[n] ?? 0) >= 2)
        .toList()
      ..sort((a, b) => (seen[b] ?? 0).compareTo(seen[a] ?? 0));
    if (rest.isNotEmpty) known.add(rest.first);
  } else {
    // 谁都不认识（纯对白式记录）：按重复次数取，最多 12 个，避免整段正文被切碎
    final rest = cands.where((n) => (seen[n] ?? 0) >= 2).toList()
      ..sort((a, b) => (seen[b] ?? 0).compareTo(seen[a] ?? 0));
    known.addAll(rest.take(12));
  }

  // —— 第二遍：真正切消息 ——
  final speakers = <String>[];
  final counts = <String, int>{};
  String curSpeaker = '', curBody = '', curTime = '';
  var matched = 0;

  void flush() {
    final body = curBody.trim();
    if (curSpeaker.isEmpty || body.isEmpty) return;
    res.msgs.add(ChatMsg(curSpeaker, body, curTime));
  }

  for (final l in lines) {
    if (_isRule(l) || _isMeta(l)) continue;
    final hit = _splitLine(l);
    if (hit != null && known.contains(hit.name)) {
      flush();
      matched++;
      if (!counts.containsKey(hit.name)) speakers.add(hit.name);
      counts[hit.name] = (counts[hit.name] ?? 0) + 1;
      curSpeaker = hit.name;
      curBody = hit.body;
      curTime = hit.time;
    } else if (curSpeaker.isNotEmpty) {
      curBody = curBody.isEmpty ? l : '$curBody\n$l';
    }
  }
  flush();

  res.speakers = speakers;
  res.counts = counts;
  // 一个说话人都没有时也算不上聊天记录；正文（每句台词平均几十行）的文稿不算
  res.isChat = matched >= 3 && speakers.length >= 2 && valid <= matched * 41;

  // —— 第三遍：判断哪一边是我、哪一边是 AI ——
  String most(List<String> l) => l.isEmpty
      ? ''
      : l.reduce((a, b) => (counts[b] ?? 0) > (counts[a] ?? 0) ? b : a);

  final meCands = <String>[], aiCands = <String>[];
  for (final sp in speakers) {
    final k = speakerKind(sp);
    if (k == kMe) meCands.add(sp);
    if (k == kAi) aiCands.add(sp);
  }
  res.meSpeaker = most(meCands);
  res.aiSpeaker = most(aiCands);

  if (speakers.length == 2) {
    // 一边认出来了，另一边自然就是对面
    if (res.meSpeaker.isEmpty && res.aiSpeaker.isNotEmpty) {
      res.meSpeaker = speakers.firstWhere((s) => s != res.aiSpeaker);
    }
    if (res.aiSpeaker.isEmpty && res.meSpeaker.isNotEmpty) {
      res.aiSpeaker = speakers.firstWhere((s) => s != res.meSpeaker);
    }
  }
  if (res.meSpeaker.isEmpty && aiCands.isNotEmpty && speakers.length > 2) {
    // 多人记录里 AI 明确，但我没认出来 —— 留给 UI 问用户
    res.aiSpeaker = most(aiCands);
  }
  return res;
}
