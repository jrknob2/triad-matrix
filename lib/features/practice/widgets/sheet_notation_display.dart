import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../midi/led_controller_protocol.dart';
import '../../midi/midi_input_models.dart';
import '../../midi/serial_led_controller.dart';
import '../pattern_audio_service.dart';
import '../pattern_led_playback_output.dart';
import '../pattern_play_along_input_feedback_output.dart';
import '../pattern_playback_scheduler.dart';
import '../sticking_cue.dart';

enum DrumSheetNoteValue {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
}

enum DrumSheetFeel { straight, triplet }

enum DrumSheetVoice {
  hihat,
  openHiHat,
  ride,
  crash,
  snare,
  tom1,
  tom2,
  floorTom,
  kick,
}

enum DrumSheetStrokeHand { left, right }

enum DrumSheetStrokeArticulation { normal, accent, ghost }

@immutable
class DrumSheetStrokeDescriptor {
  final DrumSheetStrokeHand hand;
  final DrumSheetStrokeArticulation articulation;

  const DrumSheetStrokeDescriptor({
    required this.hand,
    this.articulation = DrumSheetStrokeArticulation.normal,
  });

  String get patternLabel {
    final String handLabel = hand == DrumSheetStrokeHand.left ? 'L' : 'R';
    return switch (articulation) {
      DrumSheetStrokeArticulation.normal => handLabel,
      DrumSheetStrokeArticulation.accent => '^$handLabel',
      DrumSheetStrokeArticulation.ghost => '($handLabel)',
    };
  }

  String get displayLabel => hand == DrumSheetStrokeHand.left ? 'L' : 'R';

  StickingCue get stickingCue {
    return switch ((hand, articulation)) {
      (DrumSheetStrokeHand.left, DrumSheetStrokeArticulation.ghost) =>
        StickingCue.ghostLeft,
      (DrumSheetStrokeHand.right, DrumSheetStrokeArticulation.ghost) =>
        StickingCue.ghostRight,
      (DrumSheetStrokeHand.left, DrumSheetStrokeArticulation.accent) =>
        StickingCue.accentLeft,
      (DrumSheetStrokeHand.right, DrumSheetStrokeArticulation.accent) =>
        StickingCue.accentRight,
      (DrumSheetStrokeHand.left, _) => StickingCue.left,
      (DrumSheetStrokeHand.right, _) => StickingCue.right,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DrumSheetStrokeDescriptor &&
        other.hand == hand &&
        other.articulation == articulation;
  }

  @override
  int get hashCode => Object.hash(hand, articulation);
}

@immutable
class DrumSheetVoiceStroke {
  final DrumSheetVoice voice;
  final DrumSheetStrokeDescriptor? stroke;

  const DrumSheetVoiceStroke({required this.voice, this.stroke});

  @override
  bool operator ==(Object other) {
    return other is DrumSheetVoiceStroke &&
        other.voice == voice &&
        other.stroke == stroke;
  }

  @override
  int get hashCode => Object.hash(voice, stroke);
}

class DrumSheetNotationController {
  _DrumSheetNotationDisplayState? _state;

  Future<void> toggleAudioPreview() async {
    await _state?._toggleAudioPreview();
  }

  Future<void> startAudioPreview() async {
    await _state?._startAudioPreview();
  }

  Future<void> stopAudioPreview() async {
    await _state?._stopAudioPreview();
  }

  static Future<void> stopActiveAudioPreview() async {
    await _DrumSheetNotationDisplayState._activeAudioPreviewOwner
        ?._stopAudioPreview();
  }

  void _attach(_DrumSheetNotationDisplayState state) {
    _state = state;
  }

  void _detach(_DrumSheetNotationDisplayState state) {
    if (_state == state) _state = null;
  }
}

@immutable
class DrumSheetNotationDocument {
  final DrumSheetNoteValue subdivision;
  final DrumSheetFeel feel;
  final String timeSignature;
  final int? repeatCount;
  final List<DrumSheetNotationMeasure> measures;

  const DrumSheetNotationDocument({
    this.subdivision = DrumSheetNoteValue.eighth,
    this.feel = DrumSheetFeel.straight,
    this.timeSignature = '4/4',
    this.repeatCount,
    required this.measures,
  });

  factory DrumSheetNotationDocument.fromPattern(
    String pattern, {
    DrumSheetNoteValue subdivision = DrumSheetNoteValue.eighth,
    DrumSheetFeel feel = DrumSheetFeel.straight,
    String timeSignature = '4/4',
    int? repeatCount,
    bool lenient = false,
  }) {
    final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
      pattern,
      lenient: lenient,
    );
    return DrumSheetNotationDocument(
      subdivision: subdivision,
      feel: feel,
      timeSignature: timeSignature,
      repeatCount: repeatCount,
      measures: _measuresForNotes(
        notes,
        subdivision: subdivision,
        feel: feel,
        timeSignature: timeSignature,
      ),
    );
  }

  List<DrumSheetNotationNote> get flattenedNotes {
    return <DrumSheetNotationNote>[
      for (final DrumSheetNotationMeasure measure in measures) ...measure.notes,
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is DrumSheetNotationDocument &&
        other.subdivision == subdivision &&
        other.feel == feel &&
        other.timeSignature == timeSignature &&
        other.repeatCount == repeatCount &&
        listEquals(other.measures, measures);
  }

  @override
  int get hashCode => Object.hash(
    subdivision,
    feel,
    timeSignature,
    repeatCount,
    Object.hashAll(measures),
  );
}

List<DrumSheetNotationMeasure> _measuresForNotes(
  List<DrumSheetNotationNote> notes, {
  required DrumSheetNoteValue subdivision,
  required DrumSheetFeel feel,
  required String timeSignature,
}) {
  if (notes.isEmpty) {
    return const <DrumSheetNotationMeasure>[
      DrumSheetNotationMeasure(notes: <DrumSheetNotationNote>[]),
    ];
  }
  final int notesPerMeasure = _notesPerMeasure(
    subdivision: subdivision,
    feel: feel,
    timeSignature: timeSignature,
  );
  if (notesPerMeasure <= 0 || notes.length <= notesPerMeasure) {
    return <DrumSheetNotationMeasure>[DrumSheetNotationMeasure(notes: notes)];
  }
  return <DrumSheetNotationMeasure>[
    for (int index = 0; index < notes.length; index += notesPerMeasure)
      DrumSheetNotationMeasure(
        notes: notes.sublist(
          index,
          math.min(index + notesPerMeasure, notes.length),
        ),
      ),
  ];
}

int _notesPerMeasure({
  required DrumSheetNoteValue subdivision,
  required DrumSheetFeel feel,
  required String timeSignature,
}) {
  final double measureBeats = _quarterNoteBeatsForTimeSignature(timeSignature);
  final double noteBeats = _beatCountForSheetValue(subdivision, feel: feel);
  if (measureBeats <= 0 || noteBeats <= 0) return 0;
  return (measureBeats / noteBeats).round();
}

double _quarterNoteBeatsForTimeSignature(String timeSignature) {
  final List<String> parts = timeSignature.split('/');
  if (parts.length != 2) return 4;
  final int? numerator = int.tryParse(parts[0].trim());
  final int? denominator = int.tryParse(parts[1].trim());
  if (numerator == null || denominator == null || denominator <= 0) return 4;
  return numerator * (4 / denominator);
}

@immutable
class DrumSheetNotationMeasure {
  final List<DrumSheetNotationNote> notes;

  const DrumSheetNotationMeasure({required this.notes});

  @override
  bool operator ==(Object other) {
    return other is DrumSheetNotationMeasure && listEquals(other.notes, notes);
  }

  @override
  int get hashCode => Object.hashAll(notes);
}

@immutable
class DrumSheetNotationNote {
  final DrumSheetNoteValue? value;
  final List<DrumSheetVoice> voices;
  final List<DrumSheetVoiceStroke> voiceStrokes;
  final bool rest;
  final String sticking;
  final bool accent;
  final bool flam;
  final bool ghost;
  final bool tie;

  const DrumSheetNotationNote({
    this.value,
    this.voices = const <DrumSheetVoice>[],
    this.voiceStrokes = const <DrumSheetVoiceStroke>[],
    this.rest = false,
    this.sticking = '',
    this.accent = false,
    this.flam = false,
    this.ghost = false,
    this.tie = false,
  }) : assert(rest || voices.length > 0);

  DrumSheetNotationNote copyWith({
    DrumSheetNoteValue? value,
    bool clearValue = false,
    List<DrumSheetVoice>? voices,
    List<DrumSheetVoiceStroke>? voiceStrokes,
    bool? rest,
    String? sticking,
    bool? accent,
    bool? flam,
    bool? ghost,
    bool? tie,
  }) {
    return DrumSheetNotationNote(
      value: clearValue ? null : value ?? this.value,
      voices: voices ?? this.voices,
      voiceStrokes: voiceStrokes ?? this.voiceStrokes,
      rest: rest ?? this.rest,
      sticking: sticking ?? this.sticking,
      accent: accent ?? this.accent,
      flam: flam ?? this.flam,
      ghost: ghost ?? this.ghost,
      tie: tie ?? this.tie,
    );
  }

