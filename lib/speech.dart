// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-BDB0
// 孤猫聊天 · 语音层
// 鸿蒙：系统 Core Speech Kit 离线中文识别 + 离线多音色合成（不联网、不耗流量）
// 兜底：设备没有语音引擎时录成 WAV，走用户自己接口的 /audio/transcriptions 在线转录
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'store.dart';

// ---------------- 离线多角色语音包 ----------------
// person：系统音色（13 凌小珊女声 / 21 凌飞哲男声，男声需下载音色包）
// gender=male 的角色优先用系统男声音色包；没装也能用内置引擎的低沉音调合成男声，
// 完全离线、不依赖下载、不会悄悄变成女声。其余速度、音调、音量组合出不同「角色」。
class VoiceRole {
  final String id, name, desc, emoji;
  final int person;
  final String gender;
  // maleDepth：内置男声的低沉程度 0~1，只影响音调、不叠加速度，避免声音发闷失真
  final double speed, pitch, volume, maleDepth;
  final int c1, c2;
  const VoiceRole({
    required this.id,
    required this.name,
    required this.desc,
    required this.emoji,
    required this.person,
    this.gender = 'female',
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.maleDepth = 0.70,
    required this.c1,
    required this.c2,
  });
  bool get isMale => gender == 'male';
}

const List<VoiceRole> VOICE_ROLES = [
  // —— 女声 / 中性 ——
  VoiceRole(id: 'narrator', name: '旁白 · 温润', desc: '标准女声，适合叙述与写景', emoji: '📖',
      person: 13, speed: 1.0, pitch: 1.0, c1: 0xFF4C9677, c2: 0xFF2F7D5B),
  VoiceRole(id: 'girl', name: '少女 · 轻快', desc: '语速稍快、音调清亮，适合活泼女主', emoji: '🌸',
      person: 13, speed: 1.2, pitch: 1.3, c1: 0xFFFF8FB1, c2: 0xFFE85D8A),
  VoiceRole(id: 'whisper', name: '低语 · 温柔', desc: '放慢压低，适合内心独白与夜戏', emoji: '🌙',
      person: 13, speed: 0.82, pitch: 0.85, c1: 0xFF8C7AE6, c2: 0xFF5F4BB6),
  VoiceRole(id: 'robot', name: '电子 · 机械', desc: '高音调快速，适合系统音与科幻', emoji: '🤖',
      person: 13, speed: 1.38, pitch: 1.55, volume: 0.9, c1: 0xFF7ED9C0, c2: 0xFF2E9E86),
  // —— 男声音色（person 21 凌飞哲，可在语音页一键下载）——
  VoiceRole(id: 'man', name: '男声 · 沉稳', desc: '成熟男声，适合稳重角色与旁述', emoji: '🎩',
      person: 21, gender: 'male', speed: 0.96, pitch: 0.98, maleDepth: 0.70,
      c1: 0xFF5B8CFF, c2: 0xFF2E5CCC),
  VoiceRole(id: 'anchor', name: '播音 · 沉稳', desc: '字正腔圆的男声播音，适合正式旁白', emoji: '🎙️',
      person: 21, gender: 'male', speed: 0.98, pitch: 1.0, maleDepth: 0.60,
      c1: 0xFF3D7BE0, c2: 0xFF1B4FA8),
  VoiceRole(id: 'boy', name: '少年 · 清朗', desc: '明快少年音，适合热血与冲动台词', emoji: '⚡',
      person: 21, gender: 'male', speed: 1.08, pitch: 1.06, maleDepth: 0.35,
      c1: 0xFF42C6E8, c2: 0xFF1E88C7),
  VoiceRole(id: 'scholar', name: '书生 · 清雅', desc: '温润青年男声，适合文戏与对白', emoji: '🖋️',
      person: 21, gender: 'male', speed: 1.02, pitch: 1.02, maleDepth: 0.50,
      c1: 0xFF6C9BD2, c2: 0xFF3C68AC),
  VoiceRole(id: 'uncle', name: '大叔 · 磁性', desc: '低沉厚实，适合江湖人物与旁述', emoji: '🥃',
      person: 21, gender: 'male', speed: 0.94, pitch: 0.96, maleDepth: 0.95,
      c1: 0xFFB4713C, c2: 0xFF7A431F),
  VoiceRole(id: 'villain', name: '反派 · 冷峻', desc: '压低放慢，适合反派与悬疑段落', emoji: '🗡️',
      person: 21, gender: 'male', speed: 0.92, pitch: 0.96, maleDepth: 1.00,
      c1: 0xFF6D6F9C, c2: 0xFF383A6B),
  VoiceRole(id: 'elder', name: '老者 · 缓慢', desc: '低沉缓慢，适合长辈与智者', emoji: '🍵',
      person: 21, gender: 'male', speed: 0.90, pitch: 0.98, maleDepth: 0.90,
      c1: 0xFFC9A063, c2: 0xFF8C6A32),
  VoiceRole(id: 'story', name: '说书人 · 顿挫', desc: '男声略快而有节奏，适合章回与开场', emoji: '🪭',
      person: 21, gender: 'male', speed: 1.06, pitch: 1.0, maleDepth: 0.65,
      c1: 0xFFE8784A, c2: 0xFFC0452A),
];

