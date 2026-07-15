import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../pattern_audio_service.dart';
import '../pattern_playback_scheduler.dart';

enum DrumSheetNoteValue {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
}

enum DrumSheetFeel { straight, triplet }

enum DrumSheetVoice { hihat, ride, crash, snare, tom1, tom2, floorTom, kick }

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
}

@immutable
class DrumSheetNotationNote {
  final DrumSheetNoteValue? value;
  final List<DrumSheetVoice> voices;
  final bool rest;
  final String sticking;
  final bool accent;
  final bool flam;
  final bool ghost;
  final bool tie;

  const DrumSheetNotationNote({
    this.value,
    this.voices = const <DrumSheetVoice>[],
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
    return notes.map((DrumSheetNotationNote note) {
      if (_isSimultaneousNote(note)) {
        final String sticking = note.sticking.toUpperCase();
        final String simultaneous = note.accent
            ? '[^$sticking]'
            : '[$sticking]';
        final List<String> overrides = <String>[];
        if (note.value != null && note.value != subdivision) {
          overrides.add(note.value!.patternLabel);
        }
        return overrides.isEmpty
            ? simultaneous
            : '[${overrides.join(' ')}:$simultaneous]';
      }
      if (note.accent && note.ghost) {
        throw ArgumentError('Ghost notes cannot be accented.');
      }
      final String base = _baseTokenForNote(note);
      final String marked = note.ghost ? '($base)' : base;
      final String token = note.accent ? '^$marked' : marked;
      final List<String> overrides = <String>[];
      final String? voiceOverride = _voiceOverrideLabelForNote(note);
      if (voiceOverride != null) overrides.add(voiceOverride);
      if (note.value != null && note.value != subdivision) {
        overrides.add(note.value!.patternLabel);
      }
      return overrides.isEmpty ? token : '[${overrides.join(' ')}:$token]';
    }).join();
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
  final bool darkTheme;
  final Color? backgroundColor;
  final bool audioPreviewEnabled;
  final int audioPreviewBpm;
  final AccentVoiceV1 audioPreviewAccentVoice;
  final DrumSheetNotationController? controller;

  const DrumSheetNotationDisplay({
    super.key,
    required this.document,
    this.grouping,
    this.selectedIndexes = const <int>{},
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
    this.darkTheme = false,
    this.backgroundColor,
    this.audioPreviewEnabled = false,
    this.audioPreviewBpm = 92,
    this.audioPreviewAccentVoice = AccentVoiceV1.snare,
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
                widget.audioPreviewAccentVoice)) {
      unawaited(_stopAudioPreview());
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
          PatternAudioService();
      await audioPreview.start(
        tokens: plan.tokens,
        markings: plan.markings,
        voices: plan.voices,
        grouping: PatternGroupingV1.none,
        timing: plan.timing,
        bpm: widget.audioPreviewBpm,
        accentVoice: widget.audioPreviewAccentVoice,
        additionalVoicesByIndex: plan.additionalVoicesByIndex,
      );
      if (!mounted) return;
      _activeAudioPreviewOwner = this;
      _audioPreviewPlan = plan;
      _playheadStopwatch
        ..reset()
        ..start();
      _startPlayheadTicker();
      setState(() {
        _audioPreviewRunning = true;
        _audioPreviewPreparing = false;
      });
      _updatePlayheadFrame();
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Drum sheet notation audio preview failed: $error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Notation audio failed.')));
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

  void _updatePlayheadFrame() {
    final _SheetNotationAudioPlan? plan = _audioPreviewPlan;
    if (plan == null || !_playheadStopwatch.isRunning) {
      _playheadFrame = null;
      _sendPlayheadToWebView(null);
      return;
    }
    final _NotationPlayheadFrame? frame = _playheadFrameForElapsed(
      elapsed: _playheadStopwatch.elapsed,
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
    final String selectionJson = jsonEncode(payload['selectedIndexes']);
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
  window.DrumcabularySheetNotation.setSelection(selected);
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
    return <String, Object?>{
      'document': _documentJson(widget.document),
      'selectedIndexes': widget.selectedIndexes.toList()..sort(),
      'options': <String, Object?>{
        'availableWidth': width.floor(),
        'finalRepeat': widget.finalRepeat,
        'grouping': widget.grouping,
        'minNoteWidth': widget.minNoteWidth,
        'preserveMeasures': true,
        'showSticking': widget.showSticking,
        'theme': widget.darkTheme ? 'dark' : 'light',
        if (widget.backgroundColor != null)
          'backgroundColor': _cssColor(widget.backgroundColor!),
        if (widget.compactLayout) ...<String, Object?>{
          'staffY': 34,
          'staffHeight': 124,
          'systemGapY': 108,
          'paddingRight': 4,
          'systemEndReserve': 16,
          'timeSignatureReserve': 52,
          'noteSpacing': 30,
          'groupGap': 14,
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
class _SheetNotationAudioPlan {
  final List<PatternTokenV1> tokens;
  final List<PatternNoteMarkingV1> markings;
  final List<DrumVoiceV1> voices;
  final PatternTimingV1 timing;
  final Map<int, List<DrumVoiceV1>> additionalVoicesByIndex;
  final List<_SheetNotationPlayheadEvent> playheadEvents;
  final double totalBeatCount;

  const _SheetNotationAudioPlan({
    required this.tokens,
    required this.markings,
    required this.voices,
    required this.timing,
    required this.additionalVoicesByIndex,
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

@visibleForTesting
PatternAudioPlanV1 buildSheetNotationAudioPreviewPlanForTesting(
  DrumSheetNotationDocument document, {
  int bpm = 92,
  AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
}) {
  final _SheetNotationAudioPlan plan = _audioPlanForDocument(document);
  return PatternAudioService.buildPlan(
    tokens: plan.tokens,
    markings: plan.markings,
    voices: plan.voices,
    grouping: PatternGroupingV1.none,
    timing: plan.timing,
    bpm: bpm,
    accentVoice: accentVoice,
    additionalVoicesByIndex: plan.additionalVoicesByIndex,
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

  final String sticking = note.sticking.trim().toUpperCase();
  for (int index = 0; index < sticking.length; index += 1) {
    final String char = sticking[index];
    switch (char) {
      case 'R':
        return PatternTokenV1.right;
      case 'L':
        return PatternTokenV1.left;
      case 'K':
        return PatternTokenV1.kick;
      case 'F':
        return PatternTokenV1.flam;
      case 'X':
        return PatternTokenV1.accent;
      case '_':
        return PatternTokenV1.rest;
    }
  }

  if (note.voices.contains(DrumSheetVoice.kick)) {
    return PatternTokenV1.kick;
  }
  if (note.voices.contains(DrumSheetVoice.crash) ||
      note.voices.contains(DrumSheetVoice.ride)) {
    return PatternTokenV1.accent;
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
  if (token.kind == PatternTokenKindV1.accent) {
    for (final DrumVoiceV1 voice in voices) {
      if (voice == DrumVoiceV1.crash ||
          voice == DrumVoiceV1.ride ||
          voice == DrumVoiceV1.hihat) {
        return voice;
      }
    }
    return DrumVoiceV1.crash;
  }
  for (final DrumVoiceV1 voice in voices) {
    if (voice != DrumVoiceV1.kick) return voice;
  }
  return DrumVoiceV1.snare;
}

DrumVoiceV1 _audioVoiceForSheetVoice(DrumSheetVoice voice) {
  return switch (voice) {
    DrumSheetVoice.hihat => DrumVoiceV1.hihat,
    DrumSheetVoice.ride => DrumVoiceV1.ride,
    DrumSheetVoice.crash => DrumVoiceV1.crash,
    DrumSheetVoice.snare => DrumVoiceV1.snare,
    DrumSheetVoice.tom1 => DrumVoiceV1.rackTom,
    DrumSheetVoice.tom2 => DrumVoiceV1.tom2,
    DrumSheetVoice.floorTom => DrumVoiceV1.floorTom,
    DrumSheetVoice.kick => DrumVoiceV1.kick,
  };
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

@immutable
class _ParseOptions {
  final bool lenient;
  final bool initialAccent;
  final DrumSheetNoteValue? value;
  final List<DrumSheetVoice>? voices;

  const _ParseOptions({
    required this.lenient,
    this.initialAccent = false,
    this.value,
    this.voices,
  });
}

List<DrumSheetNotationNote> _parsePattern(
  String pattern,
  _ParseOptions options,
) {
  final List<DrumSheetNotationNote> notes = <DrumSheetNotationNote>[];
  bool accent = options.initialAccent;
  for (int index = 0; index < pattern.length; index += 1) {
    final String char = pattern[index];
    if (char.trim().isEmpty) continue;
    if (char == '^') {
      accent = true;
      continue;
    }
    if (char == '(') {
      final int close = pattern.indexOf(')', index + 1);
      if (close < 0) {
        if (options.lenient) break;
        throw const FormatException('Unclosed ghost note group.');
      }
      final String inner = pattern.substring(index + 1, close).trim();
      if (inner.isEmpty) {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        throw const FormatException('Empty ghost note group.');
      }
      if (accent) {
        throw const FormatException('Ghost notes cannot be accented.');
      }
      final List<DrumSheetNotationNote> ghostNotes = _parsePattern(
        inner,
        _ParseOptions(
          lenient: options.lenient,
          value: options.value,
          voices: options.voices,
        ),
      );
      if (ghostNotes.length != 1) {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        throw const FormatException(
          'Ghost note groups must contain exactly one note.',
        );
      }
      if (ghostNotes.first.accent) {
        throw const FormatException('Ghost notes cannot be accented.');
      }
      notes.add(ghostNotes.first.copyWith(ghost: true));
      accent = false;
      index = close;
      continue;
    }
    if (char == '[') {
      final int close = pattern.indexOf(']', index + 1);
      if (close < 0) {
        if (options.lenient) break;
        throw const FormatException('Unclosed bracket group.');
      }
      final String body = pattern.substring(index + 1, close);
      final int separator = body.indexOf(':');
      if (separator < 0) {
        try {
          notes.add(
            _simultaneousNoteFromBody(
              body,
              accent: accent,
              value: options.value,
            ),
          );
        } on FormatException {
          if (!options.lenient) rethrow;
        }
        accent = false;
        index = close;
        continue;
      }
      late final _ParsedOverride override;
      try {
        override = _overrideFromLabel(body.substring(0, separator).trim());
      } on FormatException {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        rethrow;
      }
      notes.addAll(
        _parsePattern(
          body.substring(separator + 1),
          _ParseOptions(
            initialAccent: accent,
            lenient: options.lenient,
            value: override.value ?? options.value,
            voices: override.voices ?? options.voices,
          ),
        ),
      );
      accent = false;
      index = close;
      continue;
    }
    final String? multi = _multiCharacterTokenAt(pattern, index);
    if (multi != null) {
      notes.add(
        _noteFromToken(
          multi,
          accent: accent,
          value: options.value,
          voices: options.voices,
        ),
      );
      accent = false;
      index += multi.length - 1;
      continue;
    }
    try {
      notes.add(
        _noteFromToken(
          char,
          accent: accent,
          value: options.value,
          voices: options.voices,
        ),
      );
    } on FormatException {
      if (!options.lenient) rethrow;
    }
    accent = false;
  }
  return notes;
}

DrumSheetNotationNote _simultaneousNoteFromBody(
  String body, {
  required bool accent,
  DrumSheetNoteValue? value,
}) {
  final String trimmed = body.trim();
  if (trimmed.isEmpty) {
    throw const FormatException(
      'Empty bracket. Use a multi-voice beat like [XK] or an override like [T1:L].',
    );
  }

  final List<DrumSheetNotationNote> parts = _parsePattern(
    trimmed,
    const _ParseOptions(lenient: false),
  );
  if (parts.length < 2) {
    throw const FormatException(
      'Multi-voice beats must contain at least two notes, such as [XK] or [RL].',
    );
  }
  if (parts.any((DrumSheetNotationNote note) => note.rest)) {
    throw const FormatException(
      'Rests are not allowed inside multi-voice beats.',
    );
  }

  final List<DrumSheetVoice> voices = <DrumSheetVoice>[];
  final StringBuffer sticking = StringBuffer();
  bool hasGhost = false;
  bool hasAccent = accent;
  bool hasFlam = false;
  for (final DrumSheetNotationNote note in parts) {
    for (final DrumSheetVoice voice in note.voices) {
      if (!voices.contains(voice)) voices.add(voice);
    }
    sticking.write(_baseTokenForNote(note));
    hasGhost = hasGhost || note.ghost;
    hasAccent = hasAccent || note.accent;
    hasFlam = hasFlam || note.flam;
  }
  return DrumSheetNotationNote(
    value: value,
    voices: voices,
    sticking: sticking.toString(),
    accent: hasAccent,
    ghost: hasGhost,
    flam: hasFlam,
  );
}

@immutable
class _ParsedOverride {
  final DrumSheetNoteValue? value;
  final List<DrumSheetVoice>? voices;

  const _ParsedOverride({this.value, this.voices});
}

_ParsedOverride _overrideFromLabel(String label) {
  final List<String> parts = label
      .split(RegExp(r'[,\s]+'))
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    throw const FormatException('Override label cannot be empty.');
  }
  DrumSheetNoteValue? value;
  List<DrumSheetVoice>? voices;
  for (final String part in parts) {
    final DrumSheetNoteValue? parsedValue =
        DrumSheetNoteValueSyntax.fromPatternLabel(part);
    if (parsedValue != null) {
      value = parsedValue;
      continue;
    }
    final List<DrumSheetVoice>? parsedVoices = _voicesFromLabel(part);
    if (parsedVoices != null) {
      voices = <DrumSheetVoice>[
        ...?voices,
        for (final DrumSheetVoice voice in parsedVoices)
          if (!(voices ?? const <DrumSheetVoice>[]).contains(voice)) voice,
      ];
      continue;
    }
    throw FormatException('Unsupported override: $part');
  }
  return _ParsedOverride(value: value, voices: voices);
}

String? _multiCharacterTokenAt(String pattern, int index) {
  return null;
}

DrumSheetNotationNote _noteFromToken(
  String symbol, {
  required bool accent,
  DrumSheetNoteValue? value,
  List<DrumSheetVoice>? voices,
}) {
  final String token = symbol.toUpperCase();
  DrumSheetNotationNote note({
    required String sticking,
    required List<DrumSheetVoice> defaultVoices,
    bool flam = false,
    bool rest = false,
  }) {
    return DrumSheetNotationNote(
      value: value,
      voices: rest ? const <DrumSheetVoice>[] : voices ?? defaultVoices,
      rest: rest,
      sticking: sticking,
      accent: accent,
      flam: flam,
    );
  }

  return switch (token) {
    'R' || 'L' => note(
      sticking: token,
      defaultVoices: <DrumSheetVoice>[DrumSheetVoice.snare],
    ),
    'K' => note(
      sticking: 'K',
      defaultVoices: <DrumSheetVoice>[DrumSheetVoice.kick],
    ),
    'F' => note(
      sticking: 'F',
      defaultVoices: <DrumSheetVoice>[DrumSheetVoice.snare],
      flam: true,
    ),
    'B' => throw const FormatException(
      'Invalid token: B is no longer supported. Use [RL] for both hands/unison or assign explicit voices.',
    ),
    'X' => note(
      sticking: 'X',
      defaultVoices: <DrumSheetVoice>[DrumSheetVoice.crash],
    ),
    '_' => note(
      sticking: '_',
      defaultVoices: const <DrumSheetVoice>[],
      rest: true,
    ),
    _ => throw FormatException('Unsupported pattern token: $symbol'),
  };
}

List<DrumSheetVoice>? _voicesFromLabel(String label) {
  return switch (label.toUpperCase()) {
    'S' || 'SN' || 'SNARE' => <DrumSheetVoice>[DrumSheetVoice.snare],
    'T1' || 'TOM1' => <DrumSheetVoice>[DrumSheetVoice.tom1],
    'T2' || 'TOM2' => <DrumSheetVoice>[DrumSheetVoice.tom2],
    'FT' ||
    'FLOORTOM' ||
    'FLOOR_TOM' => <DrumSheetVoice>[DrumSheetVoice.floorTom],
    'K' || 'KICK' => <DrumSheetVoice>[DrumSheetVoice.kick],
    'HH' || 'HIHAT' || 'HIGHHAT' => <DrumSheetVoice>[DrumSheetVoice.hihat],
    'C' || 'X' || 'CRASH' => <DrumSheetVoice>[DrumSheetVoice.crash],
    'RD' || 'RIDE' => <DrumSheetVoice>[DrumSheetVoice.ride],
    _ => null,
  };
}

String _baseTokenForNote(DrumSheetNotationNote note) {
  if (note.rest) return '_';
  if (note.flam) return 'F';
  final String sticking = note.sticking.toUpperCase();
  if (_isLimbSticking(sticking)) return sticking;
  if (note.voices.contains(DrumSheetVoice.kick)) return 'K';
  if (note.voices.contains(DrumSheetVoice.hihat) &&
      note.voices.contains(DrumSheetVoice.snare)) {
    return '[RL]';
  }
  if (note.voices.contains(DrumSheetVoice.crash)) {
    return 'X';
  }
  return sticking.isEmpty ? 'R' : sticking;
}

String? _voiceOverrideLabelForNote(DrumSheetNotationNote note) {
  if (!_isLimbSticking(note.sticking)) return null;
  if (note.voices.length == 1 && note.voices.first == DrumSheetVoice.snare) {
    return null;
  }
  return note.voices.map(_voiceOverrideLabel).join(' ');
}

String _voiceOverrideLabel(DrumSheetVoice voice) {
  return switch (voice) {
    DrumSheetVoice.snare => 'S',
    DrumSheetVoice.tom1 => 'T1',
    DrumSheetVoice.tom2 => 'T2',
    DrumSheetVoice.floorTom => 'FT',
    DrumSheetVoice.kick => 'K',
    DrumSheetVoice.hihat => 'HH',
    DrumSheetVoice.crash => 'X',
    DrumSheetVoice.ride => 'RD',
  };
}

List<DrumSheetVoice> _defaultVoicesForNote(DrumSheetNotationNote note) {
  if (note.rest) return const <DrumSheetVoice>[];
  if (note.flam) return const <DrumSheetVoice>[DrumSheetVoice.snare];
  return switch (note.sticking.toUpperCase()) {
    'K' => const <DrumSheetVoice>[DrumSheetVoice.kick],
    'X' => const <DrumSheetVoice>[DrumSheetVoice.crash],
    _ => const <DrumSheetVoice>[DrumSheetVoice.snare],
  };
}

bool _isLimbSticking(String sticking) {
  final String normalized = sticking.toUpperCase();
  return normalized == 'R' || normalized == 'L';
}

bool _isSimultaneousNote(DrumSheetNotationNote note) {
  if (note.rest) return false;
  if (note.sticking.length < 2) return false;
  return RegExp(r'^[RLKFX]+$').hasMatch(note.sticking.toUpperCase());
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
