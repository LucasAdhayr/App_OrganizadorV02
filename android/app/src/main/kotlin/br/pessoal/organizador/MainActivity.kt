package br.pessoal.organizador

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Backup em Downloads/Organizador via MediaStore: não precisa de permissão de
/// armazenamento e o app só enxerga os arquivos que ele mesmo criou.
class MainActivity : FlutterActivity() {
    private val folder = "Download/Organizador"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.pessoal.organizador/backup")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "save" -> {
                            save(call.argument<String>("name")!!, call.argument<ByteArray>("bytes")!!)
                            result.success(null)
                        }
                        "list" -> result.success(list())
                        "read" -> result.success(read(call.argument<String>("uri")!!))
                        "delete" -> {
                            contentResolver.delete(Uri.parse(call.argument<String>("uri")!!), null, null)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("backup", e.message ?: e.toString(), null)
                }
            }
    }

    private fun save(name: String, bytes: ByteArray) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw Exception("Backup em arquivo precisa do Android 10 ou mais novo.")
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(MediaStore.Downloads.RELATIVE_PATH, folder)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw Exception("Não foi possível criar o arquivo em Downloads.")
        try {
            contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            throw e
        }
        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        contentResolver.update(uri, values, null, null)
    }

    private fun list(): List<Map<String, Any>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.Downloads._ID,
            MediaStore.Downloads.DISPLAY_NAME,
            MediaStore.Downloads.DATE_MODIFIED,
            MediaStore.Downloads.SIZE,
        )
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            "${MediaStore.Downloads.RELATIVE_PATH} LIKE ? AND ${MediaStore.Downloads.DISPLAY_NAME} LIKE ?",
            arrayOf("$folder%", "organizador-backup-%"),
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                out.add(
                    mapOf(
                        "name" to c.getString(1),
                        "uri" to Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString()).toString(),
                        "modified" to c.getLong(2) * 1000L,
                        "size" to c.getLong(3),
                    )
                )
            }
        }
        return out
    }

    private fun read(uri: String): ByteArray =
        contentResolver.openInputStream(Uri.parse(uri))!!.use { it.readBytes() }
}
