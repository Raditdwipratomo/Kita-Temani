package id.kitatemani.kitatemani

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class PdfPreviewChannel : MethodChannel.MethodCallHandler {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler: Handler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPageCount" -> handleGetPageCount(call, result)
            "renderPage" -> handleRenderPage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleGetPageCount(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath").orEmpty().trim()
        if (filePath.isEmpty()) {
            result.error("INVALID_ARGS", "filePath wajib diisi", null)
            return
        }

        executor.execute {
            val file = File(filePath)
            if (!file.exists() || !file.isFile) {
                mainHandler.post {
                    result.error("FILE_NOT_FOUND", "File PDF tidak ditemukan", null)
                }
                return@execute
            }

            var pfd: ParcelFileDescriptor? = null
            var renderer: PdfRenderer? = null
            try {
                pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                renderer = PdfRenderer(pfd)
                val count = renderer.pageCount
                mainHandler.post { result.success(count) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error(
                        "PDF_ERROR",
                        e.message ?: "Gagal membaca dokumen PDF",
                        null,
                    )
                }
            } finally {
                try {
                    renderer?.close()
                } catch (_: Exception) {
                }
                try {
                    pfd?.close()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun handleRenderPage(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath").orEmpty().trim()
        val pageIndex = call.argument<Int>("pageIndex") ?: -1
        val requestedWidth = call.argument<Int>("targetWidth") ?: 1080
        val targetWidth = requestedWidth.coerceIn(320, 1600)

        if (filePath.isEmpty() || pageIndex < 0) {
            result.error("INVALID_ARGS", "Argumen render halaman PDF tidak valid", null)
            return
        }

        executor.execute {
            val file = File(filePath)
            if (!file.exists() || !file.isFile) {
                mainHandler.post {
                    result.error("FILE_NOT_FOUND", "File PDF tidak ditemukan", null)
                }
                return@execute
            }

            var pfd: ParcelFileDescriptor? = null
            var renderer: PdfRenderer? = null
            var page: PdfRenderer.Page? = null
            var bitmap: Bitmap? = null
            try {
                pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                renderer = PdfRenderer(pfd)
                if (pageIndex >= renderer.pageCount) {
                    mainHandler.post {
                        result.error("INDEX_OUT_OF_RANGE", "Halaman PDF di luar batas", null)
                    }
                    return@execute
                }

                page = renderer.openPage(pageIndex)
                val srcWidth = max(1, page.width)
                val srcHeight = max(1, page.height)
                val targetHeight = max(1, (targetWidth.toFloat() * srcHeight / srcWidth).roundToInt())

                bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 95, out)
                val pngBytes = out.toByteArray()
                mainHandler.post { result.success(pngBytes) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error(
                        "PDF_RENDER_ERROR",
                        e.message ?: "Gagal merender halaman PDF",
                        null,
                    )
                }
            } finally {
                try {
                    bitmap?.recycle()
                } catch (_: Exception) {
                }
                try {
                    page?.close()
                } catch (_: Exception) {
                }
                try {
                    renderer?.close()
                } catch (_: Exception) {
                }
                try {
                    pfd?.close()
                } catch (_: Exception) {
                }
            }
        }
    }
}