  DrumSheetNoteValue resolvedValue(DrumSheetNoteValue subdivision) {
    return value ?? subdivision;
  }

  DrumSheetStrokeDescriptor? strokeForVoice(DrumSheetVoice voice) {
    for (final DrumSheetVoiceStroke voiceStroke in voiceStrokes) {
      if (voiceStroke.voice == voice) return voiceStroke.stroke;
    }
    if (voices.length != 1 || voices.single != voice) return null;
    return _singleStrokeDescriptorFromLegacySticking(sticking);
  }

  @override
  bool operator ==(Object other) {
    return other is DrumSheetNotationNote &&
        other.value == value &&
        listEquals(other.voices, voices) &&
        listEquals(other.voiceStrokes, voiceStrokes) &&
        other.rest == rest &&
        other.sticking == sticking &&
        other.accent == accent &&
        other.flam == flam &&
        other.ghost == ghost &&
        other.tie == tie;
  }

  @override
  int get hashCode => Object.hash(
    value,
    Object.hashAll(voices),
    Object.hashAll(voiceStrokes),
    rest,
    sticking,
    accent,
    flam,
    ghost,
    tie,
  );
}

@immutable
class DrumSheetSelectedNote {
  final int index;
  final int measureIndex;
  final int measureNoteIndex;
  final DrumSheetNotationNote note;

  const DrumSheetSelectedNote({
    required this.index,
    required this.measureIndex,
    required this.measureNoteIndex,
    required this.note,
  });
}

enum DrumSheetNotationSelectionPurpose { editing, guidedPractice }

@immutable
class DrumSheetNotationSelection {
  final Set<int> eventIndexes;
  final DrumSheetNotationSelectionPurpose purpose;

  factory DrumSheetNotationSelection({
    required Iterable<int> eventIndexes,
    DrumSheetNotationSelectionPurpose purpose =
        DrumSheetNotationSelectionPurpose.editing,
  }) {
    return DrumSheetNotationSelection._(
      Set<int>.unmodifiable(eventIndexes.where((int index) => index >= 0)),
      purpose,
    );
  }

  factory DrumSheetNotationSelection.editing(Iterable<int> eventIndexes) {
    return DrumSheetNotationSelection(
      eventIndexes: eventIndexes,
      purpose: DrumSheetNotationSelectionPurpose.editing,
    );
  }

  factory DrumSheetNotationSelection.guidedPractice(
    Iterable<int> eventIndexes,
  ) {
    return DrumSheetNotationSelection(
      eventIndexes: eventIndexes,
      purpose: DrumSheetNotationSelectionPurpose.guidedPractice,
    );
  }

  const DrumSheetNotationSelection._(this.eventIndexes, this.purpose);

  static const DrumSheetNotationSelection empty = DrumSheetNotationSelection._(
    <int>{},
    DrumSheetNotationSelectionPurpose.editing,
  );

  bool get isEmpty => eventIndexes.isEmpty;
  bool get isGuidedPractice =>
      purpose == DrumSheetNotationSelectionPurpose.guidedPractice;

  List<int> get sortedIndexes => eventIndexes.toList()..sort();

  DrumSheetNotationSelection copyWith({
    Iterable<int>? eventIndexes,
    DrumSheetNotationSelectionPurpose? purpose,
  }) {
    return DrumSheetNotationSelection(
      eventIndexes: eventIndexes ?? this.eventIndexes,
      purpose: purpose ?? this.purpose,
    );
  }
}

class DrumSheetPatternParser {
  const DrumSheetPatternParser._();

  static List<DrumSheetNotationNote> parse(
    String pattern, {
    bool lenient = false,
  }) {
    return _parsePattern(pattern, _ParseOptions(lenient: lenient));
  }

  static String serialize(
    List<DrumSheetNotationNote> notes, {
    DrumSheetNoteValue subdivision = DrumSheetNoteValue.eighth,
  }) {
    final List<String> events = <String>[];
    for (int index = 0; index < notes.length;) {
      final _SerializedPhrase? phrase = _serializedPhraseAt(
        notes,
        index,
        subdivision: subdivision,
      );
      if (phrase != null) {
        events.add(phrase.text);
        index += phrase.noteCount;
        continue;
      }
      events.add(_serializeSingleNote(notes[index], subdivision: subdivision));
      index += 1;
    }
    return events.join(' ');
  }

  static List<DrumSheetNotationNote> applyValueOverride(
    List<DrumSheetNotationNote> notes,
    Set<int> selectedIndexes,
    DrumSheetNoteValue? value,
  ) {
    return <DrumSheetNotationNote>[
      for (int index = 0; index < notes.length; index += 1)
        selectedIndexes.contains(index)
            ? notes[index].copyWith(value: value, clearValue: value == null)
            : notes[index],
    ];
  }

  static List<DrumSheetNotationNote> applyVoiceOverride(
    List<DrumSheetNotationNote> notes,
    Set<int> selectedIndexes,
    DrumSheetVoice? voice,
  ) {
    return <DrumSheetNotationNote>[
      for (int index = 0; index < notes.length; index += 1)
        selectedIndexes.contains(index)
            ? notes[index].copyWith(
                voices: voice == null
                    ? _defaultVoicesForNote(notes[index])
                    : <DrumSheetVoice>[voice],
                voiceStrokes: _voiceStrokesAfterVoiceOverride(
                  notes[index],
                  voice,
                ),
              )
            : notes[index],
    ];
  }

  static List<DrumSheetNotationNote> toggleAccent(
    List<DrumSheetNotationNote> notes,
    Set<int> selectedIndexes,
  ) {
    final bool shouldAccent = !selectedIndexes.every(
      (int index) => notes[index].accent,
    );
    return <DrumSheetNotationNote>[
      for (int index = 0; index < notes.length; index += 1)
        selectedIndexes.contains(index) && !notes[index].rest
            ? notes[index].copyWith(
                accent: shouldAccent,
                ghost: shouldAccent ? false : notes[index].ghost,
                voiceStrokes: _voiceStrokesWithArticulation(
                  notes[index],
                  shouldAccent
                      ? DrumSheetStrokeArticulation.accent
                      : DrumSheetStrokeArticulation.normal,
                ),
              )
            : notes[index],
    ];
  }

  static List<DrumSheetNotationNote> toggleGhost(
    List<DrumSheetNotationNote> notes,
    Set<int> selectedIndexes,
  ) {
    final bool shouldGhost = !selectedIndexes.every(
      (int index) => notes[index].ghost,
    );
    return <DrumSheetNotationNote>[
      for (int index = 0; index < notes.length; index += 1)
        selectedIndexes.contains(index) && !notes[index].rest
            ? notes[index].copyWith(
                ghost: shouldGhost,
                accent: shouldGhost ? false : notes[index].accent,
                voiceStrokes: _voiceStrokesWithArticulation(
                  notes[index],
                  shouldGhost
                      ? DrumSheetStrokeArticulation.ghost
                      : DrumSheetStrokeArticulation.normal,
                ),
              )
            : notes[index],
    ];
  }

  static List<DrumSheetNotationNote> deleteSelected(
    List<DrumSheetNotationNote> notes,
    Set<int> selectedIndexes,
  ) {
    return <DrumSheetNotationNote>[
      for (int index = 0; index < notes.length; index += 1)
        if (!selectedIndexes.contains(index)) notes[index],
    ];
  }
}

class DrumSheetNotationDisplay extends StatefulWidget {
  static const double defaultMinNoteWidth = 38;

  final DrumSheetNotationDocument document;
  final String? grouping;
  final Set<int> selectedIndexes;
  final DrumSheetNotationSelection? selection;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final bool selectable;
  final bool finalRepeat;
  final bool showSticking;
  final TextStyle? stickingStyle;
  final Color? staffColor;
  final Color? noteColor;
  final Color? selectedColor;
  final double minNoteWidth;
  final bool compactLayout;
  final bool preserveMeasures;
  final bool darkTheme;
  final Color? backgroundColor;
  final bool audioPreviewEnabled;
  final int audioPreviewBpm;
  final AccentVoiceV1 audioPreviewAccentVoice;
  final bool ledPlaybackEnabled;
  final PatternLedPlaybackPresentation ledPlaybackPresentation;
  final Duration ledPlayAlongLeadTime;
  final SerialLedController? ledController;
  final Stream<DrumInputEvent>? playAlongDrumEvents;
  final bool playAlongInputEnabled;
  final DrumSheetNotationController? controller;

