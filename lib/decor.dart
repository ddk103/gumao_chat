// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-79B2
// 孤猫聊天 · 纯代码自绘装饰（无图片素材，安卓 / 鸿蒙通吃）
// 光晕 / 黑猫标识 / 渐变书封面 / 空状态插画
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 装饰渐变配色池（按名称 hash 稳定取色）
const List<List<Color>> COVER_GRADIENTS = [
  [Color(0xFF3E7C6A), Color(0xFF1D4A3C)],
  [Color(0xFF6C63B5), Color(0xFF3A347F)],
  [Color(0xFFD08A62), Color(0xFF9A4E3C)],
  [Color(0xFF3E7CA8), Color(0xFF1E4668)],
  [Color(0xFFB46C8C), Color(0xFF6E3355)],
  [Color(0xFF5C8F52), Color(0xFF2C5230)],
  [Color(0xFFC79A4B), Color(0xFF8A5E22)],
  [Color(0xFF4B6B8A), Color(0xFF263A55)],
];

List<Color> coverGradient(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return COVER_GRADIENTS[h % COVER_GRADIENTS.length];
}

/// 分组功能图标渐变（创作中心 6 组）
const List<List<Color>> GROUP_GRADIENTS = [
  [Color(0xFFFFB36B), Color(0xFFF0724A)], // 灵感：暖橙
  [Color(0xFF66C7A5), Color(0xFF2F8F72)], // 结构：青绿
  [Color(0xFF7FA8F0), Color(0xFF4567C8)], // 打磨：蓝
  [Color(0xFFB18CE8), Color(0xFF7251B8)], // 阅读：紫
  [Color(0xFFEFA36F), Color(0xFFC96B51)], // 数据：赤陶
  [Color(0xFF62C6D8), Color(0xFF2C86A8)], // AI：青蓝
];

/// 设置行图标渐变（我的页 13 行循环取色）
const List<List<Color>> ROW_GRADIENTS = [
  [Color(0xFF63C79A), Color(0xFF2E8B69)],
  [Color(0xFF7C9BE8), Color(0xFF4563B8)],
  [Color(0xFFE9A46C), Color(0xFFCE7042)],
  [Color(0xFFB484DE), Color(0xFF7A50B5)],
  [Color(0xFFE584A0), Color(0xFFB84C74)],
  [Color(0xFF5FBBD0), Color(0xFF2A7C9C)],
];

// ---------------- 柔和光晕背景 ----------------

class GlowDecor extends StatelessWidget {
  final List<Color> colors;
  final bool stars;
  const GlowDecor({super.key, required this.colors, this.stars = true});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(painter: _GlowPainter(colors, stars)),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final List<Color> colors;
  final bool stars;
  _GlowPainter(this.colors, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 两个大范围径向柔光
    _blob(canvas, Offset(w * 0.85, h * 0.12), w * 0.55,
        (colors.last).withValues(alpha: 0.55));
    _blob(canvas, Offset(w * 0.12, h * 1.05), w * 0.5,
        Colors.white.withValues(alpha: 0.16));
    if (stars) {
      final r = math.Random(7);
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
      for (var i = 0; i < 16; i++) {
        final x = r.nextDouble() * w;
        final y = r.nextDouble() * h;
        final rad = 0.8 + r.nextDouble() * 1.8;
        canvas.drawCircle(Offset(x, y), rad, paint);
      }
      // 几个半透明装饰圆环
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.18);
      canvas.drawCircle(Offset(w * 0.92, h * 0.86), w * 0.13, ring);
      canvas.drawCircle(Offset(w * 0.92, h * 0.86), w * 0.19, ring);
    }
  }

  void _blob(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.colors != colors || old.stars != stars;
}

// ---------------- 黑猫标识（自绘） ----------------

class CatMark extends StatelessWidget {
  final double size;
  final Color color;
  final Color? bg;
  final Color? detail;
  const CatMark({super.key, this.size = 72, this.color = Colors.white,
      this.bg, this.detail});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _CatPainter(color, bg, detail),
      );
}

