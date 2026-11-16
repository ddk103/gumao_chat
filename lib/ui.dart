// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-9A1B
// 孤猫聊天 · 共享 UI（多套主题 + 渐变 / 阴影 / 通用组件）
import 'package:flutter/material.dart';

import 'decor.dart';
import 'store.dart';

/// 全局 tab 切换通知（对话0/我的1）
final ValueNotifier<int> homeTab = ValueNotifier<int>(0);

/// 主题变更通知：换皮肤时整棵 UI 树重建
final ValueNotifier<int> themeTick = ValueNotifier<int>(0);

void setTheme(String key) {
  Store.I.cfg.theme = key;
  Store.I.saveCfg();
  themeTick.value++;
}

class Pal {
  final Color bg, surface, surfaceAlt, primary, primaryD, primarySoft,
      accent, accentSoft, ink, muted, line, danger, track;
  final Color? g1, g2; // 顶栏 / 大卡片渐变两端
  const Pal(this.bg, this.surface, this.surfaceAlt, this.primary, this.primaryD,
      this.primarySoft, this.accent, this.accentSoft, this.ink, this.muted,
      this.line, this.danger, this.track, [this.g1, this.g2]);

  /// 主渐变：未指定时用 主色→深主色
  List<Color> get grad => [g1 ?? primary, g2 ?? primaryD];
  bool get isDark => bg.computeLuminance() < 0.28;
}

const Map<String, Pal> PALS = {
  'default': Pal(
      Color(0xFFF4F7F3), Color(0xFFFFFFFF), Color(0xFFEAF2EB), Color(0xFF2F7D5B),
      Color(0xFF1D5A40), Color(0xFFE2F0E7), Color(0xFFD18B3C), Color(0xFFFAEEDB),
      Color(0xFF1E2C26), Color(0xFF7B8A81), Color(0xFFE2E9E1), Color(0xFFCE5B52),
      Color(0xFFE7EEE6), Color(0xFF43A57A), Color(0xFF17553C)),
  'ink': Pal(
      Color(0xFFFAF4E6), Color(0xFFFFFBF0), Color(0xFFF1E8D2), Color(0xFF5B6B4A),
      Color(0xFF3F4C33), Color(0xFFE7E9D8), Color(0xFFB07B3C), Color(0xFFF6E9D2),
      Color(0xFF2E2A20), Color(0xFF8A8069), Color(0xFFE3D9BE), Color(0xFFB85443),
      Color(0xFFEBE1C8), Color(0xFF7C8C5E), Color(0xFF3A4630)),
  'weixin': Pal(
      Color(0xFFEDEDED), Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFF07C160),
      Color(0xFF06A651), Color(0xFFE3F7EC), Color(0xFF576B95), Color(0xFFE8EDF6),
      Color(0xFF191919), Color(0xFF8A8A8A), Color(0xFFDCDCDC), Color(0xFFE44C4C),
      Color(0xFFE6E6E6), Color(0xFF20D277), Color(0xFF049B4C)),
  'dark': Pal(
      Color(0xFF151C18), Color(0xFF232C26), Color(0xFF2D3831), Color(0xFF5DBE92),
      Color(0xFF2F7D5B), Color(0xFF2C4637), Color(0xFFE0A55A), Color(0xFF453724),
      Color(0xFFE8E2D4), Color(0xFFA0AEA2), Color(0xFF37443B), Color(0xFFE3796F),
      Color(0xFF39433B), Color(0xFF2E5E48), Color(0xFF101A14)),
  // —— 新增 4 套 ——
  'sakura': Pal(
      Color(0xFFFDF3F6), Color(0xFFFFFFFF), Color(0xFFFBE7EF), Color(0xFFD66C94),
      Color(0xFFA8446C), Color(0xFFFBE5EE), Color(0xFFC08AD8), Color(0xFFF4E7FA),
      Color(0xFF3A2630), Color(0xFF9B8190), Color(0xFFF0DCE5), Color(0xFFD75B63),
      Color(0xFFF5E2EA), Color(0xFFF19AB6), Color(0xFFB84C7E)),
  'ocean': Pal(
      Color(0xFFEFF6FA), Color(0xFFFFFFFF), Color(0xFFE1EEF6), Color(0xFF2E7FA8),
      Color(0xFF1B5478), Color(0xFFDDEEF7), Color(0xFF3AAFA9), Color(0xFFDCF2EF),
      Color(0xFF1B2E38), Color(0xFF758F9C), Color(0xFFD9E7EF), Color(0xFFD2695C),
      Color(0xFFE0EDF4), Color(0xFF4FA6CE), Color(0xFF18557E)),
  'cream': Pal(
      Color(0xFFFCF5EA), Color(0xFFFFFDF8), Color(0xFFF7EAD6), Color(0xFFC97A3C),
      Color(0xFF9A5423), Color(0xFFFBEAD5), Color(0xFF7C9A5C), Color(0xFFEDF1DC),
      Color(0xFF3C2E21), Color(0xFF98836B), Color(0xFFEEDCC2), Color(0xFFC9544A),
      Color(0xFFF2E4CE), Color(0xFFE9A45B), Color(0xFFB2642C)),
  'violet': Pal(
      Color(0xFF191627), Color(0xFF252138), Color(0xFF302B48), Color(0xFFA98BE8),
      Color(0xFF7251C0), Color(0xFF342C50), Color(0xFFE2A0C8), Color(0xFF4A3458),
      Color(0xFFEFE9FA), Color(0xFFA79DBD), Color(0xFF3A3354), Color(0xFFE5798E),
      Color(0xFF332C4C), Color(0xFF6F56B8), Color(0xFF241C3E)),
};

