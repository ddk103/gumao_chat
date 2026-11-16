// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-1D82
// 孤猫聊天 · 数据层
// 配置 / 会话 / 记忆资料全部以 JSON 文件持久化在应用私有目录，不依赖任何后端。
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 截断长文本，避免把超长设定塞进 prompt
String clip(String s, int n) => s.length <= n ? s : s.substring(0, n);

/// 一条聊天消息
class Msg {
  String role; // user | assistant
  String content;
  String think; // 深度思考（reasoning_content）
  String img; // 随消息图片（本地路径，可空）
  int ts;
  Msg({required this.role, required this.content, this.think = '', this.img = '', int? ts})
      : ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (think.isNotEmpty) 'think': think,
        if (img.isNotEmpty) 'img': img,
        'ts': ts,
      };

  static Msg fromJson(dynamic m0) {
    final m = (m0 as Map).cast<String, dynamic>();
    return Msg(
      role: (m['role'] ?? 'user').toString(),
      content: (m['content'] ?? '').toString(),
      think: (m['think'] ?? '').toString(),
      img: (m['img'] ?? '').toString(),
      ts: ((m['ts'] ?? 0) as num).toInt(),
    );
  }
}

/// 一个对话会话
class Session {
  String id, title;
  int created, updated;
  List<Msg> msgs;
  Session({
    required this.id,
    this.title = '新对话',
    required this.created,
    required this.updated,
    List<Msg>? msgs,
  }) : msgs = msgs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created': created,
        'updated': updated,
        'msgs': msgs.map((m) => m.toJson()).toList(),
      };

  static Session fromJson(dynamic o0) {
    final o = (o0 as Map).cast<String, dynamic>();
    return Session(
      id: (o['id'] ?? '').toString(),
      title: (o['title'] ?? '新对话').toString(),
      created: ((o['created'] ?? 0) as num).toInt(),
      updated: ((o['updated'] ?? 0) as num).toInt(),
      msgs: ((o['msgs'] ?? []) as List).map(Msg.fromJson).toList(),
    );
  }
}

