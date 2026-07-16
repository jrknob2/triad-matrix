import 'package:flutter/foundation.dart';

import 'serial_led_controller.dart';

class SharedSerialLedController {
  static SerialLedController? _instance;

  SharedSerialLedController._();

  static SerialLedController get instance {
    return _instance ??= SerialLedController();
  }

  @visibleForTesting
  static void setInstanceForTesting(SerialLedController controller) {
    _instance?.dispose();
    _instance = controller;
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