Pal pal() => PALS[Store.I.cfg.theme] ?? PALS['default']!;

const THEME_NAMES = {
  'default': '青竹', 'ink': '纸墨', 'weixin': '微信', 'dark': '暗夜',
  'sakura': '樱粉', 'ocean': '海蓝', 'cream': '奶油', 'violet': '星夜紫',
};
const List<String> THEME_KEYS = [
  'default', 'weixin', 'sakura', 'ocean', 'cream', 'ink', 'dark', 'violet'
];
const Map<String, String> THEME_DESC = {
  'default': '清雅竹绿 · 沉静耐看', 'ink': '宣纸墨色 · 书写感',
  'weixin': '熟悉微信绿 · 清爽', 'dark': '护眼夜间 · 低亮度',
  'sakura': '柔雾樱粉 · 温柔', 'ocean': '澄澈海蓝 · 清凉',
  'cream': '奶油暖橘 · 松弛', 'violet': '星夜紫 · 深邃梦幻',
};

// ---------------- 渐变顶栏 ----------------

PreferredSizeWidget fancyAppBar(String title,
    {List<Widget>? actions, Widget? leading, double? elevation, bool? autoLeading}) {
  final p = pal();
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: p.grad),
        boxShadow: [
          BoxShadow(color: p.grad.last.withValues(alpha: 0.28), blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: autoLeading ?? true,
        leading: leading,
        title: Text(title, style: const TextStyle(
            fontSize: 17.5, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        actions: actions,
      ),
    ),
  );
}

// ---------------- 通用组件 ----------------

class SCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets pad;
  final VoidCallback? onTap;
  final List<Color>? gradient;
  const SCard({super.key, required this.child,
      this.pad = const EdgeInsets.all(14), this.onTap, this.gradient});
  @override
  Widget build(BuildContext context) {
    final p = pal();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: pad,
        decoration: BoxDecoration(
          gradient: gradient != null
              ? LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight, colors: gradient!)
              : null,
          color: gradient == null ? p.surface : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line.withValues(alpha: 0.75), width: 0.7),
          boxShadow: [
            BoxShadow(
                color: p.isDark ? Colors.black.withValues(alpha: 0.25)
                    : p.primaryD.withValues(alpha: 0.07),
                blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// 渐变主按钮
Widget gradientButton(String text, IconData icon, VoidCallback onTap,
    {bool soft = false, double height = 46}) {
  final p = pal();
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        gradient: soft ? null : LinearGradient(colors: p.grad),
        color: soft ? p.primarySoft : null,
        borderRadius: BorderRadius.circular(13),
        boxShadow: soft ? null : [
          BoxShadow(color: p.grad.first.withValues(alpha: 0.32), blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: soft ? p.primaryD : Colors.white),
        const SizedBox(width: 7),
        Text(text, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: soft ? p.primaryD : Colors.white)),
      ]),
    ),
  );
}

class ChipBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? bg, fg;
  const ChipBtn(this.text, {super.key, required this.onTap, this.bg, this.fg});
  @override
  Widget build(BuildContext context) {
    final p = pal();
    return Material(
      color: bg ?? p.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(text,
              style: TextStyle(fontSize: 13, color: fg ?? p.ink)),
        ),
      ),
    );
  }
}

