package com.example.cafeapp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.IOException

class FilePickerPlugin: FlutterPlugin, ActivityAware, MethodCallHandler, ActivityResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity
    private var pendingResult: Result? = null
    private var pendingFilePath: String? = null

    private val CREATE_DOCUMENT_REQUEST_CODE = 43

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.simsrestocafe/file_picker")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "createDocument" -> {
                val filePath = call.argument<String>("path")
                val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                val fileName = call.argument<String>("fileName") ?: "document.pdf"

                if (filePath == null) {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                    return
                }

                pendingResult = result
                pendingFilePath = filePath

                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, fileName)
                }

                activity.startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // No-op
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        // No-op
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == CREATE_DOCUMENT_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val sourceFile = pendingFilePath?.let { File(it) }
                val targetUri = data.data

                if (sourceFile != null && targetUri != null) {
                    try {
                        val inputStream = FileInputStream(sourceFile)
                        val outputStream = activity.contentResolver.openOutputStream(targetUri)

                        if (outputStream != null) {
                            val buffer = ByteArray(1024)
                            var length: Int
                            while (inputStream.read(buffer).also { length = it } > 0) {
                                outputStream.write(buffer, 0, length)
                            }
                            outputStream.flush()
                            outputStream.close()
                            inputStream.close()

                            pendingResult?.success(true)
                        } else {
                            pendingResult?.error("WRITE_ERROR", "Failed to open output stream", null)
                        }
                    } catch (e: FileNotFoundException) {
                        pendingResult?.error("FILE_NOT_FOUND", e.message, null)
                    } catch (e: IOException) {
                        pendingResult?.error("IO_EXCEPTION", e.message, null)
                    }
                } else {
                    pendingResult?.error("INVALID_FILE", "Source file or target URI is null", null)
                }
            } else {
                // User cancelled the picker
                pendingResult?.success(false)
            }

            pendingResult = null
            pendingFilePath = null
            return true
        }
        return false
    }
}