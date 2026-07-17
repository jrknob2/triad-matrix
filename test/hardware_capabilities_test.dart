import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/features/hardware/hardware_capabilities.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('desktop platforms expose hardware features', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    expect(HardwareCapabilities.supportsDesktopHardware, isTrue);
    expect(HardwareCapabilities.supportsMidiInput, isTrue);
    expect(HardwareCapabilities.supportsSerialLedController, isTrue);
    expect(HardwareCapabilities.supportsPatternMidiCapture, isTrue);
  });

  test('iPhone hides desktop hardware features', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(HardwareCapabilities.supportsDesktopHardware, isFalse);
    expect(HardwareCapabilities.supportsMidiInput, isFalse);
    expect(HardwareCapabilities.supportsSerialLedController, isFalse);
    expect(HardwareCapabilities.supportsPatternMidiCapture, isFalse);
  });
}
