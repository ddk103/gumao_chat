// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-EE1E
// 孤猫聊天 · 头像裁剪（1:1 正方形，可拖动/缩放）
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'ui.dart';

class AvatarCropPage extends StatefulWidget {
  final File src;
  const AvatarCropPage({super.key, required this.src});

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _key = GlobalKey();
  final _view = TransformationController();
  bool _busy = false;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _key.currentContext;
      if (ctx == null || !ctx.mounted) throw '裁剪区域未就绪';
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      // 3 倍像素，头像足够清晰
      final img = await boundary.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw '生成图片失败';
      if (!mounted) return;
      Navigator.pop<Uint8List>(context, data.buffer.asUint8List());
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        snackbar(context, '裁剪失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal();
    final size = MediaQuery.of(context).size;
    final side = (size.width < size.height ? size.width : size.height) - 48;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('调整头像'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _done,
            child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        const Spacer(),
        Center(
          child: RepaintBoundary(
            key: _key,
            child: SizedBox(
              width: side, height: side,
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _view,
                  minScale: 1.0,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Image.file(widget.src, fit: BoxFit.cover, width: side, height: side),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Text('拖动 / 双指缩放，把要用的部分放进方框里',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
              textAlign: TextAlign.center),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => setState(() => _view.value = Matrix4.identity()),
            child: Text('重置', style: TextStyle(color: p.primary)),
          ),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }
}
