import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum DrumSheetNoteValue {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
}

enum DrumSheetVoice { hihat, ride, crash, snare, tom1, tom2, floorTom, kick }

@immutable
class DrumSheetNotationDocument {
  final DrumSheetNoteValue subdivision;
  final List<DrumSheetNotationMeasure> measures;

  const DrumSheetNotationDocument({
    this.subdivision = DrumSheetNoteValue.eighth,
    required this.measures,
  });

  factory DrumSheetNotationDocument.fromPattern(
    String pattern, {
    DrumSheetNoteValue subdivision = DrumSheetNoteValue.eighth,
    bool lenient = false,
  }) {
    return DrumSheetNotationDocument(
      subdivision: subdivision,
      measures: <DrumSheetNotationMeasure>[
        DrumSheetNotationMeasure(
          notes: DrumSheetPatternParser.parse(pattern, lenient: lenient),
        ),
      ],
    );
  }

  List<DrumSheetNotationNote> get flattenedNotes {
    return <DrumSheetNotationNote>[
      for (final DrumSheetNotationMeasure measure in measures) ...measure.notes,
    ];
  }
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
  final bool debugUseNativeFallback;

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
    this.debugUseNativeFallback = false,
  });

  @override
  State<DrumSheetNotationDisplay> createState() =>
      _DrumSheetNotationDisplayState();
}

class _DrumSheetNotationDisplayState extends State<DrumSheetNotationDisplay> {
  static const String _hostAsset = 'web/sheet_notation/app_host.html';

  List<Rect> _hitRects = <Rect>[];
  WebViewController? _controller;
  bool _hostLoaded = false;
  double _webViewHeight = 160;
  double? _lastLayoutWidth;
  String? _lastPayloadJson;
  String? _lastRenderPayloadJson;
  String? _lastSelectionJson;

  @override
  void initState() {
    super.initState();
    if (!widget.debugUseNativeFallback) {
      _ensureWebViewController();
    }
  }