  const DrumSheetNotationDisplay({
    super.key,
    required this.document,
    this.grouping,
    this.selectedIndexes = const <int>{},
    this.selection,
    this.onSelectionChanged,
    this.selectable = true,
    this.finalRepeat = true,
    this.showSticking = true,
    this.stickingStyle,
    this.staffColor,
    this.noteColor,
    this.selectedColor,
    this.minNoteWidth = defaultMinNoteWidth,
    this.compactLayout = false,
    this.preserveMeasures = true,
    this.darkTheme = false,
    this.backgroundColor,
    this.audioPreviewEnabled = false,
    this.audioPreviewBpm = 92,
    this.audioPreviewAccentVoice = AccentVoiceV1.snare,
    this.ledPlaybackEnabled = false,
    this.ledPlaybackPresentation = PatternLedPlaybackPresentation.hearIt,
    this.ledPlayAlongLeadTime = const Duration(
      milliseconds: LedControllerProtocolDefaults.playAlongLeadMs,
    ),
    this.ledController,
    this.playAlongDrumEvents,
    this.playAlongInputEnabled = false,
    this.controller,
  });

  @override
  State<DrumSheetNotationDisplay> createState() =>
      _DrumSheetNotationDisplayState();
}

class _DrumSheetNotationDisplayState extends State<DrumSheetNotationDisplay>
    with WidgetsBindingObserver {
  static const String _hostAsset = 'web/sheet_notation/app_host.html';
  static _DrumSheetNotationDisplayState? _activeAudioPreviewOwner;

  WebViewController? _controller;
  PatternAudioService? _audioPreview;
  Timer? _playheadTicker;
  final Stopwatch _playheadStopwatch = Stopwatch();
  Duration _playheadStartElapsed = Duration.zero;
  _SheetNotationAudioPlan? _audioPreviewPlan;
  _NotationPlayheadFrame? _playheadFrame;
  bool _hostLoaded = false;
  bool _audioPreviewRunning = false;
  bool _audioPreviewPreparing = false;
  double _webViewHeight = 160;
  double? _lastLayoutWidth;
  String? _lastPayloadJson;
  String? _lastRenderPayloadJson;
  String? _lastSelectionJson;
  String? _lastPlayheadJson;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _ensureWebViewController();
  }

