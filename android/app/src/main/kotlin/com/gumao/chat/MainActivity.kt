// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-KT-4CD2
package com.gumao.chat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var speech: SpeechPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 璇煶閫氶亾锛堟湕璇?+ 璇煶杈撳叆锛夛紝涓庨缚钂欑 SpeechPlugin.ets 鍏辩敤 gumao/speech 鍗忚
        speech = SpeechPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        speech?.onPermissionResult(requestCode, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        speech?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        speech?.dispose()
        speech = null
        super.onDestroy()
    }
}
