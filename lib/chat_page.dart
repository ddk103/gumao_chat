// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-39DF
// 孤猫聊天 · 对话页（微信式气泡 / 流式输出 / 重新生成 / 导入导出 / 续聊）
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chatlog.dart';
import 'llm.dart';
import 'settings_page.dart';
import 'share_import.dart';
import 'store.dart';
import 'ui.dart';
import 'voice_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool busy = false;
  XFile? _pendingImg; // 待发送的图片
  StreamHandle? _handle;

  Session get s => Store.I.active;

  /// 把底层报错翻译成用户看得懂、知道怎么做的提示
  String friendlyErr(String e) {
    if (Store.I.cfg.apiKey.trim().isEmpty) {
      return '还没填 API Key，去「我的 → API 与模型」填好就能聊了';
    }
    if (e.contains('HTTP 401') || e.contains('HTTP 403')) {
      return 'API Key 不对或已过期，请到「我的 → API 与模型」检查';
    }
    if (e.contains('HTTP 404')) {
      return '接口地址不对（404），请检查设置里的接口网址';
    }
    if (e.contains('HTTP 429')) {
      return '请求太频繁或额度用完了（429），稍后再试';
    }
    if (e.contains('HTTP 402')) {
      return '账户余额不足（402），请给模型服务商充值';
    }
    if (RegExp(r'HTTP 5\d\d').hasMatch(e)) {
      return '模型服务暂时不可用，请稍后再试';
    }
    if (e.contains('Failed host lookup') || e.contains('SocketException')
        || e.contains('Connection refused') || e.contains('Connection timed out')) {
      return '网络连接失败，请检查网络或接口地址';
    }
    return e.length > 80 ? '${e.substring(0, 80)}…' : e;
  }

  @override
  void initState() {
    super.initState();
    if (Store.I.chats.isEmpty) Store.I.newSession();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _handle?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// 是否已经贴在最底部（用于决定要不要显示「回到底部」小按钮）
  bool _atBottom = true;
  bool _showJump = false;

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final bottom = pos.pixels >= pos.maxScrollExtent - 48;
    final jump = !bottom && s.msgs.length > 8;
    if (bottom != _atBottom || jump != _showJump) {
      setState(() {
        _atBottom = bottom;
        _showJump = jump;
      });
    }
  }

  /// 滚到最新一条。懒加载列表的总高度是估算值，连续补跳几帧直到位置稳定。
  void _jumpBottom({bool animate = false}) {
    var round = 0;
    double? last;
    void step() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final pos = _scroll.position;
        final target = pos.maxScrollExtent;
        if (animate && round == 0 && (target - pos.pixels).abs() < 1500) {
          _scroll.animateTo(target,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        } else {
          _scroll.jumpTo(target);
        }
        round++;
        final settled = last != null && (target - last!).abs() < 1;
        last = target;
        if (round < 10 && !settled) step();
      });
    }
    step();
  }

  /// 跳到最早一条。倒序列表的末端高度只能估算，连续补跳几帧尽量贴近顶部。
  void _jumpTop() {
    var round = 0;
    void step() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        round++;
        if (round < 8) step();
      });
    }
    step();
  }

  Future<void> _save() async => Store.I.saveChats();

  // ---------------- 发送 / 流式回复 / 重新生成 ----------------

  void send() {
    final q = _input.text.trim();
    final hasImg = _pendingImg != null;
    if ((q.isEmpty && !hasImg) || busy) return;
    // 还没配 API 就直接引导，不让用户对着一串报错发懵
    if (Store.I.cfg.apiKey.trim().isEmpty) {
      needApiDialog();
      return;
    }
    _input.clear();
    setState(() {
      s.msgs.add(Msg(role: 'user', content: q, img: hasImg ? _pendingImg!.path : ''));
      _pendingImg = null;
      if (s.title == '新对话') {
        s.title = q.isEmpty ? '图片对话' : (q.length > 16 ? '${q.substring(0, 16)}…' : q);
      }
      s.updated = DateTime.now().millisecondsSinceEpoch;
      busy = true;
    });
    _save();
    _jumpBottom();
    _reply(q);
  }

  /// 未填 API 的引导弹窗：一步跳到设置页
  void needApiDialog() {
    showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: const Text('还没有配置 API'),
      content: const Text('需要先填好接口地址和 API Key 才能和 AI 聊天。\n\n'
          '设置里已备好 DeepSeek / 通义 / Kimi / Gemini 等主流接口，'
          '点一下厂家名就能自动填好，只需再填自己的 Key。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('以后再说')),
        TextButton(onPressed: () {
          Navigator.pop(c);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
        }, child: const Text('去设置', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    ));
  }

  void _reply(String q) {
    final recent = <Map<String, dynamic>>[];
    var used = 0;
    var lastImg64 = '';
    for (var i = s.msgs.length - 1; i >= 0 && recent.length < 12; i--) {
      final m = s.msgs[i];
      if (m.role != 'user' && m.role != 'assistant') continue;
      if (m.content.isEmpty && m.img.isEmpty) continue;
      if (used + m.content.length > 6000) break;
      used += m.content.length;
      // 只把最新一条带图消息转 base64 发给视觉模型，历史图降级为占位文本省流量
      var img64 = '';
      if (m.role == 'user' && m.img.isNotEmpty && lastImg64.isEmpty) {
        try {
          final b = File(m.img).readAsBytesSync();
          img64 = 'data:image/jpeg;base64,${base64Encode(b)}';
          lastImg64 = img64;
        } catch (_) {}
      }
      recent.insert(0, {
        'role': m.role,
        'content': m.img.isNotEmpty && img64.isEmpty && m.content.isEmpty ? '[图片]' : m.content,
        if (img64.isNotEmpty) 'img64': img64,
      });
    }
    if (recent.isEmpty && q.isNotEmpty) {
      recent.add({'role': 'user', 'content': q});
    }
    final sys = buildSystem(q);
    // 思考过程默认完全不显示、也不写入历史，只保留最终回复
    final showThink = Store.I.cfg.showThinking;
    var raw = '', acc = '', think = '';
    _handle = streamChat(
      messages: recent,
      system: sys,
      deep: Store.I.deepThink,
      onThink: (t) {
        if (showThink) {
          think += t;
          setState(() {});
        }
      },
      onContent: (c) {
        raw += c;
        // 部分中转会把 <think> 思考块塞进正文，这里一并过滤掉
        acc = stripThink(raw);
        setState(() {});
        _jumpBottom();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(friendlyErr(e)), backgroundColor: Colors.red.shade400));
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          busy = false;
          if (acc.trim().isNotEmpty) {
            s.msgs.add(Msg(role: 'assistant', content: acc,
                think: showThink ? think : ''));
            s.updated = DateTime.now().millisecondsSinceEpoch;
          }
        });
        if (acc.trim().isEmpty && (raw.isNotEmpty || think.isNotEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              duration: Duration(seconds: 4),
              content: Text('模型只输出了思考过程没给正文，可关掉「深度思考」或换普通模型再试')));
        }
        _save();
        _jumpBottom();
      },
    );
  }

  void regen() {
    if (busy || s.msgs.isEmpty) return;
    if (s.msgs.last.role != 'assistant') return;
    setState(() {
      s.msgs.removeLast();
      busy = true;
    });
    _save();
    // 找到这条回复前面最近的用户消息作为上下文
    var q = '';
    for (var i = s.msgs.length - 1; i >= 0; i--) {
      if (s.msgs[i].role == 'user') {
        q = s.msgs[i].content;
        break;
      }
    }
    _reply(q.isEmpty ? '继续' : q);
  }

  // ---------------- 菜单 / 会话 ----------------

  void topMenu() {
    showModalBottomSheet<void>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.history), title: const Text('历史会话'), onTap: () { Navigator.pop(c); sessionsDialog(); }),
      ListTile(leading: const Icon(Icons.add), title: const Text('新对话'), onTap: () { Navigator.pop(c); setState(() { Store.I.newSession(); }); }),
      ListTile(leading: const Icon(Icons.ios_share), title: const Text('导出当前对话'), onTap: () { Navigator.pop(c); exportDialog(); }),
      ListTile(leading: const Icon(Icons.file_download), title: const Text('导入对话 / 文档'), onTap: () { Navigator.pop(c); importDialog(); }),
      ListTile(leading: const Icon(Icons.vertical_align_top), title: const Text('跳到最早一条'), onTap: () {
        Navigator.pop(c);
        _jumpTop();
      }),
    ])));
  }

  void sessionsDialog() {
    showDialog<void>(context: context, builder: (c) => SimpleDialog(
      title: const Text('历史会话'),
      children: [
        for (final chat in Store.I.chats.reversed)
          SimpleDialogOption(onPressed: () {
            Store.I.activeId = chat.id;
            Store.I.saveChats();
            Navigator.pop(c);
            setState(() {});
            _jumpBottom();
          }, child: Text(chat.title, overflow: TextOverflow.ellipsis)),
      ],
    ));
  }

  void exportDialog() {
    if (s.msgs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前对话还没有内容')));
      return;
    }
    showDialog<void>(context: context, builder: (c) => SimpleDialog(
      title: Text('导出「${s.title}」'),
      children: [
        SimpleDialogOption(onPressed: () {
          Clipboard.setData(ClipboardData(text: exportChatJson(s)));
          Navigator.pop(c);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('JSON 备份已复制到剪贴板（可粘贴保存，再导入可继续聊）')));
        }, child: const Text('JSON 备份（复制到剪贴板，可再导入继续聊）')),
        SimpleDialogOption(onPressed: () {
          Clipboard.setData(ClipboardData(text: exportChatTxt(s)));
          Navigator.pop(c);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TXT 文本已复制到剪贴板')));
        }, child: const Text('TXT 文本（复制到剪贴板，方便分享）')),
      ],
    ));
  }

  // ---------------- 导入 ----------------

  void importDialog() {
    showModalBottomSheet<void>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.link), title: const Text('粘贴 DeepSeek 分享链接'),
          subtitle: const Text('贴 https://chat.deepseek.com/share/... 直接导入，左右自动分开'),
          onTap: () async {
        Navigator.pop(c);
        final data = await Clipboard.getData('text/plain');
        final t = data?.text ?? '';
        final id = shareIdOf(t);
        if (id == null) {
          if (mounted) snackbar(context, '剪贴板里没找到分享链接（应先复制 https://chat.deepseek.com/share/...）');
          return;
        }
        if (mounted) setBusy(context, '正在读取分享对话…');
        try {
          final conv = await fetchDeepSeekShare(id);
          if (!mounted) return;
          setBusy(context, null);
          _buildShared(conv);
        } catch (e) {
          if (!mounted) return;
          setBusy(context, null);
          snackbar(context, '导入失败：$e（可改用「粘贴文本导入」）');
        }
      }),
      ListTile(leading: const Icon(Icons.content_paste), title: const Text('粘贴文本导入'), onTap: () async {
        Navigator.pop(c);
        final data = await Clipboard.getData('text/plain');
        final t = data?.text ?? '';
        if (t.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('剪贴板是空的')));
          }
          return;
        }
        handleImported('粘贴的对话', t);
      }),
      ListTile(leading: const Icon(Icons.folder_open), title: const Text('选择文件导入（JSON / TXT / MD）'), onTap: () async {
        Navigator.pop(c);
        final f = await openFile();
        if (f == null || !mounted) return;
        setBusy(context, '正在读取文件…');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final bytes = await f.readAsBytes();
        if (!mounted) return;
        setBusy(context, null);
        handleImported(f.name, utf8.decode(bytes, allowMalformed: true));
      }),
    ])));
  }

  Future<void> handleImported(String name, String text) async {
    final t = text.trim();
    if (t.startsWith('{')) {
      try {
        final o = jsonDecode(t) as Map;
        if (o['type'] == 'chat') {
          restoreExport(o.cast<String, dynamic>(), name);
          return;
        }
      } catch (_) {}
    }
    // 几千轮的记录有几 MB，放到后台 isolate 解析，界面不会卡死
    setBusy(context, '正在解析对话…');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    ParsedChatLog parsed;
    try {
      parsed = await compute(parseChatLog, text);
    } catch (_) {
      parsed = parseChatLog(text);
    }
    if (!mounted) return;
    setBusy(context, null);
    if (parsed.isChat) {
      showDocPreview(name, text, parsed);
    } else {
      showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('没识别出对话'),
        content: const Text('这个文件里没认出「谁说了什么」的对话格式。\n'
            '支持的写法：\n'
            '  用户：你好\n'
            '  【DeepSeek】你好呀\n'
            '  用户 2026-11-13 05:09:19\n'
            'JSON 备份请用本 App 导出的文件。'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))],
      ));
    }
  }

  void restoreExport(Map<String, dynamic> o, String name) {
    final msgs = <Msg>[];
    for (final m0 in (o['msgs'] ?? []) as List) {
      final m = (m0 as Map).cast<String, dynamic>();
      final role = (m['role'] ?? '').toString();
      if (role != 'user' && role != 'assistant') continue;
      msgs.add(Msg(
          role: role,
          content: (m['content'] ?? '').toString(),
          ts: ((m['ts'] ?? 0) as num).toInt()));
    }
    if (msgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份里没有消息')));
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      final ns = Store.I.newSession();
      ns.title = ((o['title'] ?? name) ?? '导入的对话').toString();
      ns.msgs.addAll(msgs);
      ns.updated = now;
    });
    _save();
    _jumpBottom();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已还原 ${msgs.length} 条消息，可继续聊')));
  }

  void showDocPreview(String name, String raw, ParsedChatLog parsed) {
    final n = parsed.msgs.length;
    final isPair = parsed.hasTwoSides;
    final me = parsed.meSpeaker;
    final ai = parsed.aiSpeaker;
    showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: const Text('载入记忆资料'),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('${raw.length} 字', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(parsed.isChat ? '识别为聊天记录' : '识别为普通文稿',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF07C160))),
            if (parsed.isChat) ...[
              const SizedBox(height: 4),
              Text('$n 条消息 · ${parsed.speakers.length} 位说话人',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                whoTag('我', me.isEmpty ? '待选择' : me, true),
                whoTag('AI', ai.isEmpty ? '待选择' : ai, false),
              ]),
              if (me.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                    '没认出谁是「我」，生成时会让你点一下',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 11))),
              const SizedBox(height: 8),
              for (final m in parsed.msgs.take(3))
                Padding(padding: const EdgeInsets.only(top: 3), child:
                  Text('${m.speaker}：${m.content.length > 60 ? '${m.content.substring(0, 60)}…' : m.content}',
                      style: const TextStyle(fontSize: 11))),
            ] else
              Text(raw.trim().replaceAll('\n', ' ').length > 160
                  ? '${raw.trim().replaceAll('\n', ' ').substring(0, 160)}…'
                  : raw.trim().replaceAll('\n', ' '),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(parsed.isChat
                ? '回放会按「我发的在右、AI 发的在左」排好，可直接往下翻，也能让 AI 接着聊。'
                : '载入后会作为参考资料注入每次 AI 对话。',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ])),
      actions: [
        if (isPair)
          TextButton(onPressed: () { Navigator.pop(context); continueDocDialogue(name, parsed); },
              child: const Text('▶ AI 接着聊',
                  style: TextStyle(color: Color(0xFF07C160), fontWeight: FontWeight.bold))),
        TextButton(onPressed: () {
          Navigator.pop(context);
          saveDoc(name, raw, parsed.isChat, quiet: parsed.isChat);
          if (parsed.isChat) createReplay(name, parsed);
        }, child: Text(parsed.isChat ? '存为记忆 ＋ 生成回放' : '存为记忆资料')),
      ],
    ));
  }

  /// 预览里的小标签：我/AI 分别对应哪个说话人
  Widget whoTag(String role, String name, bool mine) {
    final color = mine ? const Color(0xFF95EC69) : const Color(0xFF07C160);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Text('$role = $name',
          style: TextStyle(fontSize: 11, color: mine ? const Color(0xFF2E7D32) : const Color(0xFF067A3C),
              fontWeight: FontWeight.w600)),
    );
  }

  void saveDoc(String name, String text, bool chat, {bool quiet = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final doc = Doc(
        id: 'd$now',
        name: name,
        text: text.length > 1000000 ? text.substring(0, 1000000) : text,
        ts: now);
    Store.I.buildChunks(doc);
    setState(() => Store.I.docs.add(doc));
    Store.I.saveDocs();
    if (!quiet) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已载入资料《$name》')));
    }
  }

  /// 判断不出来时，让用户点一下「哪个说话人是我」
  Future<int> pickMeDialog(ParsedChatLog parsed) async {
    final cands = <String>[];
    for (final sp in parsed.speakers) {
      if (parsed.aiSpeaker.isNotEmpty && sp == parsed.aiSpeaker) continue;
      cands.add(sp);
      if (cands.length >= 6) break;
    }
    if (cands.isEmpty) cands.addAll(parsed.speakers.take(6));
    final r = await showDialog<int>(context: context, builder: (c) => SimpleDialog(
      title: const Text('哪一边是你？'),
      children: [
        for (final sp in cands)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, parsed.speakers.indexOf(sp)),
            child: Text('「$sp」是我（其余说话人交给 AI）')),
        if (parsed.aiSpeaker.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text(
              'AI 这一边识别为「${parsed.aiSpeaker}」',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, -1),
            child: const Text('取消')),
      ],
    ));
    return r ?? -1;
  }

  /// 聊天记录回放：我发的排右侧、AI 发的排左侧，只读式浏览
  Future<void> createReplay(String name, ParsedChatLog parsed) async {
    if (parsed.msgs.isEmpty || parsed.speakers.isEmpty) return;
    var idx = parsed.meIndex;
    if (idx < 0) idx = await pickMeDialog(parsed);
    if (idx < 0 || !mounted || idx >= parsed.speakers.length) return;
    await _buildReplay(name, parsed, idx);
  }

  Future<void> _buildReplay(String name, ParsedChatLog parsed, int meIdx) async {
    final meSp = parsed.speakers[meIdx];
    final others = parsed.speakers.where((x) => x != meSp).length;
    final multi = others > 1; // 多个角色时给 AI 的话加【谁】前缀，方便分人
    var title = name.replaceAll(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '').trim();
    if (title.length > 18) title = title.substring(0, 18);
    final now = DateTime.now().millisecondsSinceEpoch;
    // 上千轮的时候构造 + 存档要一会儿，给个进度提示
    if (parsed.msgs.length > 400) {
      setBusy(context, '正在生成回放…');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
    }
    var mine = 0;
    setState(() {
      final ns = Store.I.newSession();
      ns.title = '$title · 回放';
      var base = now - parsed.msgs.length * 60000;
      for (final m in parsed.msgs) {
        final isMine = m.speaker == meSp;
        if (isMine) mine++;
        ns.msgs.add(Msg(
            role: isMine ? 'user' : 'assistant',
            content: (isMine || !multi) ? m.content : '【${m.speaker}】${m.content}',
            ts: base));
        base += 60000;
      }
      ns.updated = now;
    });
    setBusy(context, null);
    await _save();
    if (!mounted) return;
    _jumpBottom();
    snackbar(context, '回放已生成：我 $mine 条 · AI ${parsed.msgs.length - mine} 条',
        icon: Icons.check_circle_outline);
  }

  /// 分享链接导入：角色由接口给出，直接左右分明
  void _buildShared(SharedConversation conv) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var title = conv.title;
    if (title.length > 18) title = title.substring(0, 18);
    setState(() {
      final ns = Store.I.newSession();
      ns.title = '$title · 分享';
      var ts = now - conv.msgs.length * 60000;
      for (final m in conv.msgs) {
        ns.msgs.add(Msg(role: m.role, content: m.text, ts: ts));
        ts += 60000;
      }
      ns.updated = now;
    });
    _save();
    _jumpBottom();
    final mine = conv.msgs.where((m) => m.role == 'user').length;
    snackbar(context, '已导入 ${conv.msgs.length} 条：我 $mine 条 · AI ${conv.msgs.length - mine} 条',
        icon: Icons.check_circle_outline);
  }

  // ---------------- 双方对话续聊 ----------------

  Future<void> continueDocDialogue(String name, ParsedChatLog parsed) async {
    if (parsed.msgs.isEmpty || !parsed.hasTwoSides) {
      snackbar(context, '没识别出双方对话');
      return;
    }
    var idx = parsed.meIndex;
    if (idx < 0) idx = await pickMeDialog(parsed);
    if (idx < 0 || !mounted) return;
    buildDocChat(name, parsed, idx);
  }

  void buildDocChat(String name, ParsedChatLog parsed, int meIdx) {
    final meSp = parsed.speakers[meIdx];
    final msgs = <Msg>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    var base = now - parsed.msgs.length * 60000;
    for (final m in parsed.msgs) {
      if (m.content.trim().isEmpty) continue;
      msgs.add(Msg(
          role: m.speaker == meSp ? 'user' : 'assistant',
          content: m.content.trim(),
          ts: base));
      base += 60000;
    }
    if (msgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有可载入的消息')));
      return;
    }
    var title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (title.length > 20) title = title.substring(0, 20);
    setState(() {
      final ns = Store.I.newSession();
      ns.title = title;
      ns.msgs.addAll(msgs);
      ns.updated = now;
      busy = true;
    });
    _save();
    _jumpBottom();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已载入 ${msgs.length} 条消息，AI 正在接着聊…')));
    _reply('继续上面的对话');
  }

  // ---------------- 气泡长按 ----------------

  void bubbleMenu(Msg m) {
    showModalBottomSheet<void>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.copy), title: const Text('复制'), onTap: () {
        Clipboard.setData(ClipboardData(text: m.content));
        Navigator.pop(c);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
      }),
      if (m.role == 'assistant' && !busy && s.msgs.isNotEmpty && identical(s.msgs.last, m))
        ListTile(leading: const Icon(Icons.refresh), title: const Text('重新生成'), onTap: () {
          Navigator.pop(c);
          regen();
        }),
    ])));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final p = pal();
    return Scaffold(
      backgroundColor: p.bg,
      appBar: fancyAppBar(Store.I.cfg.aiName, autoLeading: false,
          actions: [IconButton(onPressed: topMenu, icon: const Icon(Icons.more_vert))]),
      body: Column(children: [
        // 开关行（深度思考 / 记忆 + 历史 / 新对话）
        Container(
          color: p.bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
                chip('深度思考', Store.I.deepThink, () {
                  setState(() { Store.I.deepThink = !Store.I.deepThink; Store.I.saveChats(); });
                }),
                chip('记忆', Store.I.memEnabled, () {
                  setState(() { Store.I.memEnabled = !Store.I.memEnabled; Store.I.saveChats(); });
                }),
              ])),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              GestureDetector(onTap: sessionsDialog, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.history, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text('历史', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              )),
              const SizedBox(width: 8),
              GestureDetector(onTap: () { setState(() { Store.I.newSession(); }); _jumpBottom(); }, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF07C160)),
                ),
                child: const Text('+ 新对话', style: TextStyle(fontSize: 12, color: Color(0xFF07C160))),
              )),
              const Spacer(),
              Flexible(child: Text(s.title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
        Expanded(child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: s.msgs.length + (busy ? 1 : 0),
          itemBuilder: (c, i) {
            // 正序：最新的在最下面，消息少时自然从头往下排
            if (busy && i == s.msgs.length) return typingBubble();
            final m = s.msgs[i];
            final prevTs = i > 0 ? s.msgs[i - 1].ts : 0;
            return Column(children: [
              if (needDivider(prevTs, m.ts))
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child:
                  Text(fmtChatTime(m.ts), style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
              bubble(m),
            ]);
          },
        )),
        // 输入行（对齐原版：麦克风 + 相机 + 输入框 + 发送）
        if (_pendingImg != null)
          Container(
            color: p.surface,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Row(children: [
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_pendingImg!.path), width: 56, height: 56, fit: BoxFit.cover)),
                GestureDetector(onTap: () => setState(() => _pendingImg = null),
                  child: Container(width: 18, height: 18, margin: const EdgeInsets.only(left: 44),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 12, color: Colors.white)),
                ),
              ]),
              const SizedBox(width: 8),
              Text('图片将随下一条消息发送', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ),
        Container(
          color: p.surface,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Row(children: [
            GestureDetector(onTap: micHint, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.mic_none, size: 24, color: Colors.grey.shade600),
            )),
            GestureDetector(onTap: pickImage, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.photo_camera_outlined, size: 24, color: Colors.grey.shade600),
            )),
            Expanded(child: TextField(
              controller: _input,
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => send(),
              decoration: InputDecoration(
                hintText: '问点什么…',
                isDense: true,
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            )),
            const SizedBox(width: 6),
            GestureDetector(onTap: send, child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: p.grad),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: p.grad.first.withValues(alpha: 0.4),
                    blurRadius: 8, offset: const Offset(0, 3))]),
              child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
            )),
          ]),
        ),
      ]),
      // 几千轮的记录手动拉到底太痛苦：不在底部时给一个「回到底部」的小按钮
      floatingActionButton: _showJump
          ? Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: FloatingActionButton.small(
                backgroundColor: p.surface,
                foregroundColor: p.primary,
                elevation: 3,
                tooltip: '回到最新',
                onPressed: () => _jumpBottom(),
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            )
          : null,
    );
  }

  Widget chip(String label, bool on, VoidCallback tap) {
    final p = pal();
    return GestureDetector(
    onTap: tap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: on ? p.primarySoft : p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? p.primary : p.line),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          color: on ? p.primaryD : p.muted)),
    ),
  );
  }

  Widget avatar(bool ai) {
    final path = ai ? Store.I.cfg.aiAvatar : Store.I.cfg.userAvatar;
    ImageProvider? img;
    if (path.isNotEmpty && File(path).existsSync()) {
      img = FileImage(File(path));
    }
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
      },
      child: Container(
        width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ai ? const Color(0xFF07C160) : const Color(0xFF5B8CFF),
          borderRadius: BorderRadius.circular(6),
          image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
        ),
        child: img == null
            ? Text(ai ? Store.I.cfg.aiName.characters.first : '我',
                style: const TextStyle(color: Colors.white, fontSize: 15))
            : null,
      ),
    );
  }

  // ---------------- 图片 / 语音输入 ----------------

  Future<void> pickImage() async {
    if (busy) return;
    if (Store.I.cfg.apiKey.trim().isEmpty) { needApiDialog(); return; }
    final f = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: '图片', extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']),
    ]);
    if (f == null) return;
    try {
      // 复制到应用目录，聊天记录里存路径（重启后还能看到）
      final dir = await Store.I.dir();
      final imgDir = Directory('${dir.path}${Platform.pathSeparator}chat_imgs');
      if (!await imgDir.exists()) await imgDir.create(recursive: true);
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
      final dest = File('${imgDir.path}${Platform.pathSeparator}img_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await f.saveTo(dest.path);
      setState(() => _pendingImg = XFile(dest.path));
    } catch (_) {
      setState(() => _pendingImg = f);
    }
  }

  /// 内置语音识别：系统离线识别优先，设备不支持时用已配置接口在线转录
  Future<void> micHint() async {
    final t = await showVoiceInput(context);
    if (t == null || t.trim().isEmpty || !mounted) return;
    final old = _input.text.trim();
    _input.text = old.isEmpty ? t.trim() : '$old ${t.trim()}';
    setState(() {});
    snackbar(context, '已填入输入框，检查后点发送', icon: Icons.mic_none);
  }

  Widget bubble(Msg m) {
    final p = pal();
    final mine = m.role == 'user';
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 默认隐藏思考过程；只有用户在设置里主动打开「显示 AI 思考过程」才显示
      if (Store.I.cfg.showThinking && m.think.isNotEmpty) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          child: Text(m.think.length > 300 ? '${m.think.substring(0, 300)}…' : m.think,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
      ],
      if (m.img.isNotEmpty && File(m.img).existsSync()) ...[
        ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.file(File(m.img), width: 180, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        if (m.content.isNotEmpty) const SizedBox(height: 4),
      ],
      if (m.content.isNotEmpty)
        Text(m.content, style: TextStyle(fontSize: 15, height: 1.35, color: p.ink)),
    ]);
    // 显示密度（原生版「显示大小 / 对话间距」）：0 宽松微信风 / 1 标准 / 2 紧凑
    final d = Store.I.cfg.density.clamp(0, 2);
    final bh = d == 0 ? 16.0 : (d == 2 ? 10.0 : 12.0);
    final bv = d == 0 ? 12.0 : (d == 2 ? 6.0 : 9.0);
    final vGap = d == 0 ? 6.0 : (d == 2 ? 2.0 : 4.0);
    final baloon = Container(
      constraints: const BoxConstraints(maxWidth: 270),
      margin: EdgeInsets.only(left: mine ? 0 : 6, right: mine ? 6 : 0),
      padding: EdgeInsets.symmetric(horizontal: bh, vertical: bv),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF95EC69) : p.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: body,
    );
    return GestureDetector(
      onLongPress: () => bubbleMenu(m),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: vGap),
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: mine ? [Expanded(child: Container()), baloon, avatar(false)]
                          : [avatar(true), baloon, Expanded(child: Container())],
        ),
      ),
    );
  }

  Widget typingBubble() {
    final p = pal();
    return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
      avatar(true),
      Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: const SizedBox(
          width: 46, height: 16,
          child: _TypingDots(),
        ),
      ),
    ]),
  );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (c, _) => Row(children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3 + 0.7 * _phase(i)),
            shape: BoxShape.circle,
          ),
        ),
    ]),
  );

  double _phase(int i) {
    final t = (_c.value - i * 0.2) % 1.0;
    return t < 0 ? t + 1 : t;
  }
}
