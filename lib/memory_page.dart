// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-DART-24B7
// 孤猫聊天 · 记忆页（资料库：载入 / 查看 / 删除）
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'store.dart';
import 'ui.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final p = pal();
    return Scaffold(
      backgroundColor: p.bg,
      appBar: fancyAppBar('记忆 · 资料库'),
      body: Column(children: [
        Container(
          color: Colors.white,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Expanded(child: Text('把记忆资料注入每次 AI 对话',
                style: TextStyle(fontSize: 14))),
            Switch(value: s.memEnabled, activeThumbColor: const Color(0xFF07C160),
                onChanged: (v) { setState(() { s.memEnabled = v; s.saveChats(); }); }),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160), foregroundColor: Colors.white),
            onPressed: () async {
              final f = await openFile();
              if (f == null) return;
              final bytes = await f.readAsBytes();
              final text = utf8.decode(bytes, allowMalformed: true);
              final now = DateTime.now().millisecondsSinceEpoch;
              final doc = Doc(
                  id: 'd$now',
                  name: f.name,
                  text: text.length > 1000000 ? text.substring(0, 1000000) : text,
                  ts: now);
              s.buildChunks(doc);
              setState(() => s.docs.add(doc));
              s.saveDocs();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('＋ 载入记忆资料（TXT / MD / EPUB 文本…）'),
          )),
        ),
        Expanded(child: s.docs.isEmpty
            ? Center(child: Text('还没有资料。载入后 AI 会自动检索引用。',
                style: TextStyle(color: Colors.grey.shade500)))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: s.docs.length,
                itemBuilder: (c, i) {
                  final d = s.docs[i];
                  return Card(child: ListTile(
                    leading: const Icon(Icons.description, color: Color(0xFF07C160)),
                    title: Text(d.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${d.text.length} 字 · ${d.chunks.length} 片段',
                        style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline),
                        onPressed: () { setState(() => s.docs.removeAt(i)); s.saveDocs(); }),
                    onTap: () => showDialog<void>(context: context, builder: (c) => AlertDialog(
                      title: Text(d.name),
                      content: SingleChildScrollView(child: Text(
                          d.text.length > 1500 ? '${d.text.substring(0, 1500)}…' : d.text,
                          style: const TextStyle(fontSize: 12))),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭'))],
                    )),
                  ));
                })),
      ]),
    );
  }
}
