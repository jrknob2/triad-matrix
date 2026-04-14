package com.example.traid_trainer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    NativeMetronomePlugin(applicationContext).register(
      MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "drumcabulary/metronome"
      ),
      EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "drumcabulary/metronome_beats"
      )
    )
  }
}