  WebViewController _ensureWebViewController() {
    final WebViewController? existing = _controller;
    if (existing != null) return existing;

    _hostLoaded = false;
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      controller.setBackgroundColor(Colors.transparent);
    }
    controller
      ..addJavaScriptChannel(
        'SheetSelection',
        onMessageReceived: (JavaScriptMessage message) {
          final Object? decoded = jsonDecode(message.message);
          if (decoded is! List) return;
          widget.onSelectionChanged?.call(
            decoded.whereType<num>().map((num value) => value.toInt()).toSet(),
          );
        },
      )
      ..addJavaScriptChannel(
        'SheetHeight',
        onMessageReceived: (JavaScriptMessage message) {
          final double? nextHeight = double.tryParse(message.message);
          if (nextHeight == null || nextHeight <= 0 || !mounted) return;
          if ((_webViewHeight - nextHeight).abs() < 1) return;
          setState(() => _webViewHeight = nextHeight);
        },
      )
      ..addJavaScriptChannel(
        'SheetScroll',
        onMessageReceived: _handleSheetScroll,
      )
      ..addJavaScriptChannel(
        'SheetLog',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('Drum sheet notation WebView: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'Drum sheet notation WebView resource error: '
              '${error.errorCode} ${error.description}',
            );
          },
          onPageFinished: (String url) {
            _hostLoaded = true;
            _lastPayloadJson = null;
            _lastRenderPayloadJson = null;
            _lastSelectionJson = null;
            _lastPlayheadJson = null;
            _renderToWebView(width: _lastLayoutWidth);
          },
        ),
      );
    _controller = controller;
    unawaited(_loadHostAsset(controller));
    return controller;
  }

  void _handleSheetScroll(JavaScriptMessage message) {
    if (!mounted) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, Object?>) return;
    final double deltaY = _normalizedWheelDelta(
      decoded['deltaY'],
      decoded['deltaMode'],
    );
    if (deltaY == 0) return;
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    final ScrollPosition? position = scrollable?.position;
    if (position == null || !position.hasPixels) return;
    final double target = (position.pixels + deltaY)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) return;
    position.jumpTo(target);
  }

  double _normalizedWheelDelta(Object? deltaValue, Object? deltaModeValue) {
    final double? delta = deltaValue is num ? deltaValue.toDouble() : null;
    if (delta == null || !delta.isFinite || delta == 0) return 0;
    final int deltaMode = deltaModeValue is num ? deltaModeValue.toInt() : 0;
    return switch (deltaMode) {
      1 => delta * 16,
      2 => delta * _webViewHeight,
      _ => delta,
    };
  }

  Future<void> _loadHostAsset(WebViewController controller) async {
    try {
      if (!mounted || _controller != controller) return;
      await controller.loadFlutterAsset(_hostAsset);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Drum sheet notation host asset load failed: $error\n$stackTrace',
      );
    }
  }

  @override
  void didUpdateWidget(covariant DrumSheetNotationDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    _ensureWebViewController();
    if (_audioPreviewRunning &&
        (oldWidget.document != widget.document ||
            oldWidget.audioPreviewBpm != widget.audioPreviewBpm ||
            oldWidget.audioPreviewAccentVoice !=
                widget.audioPreviewAccentVoice ||
            oldWidget.ledController != widget.ledController ||
            oldWidget.playAlongDrumEvents != widget.playAlongDrumEvents ||
            oldWidget.playAlongInputEnabled != widget.playAlongInputEnabled ||
            oldWidget.ledPlaybackPresentation !=
                widget.ledPlaybackPresentation ||
            oldWidget.ledPlayAlongLeadTime != widget.ledPlayAlongLeadTime)) {
      unawaited(_stopAudioPreview());
    }
    if (oldWidget.ledController != widget.ledController ||
        oldWidget.playAlongDrumEvents != widget.playAlongDrumEvents ||
        oldWidget.playAlongInputEnabled != widget.playAlongInputEnabled ||
        oldWidget.ledPlaybackPresentation != widget.ledPlaybackPresentation ||
        oldWidget.ledPlayAlongLeadTime != widget.ledPlayAlongLeadTime) {
      unawaited(_audioPreview?.dispose());
      _audioPreview = null;
    }
  }

  @override
  void dispose() {
    if (_activeAudioPreviewOwner == this) {
      _activeAudioPreviewOwner = null;
    }
    widget.controller?._detach(this);
    WidgetsBinding.instance.removeObserver(this);
    _playheadTicker?.cancel();
    _playheadStopwatch.stop();
    unawaited(_audioPreview?.dispose());
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(_reloadAudioPreviewAssetsForHotReload());
  }

  Future<void> _reloadAudioPreviewAssetsForHotReload() async {
    final PatternAudioService? audioPreview = _audioPreview;
    if (audioPreview == null) return;
    if (_audioPreviewRunning || _audioPreviewPreparing) {
      await _stopAudioPreview();
    }
    await audioPreview.reloadAssets();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_audioPreviewRunning && !_audioPreviewPreparing) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_stopAudioPreview());
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget notation = _buildWebViewNotation();
    return _buildAudioPreviewShell(context, notation);
  }

  Widget _buildWebViewNotation() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final WebViewController controller = _ensureWebViewController();
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 640;
        _lastLayoutWidth = width;
        final double estimatedHeight = _estimatedHeightForWidth(width);
        if ((_webViewHeight - estimatedHeight).abs() > 1 &&
            _webViewHeight < estimatedHeight) {
          _webViewHeight = estimatedHeight;
        }
        _renderToWebView(width: width);
        return SizedBox(
          height: _webViewHeight,
          width: width,
          child: WebViewWidget(controller: controller),
        );
      },
    );
  }

  Widget _buildAudioPreviewShell(BuildContext context, Widget notation) {
    if (!widget.audioPreviewEnabled) return notation;
    final bool canPreview =
        widget.audioPreviewBpm > 0 &&
        widget.document.flattenedNotes.any(
          (DrumSheetNotationNote note) => !note.rest,
        );
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: _audioPreviewRunning
                ? 'Stop notation audio'
                : 'Hear notation',
            onPressed: canPreview && !_audioPreviewPreparing
                ? _toggleAudioPreview
                : null,
            icon: _audioPreviewPreparing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.hearing_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _audioPreviewRunning
                  ? colorScheme.primaryContainer
                  : null,
              foregroundColor: _audioPreviewRunning
                  ? colorScheme.onPrimaryContainer
                  : null,
            ),
          ),
        ),
        notation,
      ],
    );
  }

  Future<void> _toggleAudioPreview() async {
    if (_audioPreviewRunning) {
      await _stopAudioPreview();
      return;
    }
    await _startAudioPreview();
  }

  Future<void> _startAudioPreview() async {
    if (_audioPreviewPreparing) return;
    setState(() => _audioPreviewPreparing = true);
    try {
      final _SheetNotationAudioPlan plan = _audioPlanForDocument(
        widget.document,
      );
      if (plan.tokens.isEmpty ||
          plan.tokens.every((PatternTokenV1 token) => token.isRest)) {
        return;
      }

      final _DrumSheetNotationDisplayState? activeOwner =
          _activeAudioPreviewOwner;
      if (activeOwner != null && activeOwner != this) {
        await activeOwner._stopAudioPreview();
      }

      final PatternAudioService audioPreview = _audioPreview ??=
          PatternAudioService(
            playbackOutputs: _playbackOutputs(),
            onPlaybackStarted: _handleAudioPlaybackStarted,
          );
      _audioPreviewPlan = plan;
      await audioPreview.start(
        tokens: plan.tokens,
        markings: plan.markings,
        voices: plan.voices,
        grouping: PatternGroupingV1.none,
        timing: plan.timing,
        bpm: widget.audioPreviewBpm,
        accentVoice: widget.audioPreviewAccentVoice,
        additionalVoicesByIndex: plan.additionalVoicesByIndex,
        stickingByIndex: plan.stickingByIndex,
        additionalStickingByIndex: plan.additionalStickingByIndex,
      );
      if (!mounted) return;
      _activeAudioPreviewOwner = this;
      setState(() {
        _audioPreviewRunning = true;
        _audioPreviewPreparing = false;
      });
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Drum sheet notation audio preview failed: $error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Notation audio failed.')));
      _audioPreviewPlan = null;
      setState(() {
        _audioPreviewRunning = false;
        _audioPreviewPreparing = false;
      });
    } finally {
      if (mounted && _audioPreviewPreparing) {
        setState(() => _audioPreviewPreparing = false);
      }
    }
  }

  Future<void> _stopAudioPreview() async {
    _playheadTicker?.cancel();
    _playheadTicker = null;
    _playheadStopwatch
      ..stop()
      ..reset();
    _playheadStartElapsed = Duration.zero;
    _audioPreviewPlan = null;
    _playheadFrame = null;
    _sendPlayheadToWebView(null);
    await _audioPreview?.stop();
    if (_activeAudioPreviewOwner == this) {
      _activeAudioPreviewOwner = null;
    }
    if (!mounted) return;
    setState(() {
      _audioPreviewRunning = false;
      _audioPreviewPreparing = false;
    });
  }

  void _startPlayheadTicker() {
    _playheadTicker?.cancel();
    _playheadTicker = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _updatePlayheadFrame(),
    );
  }

  void _handleAudioPlaybackStarted(Duration phase) {
    if (!mounted) return;
    _playheadStartElapsed = phase;
    _playheadStopwatch
      ..reset()
      ..start();
    _startPlayheadTicker();
    _updatePlayheadFrame();
  }

  List<PatternPlaybackCueOutputV1> _playbackOutputs() {
    final SerialLedController? ledController = widget.ledController;
    if (ledController == null) return const <PatternPlaybackCueOutputV1>[];
    final Stream<DrumInputEvent>? playAlongDrumEvents =
        widget.playAlongDrumEvents;
    return <PatternPlaybackCueOutputV1>[
      PatternLedPlaybackOutput(
        controller: ledController,
        isEnabled: () => widget.ledPlaybackEnabled,
        presentation: widget.ledPlaybackPresentation,
        playAlongLeadTime: widget.ledPlayAlongLeadTime,
      ),
      if (playAlongDrumEvents != null &&
          widget.ledPlaybackPresentation ==
              PatternLedPlaybackPresentation.playAlong)
        PatternPlayAlongInputFeedbackOutput(
          drumEvents: playAlongDrumEvents,
          controller: ledController,
          isEnabled: () =>
              widget.ledPlaybackEnabled &&
              widget.playAlongInputEnabled &&
              widget.ledPlaybackPresentation ==
                  PatternLedPlaybackPresentation.playAlong,
        ),
    ];
  }

  void _updatePlayheadFrame() {
    final _SheetNotationAudioPlan? plan = _audioPreviewPlan;
    if (plan == null || !_playheadStopwatch.isRunning) {
      _playheadFrame = null;
      _sendPlayheadToWebView(null);
      return;
    }
    final _NotationPlayheadFrame? frame = _playheadFrameForElapsed(
      elapsed: _playheadStartElapsed + _playheadStopwatch.elapsed,
      plan: plan,
      bpm: widget.audioPreviewBpm,
    );
    _playheadFrame = frame;
    _sendPlayheadToWebView(frame);
  }

  void _renderToWebView({double? width}) {
    if (!_hostLoaded) return;
    final double resolvedWidth = width ?? _lastLayoutWidth ?? 640;
    final Map<String, Object?> payload = _webViewPayloadForWidth(resolvedWidth);
    final String renderPayloadJson = jsonEncode(<String, Object?>{
      'document': payload['document'],
      'options': payload['options'],
    });
    final String selectionJson = jsonEncode(payload['selection']);
    final bool shouldRender = _lastRenderPayloadJson != renderPayloadJson;
    final bool shouldUpdateSelection = _lastSelectionJson != selectionJson;
    if (!shouldRender && !shouldUpdateSelection) return;
    _lastPayloadJson = jsonEncode(payload);
    _lastRenderPayloadJson = renderPayloadJson;
    _lastSelectionJson = selectionJson;
    final String encodedPayload = jsonEncode(_lastPayloadJson);
    final String encodedSelection = jsonEncode(selectionJson);
    if (!shouldRender) {
      _runSheetJavaScript('''
(() => {
  const selected = JSON.parse($encodedSelection);
  if (window.DrumcabularySheetNotation == null) {
    return;
  }
  window.DrumcabularySheetNotation.setSelection(selected.indexes, selected.purpose);
})();
''', action: 'selection update');
      _sendPlayheadToWebView(_playheadFrame);
      return;
    }
    _runSheetJavaScript('''
(() => {
  const payload = JSON.parse($encodedPayload);
  if (window.DrumcabularySheetNotation == null) {
    window.__pendingDrumcabularySheetNotationPayload = payload;
    return;
  }
  window.DrumcabularySheetNotation.render(payload);
})();
''', action: 'render');
    _lastPlayheadJson = null;
    _sendPlayheadToWebView(_playheadFrame);
  }

  void _sendPlayheadToWebView(_NotationPlayheadFrame? frame) {
    if (!_hostLoaded) return;
    final String playheadJson = jsonEncode(
      frame?.toJson() ?? const <String, Object?>{'visible': false},
    );
    if (_lastPlayheadJson == playheadJson) return;
    _lastPlayheadJson = playheadJson;
    final String encodedPlayhead = jsonEncode(playheadJson);
    _runSheetJavaScript('''
(() => {
  const playhead = JSON.parse($encodedPlayhead);
  if (window.DrumcabularySheetNotation == null) {
    return;
  }
  window.DrumcabularySheetNotation.setPlayhead(playhead);
})();
''', action: 'playhead update');
  }

  void _runSheetJavaScript(String source, {required String action}) {
    final WebViewController? controller = _controller;
    if (controller == null) return;
    unawaited(
      controller.runJavaScript(source).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Drum sheet notation $action failed: $error\n$stackTrace');
      }),
    );
  }

  Map<String, Object?> _webViewPayloadForWidth(double width) {
    final DrumSheetNotationSelection selection =
        widget.selection ??
        DrumSheetNotationSelection.editing(widget.selectedIndexes);
    final Color selectedColor = widget.selectedColor ?? const Color(0xFFFF6A00);
    return <String, Object?>{
      'document': _documentJson(widget.document),
      'selection': <String, Object?>{
        'indexes': selection.sortedIndexes,
        'purpose': selection.purpose.name,
      },
      'selectedIndexes': selection.sortedIndexes,
      'selectionPurpose': selection.purpose.name,
      'options': <String, Object?>{
        'availableWidth': width.floor(),
        'finalRepeat': widget.finalRepeat,
        'grouping': widget.grouping,
        'minNoteWidth': widget.minNoteWidth,
        'preserveMeasures': widget.preserveMeasures,
        'selectable': widget.selectable && !selection.isGuidedPractice,
        'showSticking': widget.showSticking,
        'theme': widget.darkTheme ? 'dark' : 'light',
        'selectionColor': _cssColor(selectedColor),
        'selectionFillColor': _cssColor(selectedColor.withValues(alpha: 0.18)),
        'selectionBorderColor': _cssColor(
          selectedColor.withValues(alpha: 0.68),
        ),
        if (widget.backgroundColor != null)
          'backgroundColor': _cssColor(widget.backgroundColor!),
        if (widget.compactLayout) ...<String, Object?>{
          'staffY': 34,
          'staffHeight': 124,
          'systemGapY': 108,
          'paddingRight': 4,
          'systemEndReserve': 16,
          'timeSignatureReserve': 52,
          'noteSpacing': 38,
          'groupGap': 0,
          'stemLength': 28,
        },
      },
    };
  }

  double _estimatedHeightForWidth(double width) {
    if (widget.document.flattenedNotes.isEmpty) {
      return widget.compactLayout ? 112 : 140;
    }
    final int systems = math.max(1, widget.document.measures.length);
    if (widget.compactLayout) {
      return 158 + math.max(0, systems - 1) * 108;
    }
    return 10 + 126 + math.max(0, systems - 1) * 140;
  }
}

