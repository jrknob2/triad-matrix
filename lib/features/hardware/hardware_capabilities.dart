import 'package:flutter/foundation.dart';

class HardwareCapabilities {
  const HardwareCapabilities._();

  static bool get supportsDesktopHardware {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
  }

  static bool get supportsMidiInput => supportsDesktopHardware;
  static bool get supportsSerialLedController => supportsDesktopHardware;
  static bool get supportsPatternMidiCapture => supportsMidiInput;
}