  WebViewController _ensureWebViewController() {
    final WebViewController? existing = _controller;
    if (existing != null) return existing;

    _hostLoaded = false;
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _hostLoaded = true;
            _lastPayloadJson = null;
            _lastRenderPayloadJson = null;
            _lastSelectionJson = null;
            _renderToWebView(width: _lastLayoutWidth);
          },
        ),
      )
      ..loadFlutterAsset(_hostAsset);
    _controller = controller;
    return controller;
  }

  @override
  void didUpdateWidget(covariant DrumSheetNotationDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.debugUseNativeFallback) {
      _ensureWebViewController();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugUseNativeFallback) return _buildNativeFallback(context);
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

  Widget _buildNativeFallback(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color noteColor = widget.noteColor ?? colorScheme.onSurface;
    final TextStyle stickingStyle =
        widget.stickingStyle ??
        Theme.of(context).textTheme.labelLarge?.copyWith(
          color: noteColor,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(color: noteColor, fontWeight: FontWeight.w700);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 640;
        final _SheetLayout layout = _SheetLayout.compute(
          document: widget.document,
          width: width,
          grouping: widget.grouping,
          minNoteWidth: widget.minNoteWidth,
          stickingStyle: stickingStyle,
        );
        final CustomPaint paint = CustomPaint(
          size: Size(width, layout.height),
          painter: _DrumSheetNotationPainter(
            layout: layout,
            document: widget.document,
            selectedIndexes: widget.selectedIndexes,
            finalRepeat: widget.finalRepeat,
            showSticking: widget.showSticking,
            stickingStyle: stickingStyle,
            staffColor: widget.staffColor ?? noteColor.withValues(alpha: 0.55),
            noteColor: noteColor,
            selectedColor:
                widget.selectedColor ?? Theme.of(context).colorScheme.primary,
            onHitRectsChanged: (List<Rect> rects) {
              _hitRects = rects;
            },
          ),
        );
        if (!widget.selectable && widget.onSelectionChanged == null) {
          return paint;
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) {
            final int? index = _noteIndexAt(details.localPosition);
            if (index == null) {
              widget.onSelectionChanged?.call(<int>{});
              return;
            }
            final Set<int> next = Set<int>.of(widget.selectedIndexes);
            if (next.contains(index)) {
              next.remove(index);
            } else {
              next.add(index);
            }
            widget.onSelectionChanged?.call(next);
          },
          child: paint,
        );
      },
    );
  }

  int? _noteIndexAt(Offset position) {
    for (int index = 0; index < _hitRects.length; index += 1) {
      if (_hitRects[index].contains(position)) return index;
    }
    return null;
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
      _controller
          ?.runJavaScript('''
(() => {
  const selected = JSON.parse($encodedSelection);
  if (window.DrumcabularySheetNotation == null) {
    return;
  }
  window.DrumcabularySheetNotation.setSelection(selected);
})();
''')
          .catchError((Object error) {
            debugPrint('Drum sheet notation selection update failed: $error');
          });
      return;
    }
    _controller
        ?.runJavaScript('''
(() => {
  const payload = JSON.parse($encodedPayload);
  if (window.DrumcabularySheetNotation == null) {
    window.__pendingDrumcabularySheetNotationPayload = payload;
    return;
  }
  window.DrumcabularySheetNotation.render(payload);
})();
''')
        .catchError((Object error) {
          debugPrint('Drum sheet notation JavaScript render failed: $error');
        });
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
        'theme': widget.darkTheme ? 'dark' : 'light',
        if (widget.backgroundColor != null)
          'backgroundColor': _cssColor(widget.backgroundColor!),
        if (widget.compactLayout) ...<String, Object?>{
          'staffY': 0,
          'staffHeight': 124,
          'systemGapY': 108,
          'paddingRight': 4,
          'systemEndReserve': 16,
          'noteSpacing': 30,
        },
      },
    };
  }

  double _estimatedHeightForWidth(double width) {
    final int noteCount = widget.document.flattenedNotes.length;
    if (noteCount == 0) return widget.compactLayout ? 112 : 140;
    final double formatterWidth = math.max(
      120,
      width - (widget.compactLayout ? 20 : 48),
    );
    final int notesPerSystem = math.max(
      4,
      (formatterWidth / widget.minNoteWidth).floor(),
    );
    final int systems = (noteCount / notesPerSystem).ceil();
    if (widget.compactLayout) {
      return 124 + math.max(0, systems - 1) * 108;
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
  if (!note.rest && note.voices.length > 1) return '';
  return note.sticking.toUpperCase();
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

@immutable
class _SheetLayout {
  static const double staffLeft = 22;
  static const double staffRight = 12;
  static const double topPadding = 18;
  static const double staffHeight = 40;
  static const double lineGap = 8;
  static const double stemHeight = 58;
  static const double stickingGap = 28;
  static const double systemGap = 104;
  static const double bottomPadding = 20;

  final double width;
  final double height;
  final List<_SheetSystem> systems;
  final TextStyle stickingStyle;

  const _SheetLayout({
    required this.width,
    required this.height,
    required this.systems,
    required this.stickingStyle,
  });

  static _SheetLayout compute({
    required DrumSheetNotationDocument document,
    required double width,
    required String? grouping,
    required double minNoteWidth,
    required TextStyle stickingStyle,
  }) {
    final double usableWidth = math.max(120, width - staffLeft - staffRight);
    final int notesPerSystem = math.max(
      3,
      usableWidth ~/ math.max(24, minNoteWidth),
    );
    final List<int> groups = _parseGrouping(grouping);
    final List<_NoteEntry> entries = <_NoteEntry>[];
    int absoluteIndex = 0;
    for (
      int measureIndex = 0;
      measureIndex < document.measures.length;
      measureIndex += 1
    ) {
      final DrumSheetNotationMeasure measure = document.measures[measureIndex];
      for (
        int noteIndex = 0;
        noteIndex < measure.notes.length;
        noteIndex += 1
      ) {
        entries.add(
          _NoteEntry(
            index: absoluteIndex,
            measureIndex: measureIndex,
            measureNoteIndex: noteIndex,
            note: measure.notes[noteIndex],
          ),
        );
        absoluteIndex += 1;
      }
    }
    final List<List<_NoteEntry>> systemEntries = _systemsForEntries(
      entries,
      notesPerSystem,
      groups,
    );
    final List<_SheetSystem> systems = <_SheetSystem>[];
    for (
      int systemIndex = 0;
      systemIndex < systemEntries.length;
      systemIndex += 1
    ) {
      final List<_NoteEntry> system = systemEntries[systemIndex];
      final double y = topPadding + systemIndex * systemGap;
      final double spacing = system.isEmpty
          ? minNoteWidth
          : math.min(minNoteWidth, usableWidth / math.max(system.length, 1));
      systems.add(
        _SheetSystem(
          entries: system,
          x: staffLeft,
          y: y,
          width: usableWidth,
          noteSpacing: spacing,
          beamBreaks: _beamBreaksForEntries(system, groups),
        ),
      );
    }
    final double height =
        topPadding +
        staffHeight +
        stickingGap +
        math.max(0, systems.length - 1) * systemGap +
        bottomPadding;
    return _SheetLayout(
      width: width,
      height: height,
      systems: systems,
      stickingStyle: stickingStyle,
    );
  }
}

@immutable
class _NoteEntry {
  final int index;
  final int measureIndex;
  final int measureNoteIndex;
  final DrumSheetNotationNote note;

  const _NoteEntry({
    required this.index,
    required this.measureIndex,
    required this.measureNoteIndex,
    required this.note,
  });
}

@immutable
class _SheetSystem {
  final List<_NoteEntry> entries;
  final double x;
  final double y;
  final double width;
  final double noteSpacing;
  final Set<int> beamBreaks;

  const _SheetSystem({
    required this.entries,
    required this.x,
    required this.y,
    required this.width,
    required this.noteSpacing,
    required this.beamBreaks,
  });
}

List<List<_NoteEntry>> _systemsForEntries(
  List<_NoteEntry> entries,
  int notesPerSystem,
  List<int> grouping,
) {
  if (entries.isEmpty) return const <List<_NoteEntry>>[];
  if (grouping.isEmpty) {
    return <List<_NoteEntry>>[
      for (int index = 0; index < entries.length; index += notesPerSystem)
        entries.sublist(
          index,
          math.min(index + notesPerSystem, entries.length),
        ),
    ];
  }

  final List<List<_NoteEntry>> grouped = <List<_NoteEntry>>[];
  int index = 0;
  int groupingIndex = 0;
  while (index < entries.length) {
    final int size = grouping[groupingIndex % grouping.length];
    grouped.add(entries.sublist(index, math.min(index + size, entries.length)));
    index += size;
    groupingIndex += 1;
  }

  final List<List<_NoteEntry>> systems = <List<_NoteEntry>>[];
  List<_NoteEntry> current = <_NoteEntry>[];
  for (final List<_NoteEntry> group in grouped) {
    if (current.isNotEmpty && current.length + group.length > notesPerSystem) {
      systems.add(current);
      current = <_NoteEntry>[];
    }
    current = <_NoteEntry>[...current, ...group];
  }
  if (current.isNotEmpty) systems.add(current);
  return systems;
}

Set<int> _beamBreaksForEntries(List<_NoteEntry> entries, List<int> grouping) {
  final Set<int> breaks = <int>{};
  if (grouping.isEmpty) return breaks;
  int consumed = 0;
  int groupingIndex = 0;
  while (consumed < entries.length) {
    if (consumed > 0) breaks.add(consumed);
    consumed += grouping[groupingIndex % grouping.length];
    groupingIndex += 1;
  }
  return breaks;
}

List<int> _parseGrouping(String? grouping) {
  if (grouping == null || grouping.trim().isEmpty) return const <int>[];
  final String trimmed = grouping.trim();
  if (RegExp(r'^\d+$').hasMatch(trimmed)) {
    return trimmed
        .split('')
        .map(int.parse)
        .where((int value) => value > 0)
        .toList(growable: false);
  }
  return RegExp(r'\d+')
      .allMatches(trimmed)
      .map((RegExpMatch match) => int.parse(match.group(0)!))
      .where((int value) => value > 0)
      .toList(growable: false);
}

class _DrumSheetNotationPainter extends CustomPainter {
  final _SheetLayout layout;
  final DrumSheetNotationDocument document;
  final Set<int> selectedIndexes;
  final bool finalRepeat;
  final bool showSticking;
  final TextStyle stickingStyle;
  final Color staffColor;
  final Color noteColor;
  final Color selectedColor;
  final ValueChanged<List<Rect>> onHitRectsChanged;

  const _DrumSheetNotationPainter({
    required this.layout,
    required this.document,
    required this.selectedIndexes,
    required this.finalRepeat,
    required this.showSticking,
    required this.stickingStyle,
    required this.staffColor,
    required this.noteColor,
    required this.selectedColor,
    required this.onHitRectsChanged,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint staffPaint = Paint()
      ..color = staffColor
      ..strokeWidth = 1;
    final Paint notePaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.8;
    final List<Rect> hitRects = List<Rect>.filled(
      document.flattenedNotes.length,
      Rect.zero,
      growable: false,
    );

    for (
      int systemIndex = 0;
      systemIndex < layout.systems.length;
      systemIndex += 1
    ) {
      final _SheetSystem system = layout.systems[systemIndex];
      _drawStaff(canvas, system, staffPaint);
      _drawPercussionClef(canvas, system, notePaint);
      if (finalRepeat && systemIndex == layout.systems.length - 1) {
        _drawEndRepeat(canvas, system, notePaint);
      }
      for (
        int localIndex = 0;
        localIndex < system.entries.length;
        localIndex += 1
      ) {
        final _NoteEntry entry = system.entries[localIndex];
        final Offset center = _noteCenter(system, localIndex, entry.note);
        final Rect hitRect = Rect.fromCenter(
          center: Offset(center.dx, system.y + 28),
          width: math.max(30, system.noteSpacing),
          height: 92,
        );
        hitRects[entry.index] = hitRect;
        if (selectedIndexes.contains(entry.index)) {
          _drawSelection(canvas, hitRect, selectedColor);
        }
        _drawNote(canvas, system, localIndex, entry, center, notePaint);
      }
      _drawBeams(canvas, system, notePaint);
    }
    onHitRectsChanged(hitRects);
  }

  void _drawStaff(Canvas canvas, _SheetSystem system, Paint paint) {
    for (int line = 0; line < 5; line += 1) {
      final double y = system.y + line * _SheetLayout.lineGap;
      canvas.drawLine(
        Offset(system.x, y),
        Offset(system.x + system.width, y),
        paint,
      );
    }
    canvas.drawLine(
      Offset(system.x, system.y),
      Offset(
        system.x,
        system.y + _SheetLayout.staffHeight - _SheetLayout.lineGap,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(system.x + system.width, system.y),
      Offset(
        system.x + system.width,
        system.y + _SheetLayout.staffHeight - _SheetLayout.lineGap,
      ),
      paint,
    );
  }

  void _drawPercussionClef(Canvas canvas, _SheetSystem system, Paint paint) {
    final double top = system.y + 8;
    canvas.drawRect(Rect.fromLTWH(system.x + 7, top, 4, 18), paint);
    canvas.drawRect(Rect.fromLTWH(system.x + 15, top, 4, 18), paint);
  }

  void _drawEndRepeat(Canvas canvas, _SheetSystem system, Paint paint) {
    final double x = system.x + system.width - 8;
    final double top = system.y;
    final double bottom = system.y + 32;
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      paint..strokeWidth = 2.4,
    );
    canvas.drawLine(
      Offset(x + 5, top),
      Offset(x + 5, bottom),
      paint..strokeWidth = 4,
    );
    canvas.drawCircle(Offset(x - 8, system.y + 12), 1.7, paint);
    canvas.drawCircle(Offset(x - 8, system.y + 21), 1.7, paint);
    paint.strokeWidth = 1.8;
  }

  void _drawSelection(Canvas canvas, Rect rect, Color color) {
    final Paint fill = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(5),
    );
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, stroke);
  }

  void _drawNote(
    Canvas canvas,
    _SheetSystem system,
    int localIndex,
    _NoteEntry entry,
    Offset center,
    Paint paint,
  ) {
    final DrumSheetNotationNote note = entry.note;
    if (note.rest) {
      canvas.drawCircle(center, 3.5, paint);
      if (showSticking) _drawSticking(canvas, system, localIndex, note);
      return;
    }
    if (note.accent) _drawAccent(canvas, system, localIndex, paint);
    if (note.ghost) _drawGhostParens(canvas, center, paint);
    if (note.flam) _drawFlam(canvas, center, paint);
    for (final DrumSheetVoice voice in note.voices) {
      final Offset voiceCenter = Offset(center.dx, _voiceY(system, voice));
      if (_isXNotehead(voice)) {
        _drawXNotehead(canvas, voiceCenter, paint);
      } else {
        canvas.save();
        canvas.translate(voiceCenter.dx, voiceCenter.dy);
        canvas.rotate(-0.25);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 12, height: 8),
          paint,
        );
        canvas.restore();
      }
    }
    final double stemX = center.dx + 6;
    canvas.drawLine(
      Offset(stemX, center.dy),
      Offset(stemX, system.y - _SheetLayout.stemHeight + 40),
      paint..strokeWidth = 1.8,
    );
    paint.strokeWidth = 1.8;
    if (showSticking) _drawSticking(canvas, system, localIndex, note);
  }

  void _drawBeams(Canvas canvas, _SheetSystem system, Paint paint) {
    int start = -1;
    for (int index = 0; index <= system.entries.length; index += 1) {
      final bool closes =
          index == system.entries.length ||
          system.beamBreaks.contains(index) ||
          system.entries[index].note.rest ||
          !system.entries[index].note
              .resolvedValue(document.subdivision)
              .beamable;
      if (closes) {
        if (start >= 0 && index - start > 1) {
          _drawBeamGroup(canvas, system, start, index - 1, paint);
        }
        start = -1;
        continue;
      }
      start = start < 0 ? index : start;
    }
  }

  void _drawBeamGroup(
    Canvas canvas,
    _SheetSystem system,
    int start,
    int end,
    Paint paint,
  ) {
    final double y = system.y - 18;
    final double x1 = _noteX(system, start) + 6;
    final double x2 = _noteX(system, end) + 6;
    canvas.drawRect(Rect.fromLTRB(x1, y, x2, y + 5), paint);
    final bool hasSixteenth = system.entries
        .sublist(start, end + 1)
        .any(
          (entry) =>
              entry.note.resolvedValue(document.subdivision) ==
              DrumSheetNoteValue.sixteenth,
        );
    final bool hasThirtySecond = system.entries
        .sublist(start, end + 1)
        .any(
          (entry) =>
              entry.note.resolvedValue(document.subdivision) ==
              DrumSheetNoteValue.thirtySecond,
        );
    if (hasSixteenth || hasThirtySecond) {
      canvas.drawRect(Rect.fromLTRB(x1, y + 8, x2, y + 12), paint);
    }
    if (hasThirtySecond) {
      canvas.drawRect(Rect.fromLTRB(x1, y + 15, x2, y + 18), paint);
    }
  }

  void _drawAccent(
    Canvas canvas,
    _SheetSystem system,
    int localIndex,
    Paint paint,
  ) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: '>',
        style: stickingStyle.copyWith(
          color: noteColor,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(_noteX(system, localIndex) - textPainter.width / 2, system.y - 44),
    );
  }

  void _drawGhostParens(Canvas canvas, Offset center, Paint paint) {
    final TextStyle style = stickingStyle.copyWith(
      color: noteColor.withValues(alpha: 0.72),
      fontSize: 20,
      fontWeight: FontWeight.w700,
    );
    _drawText(canvas, '(', Offset(center.dx - 16, center.dy - 15), style);
    _drawText(canvas, ')', Offset(center.dx + 9, center.dy - 15), style);
  }

  void _drawFlam(Canvas canvas, Offset center, Paint paint) {
    final Offset grace = Offset(center.dx - 12, center.dy - 8);
    canvas.save();
    canvas.translate(grace.dx, grace.dy);
    canvas.rotate(-0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 7, height: 5),
      paint,
    );
    canvas.restore();
    canvas.drawLine(
      Offset(grace.dx + 4, grace.dy),
      Offset(grace.dx + 4, grace.dy - 20),
      paint,
    );
    canvas.drawLine(
      Offset(grace.dx - 3, grace.dy + 5),
      Offset(grace.dx + 10, grace.dy - 10),
      paint,
    );
  }

  void _drawXNotehead(Canvas canvas, Offset center, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - 6, center.dy - 6),
      Offset(center.dx + 6, center.dy + 6),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - 6, center.dy + 6),
      Offset(center.dx + 6, center.dy - 6),
      paint,
    );
  }

  void _drawSticking(
    Canvas canvas,
    _SheetSystem system,
    int localIndex,
    DrumSheetNotationNote note,
  ) {
    final String sticking = _displayStickingForNote(note);
    if (sticking.isEmpty) return;
    _drawText(
      canvas,
      sticking,
      Offset(_noteX(system, localIndex) - 8, system.y + 52),
      stickingStyle,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(offset.dx - textPainter.width / 2, offset.dy),
    );
  }

  Offset _noteCenter(
    _SheetSystem system,
    int localIndex,
    DrumSheetNotationNote note,
  ) {
    return Offset(_noteX(system, localIndex), _primaryNoteY(system, note));
  }

  double _noteX(_SheetSystem system, int localIndex) {
    return system.x + 46 + localIndex * system.noteSpacing;
  }

  double _primaryNoteY(_SheetSystem system, DrumSheetNotationNote note) {
    if (note.rest) return system.y + 16;
    if (note.voices.isEmpty) return system.y + 16;
    return _voiceY(system, note.voices.last);
  }

  double _voiceY(_SheetSystem system, DrumSheetVoice voice) {
    return system.y +
        switch (voice) {
          DrumSheetVoice.crash => -4,
          DrumSheetVoice.ride => 0,
          DrumSheetVoice.hihat => 8,
          DrumSheetVoice.tom1 => 10,
          DrumSheetVoice.snare => 16,
          DrumSheetVoice.tom2 => 24,
          DrumSheetVoice.floorTom => 32,
          DrumSheetVoice.kick => 38,
        };
  }

  bool _isXNotehead(DrumSheetVoice voice) {
    return switch (voice) {
      DrumSheetVoice.hihat ||
      DrumSheetVoice.ride ||
      DrumSheetVoice.crash => true,
      _ => false,
    };
  }

  @override
  bool shouldRepaint(covariant _DrumSheetNotationPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.document != document ||
        oldDelegate.selectedIndexes != selectedIndexes ||
        oldDelegate.finalRepeat != finalRepeat ||
        oldDelegate.showSticking != showSticking ||
        oldDelegate.stickingStyle != stickingStyle ||
        oldDelegate.staffColor != staffColor ||
        oldDelegate.noteColor != noteColor ||
        oldDelegate.selectedColor != selectedColor;
  }
}