String _cssColor(Color color) {
  final int argb = color.toARGB32();
  final int alpha = (argb >> 24) & 0xff;
  final int red = (argb >> 16) & 0xff;
  final int green = (argb >> 8) & 0xff;
  final int blue = argb & 0xff;
  if (alpha == 0xff) {
    final int rgb = argb & 0xffffff;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }
  return 'rgba($red, $green, $blue, ${(alpha / 255).toStringAsFixed(3)})';
}

Map<String, Object?> _documentJson(DrumSheetNotationDocument document) {
  return <String, Object?>{
    'subdivision': document.subdivision.noteValueLabel,
    'feel': document.feel.name,
    'timeSignature': document.timeSignature,
    if (document.repeatCount != null) 'repeatCount': document.repeatCount,
    'measures': <Object?>[
      for (final DrumSheetNotationMeasure measure in document.measures)
        <String, Object?>{
          'notes': <Object?>[
            for (final DrumSheetNotationNote note in measure.notes)
              _noteJson(note),
          ],
        },
    ],
  };
}

@immutable
class DrumSheetAudioPreviewPlan {
  final PatternAudioPlanV1 audioPlan;
  final List<int> displayIndexesByTokenIndex;

  const DrumSheetAudioPreviewPlan({
    required this.audioPlan,
    required this.displayIndexesByTokenIndex,
  });

  int? displayIndexForTokenIndex(int tokenIndex) {
    if (tokenIndex < 0 || tokenIndex >= displayIndexesByTokenIndex.length) {
      return null;
    }
    return displayIndexesByTokenIndex[tokenIndex];
  }
}

@immutable
class _SheetNotationAudioPlan {
  final List<PatternTokenV1> tokens;
  final List<PatternNoteMarkingV1> markings;
  final List<DrumVoiceV1> voices;
  final PatternTimingV1 timing;
  final Map<int, List<DrumVoiceV1>> additionalVoicesByIndex;
  final Map<int, StickingCue?> stickingByIndex;
  final Map<int, Map<DrumVoiceV1, StickingCue?>> additionalStickingByIndex;
  final List<int> visibleTokenIndexes;
  final List<_SheetNotationPlayheadEvent> playheadEvents;
  final double totalBeatCount;

  const _SheetNotationAudioPlan({
    required this.tokens,
    required this.markings,
    required this.voices,
    required this.timing,
    required this.additionalVoicesByIndex,
    required this.stickingByIndex,
    required this.additionalStickingByIndex,
    required this.visibleTokenIndexes,
    required this.playheadEvents,
    required this.totalBeatCount,
  });
}

@immutable
class _SheetNotationPlayheadEvent {
  final int tokenIndex;
  final double startBeat;
  final double beatDuration;

  const _SheetNotationPlayheadEvent({
    required this.tokenIndex,
    required this.startBeat,
    required this.beatDuration,
  });
}

@immutable
class _NotationPlayheadFrame {
  final int tokenIndex;
  final int nextTokenIndex;
  final double progress;
  final bool extendsToCycleEnd;

  const _NotationPlayheadFrame({
    required this.tokenIndex,
    required this.nextTokenIndex,
    required this.progress,
    this.extendsToCycleEnd = false,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'visible': true,
      'tokenIndex': tokenIndex,
      'nextTokenIndex': nextTokenIndex,
      'progress': progress,
      'extendsToCycleEnd': extendsToCycleEnd,
    };
  }
}

_SheetNotationAudioPlan _audioPlanForDocument(
  DrumSheetNotationDocument document,
) {
  final List<PatternTokenV1> tokens = <PatternTokenV1>[];
  final List<PatternNoteMarkingV1> markings = <PatternNoteMarkingV1>[];
  final List<DrumVoiceV1> voices = <DrumVoiceV1>[];
  final List<PatternTimingSpanV1> spans = <PatternTimingSpanV1>[];
  final List<int> visibleTokenIndexes = <int>[];
  final Map<int, List<DrumVoiceV1>> additionalVoicesByIndex =
      <int, List<DrumVoiceV1>>{};
  final Map<int, StickingCue?> stickingByIndex = <int, StickingCue?>{};
  final Map<int, Map<DrumVoiceV1, StickingCue?>> additionalStickingByIndex =
      <int, Map<DrumVoiceV1, StickingCue?>>{};
  final List<List<_IndexedSheetNotationNote>> visibleMeasures =
      <List<_IndexedSheetNotationNote>>[];
  int visibleIndex = 0;
  for (final DrumSheetNotationMeasure measure in document.measures) {
    final List<_IndexedSheetNotationNote> indexedMeasure =
        <_IndexedSheetNotationNote>[];
    for (final DrumSheetNotationNote note in measure.notes) {
      indexedMeasure.add(
        _IndexedSheetNotationNote(index: visibleIndex, note: note),
      );
      visibleIndex += 1;
    }
    visibleMeasures.add(indexedMeasure);
  }
  final int repeatCount = math.max(1, document.repeatCount ?? 1);
  final double measureBeatCount = _quarterNoteBeatsForTimeSignature(
    document.timeSignature,
  );

  for (int repeatIndex = 0; repeatIndex < repeatCount; repeatIndex += 1) {
    for (final List<_IndexedSheetNotationNote> measure in visibleMeasures) {
      double measureBeatCursor = 0;
      for (int localIndex = 0; localIndex < measure.length; localIndex += 1) {
        final _IndexedSheetNotationNote indexed = measure[localIndex];
        final DrumSheetNotationNote note = indexed.note;
        final PatternTokenV1 token = _audioTokenForSheetNote(note);
        final List<DrumVoiceV1> noteVoices = note.voices
            .map(_audioVoiceForSheetVoice)
            .toList(growable: false);
        final DrumVoiceV1 primaryVoice = _primaryAudioVoiceForNote(
          note,
          token,
          noteVoices,
        );
        final List<DrumVoiceV1> additionalVoices = <DrumVoiceV1>[
          for (final DrumVoiceV1 voice in noteVoices)
            if (voice != primaryVoice) voice,
        ];
        final Map<DrumVoiceV1, StickingCue?> stickingByVoice =
            _stickingCuesByAudioVoice(
              note: note,
              noteVoices: noteVoices,
              primaryVoice: primaryVoice,
            );
        double beatCount = _beatCountForSheetNote(
          note.resolvedValue(document.subdivision),
          document.feel,
        );
        final bool isLastNoteInMeasure = localIndex == measure.length - 1;
        final double beatCursorAfterNote = measureBeatCursor + beatCount;
        if (isLastNoteInMeasure && measureBeatCount > beatCursorAfterNote) {
          beatCount += measureBeatCount - beatCursorAfterNote;
        }
        final int tokenIndex = tokens.length;

        tokens.add(token);
        markings.add(_audioMarkingForSheetNote(note));
        voices.add(primaryVoice);
        final StickingCue? primarySticking = stickingByVoice[primaryVoice];
        if (primarySticking != null) {
          stickingByIndex[tokenIndex] = primarySticking;
        }
        visibleTokenIndexes.add(indexed.index);
        spans.add(
          PatternTimingSpanV1(
            startIndex: tokenIndex,
            tokenCount: 1,
            beatCount: beatCount,
          ),
        );
        if (additionalVoices.isNotEmpty) {
          additionalVoicesByIndex[tokenIndex] = additionalVoices;
          final Map<DrumVoiceV1, StickingCue?> additionalSticking =
              <DrumVoiceV1, StickingCue?>{};
          for (final DrumVoiceV1 voice in additionalVoices) {
            final StickingCue? sticking = stickingByVoice[voice];
            if (sticking != null) additionalSticking[voice] = sticking;
          }
          if (additionalSticking.isNotEmpty) {
            additionalStickingByIndex[tokenIndex] =
                Map<DrumVoiceV1, StickingCue?>.unmodifiable(additionalSticking);
          }
        }
        measureBeatCursor += beatCount;
      }
    }
  }

  final PatternTimingV1 timing = PatternTimingV1.explicit(
    spans: List<PatternTimingSpanV1>.unmodifiable(spans),
  );
  final PatternPlaybackPlanV1 playbackPlan =
      PatternPlaybackSchedulerV1.buildPlan(
        tokens: tokens,
        grouping: PatternGroupingV1.none,
        timing: timing,
      );

  return _SheetNotationAudioPlan(
    tokens: List<PatternTokenV1>.unmodifiable(tokens),
    markings: List<PatternNoteMarkingV1>.unmodifiable(markings),
    voices: List<DrumVoiceV1>.unmodifiable(voices),
    timing: timing,
    additionalVoicesByIndex: Map<int, List<DrumVoiceV1>>.unmodifiable(
      additionalVoicesByIndex,
    ),
    stickingByIndex: Map<int, StickingCue?>.unmodifiable(stickingByIndex),
    additionalStickingByIndex:
        Map<int, Map<DrumVoiceV1, StickingCue?>>.unmodifiable(
          additionalStickingByIndex,
        ),
    visibleTokenIndexes: List<int>.unmodifiable(visibleTokenIndexes),
    playheadEvents: List<_SheetNotationPlayheadEvent>.unmodifiable(
      playbackPlan.events.map(
        (PatternPlaybackEventV1 event) => _SheetNotationPlayheadEvent(
          tokenIndex: visibleTokenIndexes[event.tokenIndex],
          startBeat: event.startBeat,
          beatDuration: event.beatDuration,
        ),
      ),
    ),
    totalBeatCount: playbackPlan.totalBeatCount,
  );
}

