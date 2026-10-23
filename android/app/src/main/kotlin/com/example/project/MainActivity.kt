package com.example.project

import android.os.Build
import android.os.Bundle
import android.os.Process
import android.system.Os
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Tesseract هنا مبني بـ OpenMP: خيوطه تنتظر بعضها بالدوران، فإذا انشغل
        // المعالج برسم التطبيق صارت الصفحة 15–40 ثانية بدل 3. خيط واحد يمنع ذلك.
        // يجب قبل تحميل libtesseract (أول استخدام لـ TessBaseAPI).
        Os.setenv("OMP_THREAD_LIMIT", "1", true)
        super.onCreate(savedInstanceState)
        useHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quickstudy/ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "hocr") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val dataPath = call.argument<String>("dataPath")!!
                val language = call.argument<String>("language")!!
                val imagePath = call.argument<String>("imagePath")!!
                val psm = call.argument<Int>("psm") ?: TessBaseAPI.PageSegMode.PSM_AUTO
                val vars = call.argument<Map<String, String>>("vars") ?: emptyMap()
                ocrThread.execute {
                    val out = runCatching { hocr(dataPath, language, imagePath, psm, vars) }
                    runOnUiThread {
                        out.fold(
                            { result.success(it) },
                            { result.error("ocr", it.message, null) },
                        )
                    }
                }
            }
    }

    // OCR على خيط بأولوية عادية: إضافة flutter_tesseract_ocr تشغّله في AsyncTask
    // بأولوية الخلفية، فيأخذ 15–22 ثانية للصفحة بدل 3 كلما رسم التطبيق شيئًا
    // (رسالة الانتظار المتحركة أو التمرير). صفحة واحدة في كل مرة.
    private val ocrThread = Executors.newSingleThreadExecutor { task ->
        Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT)
            task.run()
        }, "quickstudy-ocr")
    }
    private var tess: TessBaseAPI? = null
    private var tessLanguage = ""

    private fun hocr(
        dataPath: String,
        language: String,
        imagePath: String,
        psm: Int,
        vars: Map<String, String>,
    ): String {
        var api = tess
        if (api == null || tessLanguage != language) {
            api?.recycle()
            api = TessBaseAPI()
            check(api.init(dataPath, language)) { "Tesseract init failed" }
            tess = api
            tessLanguage = language
        }
        for ((key, value) in vars) api.setVariable(key, value)
        api.pageSegMode = psm
        api.setImage(File(imagePath))
        val text = api.getHOCRText(0)
        api.clear()
        return text
    }

    override fun onDestroy() {
        ocrThread.execute {
            tess?.recycle()
            tess = null
        }
        ocrThread.shutdown()
        super.onDestroy()
    }

    // أندرويد يخفض معدل تحديث الشاشة للتطبيق (45 هرتز على moto g75)،
    // فنطلب أعلى معدل بنفس الدقة حتى يكون التمرير ناعمًا
    private fun useHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        } ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = best.modeId
            preferredRefreshRate = best.refreshRate
        }
    }
}
