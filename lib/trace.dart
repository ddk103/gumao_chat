// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// License: PolyForm Noncommercial 1.0.0 — 商业使用需取得书面授权
// Trace: GMCHAT-DART-TRACE-CORE-7C41
//
// 来源指纹模块：项目标识 + 隐形水印 + 隐藏的来源校验入口。
// 说明：这不是 DRM，也不能阻止决心去标识的人；它的作用是让「原样搬运 / 小改后商用」
// 留下可核对、可举证的痕迹。改动本项目时请保留本文件与其中的常量。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui.dart';

/// 项目唯一标识（APK 的 AndroidManifest、assets/trace.json 里各有一份）
const String kTraceId = 'GMCHAT-7C41-A9E3-52D8';

/// 项目名与许可（用于隐藏校验页展示）
const String kTraceProject = '孤猫聊天（gumao_chat）';
const String kTraceLicense = 'PolyForm Noncommercial 1.0.0';

/// 官方源码地址：开源发布时请改成真实仓库地址，校验页会展示给用户
const String kTraceSourceUrl = 'https://github.com/ddk103/gumao_chat';

/// 隐形水印：含零宽字符（U+200B / U+200D / U+200C / U+2060），
/// 肉眼看不见，但复制、搜索、strings 提取都能命中。
/// 这些字符是有意保留的，请勿格式化删除。
const String kTraceWatermark =
    'GMCHAT\u200B\u200D\u200C\u2060-TRACE-7C41-A9E3-52D8\u200B';

/// 常见「洗稿」手法的对照标识：源码结构指纹（模块名组合，改名也难全部抹掉）
const List<String> kTraceModules = [
  'chat_page/StreamHandle',
  'chat_parse/meAliases',
  'llm/buildSystem',
  'store/Doc.buildChunks',
  'speech/gumao_speech_channel',
  'mine_page/kAppVersion',
];

/// App 内展示的指纹文本（隐藏页 / 复制用）
String traceSummary() => [
      '项目：$kTraceProject',
      '版本：0.1.0',
      '源码指纹：$kTraceId',
      '许可：$kTraceLicense（个人 / 研究 / 非营利免费，商业使用需授权）',
      '官方源码：$kTraceSourceUrl',
      '水印串：$kTraceWatermark',
      '结构指纹：${kTraceModules.join(' · ')}',
    ].join('\n');

/// 检查一段文本是否包含本项目的任一标识；返回命中的标识，未命中返回空列表。
List<String> traceMatches(String text) {
  final out = <String>[];
  if (text.contains(kTraceId)) out.add('项目指纹 $kTraceId');
  if (text.contains('GMCHAT\u200B\u200D')) out.add('隐形水印');
  if (text.contains('gumao_speech_channel')) out.add('语音通道结构指纹');
  if (text.contains('PolyForm Noncommercial')) out.add('许可文本');
  return out;
}

/// 隐藏的来源校验页：只在「关于与许可 → 长按版本号」或
/// 「我的页标题连点 7 次」时出现，普通用户不会看到。
Future<void> showTraceDialog(BuildContext context) {
  final p = pal();
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: p.surface,
      title: Text('来源校验', style: TextStyle(color: p.ink, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('本应用的固定标识如下，用于核对来源：',
                style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.6)),
            const SizedBox(height: 8),
            SelectableText(traceSummary(),
                style: TextStyle(color: p.ink, fontSize: 11.5, height: 1.7)),
            const SizedBox(height: 10),
            Text(
              '如果你在应用商店、网盘或他人处付费购买了本应用，或看到有人删除这些标识后'
              '商用，可凭上述指纹核对来源，并向作者反馈。'
              '本项目允许个人与研究免费使用，商业使用需取得书面授权。',
              style: TextStyle(color: p.muted, fontSize: 11.5, height: 1.6),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: traceSummary()));
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('来源指纹已复制，可发给作者核对')));
          },
          child: Text('复制指纹', style: TextStyle(color: p.primary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text('关闭', style: TextStyle(color: p.primary)),
        ),
      ],
    ),
  );
}