PatternAudioPlanV1 buildSheetNotationAudioPreviewPlan(
  DrumSheetNotationDocument document, {
  int bpm = 92,
  AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
}) {
  return buildSheetNotationAudioPreviewPlanDetails(
    document,
    bpm: bpm,
    accentVoice: accentVoice,
  ).audioPlan;
}

DrumSheetAudioPreviewPlan buildSheetNotationAudioPreviewPlanDetails(
  DrumSheetNotationDocument document, {
  int bpm = 92,
  AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
}) {
  final _SheetNotationAudioPlan plan = _audioPlanForDocument(document);
  return DrumSheetAudioPreviewPlan(
    audioPlan: PatternAudioService.buildPlan(
      tokens: plan.tokens,
      markings: plan.markings,
      voices: plan.voices,
      grouping: PatternGroupingV1.none,
      timing: plan.timing,
      bpm: bpm,
      accentVoice: accentVoice,
      additionalVoicesByIndex: plan.additionalVoicesByIndex,
      stickingByIndex: plan.stickingByIndex,
      additionalStickingByIndex: plan.additionalStickingByIndex,
    ),
    displayIndexesByTokenIndex: plan.visibleTokenIndexes,
  );
}

@visibleForTesting
PatternAudioPlanV1 buildSheetNotationAudioPreviewPlanForTesting(
  DrumSheetNotationDocument document, {
  int bpm = 92,
  AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
}) {
  return buildSheetNotationAudioPreviewPlan(
    document,
    bpm: bpm,
    accentVoice: accentVoice,
  );
}

@immutable
class _IndexedSheetNotationNote {
  final int index;
  final DrumSheetNotationNote note;

  const _IndexedSheetNotationNote({required this.index, required this.note});
}

_NotationPlayheadFrame? _playheadFrameForElapsed({
  required Duration elapsed,
  required _SheetNotationAudioPlan plan,
  required int bpm,
}) {
  if (bpm <= 0 || plan.playheadEvents.isEmpty || plan.totalBeatCount <= 0) {
    return null;
  }

  final double microsPerBeat = Duration.microsecondsPerMinute / bpm;
  final double beatsElapsed = elapsed.inMicroseconds / microsPerBeat;
  final double beatInCycle = beatsElapsed % plan.totalBeatCount;

  for (int index = 0; index < plan.playheadEvents.length; index += 1) {
    final _SheetNotationPlayheadEvent event = plan.playheadEvents[index];
    final double endBeat = event.startBeat + event.beatDuration;
    if (beatInCycle >= event.startBeat && beatInCycle < endBeat) {
      final _SheetNotationPlayheadEvent next =
          plan.playheadEvents[(index + 1) % plan.playheadEvents.length];
      final double progress = event.beatDuration <= 0
          ? 0
          : ((beatInCycle - event.startBeat) / event.beatDuration).clamp(0, 1);
      return _NotationPlayheadFrame(
        tokenIndex: event.tokenIndex,
        nextTokenIndex: next.tokenIndex,
        progress: progress,
        extendsToCycleEnd: index == plan.playheadEvents.length - 1,
      );
    }
  }

  final _SheetNotationPlayheadEvent lastEvent = plan.playheadEvents.last;
  return _NotationPlayheadFrame(
    tokenIndex: lastEvent.tokenIndex,
    nextTokenIndex: plan.playheadEvents.first.tokenIndex,
    progress: 1,
    extendsToCycleEnd: true,
  );
}

PatternTokenV1 _audioTokenForSheetNote(DrumSheetNotationNote note) {
  if (note.rest) return PatternTokenV1.rest;
  if (note.flam) return PatternTokenV1.flam;
  if (note.voices.contains(DrumSheetVoice.kick)) {
    return PatternTokenV1.kick;
  }
  final DrumSheetStrokeDescriptor? firstStroke = _firstAuthoredStroke(note);
  if (firstStroke?.hand == DrumSheetStrokeHand.left) {
    return PatternTokenV1.left;
  }
  return PatternTokenV1.right;
}

PatternNoteMarkingV1 _audioMarkingForSheetNote(DrumSheetNotationNote note) {
  if (note.accent) return PatternNoteMarkingV1.accent;
  if (note.ghost) return PatternNoteMarkingV1.ghost;
  return PatternNoteMarkingV1.normal;
}

DrumVoiceV1 _primaryAudioVoiceForNote(
  DrumSheetNotationNote note,
  PatternTokenV1 token,
  List<DrumVoiceV1> voices,
) {
  if (token.isKick) return DrumVoiceV1.kick;
  for (final DrumVoiceV1 voice in voices) {
    if (voice != DrumVoiceV1.kick) return voice;
  }
  return DrumVoiceV1.snare;
}

DrumVoiceV1 _audioVoiceForSheetVoice(DrumSheetVoice voice) {
  return switch (voice) {
    DrumSheetVoice.hihat => DrumVoiceV1.hihat,
    DrumSheetVoice.openHiHat => DrumVoiceV1.openHiHat,
    DrumSheetVoice.ride => DrumVoiceV1.ride,
    DrumSheetVoice.crash => DrumVoiceV1.crash,
    DrumSheetVoice.snare => DrumVoiceV1.snare,
    DrumSheetVoice.tom1 => DrumVoiceV1.rackTom,
    DrumSheetVoice.tom2 => DrumVoiceV1.tom2,
    DrumSheetVoice.floorTom => DrumVoiceV1.floorTom,
    DrumSheetVoice.kick => DrumVoiceV1.kick,
  };
}

Map<DrumVoiceV1, StickingCue?> _stickingCuesByAudioVoice({
  required DrumSheetNotationNote note,
  required List<DrumVoiceV1> noteVoices,
  required DrumVoiceV1 primaryVoice,
}) {
  if (note.rest || noteVoices.isEmpty) {
    return const <DrumVoiceV1, StickingCue?>{};
  }
  final String sticking = note.sticking.trim().toUpperCase();
  final bool hasStructuredSticking = note.voiceStrokes.any(
    (DrumSheetVoiceStroke voiceStroke) => voiceStroke.stroke != null,
  );
  if (!hasStructuredSticking) {
    final StickingCue? eventCue = stickingCueFromText(
      sticking,
      flam: note.flam,
      ghost: note.ghost,
    );
    return eventCue == null
        ? const <DrumVoiceV1, StickingCue?>{}
        : <DrumVoiceV1, StickingCue?>{primaryVoice: eventCue};
  }
  final Map<DrumVoiceV1, StickingCue?> cues = <DrumVoiceV1, StickingCue?>{};
  for (final DrumSheetVoice sheetVoice in note.voices) {
    final DrumSheetStrokeDescriptor? stroke = note.strokeForVoice(sheetVoice);
    if (stroke == null) continue;
    cues[_audioVoiceForSheetVoice(sheetVoice)] = stroke.stickingCue;
  }
  return cues;
}

double _beatCountForSheetNote(DrumSheetNoteValue value, DrumSheetFeel feel) {
  if (feel == DrumSheetFeel.triplet) {
    return switch (value) {
      DrumSheetNoteValue.eighth => 1 / 3,
      DrumSheetNoteValue.sixteenth => 1 / 6,
      DrumSheetNoteValue.thirtySecond => 1 / 12,
      _ => _beatCountForSheetValue(value),
    };
  }
  return _beatCountForSheetValue(value);
}

double _beatCountForSheetValue(
  DrumSheetNoteValue value, {
  DrumSheetFeel feel = DrumSheetFeel.straight,
}) {
  if (feel == DrumSheetFeel.triplet) {
    return switch (value) {
      DrumSheetNoteValue.eighth => 1 / 3,
      DrumSheetNoteValue.sixteenth => 1 / 6,
      DrumSheetNoteValue.thirtySecond => 1 / 12,
      _ => _beatCountForSheetValue(value),
    };
  }
  return switch (value) {
    DrumSheetNoteValue.whole => 4,
    DrumSheetNoteValue.half => 2,
    DrumSheetNoteValue.quarter => 1,
    DrumSheetNoteValue.eighth => 0.5,
    DrumSheetNoteValue.sixteenth => 0.25,
    DrumSheetNoteValue.thirtySecond => 0.125,
  };
}

Map<String, Object?> _noteJson(DrumSheetNotationNote note) {
  final String sticking = _displayStickingForNote(note);
  return <String, Object?>{
    if (note.value != null) 'value': note.value!.noteValueLabel,
    if (!note.rest)
      'voices': <String>[
        for (final DrumSheetVoice voice in note.voices) voice.id,
      ],
    if (note.rest) 'rest': true,
    if (sticking.isNotEmpty) 'sticking': sticking,
    if (note.accent) 'accent': true,
    if (note.flam) 'flam': true,
    if (note.ghost) 'ghost': true,
    if (note.tie) 'tie': true,
  };
}