Widget pill(String text, {Color? bg, Color? fg, VoidCallback? onTap}) {
  final p = pal();
  return Material(
    color: bg ?? p.primarySoft,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: fg ?? p.primary,
            fontWeight: FontWeight.w500)),
      ),
    ),
  );
}

void snackbar(BuildContext context, String s, {IconData? icon}) {
  final p = pal();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    backgroundColor: p.isDark ? p.surfaceAlt : p.ink.withValues(alpha: 0.92),
    duration: const Duration(seconds: 2),
    content: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 17, color: p.primary),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(s, style: TextStyle(
          color: p.isDark ? p.ink : Colors.white, fontSize: 13))),
    ]),
  ));
}

/// 主题色卡选择面板（8 套，带渐变预览）
Future<String?> showThemePicker(BuildContext context) async {
  final p = pal();
  final cur = Store.I.cfg.theme;
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.palette_outlined, size: 20, color: p.primary),
        const SizedBox(width: 8),
        Text('选一套皮肤', style: TextStyle(color: p.ink, fontSize: 17)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final k in THEME_KEYS)
              GestureDetector(
                onTap: () => Navigator.pop(c, k),
                child: Container(
                  width: 118,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PALS[k]!.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: k == cur ? p.primary : p.line,
                        width: k == cur ? 2 : 0.8),
                    boxShadow: k == cur ? [
                      BoxShadow(color: p.primary.withValues(alpha: 0.25), blurRadius: 8)
                    ] : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: PALS[k]!.grad),
                          borderRadius: BorderRadius.circular(9)),
                      child: Stack(children: [
                        Positioned(right: 6, top: 6,
                            child: Icon(Icons.auto_awesome, size: 12,
                                color: Colors.white.withValues(alpha: 0.6))),
                        if (k == cur)
                          const Center(child: Icon(Icons.check, size: 18,
                              color: Colors.white)),
                      ]),
                    ),
                    const SizedBox(height: 7),
                    Text(THEME_NAMES[k]!, style: TextStyle(
                        color: PALS[k]!.ink, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(THEME_DESC[k]!.split(' · ').first,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: PALS[k]!.muted, fontSize: 10)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c),
          child: Text('关闭', style: TextStyle(color: p.muted)))],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String msg) async {
  final p = pal();
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: TextStyle(color: p.ink)),
      content: Text(msg, style: TextStyle(color: p.ink, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('取消', style: TextStyle(color: p.muted))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text('确定', style: TextStyle(color: p.primary))),
      ],
    ),
  );
  return r == true;
}

Future<String?> promptText(BuildContext context, String title, String hint,
    {String init = '', int maxLines = 1, String okText = '保存'}) async {
  final p = pal();
  final c = TextEditingController(text: init);
  final r = await showDialog<String>(
    context: context,
    builder: (c2) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: TextStyle(color: p.ink)),
      content: TextField(
        controller: c, maxLines: maxLines,
        style: TextStyle(color: p.ink),
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c2), child: Text('取消', style: TextStyle(color: p.muted))),
        TextButton(onPressed: () => Navigator.pop(c2, c.text), child: Text(okText, style: TextStyle(color: p.primary))),
      ],
    ),
  );
  return r?.trim();
}

/// 通用列表选择对话框（原生 setItems 等价）
Future<int?> pickItem(BuildContext context, String title, List<String> items) async {
  final p = pal();
  return showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: TextStyle(color: p.ink, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (c2, i) => ListTile(
            title: Text(items[i], style: TextStyle(color: p.ink, fontSize: 14)),
            onTap: () => Navigator.pop(c, i),
          ),
        ),
      ),
    ),
  );
}

/// 多字段编辑对话框（返回按 key 取值的 Map）
Future<Map<String, String>?> editFields(
    BuildContext context, String title, List<List<String>> fields,
    {Map<String, String> init = const {}}) async {
  final p = pal();
  final cs = <TextEditingController>[];
  for (final f in fields) {
    cs.add(TextEditingController(text: init[f[0]] ?? ''));
  }
  final r = await showDialog<Map<String, String>>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: TextStyle(color: p.ink)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(children: [
            for (var i = 0; i < fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: cs[i],
                  maxLines: fields[i][2] == '3' ? 3 : 1,
                  style: TextStyle(color: p.ink, fontSize: 14),
                  decoration: InputDecoration(
                      hintText: fields[i][1], isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('取消', style: TextStyle(color: p.muted))),
        TextButton(
          onPressed: () {
            final out = <String, String>{};
            for (var i = 0; i < fields.length; i++) {
              out[fields[i][0]] = cs[i].text.trim();
            }
            Navigator.pop(c, out);
          },
          child: Text('保存', style: TextStyle(color: p.primary)),
        ),
      ],
    ),
  );
  return r;
}