class _CatPainter extends CustomPainter {
  final Color color, bg, detail;
  _CatPainter(this.color, Color? bg, Color? detail)
      : bg = bg ?? color.withValues(alpha: 0.12),
        detail = detail ?? (color.computeLuminance() > 0.65
            ? const Color(0xFF204A38)
            : color.withValues(alpha: 0.8));

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final fill = Paint()..color = bg;
    canvas.drawCircle(Offset(w / 2, w / 2), w * 0.48, fill);

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // 耳朵（两个三角）
    final ear = Path()
      ..moveTo(w * 0.25, w * 0.40)
      ..lineTo(w * 0.30, w * 0.18)
      ..lineTo(w * 0.46, w * 0.30)
      ..close();
    final ear2 = Path()
      ..moveTo(w * 0.75, w * 0.40)
      ..lineTo(w * 0.70, w * 0.18)
      ..lineTo(w * 0.54, w * 0.30)
      ..close();
    canvas.drawPath(ear, p);
    canvas.drawPath(ear2, p);
    // 圆脸
    canvas.drawCircle(Offset(w * 0.5, w * 0.53), w * 0.26, p);

    final eye = Paint()
      ..color = detail
      ..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.40, w * 0.50),
            width: w * 0.055, height: w * 0.085), eye);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.60, w * 0.50),
            width: w * 0.055, height: w * 0.085), eye);
    // 小鼻子 + 胡须
    final line = Paint()
      ..color = detail
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.47, w * 0.585), Offset(w * 0.53, w * 0.585), line);
    canvas.drawLine(Offset(w * 0.25, w * 0.57), Offset(w * 0.39, w * 0.60), line);
    canvas.drawLine(Offset(w * 0.75, w * 0.57), Offset(w * 0.61, w * 0.60), line);
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) => old.color != color;
}

// ---------------- 渐变书封面 ----------------

class BookCover extends StatelessWidget {
  final String title;
  final double width;
  final double height;
  const BookCover({super.key, required this.title, this.width = 52, this.height = 68});

  @override
  Widget build(BuildContext context) {
    final g = coverGradient(title);
    final first = title.trim().isEmpty ? '书' : title.trim().characters.first;
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
        boxShadow: [
          BoxShadow(color: g.last.withValues(alpha: 0.35), blurRadius: 8,
              offset: const Offset(2, 3)),
        ],
      ),
      child: Stack(children: [
        // 书脊
        Positioned(left: 5, top: 5, bottom: 5,
            child: Container(width: 2.5,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2)))),
        // 上下细线
        Positioned(left: 14, right: 8, top: 9, child: _line()),
        Positioned(left: 14, right: 8, bottom: 9, child: _line()),
        // 首字
        Center(child: Text(first, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: height * 0.40, fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4, offset: const Offset(1, 2))]))),
        // 右下角小星点
        Positioned(right: 7, top: 7,
            child: Icon(Icons.auto_awesome, size: width * 0.20,
                color: Colors.white.withValues(alpha: 0.45))),
      ]),
    );
  }

  Widget _line() => Container(height: 1,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(1)));
}

// ---------------- 空状态插画 ----------------

class EmptyArt extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const EmptyArt({super.key, required this.icon, required this.color,
      this.size = 92});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _EmptyPainter(icon, color),
      );
}

class _EmptyPainter extends CustomPainter {
  final IconData icon;
  final Color color;
  _EmptyPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    // 光晕
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: 0.22), color.withValues(alpha: 0)
      ]).createShader(Rect.fromCircle(center: c, radius: s.width * 0.5));
    canvas.drawCircle(c, s.width * 0.5, glow);
    // 主圆
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.35);
    canvas.drawCircle(c, s.width * 0.31, ring);
    canvas.drawCircle(c, s.width * 0.42,
        ring..color = color.withValues(alpha: 0.14));
    // 图标
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: s.width * 0.38,
          color: color.withValues(alpha: 0.85),
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EmptyPainter old) => old.color != color;
}