String _displayStickingForNote(DrumSheetNotationNote note) {
  if (note.voiceStrokes.isNotEmpty) {
    final String sticking = _stickingForVoiceStrokes(note.voiceStrokes);
    if (sticking.isEmpty || note.voices.length <= 1) return sticking;
    if (sticking.length == 1) return sticking;
    if (sticking.contains('R')) return 'R';
    if (sticking.contains('L')) return 'L';
    return '';
  }
  final String sticking = note.sticking.trim().toUpperCase();
  if (sticking.isEmpty) return '';
  if (note.rest || note.voices.length <= 1) return sticking;

  if (sticking.length == 1) return sticking;
  if (sticking.contains('R')) return 'R';
  if (sticking.contains('L')) return 'L';
  if (sticking.contains('K')) return 'K';
  if (sticking.contains('F')) return 'F';
  return '';
}

DrumSheetStrokeDescriptor? _firstAuthoredStroke(DrumSheetNotationNote note) {
  for (final DrumSheetVoiceStroke voiceStroke in note.voiceStrokes) {
    if (voiceStroke.stroke != null) return voiceStroke.stroke;
  }
  return _singleStrokeDescriptorFromLegacySticking(note.sticking);
}

@immutable
class _ParseOptions {
  final bool lenient;

  const _ParseOptions({required this.lenient});
}

List<DrumSheetNotationNote> _parsePattern(
  String pattern,
  _ParseOptions options,
) {
  final List<DrumSheetNotationNote> notes = <DrumSheetNotationNote>[];
  for (int index = 0; index < pattern.length; index += 1) {
    final String char = pattern[index];
    if (char.trim().isEmpty) continue;
    if (char == '[') {
      final int close = pattern.indexOf(']', index + 1);
      if (close < 0) {
        if (options.lenient) break;
        throw const FormatException('Unclosed bracket group.');
      }
      final String body = pattern.substring(index + 1, close);
      try {
        notes.addAll(_notesFromVoiceFirstEventBody(body));
      } on FormatException {
        if (!options.lenient) rethrow;
      }
      index = close;
      continue;
    }
    if (!options.lenient) {
      throw FormatException(
        'Voice-first notation events must be bracketed: unexpected "$char".',
      );
    }
  }
  return notes;
}

@immutable
class _ParsedVoiceSpec {
  final DrumSheetVoice voice;
  final List<DrumSheetStrokeDescriptor>? strokes;

  const _ParsedVoiceSpec({required this.voice, required this.strokes});

  int get strokeCount => strokes?.length ?? 1;
}

List<DrumSheetNotationNote> _notesFromVoiceFirstEventBody(String body) {
  final String trimmed = body.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Empty notation event.');
  }
  final List<_ParsedVoiceSpec> specs = _voiceSpecsFromBody(trimmed);
  if (specs.isEmpty) {
    throw const FormatException('Notation event must contain a voice.');
  }
  final Set<DrumSheetVoice> seen = <DrumSheetVoice>{};
  for (final _ParsedVoiceSpec spec in specs) {
    if (!seen.add(spec.voice)) {
      throw FormatException(
        'Voice ${_voiceLabel(spec.voice)} appears more than once in one event.',
      );
    }
  }
  final int strokeCount = specs.first.strokeCount;
  for (final _ParsedVoiceSpec spec in specs.skip(1)) {
    if (spec.strokeCount != strokeCount) {
      throw const FormatException(
        'All voices in one event must have equal stroke counts.',
      );
    }
  }

  return <DrumSheetNotationNote>[
    for (int strokeIndex = 0; strokeIndex < strokeCount; strokeIndex += 1)
      _noteFromAlignedVoiceSpecs(specs, strokeIndex),
  ];
}

List<_ParsedVoiceSpec> _voiceSpecsFromBody(String body) {
  final List<String> tokens = body
      .split(RegExp(r'[,\s]+'))
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
  return <_ParsedVoiceSpec>[
    for (final String token in tokens) _voiceSpecFromToken(token),
  ];
}

_ParsedVoiceSpec _voiceSpecFromToken(String token) {
  final int colon = token.indexOf(':');
  final String voiceText = colon < 0 ? token : token.substring(0, colon);
  final DrumSheetVoice? voice = _voiceFromLabel(voiceText);
  if (voice == null) {
    throw FormatException('Unknown drum voice: $voiceText');
  }
  if (colon < 0) {
    return _ParsedVoiceSpec(voice: voice, strokes: null);
  }
  final String strokeText = token.substring(colon + 1);
  if (strokeText.isEmpty) {
    throw const FormatException('Stroke sequence cannot be empty.');
  }
  return _ParsedVoiceSpec(
    voice: voice,
    strokes: _parseStrokeSequence(strokeText),
  );
}

List<DrumSheetStrokeDescriptor> _parseStrokeSequence(String source) {
  final List<DrumSheetStrokeDescriptor> strokes = <DrumSheetStrokeDescriptor>[];
  for (int index = 0; index < source.length;) {
    final String char = source[index];
    if (char == '^') {
      if (index + 1 >= source.length) {
        throw const FormatException('Accent must be followed by L or R.');
      }
      final DrumSheetStrokeHand hand = _parseHand(source[index + 1]);
      strokes.add(
        DrumSheetStrokeDescriptor(
          hand: hand,
          articulation: DrumSheetStrokeArticulation.accent,
        ),
      );
      index += 2;
      continue;
    }
    if (char == '(') {
      if (index + 2 >= source.length || source[index + 2] != ')') {
        throw const FormatException(
          'Ghost stroke must be written as (L) or (R).',
        );
      }
      final DrumSheetStrokeHand hand = _parseHand(source[index + 1]);
      strokes.add(
        DrumSheetStrokeDescriptor(
          hand: hand,
          articulation: DrumSheetStrokeArticulation.ghost,
        ),
      );
      index += 3;
      continue;
    }
    strokes.add(DrumSheetStrokeDescriptor(hand: _parseHand(char)));
    index += 1;
  }
  if (strokes.isEmpty) {
    throw const FormatException('Stroke sequence cannot be empty.');
  }
  return strokes;
}

DrumSheetStrokeHand _parseHand(String source) {
  return switch (source.toUpperCase()) {
    'L' => DrumSheetStrokeHand.left,
    'R' => DrumSheetStrokeHand.right,
    _ => throw FormatException('Unsupported stroke hand: $source'),
  };
}

DrumSheetNotationNote _noteFromAlignedVoiceSpecs(
  List<_ParsedVoiceSpec> specs,
  int strokeIndex,
) {
  final List<DrumSheetVoice> voices = <DrumSheetVoice>[
    for (final _ParsedVoiceSpec spec in specs) spec.voice,
  ];
  final List<DrumSheetVoiceStroke> voiceStrokes = <DrumSheetVoiceStroke>[
    for (final _ParsedVoiceSpec spec in specs)
      DrumSheetVoiceStroke(
        voice: spec.voice,
        stroke: spec.strokes == null ? null : spec.strokes![strokeIndex],
      ),
  ];
  final String sticking = _stickingForVoiceStrokes(voiceStrokes);
  final Iterable<DrumSheetStrokeDescriptor> authoredStrokes = voiceStrokes
      .map((DrumSheetVoiceStroke voiceStroke) => voiceStroke.stroke)
      .whereType<DrumSheetStrokeDescriptor>();
  final bool accent = authoredStrokes.any(
    (DrumSheetStrokeDescriptor stroke) =>
        stroke.articulation == DrumSheetStrokeArticulation.accent,
  );
  final bool ghost =
      authoredStrokes.isNotEmpty &&
      authoredStrokes.every(
        (DrumSheetStrokeDescriptor stroke) =>
            stroke.articulation == DrumSheetStrokeArticulation.ghost,
      );
  return DrumSheetNotationNote(
    voices: voices,
    voiceStrokes: voiceStrokes,
    sticking: sticking,
    accent: accent,
    ghost: ghost,
  );
}

String _stickingForVoiceStrokes(List<DrumSheetVoiceStroke> voiceStrokes) {
  final List<String> labels = <String>[
    for (final DrumSheetVoiceStroke voiceStroke in voiceStrokes)
      if (voiceStroke.stroke != null) voiceStroke.stroke!.displayLabel,
  ];
  return labels.join();
}

@immutable
class _SerializedPhrase {
  final String text;
  final int noteCount;

  const _SerializedPhrase({required this.text, required this.noteCount});
}

_SerializedPhrase? _serializedPhraseAt(
  List<DrumSheetNotationNote> notes,
  int start, {
  required DrumSheetNoteValue subdivision,
}) {
  final DrumSheetNotationNote first = notes[start];
  if (!_canPhraseSerialize(first, subdivision: subdivision)) return null;
  final List<DrumSheetVoice> voices = first.voices;
  int end = start + 1;
  while (end < notes.length &&
      _samePhraseShape(
        first,
        notes[end],
        subdivision: subdivision,
        voices: voices,
      )) {
    end += 1;
  }
  if (end - start < 2) return null;
  final List<DrumSheetNotationNote> phraseNotes = notes.sublist(start, end);
  return _SerializedPhrase(
    text: _serializePhraseNotes(phraseNotes),
    noteCount: phraseNotes.length,
  );
}

