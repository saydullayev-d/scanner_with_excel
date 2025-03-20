package com.ssline.scanner_with_excel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterActivityHolder.activity = this
        flutterEngine.plugins.add(BluetoothScanner())
    }
}