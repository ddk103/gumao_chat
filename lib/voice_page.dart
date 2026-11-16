// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-61C9
// 孤猫聊天 · 语音与朗读：离线多角色语音包 + 通用语音输入弹层
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'speech.dart';
import 'store.dart';
import 'ui.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});
  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  Map<String, dynamic> _caps = {};
  List<Map<String, dynamic>> _voices = [];
  bool _loading = true;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final caps = await Speech.I.check();
    await Speech.I.refreshVoices();
    if (!mounted) return;
    setState(() {
      _caps = caps;
      _voices = Speech.I.voicePacks;
      _loading = false;
    });
  }

  Future<void> _recheck() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _tryPack(Map<String, dynamic> v) async {
    final person = v['person'] is num ? (v['person'] as num).toInt() : 13;
    final male = v['gender'] == 'male';
    if (v['installed'] != true && v['status'] == 'GA') {
      if (mounted) {
        snackbar(context, '音色 $person 尚未安装；内置男声已可直接使用',
            icon: Icons.volume_up_outlined);
      }
      return;
    }
    try {
      await Speech.I.speak(
        '你好，这是音色 $person 的试听，由系统离线引擎合成。',
        roleById(male ? 'man' : 'narrator'),
        personOverride: person,
        maleOverride: male,
      );
      if (mounted) snackbar(context, '正在试听音色 $person', icon: Icons.volume_up_outlined);
    } catch (e) {
      if (mounted) snackbar(context, '这个音色还没下载，试听已自动回退到内置音色');
    }
  }

  Future<void> _save() async {
    await Store.I.saveCfg();
    if (mounted) setState(() {});
  }

  Future<void> _tryRole(VoiceRole r) async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await Speech.I.speak('你好，我是${r.name}。这段声音由系统离线引擎合成，不联网也能朗读。', r);
      if (mounted) snackbar(context, '正在试听「${r.name}」', icon: Icons.volume_up_outlined);
    } on PlatformException catch (e) {
      if (mounted) snackbar(context, e.message ?? '这台设备暂时无法合成语音');
    } catch (e) {
      if (mounted) snackbar(context, '试听失败：$e');
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal();
    final c = Store.I.cfg;
    final asrOk = _caps['asr'] == true;
    final ttsOk = _caps['tts'] == true;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: fancyAppBar('语音与朗读', actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20),
            tooltip: '重新检测 / 重置下载', onPressed: _recheck),
      ]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        glowBanner(
          title: Platform.isAndroid ? '朗读 · 语音输入' : '离线语音 · 不耗流量',
          subtitle: Platform.isAndroid
              ? '用手机自带的语音引擎朗读，语音输入支持系统识别 / 录音转录'
              : '中文识别 + 男女多音色合成，飞行模式也能朗读',
          trailing: const Icon(Icons.graphic_eq, size: 54, color: Colors.white70),
          height: 108,
        ),
        const SizedBox(height: 14),

        // —— 引擎状态 ——
        SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            gradientIcon(const Icon(Icons.memory, color: Colors.white, size: 19),
                [p.grad.first, p.grad.last], size: 36),
            const SizedBox(width: 10),
            Expanded(child: Text('语音引擎', style: TextStyle(
                color: p.ink, fontSize: 15, fontWeight: FontWeight.bold))),
            if (_loading) const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 12),
          _statusLine(Platform.isAndroid ? '语音识别' : '离线语音识别',
              asrOk ? (Platform.isAndroid ? '已就绪 · 系统识别' : '已就绪 · 中文离线')
                  : '本设备不可用', asrOk, p),
          _statusLine(Platform.isAndroid ? '语音合成（朗读）' : '离线语音合成',
              ttsOk ? (Platform.isAndroid ? '已就绪 · 系统引擎' : '已就绪 · 多音色')
                  : '本设备不可用', ttsOk, p),
          _statusLine('男声音色', Speech.I.maleInstalled
              ? '自然男声 · 音色 ${c.malePerson > 0 ? c.malePerson : Speech.I.malePerson}'
              : (_loading ? '正在检测…' : '内置男声 · 无需下载'),
              true, p),
          _statusLine('在线转录兜底', c.apiKey.isEmpty ? '未填 API Key' : '已配置接口',
              c.apiKey.isNotEmpty, p),
          const SizedBox(height: 8),
          Text((_caps['note'] ?? '正在检测设备语音能力…').toString(),
              style: TextStyle(color: p.muted, fontSize: 11.5, height: 1.5)),
          if (!ttsOk) ...[
            const SizedBox(height: 6),
            Text(Platform.isAndroid
                    ? '提示：安卓的朗读用的是手机自带的语音引擎。若显示不可用，请到「设置 →'
                        ' 语言和输入法（或 无障碍）→ 文字转语音」选择并安装中文语音数据，'
                        '或安装「讯飞语音+」「Google 语音服务」后再回到这里点右上角重新检测。'
                    : '提示：系统男声音色包需通过华为语音服务下载，部分设备/模拟器的下载服务不可用；'
                        '内置男声不依赖它，照常可用。',
                style: TextStyle(color: p.muted, fontSize: 11, height: 1.5)),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('打开系统「文字转语音」设置', style: TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: p.primaryD, side: BorderSide(color: p.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  final ok = await Speech.I.openTtsSettings();
                  if (!context.mounted) return;
                  if (!ok) {
                    snackbar(context,
                        '打不开系统设置，请手动到「设置 → 文字转语音」里安装中文语音数据');
                  }
                },
              )),
            ],
          ],
        ])),
        const SizedBox(height: 16),



        // —— 内置角色语音包 ——
        Row(children: [
          Text('离线多角色语音包', style: TextStyle(
              color: p.primaryD, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('${VOICE_ROLES.length} 款 · 男声 $maleRoleCount 款',
              style: TextStyle(color: p.muted, fontSize: 11)),
          const Spacer(),
          Text('点 ▶ 试听', style: TextStyle(color: p.muted, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        for (final r in VOICE_ROLES.where((r) => !r.isMale)) _roleCard(r, p),
        const SizedBox(height: 16),

        // —— 全局朗读参数 ——
        Text('朗读参数', style: TextStyle(
            color: p.primaryD, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SCard(child: Column(children: [
          _slider('语速', c.voiceSpeed, 0.5, 1.8, p, (v) { c.voiceSpeed = v; _save(); }),
          _slider('音调', c.voicePitch, 0.5, 1.8, p, (v) { c.voicePitch = v; _save(); }),
          _slider('音量', c.voiceVolume, 0.2, 1.6, p, (v) { c.voiceVolume = v; _save(); }),
          const Divider(height: 14),
          _slider('角色差异', c.voiceCharacter, 0.0, 1.0, p,
              (v) { c.voiceCharacter = v; _save(); }, suffix: ''),
          _slider('男声低沉', c.maleDepth, 0.0, 1.0, p,
              (v) { c.maleDepth = v; _save(); }, suffix: ''),
          const SizedBox(height: 4),
          Text('觉得发闷、发飘或像变速带：把「角色差异」拉到 0 就是完全自然原声，'
              '或把「男声低沉」调小。想更明显的角色感再往右拉。',
              style: TextStyle(color: p.muted, fontSize: 11, height: 1.5)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.healing_outlined, size: 16),
            label: const Text('恢复自然原声（不变调不变速）',
                style: TextStyle(fontSize: 12.5)),
            style: OutlinedButton.styleFrom(
                foregroundColor: p.primaryD, side: BorderSide(color: p.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              c.voiceCharacter = 0;
              c.maleDepth = 0;
              c.voiceSpeed = 1.0;
              c.voicePitch = 1.0;
              c.voiceVolume = 1.0;
              await _save();
              if (context.mounted) {
                snackbar(context, '已恢复自然原声', icon: Icons.check_circle_outline);
              }
            },
          )),
          const Divider(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('朗读时按角色自动换音色',
                style: TextStyle(color: p.ink, fontSize: 13.5)),
            subtitle: Text('旁白 / 对白 / 不同人物自动分配，关闭则全程用默认角色',
                style: TextStyle(color: p.muted, fontSize: 11)),
            value: c.multiRole,
            activeThumbColor: p.primary,
            onChanged: (v) { c.multiRole = v; _save(); },
          ),
        ])),
        const SizedBox(height: 16),

        // —— 识别与兜底 ——
        Text('语音输入', style: TextStyle(
            color: p.primaryD, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('优先用系统离线识别；设备不支持或没听清时，把录音发到你配置的接口转录。',
              style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: gradientButton(
              '测试语音输入', Icons.mic_none, () async {
            final t = await showVoiceInput(context);
            if (t != null && t.isNotEmpty && context.mounted) {
              snackbar(context, '识别结果：$t', icon: Icons.check_circle_outline);
            }
          })),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: c.sttModel)..selection =
                TextSelection.collapsed(offset: c.sttModel.length),
            style: TextStyle(color: p.ink, fontSize: 13),
            decoration: InputDecoration(labelText: '转录模型（默认 whisper-1）',
                labelStyle: TextStyle(color: p.muted, fontSize: 12), isDense: true),
            onChanged: (v) => c.sttModel = v.trim(),
            onEditingComplete: _save,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: c.sttUrl)..selection =
                TextSelection.collapsed(offset: c.sttUrl.length),
            style: TextStyle(color: p.ink, fontSize: 13),
            decoration: InputDecoration(labelText: '转录接口完整地址（留空自动推导）',
                labelStyle: TextStyle(color: p.muted, fontSize: 12), isDense: true),
            onChanged: (v) => c.sttUrl = v.trim(),
            onEditingComplete: _save,
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: gradientButton(
              '保存识别设置', Icons.save_outlined, () async {
            await _save();
            if (context.mounted) snackbar(context, '已保存', icon: Icons.check);
          }, soft: true, height: 40)),
        ])),
        const SizedBox(height: 12),

        // —— 在线朗读（OpenAI 兼容 /audio/speech）——
        Text('在线朗读（可选，音色最自然）',
            style: TextStyle(color: p.primaryD, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: c.ttsOnline,
            activeThumbColor: p.primary,
            title: Text('开启在线朗读', style: TextStyle(color: p.ink, fontSize: 14.5)),
            subtitle: Text('开启后朗读与试听走在线合成，男声/女声都自然；失败会自动退回系统语音',
                style: TextStyle(color: p.muted, fontSize: 11.5, height: 1.4)),
            onChanged: (v) async {
              setState(() => c.ttsOnline = v);
              await _save();
              if (v && c.ttsUrl.trim().isEmpty) {
                if (context.mounted) snackbar(context, '记得填下面的接口地址，否则会用「接口地址」自动推导');
              }
            },
          ),
          if (c.ttsOnline) ...[
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: c.ttsUrl)
                ..selection = TextSelection.collapsed(offset: c.ttsUrl.length),
              style: TextStyle(color: p.ink, fontSize: 13),
              decoration: const InputDecoration(
                  labelText: '合成接口地址（留空 = 由对话接口推导 /audio/speech）'),
              onChanged: (v) => c.ttsUrl = v.trim(),
            ),
            TextField(
              controller: TextEditingController(text: c.ttsModel)
                ..selection = TextSelection.collapsed(offset: c.ttsModel.length),
              style: TextStyle(color: p.ink, fontSize: 13),
              decoration: const InputDecoration(labelText: '合成模型（如 tts-1 / fishaudio）'),
              onChanged: (v) => c.ttsModel = v.trim(),
            ),
            Row(children: [
              Expanded(child: TextField(
                controller: TextEditingController(text: c.ttsVoice)
                  ..selection = TextSelection.collapsed(offset: c.ttsVoice.length),
                style: TextStyle(color: p.ink, fontSize: 13),
                decoration: const InputDecoration(labelText: '女声 voice'),
                onChanged: (v) => c.ttsVoice = v.trim(),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: TextEditingController(text: c.ttsVoiceAlt)
                  ..selection = TextSelection.collapsed(offset: c.ttsVoiceAlt.length),
                style: TextStyle(color: p.ink, fontSize: 13),
                decoration: const InputDecoration(labelText: '其他角色 voice'),
                onChanged: (v) => c.ttsVoiceAlt = v.trim(),
              )),
            ]),
            const SizedBox(height: 6),
            Text('用的是「我的 → API 与模型」里填的 Key；接口需兼容 OpenAI 的 /audio/speech。'
                '常见：硅基流动 …/v1/audio/speech（cosyvoice / fishaudio），OpenAI …/v1/audio/speech（tts-1）。',
                style: TextStyle(color: p.muted, fontSize: 11, height: 1.5)),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('保存在线朗读设置', style: TextStyle(fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: p.primaryD, side: BorderSide(color: p.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _save,
            )),
          ],
        ])),
        const SizedBox(height: 16),
        // —— 系统音色包清单 ——
        if (_voices.isNotEmpty) ...[
          Text('系统音色包清单', style: TextStyle(
              color: p.primaryD, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SCard(child: Column(children: [
            for (final v in _voices)
              ListTile(dense: true, contentPadding: EdgeInsets.zero,
                onTap: () => _tryPack(v),
                leading: Icon(v['gender'] == 'male' ? Icons.male : Icons.female,
                    size: 19, color: v['gender'] == 'male' ? p.primary : p.muted),
                title: Text('${v['description'] ?? '系统音色'} · 音色 ${v['person']}',
                    style: TextStyle(color: p.ink, fontSize: 12.5)),
                subtitle: Text(
                    '${v['gender'] == 'male' ? '男声' : '女声'} · ${_packStatus(v['status'])} · ${v['language']} · 点按试听',
                    style: TextStyle(color: p.muted, fontSize: 10.5)),
                trailing: Icon(Icons.play_circle_outline, size: 18, color: p.primary),
              ),
          ])),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  String _packStatus(dynamic s) {
    switch (s.toString().toUpperCase()) {
      case 'INSTALLED':
        return '已安装';
      case 'GA':
        return '可下载';
      case 'EOM':
        return '不可用';
      default:
        return '内置 / 状态未知';
    }
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(
        color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _statusLine(String label, String value, bool ok, Pal p) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 15, color: ok ? p.primary : p.muted),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: p.ink, fontSize: 12.5)),
      const Spacer(),
      Text(value, style: TextStyle(color: ok ? p.primaryD : p.muted, fontSize: 11.5)),
    ]),
  );

  Widget _roleCard(VoiceRole r, Pal p) {
    final selected = Store.I.cfg.voiceRole == r.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SCard(
        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () { Store.I.cfg.voiceRole = r.id; _save(); },
        child: Row(children: [
          gradientIcon(Text(r.emoji, style: const TextStyle(fontSize: 19)),
              [Color(r.c1), Color(r.c2)], size: 42, radius: 12),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(r.name, style: TextStyle(color: p.ink, fontSize: 14,
                  fontWeight: FontWeight.w600)),
              if (r.isMale) _tag('♂ 男声', p.primarySoft, p.primaryD),
              if (r.isMale && !Speech.I.maleInstalled && Store.I.cfg.malePerson <= 0)
                _tag('内置', p.primarySoft, p.primaryD),
              if (selected) _tag('默认', p.primarySoft, p.primaryD),
            ]),
            const SizedBox(height: 3),
            Text(r.desc, style: TextStyle(color: p.muted, fontSize: 11)),
          ])),
          GestureDetector(
            onTap: () => _tryRole(r),
            child: Container(width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(r.c1), Color(r.c2)]),
                shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 19)),
          ),
        ]),
      ),
    );
  }

  Widget _slider(String label, double val, double min, double max, Pal p,
      void Function(double) onChanged, {String suffix = 'x'}) => Row(children: [
    SizedBox(width: 54, child: Text(label, style: TextStyle(color: p.ink, fontSize: 12.5))),
    Expanded(child: Slider(
      value: val.clamp(min, max), min: min, max: max,
      activeColor: p.primary, inactiveColor: p.line,
      onChanged: (v) { onChanged(v); setState(() {}); },
    )),
    SizedBox(width: 38, child: Text('${val.toStringAsFixed(2)}$suffix',
        style: TextStyle(color: p.muted, fontSize: 11), textAlign: TextAlign.right)),
  ]);
}