bool _canPhraseSerialize(
  DrumSheetNotationNote note, {
  required DrumSheetNoteValue subdivision,
}) {
  if (note.rest || (note.value != null && note.value != subdivision)) {
    return false;
  }
  if (note.voices.isEmpty) return false;
  return note.voices.every(
    (DrumSheetVoice voice) => _strokeForSerialization(note, voice) != null,
  );
}

bool _samePhraseShape(
  DrumSheetNotationNote first,
  DrumSheetNotationNote candidate, {
  required DrumSheetNoteValue subdivision,
  required List<DrumSheetVoice> voices,
}) {
  if (!_canPhraseSerialize(candidate, subdivision: subdivision)) return false;
  if (candidate.voices.length != voices.length) return false;
  for (int index = 0; index < voices.length; index += 1) {
    if (candidate.voices[index] != voices[index]) return false;
  }
  return true;
}

String _serializePhraseNotes(List<DrumSheetNotationNote> notes) {
  final List<DrumSheetVoice> voices = notes.first.voices;
  final List<String> specs = <String>[];
  for (final DrumSheetVoice voice in voices) {
    final String strokes = notes.map((DrumSheetNotationNote note) {
      return _strokeForSerialization(note, voice)!.patternLabel;
    }).join();
    specs.add('${_voiceLabel(voice)}:$strokes');
  }
  return '[${specs.join(' ')}]';
}

String _serializeSingleNote(
  DrumSheetNotationNote note, {
  required DrumSheetNoteValue subdivision,
}) {
  if (note.rest) {
    throw ArgumentError(
      'Rests are not part of the voice-first notation syntax.',
    );
  }
  final List<String> specs = <String>[];
  for (final DrumSheetVoice voice in note.voices) {
    final DrumSheetStrokeDescriptor? stroke = _strokeForSerialization(
      note,
      voice,
    );
    specs.add(
      stroke == null
          ? _voiceLabel(voice)
          : '${_voiceLabel(voice)}:${stroke.patternLabel}',
    );
  }
  return '[${specs.join(' ')}]';
}

DrumSheetStrokeDescriptor? _strokeForSerialization(
  DrumSheetNotationNote note,
  DrumSheetVoice voice,
) {
  final DrumSheetStrokeDescriptor? structured = note.strokeForVoice(voice);
  if (structured != null) return structured;
  if (note.voiceStrokes.isNotEmpty) return null;
  if (note.voices.length != 1 || note.voices.single != voice) return null;
  return _singleStrokeDescriptorFromLegacySticking(
    note.sticking,
    accent: note.accent,
    ghost: note.ghost,
  );
}

DrumSheetStrokeDescriptor? _singleStrokeDescriptorFromLegacySticking(
  String sticking, {
  bool accent = false,
  bool ghost = false,
}) {
  final String normalized = sticking.trim().toUpperCase();
  if (normalized != 'L' && normalized != 'R') return null;
  return DrumSheetStrokeDescriptor(
    hand: normalized == 'L'
        ? DrumSheetStrokeHand.left
        : DrumSheetStrokeHand.right,
    articulation: accent
        ? DrumSheetStrokeArticulation.accent
        : ghost
        ? DrumSheetStrokeArticulation.ghost
        : DrumSheetStrokeArticulation.normal,
  );
}

DrumSheetVoice? _voiceFromLabel(String label) {
  return switch (label.trim().toUpperCase()) {
    'S' || 'SN' || 'SNARE' => DrumSheetVoice.snare,
    'T1' || 'TOM1' => DrumSheetVoice.tom1,
    'T2' || 'TOM2' => DrumSheetVoice.tom2,
    'FT' || 'FLOORTOM' || 'FLOOR_TOM' => DrumSheetVoice.floorTom,
    'K' || 'KICK' => DrumSheetVoice.kick,
    'HH' || 'HIHAT' || 'HIGHHAT' => DrumSheetVoice.hihat,
    'OHH' ||
    'OPEN_HH' ||
    'OPENHIHAT' ||
    'OPEN_HIHAT' => DrumSheetVoice.openHiHat,
    'CR' || 'C' || 'X' || 'CRASH' => DrumSheetVoice.crash,
    'RD' || 'RIDE' => DrumSheetVoice.ride,
    _ => null,
  };
}

String _voiceLabel(DrumSheetVoice voice) {
  return switch (voice) {
    DrumSheetVoice.snare => 'S',
    DrumSheetVoice.tom1 => 'T1',
    DrumSheetVoice.tom2 => 'T2',
    DrumSheetVoice.floorTom => 'FT',
    DrumSheetVoice.kick => 'K',
    DrumSheetVoice.hihat => 'HH',
    DrumSheetVoice.openHiHat => 'OHH',
    DrumSheetVoice.crash => 'CR',
    DrumSheetVoice.ride => 'RD',
  };
}

List<DrumSheetVoice> _defaultVoicesForNote(DrumSheetNotationNote note) {
  if (note.rest) return const <DrumSheetVoice>[];
  return note.voices.isEmpty
      ? const <DrumSheetVoice>[DrumSheetVoice.snare]
      : note.voices;
}

List<DrumSheetVoiceStroke> _voiceStrokesAfterVoiceOverride(
  DrumSheetNotationNote note,
  DrumSheetVoice? voice,
) {
  final List<DrumSheetVoice> nextVoices = voice == null
      ? _defaultVoicesForNote(note)
      : <DrumSheetVoice>[voice];
  if (nextVoices.isEmpty) return const <DrumSheetVoiceStroke>[];
  if (nextVoices.length == note.voices.length &&
      nextVoices.every((DrumSheetVoice next) => note.voices.contains(next))) {
    return note.voiceStrokes;
  }
  final DrumSheetStrokeDescriptor? existingStroke = _firstAuthoredStroke(note);
  return <DrumSheetVoiceStroke>[
    for (final DrumSheetVoice next in nextVoices)
      DrumSheetVoiceStroke(voice: next, stroke: existingStroke),
  ];
}

List<DrumSheetVoiceStroke> _voiceStrokesWithArticulation(
  DrumSheetNotationNote note,
  DrumSheetStrokeArticulation articulation,
) {
  final List<DrumSheetVoiceStroke> source = note.voiceStrokes.isNotEmpty
      ? note.voiceStrokes
      : <DrumSheetVoiceStroke>[
          for (final DrumSheetVoice voice in note.voices)
            DrumSheetVoiceStroke(
              voice: voice,
              stroke: _singleStrokeDescriptorFromLegacySticking(note.sticking),
            ),
        ];
  return <DrumSheetVoiceStroke>[
    for (final DrumSheetVoiceStroke voiceStroke in source)
      DrumSheetVoiceStroke(
        voice: voiceStroke.voice,
        stroke: voiceStroke.stroke == null
            ? null
            : DrumSheetStrokeDescriptor(
                hand: voiceStroke.stroke!.hand,
                articulation: articulation,
              ),
      ),
  ];
}

extension DrumSheetNoteValueSyntax on DrumSheetNoteValue {
  static DrumSheetNoteValue? fromPatternLabel(String label) {
    final String normalized = label.endsWith('n') ? label : '${label}n';
    return switch (normalized) {
      '1n' => DrumSheetNoteValue.whole,
      '2n' => DrumSheetNoteValue.half,
      '4n' => DrumSheetNoteValue.quarter,
      '8n' => DrumSheetNoteValue.eighth,
      '16n' => DrumSheetNoteValue.sixteenth,
      '32n' => DrumSheetNoteValue.thirtySecond,
      _ => null,
    };
  }

  String get patternLabel {
    return switch (this) {
      DrumSheetNoteValue.whole => '1',
      DrumSheetNoteValue.half => '2',
      DrumSheetNoteValue.quarter => '4',
      DrumSheetNoteValue.eighth => '8',
      DrumSheetNoteValue.sixteenth => '16',
      DrumSheetNoteValue.thirtySecond => '32',
    };
  }

  String get noteValueLabel => '${patternLabel}n';

  bool get beamable {
    return switch (this) {
      DrumSheetNoteValue.eighth ||
      DrumSheetNoteValue.sixteenth ||
      DrumSheetNoteValue.thirtySecond => true,
      _ => false,
    };
  }
}

extension DrumSheetVoiceSyntax on DrumSheetVoice {
  String get id {
    return switch (this) {
      DrumSheetVoice.hihat => 'hihat',
      DrumSheetVoice.openHiHat => 'openHiHat',
      DrumSheetVoice.ride => 'ride',
      DrumSheetVoice.crash => 'crash',
      DrumSheetVoice.snare => 'snare',
      DrumSheetVoice.tom1 => 'tom1',
      DrumSheetVoice.tom2 => 'tom2',
      DrumSheetVoice.floorTom => 'floorTom',
      DrumSheetVoice.kick => 'kick',
    };
  }
}
