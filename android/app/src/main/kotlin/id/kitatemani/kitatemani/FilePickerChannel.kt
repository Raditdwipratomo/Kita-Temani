package id.kitatemani.kitatemani

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

class FilePickerChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private var pendingResult: MethodChannel.Result? = null
    private var pendingMaxBytes: Long = DEFAULT_MAX_DOCUMENT_BYTES
    private var pendingAllowedExtensions: Set<String> = DEFAULT_ALLOWED_EXTENSIONS

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickDocument") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error("ALREADY_ACTIVE", "Pemilih berkas sedang dibuka", null)
            return
        }
        pendingResult = result

        val requestedMimes = call.argument<List<String>>("mimeTypes")
            ?.filter { it.isNotBlank() }
            ?.toTypedArray()
            ?.takeIf { it.isNotEmpty() }
            ?: DEFAULT_MIME_TYPES

        val requestedExtensions = call.argument<List<String>>("extensions")
            ?.map { it.trim().lowercase() }
            ?.filter { it.isNotEmpty() }
            ?.toSet()
            ?.takeIf { it.isNotEmpty() }
            ?: DEFAULT_ALLOWED_EXTENSIONS

        pendingMaxBytes = (call.argument<Number>("maxBytes")?.toLong())
            ?.takeIf { it > 0L }
            ?: DEFAULT_MAX_DOCUMENT_BYTES
        pendingAllowedExtensions = requestedExtensions

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, requestedMimes)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_DOCUMENT)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_DOCUMENT) return false
        val result = pendingResult ?: return true
        val maxBytes = pendingMaxBytes
        val allowedExtensions = pendingAllowedExtensions
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }

        val uri = data.data!!
        try {
            val copied = copyToCache(uri, maxBytes, allowedExtensions)
            result.success(copied)
        } catch (e: Exception) {
            result.error("FILE_READ_ERROR", e.message, null)
        }
        return true
    }

    private fun copyToCache(
        uri: Uri,
        maxBytes: Long,
        allowedExtensions: Set<String>,
    ): Map<String, Any> {
        val resolver = activity.contentResolver
        var displayName = "lampiran_${System.currentTimeMillis()}"
        var queriedSize: Long = -1L

        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIdx >= 0) {
                    val value = cursor.getString(nameIdx)
                    if (!value.isNullOrBlank()) displayName = value
                }
                val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) {
                    queriedSize = cursor.getLong(sizeIdx)
                }
            }
        }

        val ext = displayName.substringAfterLast('.', "").trim().lowercase()
        if (ext.isEmpty() || ext !in allowedExtensions) {
            return mapOf(
                "error" to "UNSUPPORTED_FORMAT",
                "name" to displayName,
            )
        }

        if (queriedSize > maxBytes) {
            return mapOf(
                "error" to "FILE_TOO_LARGE",
                "name" to displayName,
                "size" to queriedSize,
            )
        }

        val safeName = displayName.replace(Regex("[^\\w.\\-]"), "_")
        val outFile = File(activity.cacheDir, "${System.currentTimeMillis()}_$safeName")
        var totalBytes = 0L

        resolver.openInputStream(uri)?.use { input ->
            outFile.outputStream().use { output ->
                val buffer = ByteArray(8192)
                while (true) {
                    val read = input.read(buffer)
                    if (read == -1) break
                    totalBytes += read
                    if (totalBytes > maxBytes) {
                        break
                    }
                    output.write(buffer, 0, read)
                }
            }
        } ?: return mapOf(
            "error" to "READ_FAILED",
            "name" to displayName,
        )

        if (totalBytes > maxBytes) {
            outFile.delete()
            return mapOf(
                "error" to "FILE_TOO_LARGE",
                "name" to displayName,
                "size" to totalBytes,
            )
        }

        if (totalBytes <= 0L) {
            outFile.delete()
            return mapOf(
                "error" to "EMPTY_FILE",
                "name" to displayName,
                "size" to 0L,
            )
        }

        return mapOf(
            "name" to displayName,
            "path" to outFile.absolutePath,
            "size" to totalBytes,
        )
    }

    companion object {
        private const val REQUEST_CODE_PICK_DOCUMENT = 9412
        private const val DEFAULT_MAX_DOCUMENT_BYTES = 2L * 1024L * 1024L
        private val DEFAULT_ALLOWED_EXTENSIONS = setOf("pdf", "docx")
        private val DEFAULT_MIME_TYPES = arrayOf(
            "application/pdf",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        )
    }
}
