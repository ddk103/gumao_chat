// 孤猫聊天 (gumao_chat) · Copyright (c) 2026 孤猫聊天 contributors
// 许可：PolyForm Noncommercial 1.0.0 —— 商业使用需取得书面授权
// Trace: GMCHAT-KT-19C9
// 孤猫聊天 · 安卓原生语音插件
// 对应 Dart 侧 lib/speech.dart 的 gumao/speech 通道。
//   · 朗读：系统 TextToSpeech 引擎（各手机自带，如 讯飞 / 华为 / 三星 / Google 语音服务）
//   · 识别：系统 SpeechRecognizer；设备没有识别服务时降级为「只录音」
//           录好的 16k/16bit/mono WAV 交给 Dart 侧走用户自己接口的在线转录
package com.gumao.chat

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class SpeechPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "gumao/speech"
        private const val REQ_MIC = 0x6D01
        private const val REQ_ASR_UI = 0x6D02
        private const val SAMPLE_RATE = 16000
        private const val MAX_PCM = SAMPLE_RATE * 2 * 60 // 最多 60 秒
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    // ---------------- TTS ----------------
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsFailed = false
    private var voices: List<Voice> = emptyList()
    private var utteranceSeq = 0

    // ---------------- ASR ----------------
    private var recognizer: SpeechRecognizer? = null
    private var listening = false
    private var recording = false
    private var recordOnly = false
    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null
    private val pcm = ByteArrayOutputStream()
    private var lastWav = ""
    private var lastText = ""
    private var pendingMicResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    // ================= 通道入口 =================

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "check" -> result.success(checkMap())
            "asrStart" -> doAsrStart(result)
            "asrStop" -> doAsrStop(result)
            "asrCancel" -> doAsrCancel(result)
            "ttsSpeak" -> doTtsSpeak(call, result)
            "ttsStop" -> {
                try { tts?.stop() } catch (_: Throwable) {}
                result.success(mapOf("ok" to true))
            }
            "ttsListVoices" -> prepareVoices { result.success(listVoices()) }
            "ttsVoicePacks" -> prepareVoices { result.success(voicePacks()) }
            "ttsDownloadMale" -> {
                emit("voiceError", mapOf(
                    "message" to "安卓的音色由系统语音引擎管理，不能在应用内下载。请到「设置 → 语言和输入 → 文字转语音」安装中文语音数据（或装讯飞 / Google 语音服务）",
                    "code" to -3,
                ))
                result.success(mapOf("ok" to false, "state" to "failed"))
            }
            "ttsResetDownload" -> result.success(mapOf("ok" to true))
            "openTtsSettings" -> result.success(mapOf("ok" to openTtsSettings()))
            else -> result.notImplemented()
        }
    }

    /** 原生事件统一抛给 Dart（必须回主线程） */
    private fun emit(event: String, detail: Map<String, Any?>) {
        val msg = mapOf("event" to event, "detail" to detail)
        main.post {
            try { channel.invokeMethod("speechEvent", msg) } catch (_: Throwable) {}
        }
    }

    // ================= 能力探测 =================

    private fun hasTtsEngine(): Boolean = try {
        activity.packageManager.queryIntentServices(
            Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE), 0
        ).isNotEmpty()
    } catch (_: Throwable) {
        false
    }

    private fun hasAsrEngine(): Boolean = try {
        SpeechRecognizer.isRecognitionAvailable(activity)
    } catch (_: Throwable) {
        false
    }

    /** 打开系统的「文字转语音」设置页，方便用户直接去装中文语音数据 */
    private fun openTtsSettings(): Boolean {
        val tries = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(android.provider.Settings.ACTION_SETTINGS),
        )
        for (i in tries) {
            try {
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(i)
                return true
            } catch (_: Throwable) {}
        }
        return false
    }

    private fun hasMic(): Boolean =
        if (Build.VERSION.SDK_INT >= 23) {
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        } else true

    private fun checkMap(): Map<String, Any?> {
        val asr = hasAsrEngine()
        val tts = hasTtsEngine()
        val note = when {
            !tts && !asr -> "本机没有系统语音引擎：朗读需在系统设置里装中文语音包，语音输入会录音后走你配置的接口转录"
            !tts -> "本机没有系统语音合成引擎，朗读需先在系统设置里安装中文语音包"
            !asr -> "本机没有系统语音识别服务，语音输入会录音后走你配置的接口转录"
            else -> "系统语音引擎已就绪"
        }
        return mapOf(
            "asr" to asr,
            "tts" to tts,
            "mic" to true,
            "offline" to asr,
            "note" to note,
        )
    }

    // ================= TTS =================

    private fun ensureTts() {
        if (tts != null) return
        tts = TextToSpeech(activity) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            ttsFailed = !ttsReady
            if (ttsReady) prepareVoiceList()
        }
    }

    private fun prepareVoiceList() {
        val t = tts ?: return
        try {
            val all = t.voices ?: return
            val zh = all.filter {
                val l = try { it.locale.language.lowercase(Locale.ROOT) } catch (_: Throwable) { "" }
                l == "zh" || l == "cmn" || l == "yue"
            }.sortedBy { it.name ?: "" }
            voices = if (zh.isNotEmpty()) zh else all.sortedBy { it.name ?: "" }
        } catch (_: Throwable) {
            voices = emptyList()
        }
    }

    /** 等引擎初始化（最多约 4 秒），然后回调；超时/失败也回调，让业务侧给出提示 */
    private fun prepareVoices(attempt: Int = 0, action: () -> Unit) {
        if (ttsReady || ttsFailed) { action(); return }
        ensureTts()
        if (attempt >= 40) { action(); return }
        main.postDelayed({ prepareVoices(attempt + 1, action) }, 100)
    }

    private fun isMaleVoice(v: Voice): Boolean = try {
        val s = ((v.name ?: "") + " " + v.features.joinToString(" ")).lowercase(Locale.ROOT)
        s.contains("male") && !s.contains("female")
    } catch (_: Throwable) {
        false
    }

    private fun listVoices(): List<Map<String, Any?>> = voices.mapIndexed { i, v ->
        mapOf(
            "language" to (try { v.locale.toLanguageTag() } catch (_: Throwable) { "zh-CN" }),
            "person" to (i + 1),
            "style" to "default",
            "gender" to if (isMaleVoice(v)) "male" else "female",
            "description" to (v.name ?: "音色 ${i + 1}"),
            "status" to "INSTALLED",
            "installed" to true,
        )
    }

    private fun voicePacks(): Map<String, Any?> {
        val packs = listVoices()
        val maleIdx = packs.indexOfFirst { it["gender"] == "male" }
        val malePerson = if (maleIdx >= 0) (maleIdx + 1) else -1
        return mapOf(
            "voices" to packs,
            "malePerson" to malePerson,
            "male" to (malePerson >= 0),
            "systemInstalled" to malePerson,
            "downloadable" to false,
            "candidate" to malePerson,
        )
    }

    private fun voiceFor(person: Int): Voice? {
        if (person <= 0) return null
        return voices.getOrNull(person - 1)
    }

    private fun noEngineMsg() =
        "本机没有可用的系统语音合成引擎。请到「设置 → 语言和输入 → 文字转语音」安装中文语音数据（或安装讯飞 / Google 语音服务）后重试"

    private fun doTtsSpeak(call: MethodCall, result: MethodChannel.Result) {
        val text = (call.argument<String>("text") ?: "").trim()
        if (text.isEmpty()) { result.success(mapOf("ok" to false)); return }
        val person = call.argument<Int>("person") ?: 1
        val speed = (call.argument<Double>("speed") ?: 1.0).toFloat()
        val pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat()
        val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
        speakWhenReady(text, person, speed, pitch, volume, result, 0)
    }

    private fun speakWhenReady(
        text: String, person: Int, speed: Float, pitch: Float, volume: Float,
        result: MethodChannel.Result, attempt: Int,
    ) {
        if (ttsReady) { doSpeak(text, person, speed, pitch, volume, result); return }
        if (ttsFailed) { result.error("TTS_UNAVAILABLE", noEngineMsg(), null); return }
        ensureTts()
        if (attempt >= 40) {
            result.error("TTS_ENGINE", "语音引擎初始化超时，请稍后重试或在系统设置里检查文字转语音引擎", null)
            return
        }
        main.postDelayed({ speakWhenReady(text, person, speed, pitch, volume, result, attempt + 1) }, 100)
    }

    private fun doSpeak(
        text: String, person: Int, speed: Float, pitch: Float, volume: Float,
        result: MethodChannel.Result,
    ) {
        val t = tts ?: run {
            result.error("TTS_ENGINE", noEngineMsg(), null); return
        }
        try {
            val v = voiceFor(person)
            if (v != null) {
                try { t.voice = v } catch (_: Throwable) {}
            } else {
                // 没指定到具体音色（鸿蒙音色编号 13/21 在安卓不存在）时用系统默认中文
                val r = t.setLanguage(Locale.SIMPLIFIED_CHINESE)
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                    result.error("TTS_LANG", "系统语音引擎里没有中文语音数据，请到「文字转语音」设置里下载中文", null)
                    return
                }
            }
            t.setSpeechRate(speed.coerceIn(0.5f, 2.0f))
            t.setPitch(pitch.coerceIn(0.5f, 2.0f))
            t.setOnUtteranceProgressListener(progress)
            val params = Bundle()
            params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume.coerceIn(0f, 1f))
            val id = "gm" + (++utteranceSeq) + "_" + System.currentTimeMillis()
            val code = t.speak(text.take(4000), TextToSpeech.QUEUE_FLUSH, params, id)
            if (code != TextToSpeech.SUCCESS) {
                result.error("TTS_SPEAK", "语音合成启动失败，可能是系统语音引擎未就绪", null)
                return
            }
            result.success(mapOf("ok" to true, "person" to person, "simulated" to false))
        } catch (e: Throwable) {
            result.error("TTS_SPEAK", e.message ?: "语音合成失败", null)
        }
    }

    private val progress = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {
            emit("ttsState", mapOf("state" to "start", "id" to utteranceId))
        }

        override fun onDone(utteranceId: String?) {
            emit("ttsState", mapOf("state" to "done", "id" to utteranceId))
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) {
            emit("ttsState", mapOf("state" to "error", "id" to utteranceId, "message" to "语音合成出错"))
        }

        override fun onError(utteranceId: String?, errorCode: Int) {
            emit("ttsState", mapOf(
                "state" to "error", "id" to utteranceId, "code" to errorCode,
                "message" to "语音合成出错（$errorCode）",
            ))
        }

        override fun onStop(utteranceId: String?, interrupted: Boolean) {
            emit("ttsState", mapOf("state" to "stop", "id" to utteranceId))
        }
    }

    // ================= ASR =================

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQ_MIC) return
        val r = pendingMicResult ?: return
        pendingMicResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startListening(r)
        } else {
            r.error("MIC_DENIED", "麦克风权限未开启，请到系统设置里允许本应用使用麦克风", null)
        }
    }

    private fun doAsrStart(result: MethodChannel.Result) {
        if (recording) {
            result.success(mapOf("ok" to true, "mode" to if (recordOnly) "recordOnly" else "offline"))
            return
        }
        if (!hasMic()) {
            pendingMicResult = result
            if (Build.VERSION.SDK_INT >= 23) {
                activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQ_MIC)
            } else {
                pendingMicResult = null
                result.error("MIC_DENIED", "麦克风权限未开启", null)
            }
            return
        }
        startListening(result)
    }

    private fun startListening(result: MethodChannel.Result) {
        lastText = ""
        lastWav = ""
        recording = true
        if (hasAsrEngine()) {
            recordOnly = false
            startRecognizer()
            emit("asrState", mapOf("state" to "listening"))
            result.success(mapOf("ok" to true, "mode" to "offline"))
            return
        }
        // 没有可用的系统识别服务时，先试系统自带的「语音输入」界面（国产 ROM 常见）
        if (startSystemRecognizer()) {
            recordOnly = false
            emit("asrState", mapOf("state" to "listening"))
            result.success(mapOf("ok" to true, "mode" to "system"))
            return
        }
        recordOnly = true
        if (startRecorder()) {
            emit("asrState", mapOf("state" to "recordOnly"))
            result.success(mapOf("ok" to true, "mode" to "recordOnly"))
        } else {
            recording = false
            result.error("REC_FAILED", "无法启动录音，请检查是否有其它应用正在占用麦克风", null)
        }
    }

    /** 拉起系统语音输入界面，结果走 onActivityResult 回来 */
    private fun startSystemRecognizer(): Boolean = try {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "请说话，说完会自动返回")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        if (intent.resolveActivity(activity.packageManager) == null) {
            false
        } else {
            activity.startActivityForResult(intent, REQ_ASR_UI)
            true
        }
    } catch (_: Throwable) {
        false
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQ_ASR_UI) return
        recording = false
        if (resultCode == Activity.RESULT_OK) {
            val t = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()?.trim().orEmpty()
            if (t.isNotEmpty()) {
                lastText = t
                emit("asrText", mapOf("text" to t, "final" to true))
                emit("asrDone", mapOf("text" to t))
            } else {
                emit("asrError", mapOf("code" to -2, "message" to "没有识别到内容"))
            }
        } else {
            emit("asrError", mapOf("code" to -3, "message" to "已取消语音输入"))
        }
        emit("asrState", mapOf("state" to "idle"))
    }

    private fun startRecognizer() {
        try {
            if (recognizer == null) {
                recognizer = SpeechRecognizer.createSpeechRecognizer(activity)
                recognizer?.setRecognitionListener(listener)
            }
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "zh-CN")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
            }
            recognizer?.startListening(intent)
            listening = true
        } catch (e: Throwable) {
            listening = false
            emit("asrError", mapOf("code" to -1, "message" to (e.message ?: "语音识别启动失败")))
        }
    }

    private fun bestText(results: Bundle?): String {
        val arr = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return arr?.firstOrNull()?.trim() ?: ""
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            emit("asrState", mapOf("state" to "listening"))
        }

        override fun onBeginningOfSpeech() {
            emit("asrState", mapOf("state" to "speaking"))
        }

        override fun onRmsChanged(rmsdB: Float) {}

        override fun onBufferReceived(buffer: ByteArray?) {}

        override fun onEndOfSpeech() {
            emit("asrState", mapOf("state" to "silence"))
        }

        override fun onError(error: Int) {
            listening = false
            if (!recording) return
            // 「没听清 / 说话超时」这类不算错，继续听下一句
            if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                main.postDelayed({ if (recording && !recordOnly) startRecognizer() }, 300)
                return
            }
            if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                recording = false
                emit("asrError", mapOf("code" to error, "message" to "麦克风权限未开启"))
                return
            }
            emit("asrError", mapOf("code" to error, "message" to errorText(error)))
            // 偶发的 busy / client 错误自动重试，避免用户点一次就断了
            if (recording && (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY ||
                        error == SpeechRecognizer.ERROR_CLIENT || error == SpeechRecognizer.ERROR_AUDIO)) {
                main.postDelayed({ if (recording && !recordOnly) startRecognizer() }, 500)
            }
        }

        override fun onResults(results: Bundle?) {
            listening = false
            val t = bestText(results)
            if (t.isNotEmpty()) {
                lastText = t
                emit("asrText", mapOf("text" to t, "final" to true))
                emit("asrDone", mapOf("text" to t))
            }
            // 说完一句继续听，支持连续口述
            if (recording && !recordOnly) {
                main.postDelayed({ if (recording && !recordOnly) startRecognizer() }, 250)
            }
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val t = bestText(partialResults)
            if (t.isNotEmpty()) emit("asrText", mapOf("text" to t, "final" to false))
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    private fun errorText(code: Int): String = when (code) {
        SpeechRecognizer.ERROR_AUDIO -> "录音出错"
        SpeechRecognizer.ERROR_CLIENT -> "识别服务连接失败"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "麦克风权限未开启"
        SpeechRecognizer.ERROR_NETWORK -> "网络不可用，无法用在线识别"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络超时"
        SpeechRecognizer.ERROR_NO_MATCH -> "没听清"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别服务忙，请稍后再试"
        SpeechRecognizer.ERROR_SERVER -> "识别服务返回错误"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没听到声音"
        else -> "识别失败（$code）"
    }

    private fun doAsrStop(result: MethodChannel.Result) {
        if (!recording) { result.success(mapOf("ok" to true)); return }
        recording = false
        if (recordOnly) {
            stopRecorder(emitWav = true)
        } else {
            try { recognizer?.stopListening() } catch (_: Throwable) {}
        }
        emit("asrState", mapOf("state" to "idle"))
        result.success(mapOf("ok" to true))
    }

    private fun doAsrCancel(result: MethodChannel.Result) {
        recording = false
        if (recordOnly) {
            stopRecorder(emitWav = false)
        } else {
            try { recognizer?.cancel() } catch (_: Throwable) {}
        }
        emit("asrState", mapOf("state" to "idle"))
        result.success(mapOf("ok" to true))
    }

    // ---------- 录音（无识别服务时的兜底） ----------

    private fun startRecorder(): Boolean = try {
        val min = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = if (min > 0) min * 2 else 8192
        val ar = AudioRecord(
            MediaRecorder.AudioSource.MIC, SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufSize
        )
        if (ar.state != AudioRecord.STATE_INITIALIZED) {
            try { ar.release() } catch (_: Throwable) {}
            false
        } else {
            synchronized(pcm) { pcm.reset() }
            ar.startRecording()
            audioRecord = ar
            val th = Thread {
                val b = ByteArray(4096)
                while (recording && recordOnly) {
                    val n = try { ar.read(b, 0, b.size) } catch (_: Throwable) { -1 }
                    if (n < 0) break
                    if (n > 0) {
                        synchronized(pcm) { pcm.write(b, 0, n) }
                        val size = synchronized(pcm) { pcm.size() }
                        if (size >= MAX_PCM) {
                            main.post {
                                if (recording && recordOnly) {
                                    recording = false
                                    stopRecorder(emitWav = true)
                                    emit("asrState", mapOf("state" to "idle"))
                                }
                            }
                            break
                        }
                    }
                }
            }
            th.isDaemon = true
            th.start()
            recordThread = th
            true
        }
    } catch (e: Throwable) {
        false
    }

    private fun stopRecorder(emitWav: Boolean) {
        try { audioRecord?.stop() } catch (_: Throwable) {}
        try { audioRecord?.release() } catch (_: Throwable) {}
        audioRecord = null
        recordThread = null
        val bytes = synchronized(pcm) {
            val b = pcm.toByteArray()
            pcm.reset()
            b
        }
        if (emitWav && bytes.isNotEmpty()) {
            val path = writeWav(bytes)
            lastWav = path
            emit("asrRecorded", mapOf("wav" to path, "bytes" to bytes.size))
        }
    }

    /** 16k / 16bit / 单声道 WAV，供 Dart 侧在线转录 */
    private fun writeWav(data: ByteArray): String {
        return try {
            val dir = activity.cacheDir
            val f = File(dir, "gm_asr_" + System.currentTimeMillis() + ".wav")
            val header = ByteArray(44)
            fun str(off: Int, s: String) { for (i in s.indices) header[off + i] = s[i].code.toByte() }
            fun u32(off: Int, v: Int) {
                header[off] = (v and 0xff).toByte()
                header[off + 1] = ((v ushr 8) and 0xff).toByte()
                header[off + 2] = ((v ushr 16) and 0xff).toByte()
                header[off + 3] = ((v ushr 24) and 0xff).toByte()
            }
            fun u16(off: Int, v: Int) {
                header[off] = (v and 0xff).toByte()
                header[off + 1] = ((v ushr 8) and 0xff).toByte()
            }
            str(0, "RIFF"); u32(4, 36 + data.size); str(8, "WAVE")
            str(12, "fmt "); u32(16, 16); u16(20, 1); u16(22, 1)
            u32(24, SAMPLE_RATE); u32(28, SAMPLE_RATE * 2); u16(32, 2); u16(34, 16)
            str(36, "data"); u32(40, data.size)
            FileOutputStream(f).use { out ->
                out.write(header)
                out.write(data)
                out.flush()
            }
            f.absolutePath
        } catch (e: Throwable) {
            ""
        }
    }

    // ================= 释放 =================

    fun dispose() {
        recording = false
        try { recognizer?.destroy() } catch (_: Throwable) {}
        recognizer = null
        try { audioRecord?.release() } catch (_: Throwable) {}
        audioRecord = null
        try { tts?.stop() } catch (_: Throwable) {}
        try { tts?.shutdown() } catch (_: Throwable) {}
        tts = null
        ttsReady = false
    }
}
