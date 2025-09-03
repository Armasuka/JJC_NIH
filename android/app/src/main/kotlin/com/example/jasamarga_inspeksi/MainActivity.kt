package com.example.jasamarga_inspeksi

import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.jasamarga_inspeksi/file_intent"
    private var sharedFilePath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFilePath" -> {
                    Log.d("MainActivity", "getSharedFilePath called, returning: $sharedFilePath")
                    result.success(sharedFilePath)
                    sharedFilePath = null // Reset after sending
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent called with action: ${intent.action}")
        handleIntent(intent)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate called")
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        Log.d("MainActivity", "handleIntent called with action: ${intent.action}")
        Log.d("MainActivity", "Intent data: ${intent.data}")
        Log.d("MainActivity", "Intent extras: ${intent.extras}")
        
        when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                Log.d("MainActivity", "ACTION_VIEW uri: $uri")
                if (uri != null) {
                    val path = getFilePathFromUri(uri)
                    Log.d("MainActivity", "Extracted path: $path")
                    if (path != null && (path.endsWith(".zip") || path.endsWith(".json"))) {
                        sharedFilePath = path
                        Log.d("MainActivity", "Set sharedFilePath to: $sharedFilePath")
                        // Notify Flutter immediately
                        methodChannel?.invokeMethod("fileReceived", path)
                    }
                }
            }
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                Log.d("MainActivity", "ACTION_SEND uri: $uri")
                if (uri != null) {
                    val path = getFilePathFromUri(uri)
                    Log.d("MainActivity", "Extracted path: $path")
                    if (path != null && (path.endsWith(".zip") || path.endsWith(".json"))) {
                        sharedFilePath = path
                        Log.d("MainActivity", "Set sharedFilePath to: $sharedFilePath")
                        // Notify Flutter immediately
                        methodChannel?.invokeMethod("fileReceived", path)
                    }
                }
            }
            Intent.ACTION_MAIN -> {
                // Check if this is a file opening intent
                val uri = intent.data
                Log.d("MainActivity", "ACTION_MAIN uri: $uri")
                if (uri != null) {
                    val path = getFilePathFromUri(uri)
                    Log.d("MainActivity", "Extracted path from MAIN: $path")
                    if (path != null && (path.endsWith(".zip") || path.endsWith(".json"))) {
                        sharedFilePath = path
                        Log.d("MainActivity", "Set sharedFilePath to: $sharedFilePath")
                        // Notify Flutter immediately
                        methodChannel?.invokeMethod("fileReceived", path)
                    }
                }
            }
        }
    }

    private fun getFilePathFromUri(uri: Uri): String? {
        Log.d("MainActivity", "getFilePathFromUri called with uri: $uri")
        return when (uri.scheme) {
            "file" -> {
                val path = uri.path
                Log.d("MainActivity", "File scheme, path: $path")
                path
            }
            "content" -> {
                try {
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val columnIndex = it.getColumnIndex("_data")
                            if (columnIndex != -1) {
                                val path = it.getString(columnIndex)
                                Log.d("MainActivity", "Content scheme, path: $path")
                                return path
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error getting content path", e)
                }
                null
            }
            else -> {
                Log.d("MainActivity", "Unknown scheme: ${uri.scheme}")
                null
            }
        }
    }
}