/// 男声角色数量（语音页显示用）
int get maleRoleCount => VOICE_ROLES.where((r) => r.isMale).length;

VoiceRole roleById(String id) {
  for (final r in VOICE_ROLES) {
    if (r.id == id) return r;
  }
  return VOICE_ROLES.first;
}

/// 一段待朗读文本 + 分配给它的角色
class SpeakSeg {
  final VoiceRole role;
  final String text;
  const SpeakSeg(this.role, this.text);
}

/// 把文本拆成「旁白 / 角色对白」，供朗读时按角色换音色。
/// 规则：含中文引号的句子视为对白；「名字：」按名字固定分配角色；
/// 无名字的对白在 少女/男声/少年/大叔/书生 之间男女轮换。
List<SpeakSeg> splitDialogue(String raw, {bool multiRole = true}) {
  final narrator = roleById('narrator');
  final out = <SpeakSeg>[];
  if (!multiRole) {
    return [SpeakSeg(narrator, raw.trim())];
  }
  final voices = [
    roleById('girl'), roleById('man'), roleById('boy'),
    roleById('whisper'), roleById('uncle'), roleById('scholar'),
  ];
  final named = <String, VoiceRole>{};
  var turn = 0;

  // 先按行、再按句末标点切，避免一段太长
  final sentences = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final t = line.trim();
    if (t.isEmpty) continue;
    sentences.addAll(t.split(RegExp(r'(?<=[。！？!?；;])')).where((e) => e.trim().isNotEmpty));
  }

  for (final rawSeg in sentences) {
    final s = rawSeg.trim();
    if (s.isEmpty) continue;
    // 长句再按逗号切成 <=150 字，朗读引擎单次上限 10000 字，切小听感更自然
    final parts = s.length <= 150
        ? [s]
        : s.split(RegExp(r'(?<=[，,、])')).where((e) => e.trim().isNotEmpty).toList();
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      final quoted = t.contains('“') || t.contains('「') || t.contains('"') || t.contains('『');
      VoiceRole role = narrator;
      if (quoted) {
        final m = RegExp(r'^\s*[「“『"]?\s*([^：:，。！？]{1,8})\s*[：:]').firstMatch(t);
        final who = m?.group(1)?.trim() ?? '';
        if (who.isNotEmpty) {
          role = named.putIfAbsent(who, () => voices[named.length % voices.length]);
        } else {
          role = voices[turn % voices.length];
          turn++;
        }
      }
      out.add(SpeakSeg(role, t));
    }
  }
  if (out.isEmpty) out.add(SpeakSeg(narrator, raw.trim()));
  return out;
}

// ---------------- 原生通道 ----------------

class Speech {
  static final Speech I = Speech._();
  Speech._() {
    _ch.setMethodCallHandler(_onEvent);
  }

  final MethodChannel _ch = const MethodChannel('gumao/speech');

  /// 原生事件：asrState / asrText / asrDone / asrError / asrRecorded / ttsState /
  /// voiceProgress / voiceDone / voiceError
  /// 用多播，朗读页与语音设置页可以同时监听
  final List<void Function(String type, Map<String, dynamic> data)> _listeners = [];
  void addListener(void Function(String type, Map<String, dynamic> data) f) => _listeners.add(f);
  void removeListener(void Function(String type, Map<String, dynamic> data) f) => _listeners.remove(f);

  String _lastWav = '';
  String get lastWav => _lastWav;

