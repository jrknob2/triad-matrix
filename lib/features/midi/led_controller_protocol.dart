import 'package:flutter/foundation.dart';

const String ledClearCommand = 'CLEAR\n';

class LedControllerProtocolDefaults {
  static const int guidedSolidRetriggerMs = 55;
  static const int hearItFlashDecayMs = 220;
  static const int playAlongLeadMs = 250;
  static const int playAlongDecayMs = 180;

  const LedControllerProtocolDefaults._();
}

enum LedAnimationType {
  solid('SOLID'),
  flash('FLASH'),
  fadeIn('FADE_IN');

  final String protocolName;

  const LedAnimationType(this.protocolName);

  static LedAnimationType? fromProtocolName(String value) {
    final String normalized = value.trim().toUpperCase();
    for (final LedAnimationType type in LedAnimationType.values) {
      if (type.protocolName == normalized) return type;
    }
    return null;
  }
}

@immutable
class LedFrameAnimation {
  final LedAnimationType type;
  final int primaryMs;
  final int? secondaryMs;

  const LedFrameAnimation.solid(this.primaryMs)
    : assert(primaryMs >= 0),
      type = LedAnimationType.solid,
      secondaryMs = null;

  const LedFrameAnimation.flash(this.primaryMs)
    : assert(primaryMs >= 0),
      type = LedAnimationType.flash,
      secondaryMs = null;

  const LedFrameAnimation.fadeIn({required int leadMs, required int decayMs})
    : assert(leadMs > 0),
      assert(decayMs >= 0),
      type = LedAnimationType.fadeIn,
      primaryMs = leadMs,
      secondaryMs = decayMs;

  String get commandLine {
    return switch (type) {
      LedAnimationType.solid => 'ANIMATION,SOLID,$primaryMs',
      LedAnimationType.flash => 'ANIMATION,FLASH,$primaryMs',
      LedAnimationType.fadeIn => 'ANIMATION,FADE_IN,$primaryMs,${secondaryMs!}',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is LedFrameAnimation &&
        other.type == type &&
        other.primaryMs == primaryMs &&
        other.secondaryMs == secondaryMs;
  }

  @override
  int get hashCode => Object.hash(type, primaryMs, secondaryMs);

  @override
  String toString() => commandLine;
}

enum LedControllerVoice {
  snare('SNARE', 'Snare'),
  kick('KICK', 'Kick'),
  hiHat('HIHAT', 'Hi-hat'),
  tom1('TOM1', 'Tom 1'),
  tom2('TOM2', 'Tom 2'),
  floorTom('FLOORTOM', 'Floor tom'),
  crash('CRASH', 'Crash'),
  ride('RIDE', 'Ride');

  final String protocolName;
  final String displayName;

  const LedControllerVoice(this.protocolName, this.displayName);

  static LedControllerVoice? fromProtocolName(String value) {
    final String normalized = value.trim().toUpperCase();
    for (final LedControllerVoice voice in LedControllerVoice.values) {
      if (voice.protocolName == normalized) return voice;
    }
    return null;
  }
}

enum LedOrientation {
  left('LEFT'),
  right('RIGHT');

  final String protocolName;

  const LedOrientation(this.protocolName);

  static LedOrientation? fromProtocolName(String value) {
    return switch (value.trim().toUpperCase()) {
      'LEFT' => LedOrientation.left,
      'RIGHT' => LedOrientation.right,
      _ => null,
    };
  }
}

String buildSetOrientationCommand(
  LedControllerVoice voice,
  LedOrientation orientation,
) {
  return 'SYS,SET,ORIENTATION,${voice.protocolName},${orientation.protocolName}\n';
}

String buildGetOrientationCommand(LedControllerVoice? voice) {
  final String target = voice?.protocolName ?? 'ALL';
  return 'SYS,GET,ORIENTATION,$target\n';
}

String buildResetOrientationCommand(LedControllerVoice? voice) {
  final String target = voice?.protocolName ?? 'ALL';
  return 'SYS,RESET,ORIENTATION,$target\n';
}

sealed class LedControllerResponse {
  const LedControllerResponse();
}

class LedAnimationAckResponse extends LedControllerResponse {
  final LedFrameAnimation animation;
  final bool frameCommitted;