/// 全局配置
class Cfg {
  // 接口
  String baseUrl = 'https://api.deepseek.com';
  String apiKey = '';
  String model = 'deepseek-flash';
  String deepModel = 'deepseek-v4-pro';
  // 自定义第三方接口（中转站 / 自建服务 / 本地代理）
  List<Map<String, String>> customApis = [];
  // AI 身份
  String aiName = 'AI助手';
  String persona = ''; // 风格设定
  String profile = ''; // AI 资料
  int memBudget = 2400; // 记忆资料注入预算（省 token）
  bool showThinking = false; // 是否展示深度思考过程
  // 外观
  String theme = 'default'; // 主题：default/ink/weixin/dark...
  int density = 1; // 显示密度：0 宽松微信风 / 1 标准 / 2 紧凑
  String userAvatar = ''; // 我的头像（本地文件路径）
  String aiAvatar = ''; // AI 头像（本地文件路径）
  // 内置语音（离线识别 + 多角色语音包）
  String voiceRole = 'narrator'; // 默认朗读角色
  double voiceSpeed = 1.0; // 全局语速倍率 0.5~2
  double voicePitch = 1.0; // 全局音调倍率 0.5~2
  double voiceVolume = 1.0; // 全局音量倍率 0.2~2
  double voiceCharacter = 0.35; // 角色差异强度
  double maleDepth = 0.7; // 内置男声低沉度
  bool multiRole = true; // 按角色自动换音色
  int malePerson = 0; // 手动指定系统男声音色编号，0=自动探测
  int malePackConfirmed = 0; // 本机已成功装过的男声包编号
  bool malePackFailed = false; // 系统下载服务不可用，记住后不再弹窗
  String sttModel = 'whisper-1'; // 在线转录兜底模型
  String sttUrl = ''; // 在线转录完整地址（留空则由接口地址推导）
  // 在线朗读（OpenAI 兼容 /audio/speech）
  String ttsUrl = ''; // 在线朗读接口（可空）
  bool ttsOnline = false; // 开启后朗读走在线合成，失败自动退回系统
  String ttsModel = 'tts-1';
  String ttsVoice = 'alloy';
  String ttsVoiceAlt = 'onyx';
  // 隐私政策同意状态（首次启动必须弹窗同意）
  bool privacyAgreed = false;
  int privacyVersion = 0;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'deepModel': deepModel,
        'customApis': customApis,
        'aiName': aiName,
        'persona': persona,
        'profile': profile,
        'memBudget': memBudget,
        'showThinking': showThinking,
        'theme': theme,
        'density': density,
        'userAvatar': userAvatar,
        'aiAvatar': aiAvatar,
        'voiceRole': voiceRole,
        'voiceSpeed': voiceSpeed,
        'voicePitch': voicePitch,
        'voiceVolume': voiceVolume,
        'voiceCharacter': voiceCharacter,
        'maleDepth': maleDepth,
        'multiRole': multiRole,
        'malePerson': malePerson,
        'malePackConfirmed': malePackConfirmed,
        'malePackFailed': malePackFailed,
        'sttModel': sttModel,
        'sttUrl': sttUrl,
        'ttsUrl': ttsUrl,
        'ttsOnline': ttsOnline,
        'ttsModel': ttsModel,
        'ttsVoice': ttsVoice,
        'ttsVoiceAlt': ttsVoiceAlt,
        'privacyAgreed': privacyAgreed,
        'privacyVersion': privacyVersion,
      };

  static Cfg fromJson(dynamic o0) {
    final o = (o0 as Map).cast<String, dynamic>();
    final out = Cfg()
      ..baseUrl = (o['baseUrl'] ?? 'https://api.deepseek.com').toString()
      ..apiKey = (o['apiKey'] ?? '').toString()
      ..model = (o['model'] ?? 'deepseek-flash').toString()
      ..deepModel = (o['deepModel'] ?? 'deepseek-v4-pro').toString();
    // 老版本写死的模型别名已过时，自动迁移（用户自定义的名字不动）
    if (out.model == 'deepseek-chat') out.model = 'deepseek-flash';
    if (out.deepModel == 'deepseek-reasoner') out.deepModel = 'deepseek-v4-pro';
    final name = (o['aiName'] ?? '').toString();
    out.aiName = (name.isEmpty || name == '小婉') ? 'AI助手' : name;
    out.persona = (o['persona'] ?? '').toString();
    out.profile = (o['profile'] ?? '').toString();
    out.memBudget = ((o['memBudget'] ?? 2400) as num).toInt();
    out.showThinking = o['showThinking'] is bool ? o['showThinking'] as bool : false;
    out.theme = (o['theme'] ?? 'default').toString();
    out.density = ((o['density'] ?? 1) as num).toInt();
    out.userAvatar = (o['userAvatar'] ?? '').toString();
    out.aiAvatar = (o['aiAvatar'] ?? '').toString();
    out.voiceRole = (o['voiceRole'] ?? 'narrator').toString();
    out.voiceSpeed = ((o['voiceSpeed'] ?? 1.0) as num).toDouble().clamp(0.5, 2.0);
    out.voicePitch = ((o['voicePitch'] ?? 1.0) as num).toDouble().clamp(0.5, 2.0);
    out.voiceVolume = ((o['voiceVolume'] ?? 1.0) as num).toDouble().clamp(0.2, 2.0);
    out.voiceCharacter = ((o['voiceCharacter'] ?? 0.35) as num).toDouble().clamp(0.0, 1.0);
    out.maleDepth = ((o['maleDepth'] ?? 0.7) as num).toDouble().clamp(0.0, 1.0);
    out.multiRole = o['multiRole'] is bool ? o['multiRole'] as bool : true;
    out.malePerson = ((o['malePerson'] ?? 0) as num).toInt();
    out.malePackConfirmed = ((o['malePackConfirmed'] ?? 0) as num).toInt();
    out.malePackFailed = o['malePackFailed'] is bool ? o['malePackFailed'] as bool : false;
    out.sttModel = (o['sttModel'] ?? 'whisper-1').toString();
    out.sttUrl = (o['sttUrl'] ?? '').toString();
    out.ttsUrl = (o['ttsUrl'] ?? '').toString();
    out.ttsOnline = o['ttsOnline'] == true;
    out.ttsModel = (o['ttsModel'] ?? 'tts-1').toString();
    out.ttsVoice = (o['ttsVoice'] ?? 'alloy').toString();
    out.ttsVoiceAlt = (o['ttsVoiceAlt'] ?? 'onyx').toString();
    out.privacyAgreed = o['privacyAgreed'] == true;
    out.privacyVersion = ((o['privacyVersion'] ?? 0) as num).toInt();
    out.customApis = [];
    if (o['customApis'] is List) {
      for (final e in (o['customApis'] as List)) {
        if (e is Map) {
          out.customApis.add({
            'name': (e['name'] ?? '自定义接口').toString(),
            'url': (e['url'] ?? '').toString(),
            'model': (e['model'] ?? '').toString(),
            'deepModel': (e['deepModel'] ?? '').toString(),
          });
        }
      }
    }
    return out;
  }
}

