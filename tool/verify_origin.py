#!/usr/bin/env python3
"""孤猫聊天 (gumao_chat) · 来源核对脚本

用途：判断一个 APK（或源码目录）是否来自本项目，即使对方改了应用名、包名、
图标或删掉了部分界面，仍能通过多层标识给出证据。

用法：
    python tool/verify_origin.py app-release.apk
    python tool/verify_origin.py D:\\path\\to\\suspicious-source
    python tool/verify_origin.py app.apk --json

原理（四层标识，任何一层命中都算「同源证据」）：
    1. APK 的 AndroidManifest（二进制 XML）里的 meta-data 指纹
    2. assets/trace.json 与 assets/privacy_policy.txt 里的指纹文本
    3. libapp.so 里编译进去的常量指纹与隐形水印（零宽字符）
    4. 源码目录里的版权头与 lib/trace.dart 结构指纹

注意：这是取证辅助，不是 DRM。决心彻底重写的人仍可去掉标识；
但只要对方是「拿走源码改个名字」或「反编译后小改」，本脚本基本都能命中。
"""
import json
import os
import sys
import zipfile

# Windows 控制台默认 GBK，统一成 UTF-8，避免中文 / 符号打印崩溃
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

TRACE_ID = "GMCHAT-7C41-A9E3-52D8"
WATERMARK = "GMCHAT\u200b\u200d\u200c\u2060-TRACE-7C41-A9E3-52D8\u200b"
MODULE_FINGERPRINTS = [
    "gumao_speech_channel",
    "meAliases",
    "buildChunks",
    "kAppVersion",
    "PolyForm Noncommercial",
]

# 命中任意一个即视为同源证据
MARKERS = [TRACE_ID, WATERMARK, *MODULE_FINGERPRINTS]


def _encodings(s: str):
    yield s.encode("utf-8")
    yield s.encode("utf-16-le")


def _find_in_bytes(blob: bytes, text: str) -> bool:
    return any(enc in blob for enc in _encodings(text))


def scan_apk(path: str) -> dict:
    hits = []
    total = 0
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        total = sum(i.file_size for i in z.infolist())

        # 1) 清单与资产（文本）
        for name in names:
            if name in ("AndroidManifest.xml", "assets/trace.json",
                        "assets/privacy_policy.txt", "assets/flutter_assets/assets/trace.json",
                        "assets/flutter_assets/assets/privacy_policy.txt"):
                blob = z.read(name)
                for m in MARKERS:
                    if _find_in_bytes(blob, m):
                        hits.append({"where": name, "marker": m})

        # 2) 编译产物（二进制快照 / 引擎库）
        for name in names:
            if name.endswith((".so", ".dex", ".bin")) or name.startswith("assets/flutter_assets/kernel_blob"):
                try:
                    blob = z.read(name)
                except Exception:
                    continue
                for m in MARKERS:
                    if _find_in_bytes(blob, m):
                        hits.append({"where": name, "marker": m})

        # 3) 包名 / 应用名（仅作参考，不作为判定依据）
        info = {"apk": path, "entries": len(names), "uncompressed_bytes": total}
    return {"target": info, "hits": hits}


def scan_dir(path: str) -> dict:
    hits = []
    files = 0
    for root, _dirs, names in os.walk(path):
        # 跳过构建产物与依赖缓存，避免自己命中自己
        if any(seg in root for seg in ("/build", "\\build", ".dart_tool", ".git", "node_modules")):
            continue
        for name in names:
            if not name.endswith((".dart", ".kt", ".kts", ".xml", ".json", ".txt", ".md", ".yaml")):
                continue
            files += 1
            full = os.path.join(root, name)
            try:
                with open(full, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
            except OSError:
                continue
            for m in MARKERS:
                if m in text:
                    hits.append({"where": os.path.relpath(full, path), "marker": m})
    return {"target": {"dir": path, "text_files": files}, "hits": hits}


def summarize(result: dict) -> int:
    hits = result["hits"]
    uniq = sorted({h["where"] for h in hits})
    print("=" * 60)
    print("孤猫聊天 · 来源核对")
    print("目标：", result["target"])
    print(f"命中：{len(hits)} 处，涉及 {len(uniq)} 个文件")
    for h in hits[:40]:
        print(f"  [+] {h['where']}  <-  {h['marker']}")
    if len(hits) > 40:
        print(f"  … 其余 {len(hits) - 40} 处省略")
    print("-" * 60)
    if hits:
        print("结论：高度疑似由「孤猫聊天」源码构建或修改而来。")
        print("      代码指纹为：", TRACE_ID)
        print("      许可：PolyForm Noncommercial 1.0.0 —— 商业使用需书面授权。")
        print("      请保留上述证据（文件路径 + 命中标识）用于沟通或维权。")
        return 0
    print("结论：未发现本项目标识。可能不是同源，或标识已被刻意清除；")
    print("      可继续比对结构指纹（chat_page/chat_parse/llm/store 的类与方法命名）。")
    return 2


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    as_json = "--json" in sys.argv
    if not args:
        print(__doc__)
        return 1
    target = args[0]
    if not os.path.exists(target):
        print("路径不存在：", target)
        return 1
    result = scan_apk(target) if os.path.isfile(target) else scan_dir(target)
    if as_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["hits"] else 2
    return summarize(result)


if __name__ == "__main__":
    raise SystemExit(main())
