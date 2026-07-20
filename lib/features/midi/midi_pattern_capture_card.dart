import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../practice/widgets/sheet_notation_display.dart';
import 'midi_pattern_capture.dart';

class MidiPatternCaptureCard extends StatefulWidget {
  final MidiPatternCaptureController controller;

  const MidiPatternCaptureCard({super.key, required this.controller});

  @override
  State<MidiPatternCaptureCard> createState() => _MidiPatternCaptureCardState();
}

class _MidiPatternCaptureCardState extends State<MidiPatternCaptureCard> {
  static const Duration _manualEditDebounce = Duration(milliseconds: 250);

  late final TextEditingController _patternController;
  Timer? _manualEditTimer;
  DrumSheetNotationDocument? _renderedDocument;
  String? _validationError;
  bool _syncingText = false;

  @override
  void initState() {
    super.initState();
    _patternController = TextEditingController(
      text: widget.controller.generatedPattern,
    );
    widget.controller.addListener(_handleCaptureChanged);
    _syncFromCaptureController();
  }

  @override
  void didUpdateWidget(covariant MidiPatternCaptureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleCaptureChanged);
    widget.controller.addListener(_handleCaptureChanged);
    _syncFromCaptureController();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleCaptureChanged);
    _manualEditTimer?.cancel();
    _patternController.dispose();
    super.dispose();
  }

  void _handleCaptureChanged() {
    _syncFromCaptureController();
  }

  void _syncFromCaptureController() {
    _manualEditTimer?.cancel();
    final String pattern = widget.controller.generatedPattern;
    _syncingText = true;
    if (_patternController.text != pattern) {
      _patternController.value = TextEditingValue(
        text: pattern,
        selection: TextSelection.collapsed(offset: pattern.length),
      );
    }
    _syncingText = false;
    _validateAndRender(pattern, clearPreviewWhenEmpty: true);
  }

  void _handleManualEdit(String value) {
    if (_syncingText || widget.controller.isRecording) {
      return;
    }
    _manualEditTimer?.cancel();
    _manualEditTimer = Timer(_manualEditDebounce, () {
      if (!mounted) return;
      _validateAndRender(value, clearPreviewWhenEmpty: true);
    });
  }

  void _validateAndRender(String value, {required bool clearPreviewWhenEmpty}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        if (clearPreviewWhenEmpty) _renderedDocument = null;
        _validationError = null;
      });
      return;
    }

    try {
      final DrumSheetNotationDocument document =
          DrumSheetNotationDocument.fromPattern(trimmed);
      if (!mounted) return;
      setState(() {
        _renderedDocument = document;
        _validationError = null;
      });
    } on FormatException catch (error) {
      _setValidationError(error.message);
    } on ArgumentError catch (error) {
      _setValidationError(error.message ?? 'Invalid pattern.');
    } on Object catch (error) {
      _setValidationError('$error');
    }
  }

  void _setValidationError(String message) {
    if (!mounted) return;
    setState(() => _validationError = message);
  }

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'MIDI Pattern Capture',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          DrumActionRow(
            children: <Widget>[
              FilledButton.icon(
                onPressed: widget.controller.record,
                icon: const Icon(Icons.fiber_manual_record_rounded),
                label: const Text('Record'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.isRecording
                    ? widget.controller.stop
                    : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                'Estimated BPM ${_tempoEstimateLabel(widget.controller.tempoEstimate)}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Generated pattern string',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeOrange,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _patternController,
            readOnly: widget.controller.isRecording,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              height: 1.35,
            ),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: DrumcabularyTheme.edgeSurfaceSecondary,
              errorText: _validationError,
              errorMaxLines: 2,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: _handleManualEdit,
          ),
          const SizedBox(height: 14),
          Text(
            'Rendered notation preview',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeOrange,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _CapturedPatternPreview(document: _renderedDocument),
        ],
      ),
    );
  }
}

class _CapturedPatternPreview extends StatelessWidget {
  static const DrumSheetNotationDocument _emptyDocument =
      DrumSheetNotationDocument(
        measures: <DrumSheetNotationMeasure>[
          DrumSheetNotationMeasure(notes: <DrumSheetNotationNote>[]),
        ],
      );

  final DrumSheetNotationDocument? document;

  const _CapturedPatternPreview({required this.document});

  @override
  Widget build(BuildContext context) {
    final DrumSheetNotationDocument document = this.document ?? _emptyDocument;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeNotationPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D2C6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: DrumSheetNotationDisplay(
          document: document,
          selectable: false,
          compactLayout: true,
          minNoteWidth: 34,
          showSticking: false,
          backgroundColor: DrumcabularyTheme.edgeNotationPanel,
          noteColor: DrumcabularyTheme.edgeNotationInk,
          staffColor: DrumcabularyTheme.edgeNotationInk.withValues(alpha: 0.62),
          selectedColor: DrumcabularyTheme.edgeOrange,
        ),
      ),
    );
  }
}

String _tempoEstimateLabel(MidiTempoEstimate? estimate) {
  if (estimate == null) return '--';
  return '${estimate.roundedBpm}';
}
