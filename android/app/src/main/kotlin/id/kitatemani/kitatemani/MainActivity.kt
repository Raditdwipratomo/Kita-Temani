package id.kitatemani.kitatemani

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var filePickerChannel: FilePickerChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.kitatemani/sms",
        ).setMethodCallHandler(SmsChannel(applicationContext))

        val picker = FilePickerChannel(this)
        filePickerChannel = picker
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.kitatemani/file_picker",
        ).setMethodCallHandler(picker)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.kitatemani/pdf_preview",
        ).setMethodCallHandler(PdfPreviewChannel())
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (filePickerChannel?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