/// 忙碌对话框（setBusy 等价）
OverlayEntry? _busyEntry;
void setBusy(BuildContext context, String? msg) {
  _busyEntry?.remove();
  _busyEntry = null;
  if (msg == null) return;
  final p = pal();
  _busyEntry = OverlayEntry(builder: (c) => Stack(children: [
    const ModalBarrier(dismissible: false, color: Colors.black26),
    Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
          color: p.surface, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(strokeWidth: 2.5, color: p.primary),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: p.ink, fontSize: 13)),
      ]),
    )),
  ]));
  Overlay.of(context, rootOverlay: true).insert(_busyEntry!);
}

/// 子页面脚手架：渐变顶栏 + 返回 + 标题
class SubPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  const SubPage({super.key, required this.title, required this.body, this.actions});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeTick,
      builder: (context, v, _) {
        final p = pal();
        return Scaffold(
          key: ValueKey('sub_$v'),
          backgroundColor: p.bg,
          appBar: fancyAppBar(title, actions: actions),
          body: body,
        );
      },
    );
  }
}

/// 空状态：自绘插画 + 文案 + 可选行动按钮
Widget emptyHint(String text,
    {IconData icon = Icons.auto_stories_outlined,
    String? actionText, VoidCallback? onAction}) {
  final p = pal();
  // 短屏 / 横屏（如 960x544）下固定高度会溢出，这里按可用高度缩放并允许滚动
  return LayoutBuilder(builder: (ctx, box) {
    final short = box.maxHeight > 0 && box.maxHeight < 460;
    final artSize = short ? 64.0 : 116.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: short ? 10 : 26, horizontal: 20),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      EmptyArt(icon: icon, color: p.primary, size: artSize),
      const SizedBox(height: 12),
      Text(text.split('\n').first.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(color: p.ink, fontSize: 15,
              fontWeight: FontWeight.w600, height: 1.4)),
      if (text.contains('\n')) ...[
        const SizedBox(height: 8),
        Text(text.split('\n').skip(1).join('\n').trim(),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.6)),
      ],
      if (actionText != null && onAction != null) ...[
        SizedBox(height: short ? 10 : 18),
        pill(actionText, bg: p.primary, fg: Colors.white, onTap: onAction),
      ],
    ])),
    );
  });
}

/// 名字首字圆形头像（支持本地图片）
Widget avatarCircle(String name,
    {double size = 44, Color? color, String? avatarPath}) {
  final p = pal();
  final initial = name.isNotEmpty ? name.characters.first : '?';
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color ?? p.grad.first, color ?? p.grad.last]),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: (color ?? p.primary).withValues(alpha: 0.30),
            blurRadius: 8, offset: const Offset(0, 3))]),
    alignment: Alignment.center,
    child: Text(initial,
        style: TextStyle(color: Colors.white, fontSize: size * 0.42)),
  );
}

/// 带渐变的小图标方块
Widget gradientIcon(Widget child, List<Color> colors,
    {double size = 40, double radius = 12}) {
  return Container(
    width: size, height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight, colors: colors),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(color: colors.last.withValues(alpha: 0.28), blurRadius: 7,
            offset: const Offset(0, 3)),
      ],
    ),
    child: child,
  );
}

/// 顶部欢迎横幅（渐变 + 光晕装饰）
Widget glowBanner({required String title, required String subtitle,
    required Widget trailing, double height = 116}) {
  final p = pal();
  return Container(
    height: height,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
            end: Alignment.bottomRight, colors: p.grad),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: p.grad.last.withValues(alpha: 0.30), blurRadius: 14,
              offset: const Offset(0, 5)),
        ]),
    child: Stack(children: [
      GlowDecor(colors: p.grad),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(
                    color: Colors.white, fontSize: 19,
                    fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86), fontSize: 12)),
              ])),
          trailing,
        ]),
      ),
    ]),
  );
}