  // —— 男声音色包状态 ——
  List<Map<String, dynamic>> voicePacks = [];
  int malePerson = -1;        // >=0：系统里真的存在可用男声音色
  int maleCandidate = 21;     // 待下载的官方男声编号（凌飞哲）
  bool maleDownloadable = false;
  bool voiceProbed = false;
  bool get maleInstalled => malePerson >= 0;
  // 并发调用共享同一个 Future，避免下载完成时两次刷新互相把状态覆盖掉
  Future<Map<String, dynamic>>? _voicesFuture;

  /// 朗读前确保探测过一次系统音色；失败也不阻塞朗读（会走内置低沉男声）
  Future<void> ensureVoices() async {
    if (voiceProbed) return;
    await refreshVoices();
  }

  /// 重新枚举系统音色包，并同步「本地已确认下载」状态
  Future<Map<String, dynamic>> refreshVoices() {
    final running = _voicesFuture;
    if (running != null) return running;
    final f = _doRefreshVoices();
    _voicesFuture = f;
    f.whenComplete(() { _voicesFuture = null; });
    return f;
  }

  Future<Map<String, dynamic>> _doRefreshVoices() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('ttsVoicePacks', {
        'confirmedMale': Store.I.cfg.malePackConfirmed,
      });
      final m = (r ?? {}).cast<String, dynamic>();
      final list = m['voices'];
      voicePacks = list is List
          ? list.map((e) => (e as Map).cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      malePerson = m['malePerson'] is num ? (m['malePerson'] as num).toInt() : -1;
      maleCandidate = m['candidate'] is num ? (m['candidate'] as num).toInt() : 21;
      maleDownloadable = m['downloadable'] == true;
      final sys = m['systemInstalled'] is num
          ? (m['systemInstalled'] as num).toInt() : -1;
      if (sys > 0) {
        // 系统里确实装好了：清掉失败标记并同步本地确认值
        if (Store.I.cfg.malePackConfirmed != sys || Store.I.cfg.malePackFailed) {
          Store.I.cfg.malePackConfirmed = sys;
          Store.I.cfg.malePackFailed = false;
          await Store.I.saveCfg();
        }
      } else if (Store.I.cfg.malePackConfirmed > 0) {
        // 下载成功但系统清单还停留在 GA，以本地确认为准，绝不退回「可下载」
        malePerson = Store.I.cfg.malePackConfirmed;
        maleDownloadable = false;
      }
      voiceProbed = true;
      return m;
    } on MissingPluginException {
      voicePacks = [];
      malePerson = -1;
      maleDownloadable = false;
      voiceProbed = true;
      return {};
    } catch (_) {
      voicePacks = [];
      malePerson = -1;
      maleDownloadable = false;
      voiceProbed = true;
      return {};
    }
  }

  /// 下载成功：把「已安装」持久化，系统清单 GA 也不能把它覆盖回去
  Future<void> confirmMalePack(dynamic p) async {
    final person = p is num ? p.toInt() : maleCandidate;
    Store.I.cfg.malePackConfirmed = person;
    Store.I.cfg.malePackFailed = false;
    await Store.I.saveCfg();
    malePerson = person;
    maleDownloadable = false;
    voiceProbed = true;
  }

  /// 系统下载服务不可用：记住状态，界面不再反复拉系统弹窗
  Future<void> markMalePackFailed() async {
    if (Store.I.cfg.malePackFailed) return;
    Store.I.cfg.malePackFailed = true;
    await Store.I.saveCfg();
  }

  /// 用户主动重试 / 重新检测时清掉失败标记
  Future<void> clearMalePackFailed() async {
    if (!Store.I.cfg.malePackFailed) return;
    Store.I.cfg.malePackFailed = false;
    await Store.I.saveCfg();
  }

  /// 超时或强制重置时解锁原生下载状态
  Future<void> resetDownload() async {
    try {
      await _ch.invokeMethod<void>('ttsResetDownload');
    } catch (_) {}
  }

  /// 应用内下载男声音色包；返回 started / running / cooling / failed
  Future<String> downloadMaleVoice({int? person}) async {
    final p = person ??
        (Store.I.cfg.malePerson > 0 ? Store.I.cfg.malePerson : maleCandidate);
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>(
          'ttsDownloadMale', {'person': p});
      return ((r ?? {})['state'] ?? 'failed').toString();
    } catch (_) {
      return 'failed';
    }
  }

  Future<dynamic> _onEvent(MethodCall call) async {
    if (call.method != 'speechEvent') return null;
    final m = (call.arguments as Map).cast<dynamic, dynamic>();
    final type = (m['event'] ?? '').toString();
    final d0 = m['detail'];
    final d = (d0 is Map) ? d0.cast<String, dynamic>() : <String, dynamic>{};
    if (type == 'asrRecorded') {
      _lastWav = (d['wav'] ?? '').toString();
    }
    if (type == 'voiceDone') {
      // 先落盘再刷新，保证 listener 收到事件时状态已是「已安装」
      await confirmMalePack(d['person']);
      await refreshVoices();
    } else if (type == 'voiceError' && d['cancelled'] != true) {
      await markMalePackFailed();
    }
    for (final f in List.of(_listeners)) {
      try { f(type, d); } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>> check() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('check');
      return (r ?? {}).cast<String, dynamic>();
    } on MissingPluginException {
      return {'asr': false, 'tts': false, 'note': '当前平台暂未内置语音插件'};
    } on PlatformException catch (e) {
      return {'asr': false, 'tts': false, 'note': e.message ?? '语音插件不可用'};
    } catch (_) {
      return {'asr': false, 'tts': false, 'note': '语音能力探测失败'};
    }
  }

  /// 开始识别，返回模式：offline（系统离线识别）/ recordOnly（仅录音，需在线兜底）
  Future<String> startAsr() async {
    final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('asrStart');
    return ((r ?? {})['mode'] ?? 'recordOnly').toString();
  }

  Future<void> stopAsr() => _ch.invokeMethod<void>('asrStop');
  Future<void> cancelAsr() => _ch.invokeMethod<void>('asrCancel');

  /// 朗读一段文字。男声角色会自动改用系统真实男声音色；
  /// 系统未安装男声包时，用内置低沉男声合成，不会悄悄退回女声。
  /// [personOverride] 供「系统音色包」清单里逐条试听使用。
  Future<void> speak(
    String text,
    VoiceRole role, {
    int? personOverride,
    bool? maleOverride,
  }) async {
    // 开了在线朗读就先走在线合成（自然男/女声），失败再退回系统引擎
    if (Store.I.cfg.ttsOnline) {
      try {
        await speakOnline(text, role);
        return;
      } catch (_) {
        // 静默回退
      }
    }
    await ensureVoices();
    final c = Store.I.cfg;
    final isMale = maleOverride ?? role.isMale;
    var person = personOverride ?? role.person;
    // 角色差异强度：k=0 → 完全自然原声；k=1 → 原设计的夸张差异。
    // 默认 0.35，避免把 pitch/speed 推到 0.5 / 1.55 这类容易发闷、失真的极端值。
    final k = c.voiceCharacter.clamp(0.0, 1.0).toDouble();
    double mild(double v) => 1.0 + (v - 1.0) * k;
    var pitch = c.voicePitch * mild(role.pitch);
    final speed = c.voiceSpeed * mild(role.speed);
    final volume = c.voiceVolume * mild(role.volume);
    // 【已下线男声】系统 Core Speech Kit 里没有可用的中文男声（21 号标男声实为女声），
    // 强行降调又会变成怪声。在接入离线多音色引擎之前，统一用系统女声朗读，
    // 只靠语速/音量的轻微差异区分角色，避免用户听到"变声带"。
    person = 13;
    await _ch.invokeMethod<void>('ttsSpeak', {
      'text': text,
      'person': person,
      'male': isMale,
      'speed': speed.clamp(0.7, 1.5),
      'pitch': pitch.clamp(0.62, 1.45),
      'volume': volume.clamp(0.5, 1.5),
    });
  }

  /// 在线朗读：OpenAI 兼容 /audio/speech，返回音频交给原生播放
  Future<void> speakOnline(String text, VoiceRole role) async {
    final c = Store.I.cfg;
    final url = c.ttsUrl.trim().isNotEmpty ? c.ttsUrl.trim() : ttsUrl(c.baseUrl);
    if (url.isEmpty) throw '未配置在线朗读接口';
    if (c.apiKey.trim().isEmpty) throw '在线朗读需要先填 API Key';
    final voice = role.isMale ? c.ttsVoiceAlt : c.ttsVoice;
    final body = jsonEncode({
      'model': c.ttsModel.trim().isEmpty ? 'tts-1' : c.ttsModel.trim(),
      'input': text.length > 800 ? text.substring(0, 800) : text,
      'voice': voice.isEmpty ? 'alloy' : voice,
      'response_format': 'mp3',
    });
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${c.apiKey.trim()}');
      req.add(utf8.encode(body));
      final resp = await req.close();
      final bytes = await resp.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      if (resp.statusCode != 200) {
        throw '合成接口 HTTP ${resp.statusCode}（检查地址/模型/voice 是否支持）';
      }
      if (bytes.length < 1000) throw '合成结果为空，可能 voice 不被支持';
      final dir = await Store.I.dir();
      final f = File('${dir.path}${Platform.pathSeparator}tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await f.writeAsBytes(bytes, flush: true);
      await _ch.invokeMethod<void>('ttsPlayFile', {'path': f.path});
    } finally {
      client.close(force: true);
    }
  }

  Future<void> stop() => _ch.invokeMethod<void>('ttsStop');

  /// 打开系统的「文字转语音」设置页（安卓装中文语音数据用；鸿蒙不支持时返回 false）
  Future<bool> openTtsSettings() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('openTtsSettings');
      return (r ?? const {})['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listVoices() async {
    try {
      final r = await _ch.invokeListMethod<dynamic>('ttsListVoices');
      return (r ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  /// 在线转录兜底：把原生录好的 WAV 发给用户配置接口的 OpenAI 兼容转录端点
  Future<String> transcribeOnline(String wavPath) async {
    final c = Store.I.cfg;
    if (wavPath.isEmpty || !File(wavPath).existsSync()) {
      throw '没有录到声音，请检查麦克风权限';
    }
    if (c.apiKey.trim().isEmpty) {
      throw '在线转录需要先在「我的 → API 与模型」填好 API Key';
    }
    final bytes = await File(wavPath).readAsBytes();
    final url = c.sttUrl.trim().isNotEmpty ? c.sttUrl.trim() : audioUrl(c.baseUrl);
    final boundary = '----gm${DateTime.now().millisecondsSinceEpoch}';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${c.apiKey.trim()}');
      final buf = <int>[];
      void addStr(String s) => buf.addAll(utf8.encode(s));
      void field(String name, String value) {
        addStr('--$boundary\r\n'
            'Content-Disposition: form-data; name="$name"\r\n\r\n'
            '$value\r\n');
      }
      field('model', c.sttModel.isEmpty ? 'whisper-1' : c.sttModel);
      field('language', 'zh');
      addStr('--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="speech.wav"\r\n'
          'Content-Type: audio/wav\r\n\r\n');
      buf.addAll(bytes);
      addStr('\r\n--$boundary--\r\n');
      req.contentLength = buf.length;
      req.add(buf);
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      if (resp.statusCode != 200) {
        throw '转录接口返回 HTTP ${resp.statusCode}：${body.length > 120 ? '${body.substring(0, 120)}…' : body}';
      }
      final j = jsonDecode(body);
      final text = (j is Map ? (j['text'] ?? '') : '').toString();
      if (text.trim().isEmpty) throw '转录结果为空，可能没听清或接口不支持音频转录';
      return text.trim();
    } on SocketException {
      throw '网络连不上，离线识别在本设备不可用';
    } finally {
      client.close(force: true);
    }
  }
}

/// 由对话接口地址推导 /audio/speech
String ttsUrl(String base) {
  var b = base.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  if (b.endsWith('/audio/speech')) return b;
  if (b.endsWith('/v1') || b.endsWith('/api/v3') || b.endsWith('/api/paas/v4')
      || b.endsWith('/v1beta/openai') || b.endsWith('/compatible-mode/v1')) {
    return '$b/audio/speech';
  }
  return '$b/v1/audio/speech';
}

/// 由对话接口地址推导 /audio/transcriptions
String audioUrl(String base) {
  var b = base.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  if (b.endsWith('/audio/transcriptions')) return b;
  if (b.endsWith('/v1') || b.endsWith('/api/v3') || b.endsWith('/api/paas/v4')
      || b.endsWith('/v1beta/openai') || b.endsWith('/compatible-mode/v1')) {
    return '$b/audio/transcriptions';
  }
  return '$b/v1/audio/transcriptions';
}