/// 长期记忆资料（导入的文档 / 聊天记录，按关键词检索后注入上下文）
class Doc {
  String id, name;
  String text;
  int ts;
  List<String> chunks; // 分片缓存（检索用）
  Doc({required this.id, required this.name, required this.text, required this.ts})
      : chunks = [];

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'text': text, 'ts': ts};

  static Doc fromJson(dynamic o0) {
    final o = (o0 as Map).cast<String, dynamic>();
    return Doc(
      id: (o['id'] ?? '').toString(),
      name: (o['name'] ?? '').toString(),
      text: (o['text'] ?? '').toString(),
      ts: ((o['ts'] ?? 0) as num).toInt(),
    );
  }
}

class Store {
  Store._();
  static final Store I = Store._();

  Cfg cfg = Cfg();
  List<Session> chats = [];
  List<Doc> docs = [];
  String activeId = '';
  bool memEnabled = true;
  bool deepThink = false;

  Directory? _dir;

  Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    _dir = await getApplicationDocumentsDirectory();
    return _dir!;
  }

  File _f(Directory d, String name) =>
      File('${d.path}${Platform.pathSeparator}$name');

  /// 启动时读取全部本地数据；文件损坏时用默认值兜底，不影响启动
  Future<void> loadAll() async {
    final d = await dir();
    try {
      if (await _f(d, 'cfg.json').exists()) {
        cfg = Cfg.fromJson(jsonDecode(await _f(d, 'cfg.json').readAsString()));
      }
      if (await _f(d, 'chats.json').exists()) {
        final o = (jsonDecode(await _f(d, 'chats.json').readAsString()) as Map)
            .cast<String, dynamic>();
        chats = ((o['chats'] ?? []) as List).map(Session.fromJson).toList();
        activeId = (o['active'] ?? '').toString();
        memEnabled = o['memEnabled'] is bool ? o['memEnabled'] as bool : true;
        deepThink = o['deepThink'] is bool ? o['deepThink'] as bool : false;
      }
      if (await _f(d, 'docs.json').exists()) {
        final o = (jsonDecode(await _f(d, 'docs.json').readAsString()) as Map)
            .cast<String, dynamic>();
        docs = ((o['docs'] ?? []) as List).map(Doc.fromJson).toList();
        for (final doc in docs) {
          buildChunks(doc);
        }
      }
    } catch (_) {}
  }

  Future<void> saveCfg() async {
    final d = await dir();
    await _f(d, 'cfg.json').writeAsString(jsonEncode(cfg.toJson()));
  }

  Future<void> saveChats() async {
    final d = await dir();
    await _f(d, 'chats.json').writeAsString(jsonEncode({
      'chats': chats.map((c) => c.toJson()).toList(),
      'active': activeId,
      'memEnabled': memEnabled,
      'deepThink': deepThink,
    }));
  }

  Future<void> saveDocs() async {
    final d = await dir();
    await _f(d, 'docs.json').writeAsString(
        jsonEncode({'docs': docs.map((x) => x.toJson()).toList()}));
  }

  /// 全量备份：一份 JSON 覆盖配置 / 会话 / 记忆资料
  String backupJson() {
    return jsonEncode({
      'app': 'gumao_chat',
      'ver': 1,
      'cfg': cfg.toJson(),
      'chats': chats.map((c) => c.toJson()).toList(),
      'docs': docs.map((d) => d.toJson()).toList(),
      'activeId': activeId,
      'memEnabled': memEnabled,
      'deepThink': deepThink,
    });
  }

  Session? sessionById(String id) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Session get active =>
      sessionById(activeId) ?? (chats.isEmpty ? _newSession() : chats.first);

  Session _newSession() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = Session(id: 'c$now', created: now, updated: now);
    chats.add(s);
    activeId = s.id;
    return s;
  }

  Session newSession() {
    final s = _newSession();
    saveChats();
    return s;
  }

  /// 分片缓存：约 560 字一片、50 字重叠，方便关键词检索命中
  void buildChunks(Doc doc) {
    doc.chunks.clear();
    final t = doc.text;
    for (var i = 0; i < t.length; i += 500) {
      final end = (i + 560 > t.length) ? t.length : i + 560;
      doc.chunks.add(t.substring(i, end));
    }
  }
}
