// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-EF79
// 孤猫聊天 · 设置页（接口 / AI 名字 / 头像 / 风格 / 资料 / 主题）
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'llm.dart';
import 'avatar_crop.dart';
import 'store.dart';
import 'ui.dart';

// 主流大模型预设：点一下自动填好地址和模型名，用户只需再填 API Key
// 模型名仅作兜底（各家会更新），填好 Key 后点「刷新模型」拉取实时列表
const List<List<String>> API_PRESETS = [
  ['DeepSeek', 'https://api.deepseek.com', 'deepseek-flash', 'deepseek-v4-pro'],
  ['通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-plus', 'qwen-max'],
  ['Kimi', 'https://api.moonshot.cn/v1', 'kimi-k2.5', 'kimi-k2.6'],
  ['智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4.7-flash', 'glm-5.1'],
  ['硅基流动', 'https://api.siliconflow.cn/v1', 'deepseek-ai/DeepSeek-V3', 'deepseek-ai/DeepSeek-R1'],
  ['豆包', 'https://ark.cn-beijing.volces.com/api/v3', 'doubao-seed-1-6-250615', 'doubao-seed-1-6-250615'],
  ['Gemini', 'https://generativelanguage.googleapis.com/v1beta/openai', 'gemini-3-flash', 'gemini-3-pro'],
  ['OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini', 'gpt-4o'],
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrl = TextEditingController(text: Store.I.cfg.baseUrl);
  late final TextEditingController _apiKey = TextEditingController(text: Store.I.cfg.apiKey);
  late final TextEditingController _model = TextEditingController(text: Store.I.cfg.model);
  late final TextEditingController _deepModel = TextEditingController(text: Store.I.cfg.deepModel);
  late final TextEditingController _aiName = TextEditingController(text: Store.I.cfg.aiName);
  late final TextEditingController _persona = TextEditingController(text: Store.I.cfg.persona);
  late final TextEditingController _profile = TextEditingController(text: Store.I.cfg.profile);

  void save() {
    final c = Store.I.cfg;
    c.baseUrl = _baseUrl.text.trim();
    c.apiKey = _apiKey.text.trim();
    c.model = _model.text.trim();
    c.deepModel = _deepModel.text.trim();
    c.aiName = _aiName.text.trim().isEmpty ? 'AI助手' : _aiName.text.trim();
    c.persona = _persona.text;
    c.profile = _profile.text;
    Store.I.saveCfg();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    setState(() {});
  }

  void applyPreset(List<String> pr) {
    setState(() {
      _baseUrl.text = pr[1];
      _model.text = pr[2];
      _deepModel.text = pr[3];
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已填入 ${pr[0]} 预设，再填你的 API Key 后点保存')));
  }

  // ---------------- 自定义第三方 API（中转站 / 自建服务 / 本地代理） ----------------

  /// 一键切换到某个自定义接口：只改地址与模型，不动已填的 API Key
  void applyCustom(Map<String, String> m) {
    setState(() {
      _baseUrl.text = m['url'] ?? '';
      final mo = (m['model'] ?? '').trim();
      final dm = (m['deepModel'] ?? '').trim();
      if (mo.isNotEmpty) _model.text = mo;
      if (dm.isNotEmpty) _deepModel.text = dm;
    });
    snackbar(context, '已切换到「${m['name'] ?? '自定义接口'}」，确认 API Key 后点保存',
        icon: Icons.lan_outlined);
  }

  Future<void> saveCustomApis() async {
    await Store.I.saveCfg();
    if (mounted) setState(() {});
  }

  Future<void> customDialog(int? index) async {
    final p = pal();
    final list = Store.I.cfg.customApis;
    final old = index == null ? null : list[index];
    final name = TextEditingController(text: old?['name'] ?? '');
    final url = TextEditingController(text: old?['url'] ?? '');
    final model = TextEditingController(text: old?['model'] ?? '');
    final deep = TextEditingController(text: old?['deepModel'] ?? '');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      title: Text(index == null ? '添加自定义第三方接口' : '编辑自定义接口',
          style: TextStyle(color: p.ink, fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('支持任意 OpenAI 兼容服务：API 中转站、自建网关、本地代理。\n'
            '地址填到 /v1 或完整 /chat/completions 都行；填完整地址时不会被改写。',
            style: TextStyle(color: p.muted, fontSize: 11.5, height: 1.5)),
        const SizedBox(height: 10),
        _customField(name, '接口名称（如：我的中转 / 本地 Ollama）', p),
        _customField(url, '接口地址（如 https://xxx.com/v1）', p),
        _customField(model, '普通模型（可留空，随后点刷新模型拉取）', p),
        _customField(deep, '深度思考模型（可留空）', p),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false),
            child: Text('取消', style: TextStyle(color: p.muted))),
        TextButton(onPressed: () => Navigator.pop(c, true),
            child: Text('保存', style: TextStyle(color: p.primary,
                fontWeight: FontWeight.bold))),
      ],
    ));
    if (ok != true) return;
    final u = url.text.trim();
    if (u.isEmpty) {
      if (mounted) snackbar(context, '接口地址不能为空', icon: Icons.info_outline);
      return;
    }
    final item = <String, String>{
      'name': name.text.trim().isEmpty ? '自定义接口' : name.text.trim(),
      'url': u,
      'model': model.text.trim(),
      'deepModel': deep.text.trim(),
    };
    setState(() {
      if (index == null) {
        list.add(item);
      } else {
        list[index] = item;
      }
    });
    await saveCustomApis();
    applyCustom(item);
  }

  Widget _customField(TextEditingController c, String hint, Pal p) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, style: TextStyle(color: p.ink, fontSize: 13),
      decoration: InputDecoration(hintText: hint, isDense: true,
          hintStyle: TextStyle(color: p.muted, fontSize: 12),
          filled: true, fillColor: p.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none))),
  );

  /// 测试连通性：用当前填的 API Key 去拉 /models
  Future<void> testCustom(Map<String, String> m) async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      snackbar(context, '先在上面填 API Key，再点测试', icon: Icons.vpn_key_outlined);
      return;
    }
    snackbar(context, '正在测试「${m['name']}」…', icon: Icons.lan_outlined);
    try {
      final models = await fetchModels(baseUrl: m['url'] ?? '', apiKey: key);
      if (mounted) {
        snackbar(context, '连接成功，拉到 ${models.length} 个模型',
            icon: Icons.check_circle_outline);
      }
    } catch (e) {
      final s = e.toString();
      String tip = s.length > 70 ? '${s.substring(0, 70)}…' : s;
      if (s.contains('401') || s.contains('403')) tip = 'API Key 不对或没权限';
      if (s.contains('404')) tip = '地址不对或这家没有 /models 接口';
      if (s.contains('Failed host lookup') || s.contains('SocketException')) {
        tip = '连不上服务器，检查地址与网络';
      }
      if (mounted) snackbar(context, '测试失败：$tip', icon: Icons.info_outline);
    }
  }

  Future<void> customManager() async {
    final p = pal();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (c2, setD) {
        final list = Store.I.cfg.customApis;
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: SizedBox(height: 430, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.lan_outlined, size: 19, color: p.primary),
              const SizedBox(width: 8),
              Text('我的第三方接口（${list.length}）', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: p.ink)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, size: 20, color: p.muted),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
            Text('点「使用」把地址与模型填进设置页；「测试」会调用 /models 验证连通',
                style: TextStyle(fontSize: 11, color: p.muted)),
            const SizedBox(height: 10),
            Expanded(child: list.isEmpty
                ? Center(child: Text('还没有保存的自定义接口',
                    style: TextStyle(color: p.muted, fontSize: 13)))
                : ListView.builder(itemCount: list.length, itemBuilder: (c3, i) {
                    final m = list[i];
                    final active = _baseUrl.text.trim() == (m['url'] ?? '');
                    return Card(
                      color: active ? p.primarySoft : p.surfaceAlt,
                      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.lan, size: 20,
                            color: active ? p.primary : p.muted),
                        title: Text(m['name'] ?? '自定义接口',
                            style: TextStyle(color: p.ink, fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(m['url'] ?? '', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.muted, fontSize: 10.5)),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, color: p.muted, size: 20),
                          color: p.surface,
                          onSelected: (v) async {
                            if (v == 'use') {
                              applyCustom(m);
                              Navigator.pop(ctx);
                            } else if (v == 'test') {
                              await testCustom(m);
                            } else if (v == 'edit') {
                              Navigator.pop(ctx);
                              await customDialog(i);
                            } else if (v == 'del') {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (d) => AlertDialog(
                                  backgroundColor: p.surface,
                                  title: Text('删除「${m['name']}」？',
                                      style: TextStyle(color: p.ink, fontSize: 15)),
                                  content: Text('只删除这条快捷配置，不会改动当前接口地址。',
                                      style: TextStyle(color: p.muted, fontSize: 12.5)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(d, false),
                                        child: Text('取消', style: TextStyle(color: p.muted))),
                                    TextButton(onPressed: () => Navigator.pop(d, true),
                                        child: Text('删除', style: TextStyle(color: Colors.red.shade400))),
                                  ]),
                              );
                              if (yes == true) {
                                setState(() => list.removeAt(i));
                                await saveCustomApis();
                                setD(() {});
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'use', child: Text('使用')),
                            PopupMenuItem(value: 'test', child: Text('测试连接')),
                            PopupMenuItem(value: 'edit', child: Text('编辑')),
                            PopupMenuItem(value: 'del', child: Text('删除')),
                          ],
                        ),
                      ),
                    );
                  })),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 42,
                child: gradientButton('＋ 新增第三方接口', Icons.add, () async {
                  Navigator.pop(ctx);
                  await customDialog(null);
                }, height: 42)),
          ])),
        ));
      }),
    );
  }

  Widget customSection(Pal p) {
    final list = Store.I.cfg.customApis;
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [p.primarySoft, p.surfaceAlt]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.primary.withValues(alpha: 0.32)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lan_outlined, size: 17, color: p.primaryD),
          const SizedBox(width: 7),
          Text('自定义第三方 API', style: TextStyle(color: p.ink,
              fontSize: 13.5, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(onTap: customManager,
              child: Text('管理 ›', style: TextStyle(color: p.primary, fontSize: 12))),
        ]),
        const SizedBox(height: 5),
        Text('中转站 / 自建服务 / 本地代理，任意 OpenAI 兼容地址都能存下来一键切换',
            style: TextStyle(color: p.muted, fontSize: 11, height: 1.45)),
        if (list.isEmpty) ...[
          const SizedBox(height: 9),
          SizedBox(width: double.infinity, height: 36,
              child: gradientButton('＋ 添加自定义接口', Icons.add,
                  () => customDialog(null), soft: true, height: 36)),
        ] else ...[
          const SizedBox(height: 8),
          for (final m in list)
            GestureDetector(
              onTap: () => applyCustom(m),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: p.surface,
                    borderRadius: BorderRadius.circular(9)),
                child: Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['name'] ?? '自定义接口',
                        style: TextStyle(color: p.ink, fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    Text(m['url'] ?? '', maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 10)),
                  ])),
                  Text('使用 ›', style: TextStyle(color: p.primary, fontSize: 11.5)),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  // ---------------- 刷新模型（GET /models） ----------------

  Future<void> refreshModels() async {
    if (_apiKey.text.trim().isEmpty) {
      snackbar(context, '先填 API Key，再点刷新模型', icon: Icons.vpn_key_outlined);
      return;
    }
    setBusy(context, '正在从接口拉取模型…');
    List<String> models;
    try {
      models = await fetchModels(
          baseUrl: _baseUrl.text.trim(), apiKey: _apiKey.text.trim());
    } catch (e) {
      if (!mounted) return;
      setBusy(context, null);
      final msg = e.toString();
      String tip = '拉取失败：${msg.length > 60 ? '${msg.substring(0, 60)}…' : msg}';
      if (msg.contains('401') || msg.contains('403')) {
        tip = 'API Key 不对或没权限，检查后重试';
      } else if (msg.contains('404')) {
        tip = '这家服务商没有 /models 接口，直接在上面手填模型名即可';
      } else if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
        tip = '连不上接口，检查网络或接口地址';
      }
      if (mounted) snackbar(context, tip, icon: Icons.info_outline);
      return;
    }
    if (!mounted) return;
    setBusy(context, null);
    await showModelPicker(models);
  }

  Future<void> showModelPicker(List<String> models) async {
    final p = pal();
    var kw = '';
    var forDeep = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(builder: (c2, setD) {
        final list = models
            .where((m) => m.toLowerCase().contains(kw.toLowerCase()))
            .toList();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(c2).viewInsets.bottom + 12),
            child: SizedBox(
              height: 480,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.refresh, size: 19, color: p.primary),
                  const SizedBox(width: 8),
                  Text('可用模型（${models.length}）', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: p.ink)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.close, color: p.muted, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx)),
                ]),
                Text('实时拉取自 ${modelsUrl(_baseUrl.text.trim())}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: p.muted)),
                const SizedBox(height: 10),
                Row(children: [
                  for (final e in [false, true])
                    GestureDetector(
                      onTap: () => setD(() => forDeep = e),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: forDeep == e
                              ? LinearGradient(colors: p.grad) : null,
                          color: forDeep == e ? null : p.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(e ? '设为深度思考模型' : '设为普通模型',
                            style: TextStyle(fontSize: 12,
                                color: forDeep == e ? Colors.white : p.ink,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setD(() => kw = v.trim()),
                  style: TextStyle(color: p.ink, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索模型名…', isDense: true,
                    hintStyle: TextStyle(color: p.muted),
                    prefixIcon: Icon(Icons.search, size: 18, color: p.muted),
                    filled: true, fillColor: p.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (c3, i) {
                    final m = list[i];
                    final cur = forDeep ? _deepModel.text : _model.text;
                    return ListTile(
                      dense: true,
                      title: Text(m, style: TextStyle(fontSize: 13, color: p.ink)),
                      trailing: m == cur
                          ? Icon(Icons.check_circle, size: 18, color: p.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          if (forDeep) {
                            _deepModel.text = m;
                          } else {
                            _model.text = m;
                          }
                        });
                        Navigator.pop(sheetCtx);
                        snackbar(context, '已设为${forDeep ? '深度思考' : '普通'}模型：$m',
                            icon: Icons.check_circle_outline);
                      },
                    );
                  },
                )),
              ]),
            ),
          ),
        );
      }),
    );
  }

  // ---------------- 头像 ----------------

  Widget avatarPicker(bool isAi) {
    final p = pal();
    final path = isAi ? Store.I.cfg.aiAvatar : Store.I.cfg.userAvatar;
    ImageProvider? img;
    if (path.isNotEmpty && File(path).existsSync()) {
      img = FileImage(File(path));
    }
    return GestureDetector(
      onTap: () => pickAvatar(isAi),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 72, height: 72, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isAi ? p.primarySoft : p.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: img == null ? p.primary.withValues(alpha: 0.5) : p.line, width: 1.5),
              image: img != null
                  ? DecorationImage(image: img, fit: BoxFit.cover)
                  : null,
            ),
            child: img == null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, size: 22, color: p.primary),
                    const SizedBox(height: 2),
                    Text(isAi ? 'AI' : '我', style: TextStyle(fontSize: 11, color: p.primary)),
                  ])
                : null,
          ),
          Positioned(right: -4, bottom: -4, child: Container(
            width: 24, height: 24, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.primary, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.edit, size: 12, color: Colors.white),
          )),
        ]),
        const SizedBox(height: 6),
        Text(isAi ? '换 AI 头像' : '换我的头像',
            style: TextStyle(fontSize: 12, color: p.primary, fontWeight: FontWeight.w600)),
        Text('点一下选图，可裁剪', style: TextStyle(fontSize: 10, color: p.muted)),
      ]),
    );
  }

  Future<void> pickAvatar(bool isAi) async {
    final f = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: '图片', extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']),
    ]);
    if (f == null || !mounted) return;
    // 先让用户拖动缩放裁成正方形（1:1），再保存
    Uint8List? cropped;
    try {
      cropped = await Navigator.push<Uint8List>(context,
          MaterialPageRoute(builder: (_) => AvatarCropPage(src: File(f.path))));
    } catch (_) {}
    if (cropped == null) return; // 用户取消
    try {
      final dir = await Store.I.dir();
      final dest = File('${dir.path}${Platform.pathSeparator}avatar_${isAi ? 'ai' : 'me'}.png');
      await dest.writeAsBytes(cropped, flush: true);
      setState(() {
        if (isAi) {
          Store.I.cfg.aiAvatar = dest.path;
        } else {
          Store.I.cfg.userAvatar = dest.path;
        }
      });
      await Store.I.saveCfg();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('换头像失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeTick,
      builder: (context, tv, _) {
        final p = pal();
        final c = Store.I.cfg;
        return Scaffold(
          key: ValueKey('set_$tv'),
          backgroundColor: p.bg,
      appBar: fancyAppBar('设置'),
      body: ListView(padding: const EdgeInsets.all(10), children: [
        card('接口设置', [
          Text('点厂家名一键填好地址；第三方中转 / 自建服务用「＋ 自定义」；填好 Key 后可刷新模型',
              style: TextStyle(fontSize: 11, color: p.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final pr in API_PRESETS)
              GestureDetector(
                onTap: () => applyPreset(pr),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _baseUrl.text.trim() == pr[1] ? p.primarySoft : p.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _baseUrl.text.trim() == pr[1] ? p.primary : p.line),
                  ),
                  child: Text(pr[0], style: TextStyle(
                      fontSize: 12,
                      color: _baseUrl.text.trim() == pr[1] ? p.primary : p.ink)),
                ),
              ),
            // 自定义第三方接口入口
            GestureDetector(
              onTap: () => customDialog(null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: p.grad),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 13, color: Colors.white),
                  SizedBox(width: 3),
                  Text('自定义', style: TextStyle(fontSize: 12, color: Colors.white)),
                ]),
              ),
            ),
          ]),
          customSection(p),
          const SizedBox(height: 10),
          field(_baseUrl, '接口地址（如 https://api.deepseek.com）'),
          field(_apiKey, 'API Key', obscure: true),
          field(_model, '普通模型（点刷新可实时选取）'),
          field(_deepModel, '深度思考模型（点刷新可实时选取）'),
          const SizedBox(height: 2),
          SizedBox(height: 40, child: gradientButton(
              '刷新模型（从接口拉取最新列表）', Icons.refresh, refreshModels,
              soft: true, height: 40)),
          const SizedBox(height: 6),
          Text('预设模型名只是兜底，各家随时会更新；以刷新出来的列表为准。\n'
              '自定义接口地址以 /v1 结尾或填完整 /chat/completions 均可，填完整地址时不会被改写。',
              style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.5)),
        ]),
        card('AI 设定', [
          Text('头像与昵称（点头像即可更换）',
              style: TextStyle(fontSize: 12, color: p.muted)),
          const SizedBox(height: 8),
          Row(children: [
            avatarPicker(false),
            const SizedBox(width: 16),
            avatarPicker(true),
          ]),
          const SizedBox(height: 4),
          field(_aiName, 'AI 的名字（默认 AI助手，可改成小婉等）'),
          field(_persona, '风格设定（说话口味，可空）', maxLines: 3),
          field(_profile, 'AI 资料（身份背景，可空）', maxLines: 3),
        ]),
        // 开关组
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line.withValues(alpha: 0.7), width: 0.7)),
          child: Column(children: [
            switchRow('显示 AI 思考过程', '默认关闭：只看最终回复，不打断聊天沉浸感',
                c.showThinking,
                (v) { c.showThinking = v; Store.I.saveCfg(); setState(() {}); }),
            switchRow('记忆资料', '导入的资料 / 聊天记录会检索后注入对话',
                Store.I.memEnabled,
                (v) { Store.I.memEnabled = v; Store.I.saveChats(); setState(() {}); }),
          ]),
        ),
        // 主题（8 套渐变皮肤）
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line.withValues(alpha: 0.7), width: 0.7),
              boxShadow: [BoxShadow(color: p.isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : p.primaryD.withValues(alpha: 0.07),
                  blurRadius: 14, offset: const Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.palette_outlined, size: 17, color: p.primary),
              const SizedBox(width: 6),
              Text('主题皮肤', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: p.ink)),
              const Spacer(),
              Text('${THEME_KEYS.length} 套', style: TextStyle(fontSize: 11, color: p.muted)),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final k = await showThemePicker(context);
                if (k != null) setTheme(k);
              },
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: p.grad),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  const SizedBox(width: 9),
                  Text('当前：${THEME_NAMES[c.theme] ?? '青竹'}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('点这里挑选 ›', style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in THEME_KEYS)
                GestureDetector(
                  onTap: () => setTheme(k),
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: PALS[k]!.grad),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: k == c.theme ? p.ink : Colors.white,
                            width: k == c.theme ? 2 : 1.5)),
                    child: k == c.theme
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(height: 46,
            child: gradientButton('保存设置', Icons.check_circle_outline, save)),
        const SizedBox(height: 16),
        Center(child: Text('孤猫聊天 · 源码开放版 0.1.0',
            style: TextStyle(color: p.muted, fontSize: 11))),
        const SizedBox(height: 10),
      ]),
        );
      },
    );
  }

  Widget switchRow(String title, String sub, bool val, ValueChanged<bool> on) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: pal().ink, fontSize: 14)),
      Text(sub, style: TextStyle(color: pal().muted, fontSize: 11)),
    ])),
    Switch(value: val, activeThumbColor: pal().primary, onChanged: on),
  ]);

  Widget card(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: pal().surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal().line.withValues(alpha: 0.7), width: 0.7),
        boxShadow: [BoxShadow(color: pal().isDark
            ? Colors.black.withValues(alpha: 0.25)
            : pal().primaryD.withValues(alpha: 0.07),
            blurRadius: 14, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.bold,
          fontSize: 14, color: pal().ink)),
      const SizedBox(height: 8),
      ...children,
    ]),
  );

  Widget field(TextEditingController c, String hint, {bool obscure = false, int maxLines = 1}) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(
        controller: c, obscureText: obscure, maxLines: maxLines,
        style: TextStyle(color: pal().ink),
        decoration: InputDecoration(
          hintText: hint, isDense: true,
          filled: true, fillColor: pal().surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ));
}
