package id.kitatemani.kitatemani

import android.content.Context
import android.os.Build
import android.telephony.SmsManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "sendSms") {
            result.notImplemented()
            return
        }
        val numbers = call.argument<List<String>>("numbers").orEmpty()
        val text = call.argument<String>("text").orEmpty()
        try {
            val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = manager.divideMessage(text)
            numbers.forEach {
                manager.sendMultipartTextMessage(it, null, parts, null, null)
            }
            result.success(null)
        } catch (e: SecurityException) {
            result.error("SMS_PERMISSION", "Izin SMS belum diberikan", null)
        }
    }
}