  const LedAnimationAckResponse({
    required this.animation,
    required this.frameCommitted,
  });
}

class LedOrientationValueResponse extends LedControllerResponse {
  final LedControllerVoice voice;
  final LedOrientation orientation;
  final bool acknowledged;

  const LedOrientationValueResponse({
    required this.voice,
    required this.orientation,
    this.acknowledged = false,
  });
}

class LedOrientationResetResponse extends LedControllerResponse {
  final LedControllerVoice? voice;

  const LedOrientationResetResponse({this.voice});

  bool get all => voice == null;
}

class LedControllerErrorResponse extends LedControllerResponse {
  final String code;
  final String detail;

  const LedControllerErrorResponse({required this.code, required this.detail});
}

class LedControllerUnknownResponse extends LedControllerResponse {
  final String line;

  const LedControllerUnknownResponse(this.line);
}

LedControllerResponse parseLedControllerResponse(String line) {
  final String trimmed = line.trim();
  if (trimmed.isEmpty) return const LedControllerUnknownResponse('');
  final List<String> parts = trimmed.split(':');

  if (parts.length >= 4 && parts[0] == 'OK') {
    final bool animationAck = parts[1] == 'ANIMATION';
    final bool frameAck = parts[1] == 'FRAME_END';
    if (animationAck || frameAck) {
      final LedFrameAnimation? animation = _animationFromAckParts(parts, 2);
      if (animation != null) {
        return LedAnimationAckResponse(
          animation: animation,
          frameCommitted: frameAck,
        );
      }
    }
  }

  if (parts.length == 3 && parts[0] == 'ORIENTATION') {
    final LedControllerVoice? voice = LedControllerVoice.fromProtocolName(
      parts[1],
    );
    final LedOrientation? orientation = LedOrientation.fromProtocolName(
      parts[2],
    );
    if (voice != null && orientation != null) {
      return LedOrientationValueResponse(
        voice: voice,
        orientation: orientation,
      );
    }
  }
  if (parts.length == 4 && parts[0] == 'OK' && parts[1] == 'ORIENTATION') {
    final LedControllerVoice? voice = LedControllerVoice.fromProtocolName(
      parts[2],
    );
    final LedOrientation? orientation = LedOrientation.fromProtocolName(
      parts[3],
    );
    if (voice != null && orientation != null) {
      return LedOrientationValueResponse(
        voice: voice,
        orientation: orientation,
        acknowledged: true,
      );
    }
  }
  if (parts.length == 3 &&
      parts[0] == 'OK' &&
      parts[1] == 'ORIENTATION_RESET') {
    if (parts[2] == 'ALL') return const LedOrientationResetResponse();
    final LedControllerVoice? voice = LedControllerVoice.fromProtocolName(
      parts[2],
    );
    if (voice != null) return LedOrientationResetResponse(voice: voice);
  }
  if (parts.length >= 2 && parts[0] == 'ERROR') {
    return LedControllerErrorResponse(
      code: parts[1],
      detail: parts.length > 2 ? parts.sublist(2).join(':') : '',
    );
  }
  return LedControllerUnknownResponse(trimmed);
}

LedFrameAnimation? _animationFromAckParts(List<String> parts, int typeIndex) {
  final LedAnimationType? type = LedAnimationType.fromProtocolName(
    parts[typeIndex],
  );
  if (type == null) return null;
  final int? primaryMs = _parsePositiveOrZero(parts, typeIndex + 1);
  if (primaryMs == null) return null;
  return switch (type) {
    LedAnimationType.solid => LedFrameAnimation.solid(primaryMs),
    LedAnimationType.flash => LedFrameAnimation.flash(primaryMs),
    LedAnimationType.fadeIn => () {
      if (parts.length <= typeIndex + 2) return null;
      final int? secondaryMs = _parsePositiveOrZero(parts, typeIndex + 2);
      if (secondaryMs == null) return null;
      return LedFrameAnimation.fadeIn(leadMs: primaryMs, decayMs: secondaryMs);
    }(),
  };
}

int? _parsePositiveOrZero(List<String> parts, int index) {
  if (index >= parts.length) return null;
  final int? value = int.tryParse(parts[index]);
  if (value == null || value < 0) return null;
  return value;
}