// ---------------- 通用语音输入弹层 ----------------

/// 弹出内置语音识别，返回识别到的文字（取消返回 null）
Future<String?> showVoiceInput(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VoiceSheet(),
    );

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  String _confirmed = '', _partial = '', _hint = '正在启动麦克风…';
  String _mode = '';
  bool _recording = false, _busy = false;

  String get _text => (_confirmed + _partial).trim();

  @override
  void initState() {
    super.initState();
    Speech.I.addListener(_onEvent);
    _start();
  }

  @override
  void dispose() {
    Speech.I.removeListener(_onEvent);
    _pulse.dispose();
    if (_recording) Speech.I.cancelAsr();
    super.dispose();
  }

  void _onEvent(String type, Map<String, dynamic> d) {
    if (!mounted) return;
    switch (type) {
      case 'asrState':
        final st = (d['state'] ?? '').toString();
        setState(() {
          _hint = st == 'listening' ? '正在听，说话吧…'
              : st == 'speaking' ? '听到声音了，继续说'
              : st == 'recordOnly' ? '正在录音（本机无离线识别，稍后自动转录）'
              : st == 'silence' ? '等你继续说…' : '准备就绪';
        });
        break;
      case 'asrText':
        final t = (d['text'] ?? '').toString();
        setState(() {
          if (d['final'] == true) { _confirmed += t; _partial = ''; }
          else { _partial = t; }
        });
        break;
      case 'asrDone':
        final t = (d['text'] ?? '').toString();
        if (t.isNotEmpty && _text.isEmpty) setState(() => _confirmed = t);
        break;
      case 'asrError':
        setState(() => _hint = '识别出错：${d['message'] ?? ''}');
        break;
      case 'ttsState':
      case 'asrRecorded':
        break;
    }
  }

  Future<void> _start() async {
    try {
      _mode = await Speech.I.startAsr();
      _recording = true;
      if (mounted) {
        setState(() => _hint = _mode == 'offline'
            ? '离线识别已开启，说话吧…'
            : _mode == 'system' ? '已打开系统语音输入，说完自动返回'
            : '本机无离线引擎，正在录音…');
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _hint = e.message ?? '无法启动麦克风');
    } catch (e) {
      if (mounted) setState(() => _hint = '无法启动麦克风：$e');
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (_recording) {
      try { await Speech.I.stopAsr(); } catch (_) {}
      _recording = false;
    }
    // 等离线识别把最后一句送回来
    await Future.delayed(const Duration(milliseconds: 700));
    var result = _text;
    if (result.isEmpty && Speech.I.lastWav.isNotEmpty) {
      setState(() => _hint = '正在用你的接口转录录音…');
      try {
        result = await Speech.I.transcribeOnline(Speech.I.lastWav);
      } catch (e) {
        if (mounted) {
          setState(() { _hint = '$e'; _busy = false; });
        }
        return;
      }
    }
    if (!mounted) return;
    if (result.isEmpty) {
      setState(() { _hint = '没听清，再试一次吧'; _busy = false; });
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal();
    return SafeArea(child: Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 38, height: 4,
            decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('语音输入', style: TextStyle(color: p.ink, fontSize: 16,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_mode == 'offline' ? '系统离线识别 · 不联网'
            : _mode == 'system' ? '系统语音输入'
            : '内置录音 · 在线兜底转录',
            style: TextStyle(color: p.muted, fontSize: 11.5)),
        const SizedBox(height: 20),
        AnimatedBuilder(animation: _pulse, builder: (c, _) {
          final scale = _recording ? 1.0 + 0.10 * _pulse.value : 1.0;
          return Transform.scale(scale: scale, child: Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.grad), shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: p.grad.last.withValues(alpha: 0.4),
                  blurRadius: 18 + 10 * _pulse.value, offset: const Offset(0, 5))],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 38),
          ));
        }),
        const SizedBox(height: 16),
        Text(_hint, style: TextStyle(color: p.muted, fontSize: 12.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 66, maxHeight: 130),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line)),
          child: SingleChildScrollView(child: Text(
            _text.isEmpty ? '识别到的文字会显示在这里…' : _text,
            style: TextStyle(color: _text.isEmpty ? p.muted : p.ink,
                fontSize: 14, height: 1.5),
          )),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: SizedBox(height: 44, child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: p.muted)),
          ))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: SizedBox(height: 44, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: p.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _busy ? null : _finish,
            icon: _busy ? const SizedBox(width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: const Text('停止并使用文字'),
          ))),
        ]),
      ]),
    ));
  }
}
