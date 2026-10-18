import '../../core/music/canonical_musical_document.dart';
import '../../core/practice/practice_domain_v1.dart';
import 'widgets/sheet_notation_display.dart';

enum MusicalDiagnosticSeverity { warning, error }

class MusicalConversionDiagnostic {
  final String code;
  final String message;
  final MusicalDiagnosticSeverity severity;
  final int? measureIndex;
  final int? noteIndex;
  const MusicalConversionDiagnostic(
    this.code,
    this.message, {
    this.severity = MusicalDiagnosticSeverity.error,
    this.measureIndex,
    this.noteIndex,
  });
}

class CanonicalConversionResult {
  final CanonicalMusicalDocument? document;
  final List<MusicalConversionDiagnostic> diagnostics;
  CanonicalConversionResult(
    this.document,
    List<MusicalConversionDiagnostic> diagnostics,
  ) : diagnostics = List.unmodifiable(diagnostics);
  bool get isSuccess => document != null;
}

/// Opt-in, one-way boundary. Existing consumers never call this implicitly.
class SheetToCanonicalAdapter {
  static CanonicalConversionResult convert(
    DrumSheetNotationDocument source, {
    String sourceId = 'sheet',
  }) {
    final diagnostics = <MusicalConversionDiagnostic>[];
    if (sourceId.isEmpty) {
      return CanonicalConversionResult(null, [
        const MusicalConversionDiagnostic(
          'invalid_source_id',
          'Source identity must be nonempty.',
        ),
      ]);
    }
    try {
      final parts = source.timeSignature.split('/');
      if (parts.length != 2) throw ArgumentError('Invalid time signature.');
      final meter = MusicalTimeSignature(
        int.parse(parts[0].trim()),
        int.parse(parts[1].trim()),
      );
      if (source.repeatCount != null && source.repeatCount != 1) {
        return CanonicalConversionResult(null, [
          const MusicalConversionDiagnostic(
            'unsupported_repeat',
            'Repeat semantics require an explicit future arrangement model; no expansion was performed.',
          ),
        ]);
      }
      final events = <TimedMusicalEvent>[];
      final measures = <MusicalMeasure>[];
      final tuplets = <TupletGroup>[];
      var cursor = MusicalTime.zero;
      for (var m = 0; m < source.measures.length; m++) {
        final notes = source.measures[m].notes;
        final measureStart = cursor;
        final pendingTuplet = <TimedMusicalEvent>[];
        void flushTuplet() {
          if (pendingTuplet.isEmpty) return;
          tuplets.add(
            TupletGroup(
              id: '$sourceId:tuplet:${tuplets.length}',
              eventIds: pendingTuplet.map((e) => e.id).toList(),
              actual: 3,
              normal: 2,
              isIncomplete: pendingTuplet.length < 3,
            ),
          );
          pendingTuplet.clear();
        }

        for (var n = 0; n < notes.length; n++) {
          final note = notes[n];
          final problem = _noteProblem(note);
          if (problem != null) {
            diagnostics.add(
              MusicalConversionDiagnostic(
                problem.$1,
                problem.$2,
                measureIndex: m,
                noteIndex: n,
              ),
            );
            continue;
          }
          final written = _duration(note.resolvedValue(source.subdivision));
          final isTriplet =
              source.feel == DrumSheetFeel.triplet && written < MusicalTime(1);
          final duration = isTriplet ? written * MusicalTime(2, 3) : written;
          final event = TimedMusicalEvent(
            id: '$sourceId:m$m:e$n',
            onset: cursor,
            duration: duration,
            writtenDuration: written,
            isRest: note.rest,
            strikes: note.rest
                ? []
                : note.voices.map((voice) => _strike(note, voice)).toList(),
          );
          events.add(event);
          cursor = cursor + duration;
          if (isTriplet) {
            if (pendingTuplet.isNotEmpty &&
                pendingTuplet.last.writtenDuration != written) {
              flushTuplet();
            }
            pendingTuplet.add(event);
            if (pendingTuplet.length == 3) flushTuplet();
          } else {
            flushTuplet();
          }
        }
        flushTuplet();
        final duration = cursor - measureStart;
        if (!duration.isPositive || duration > meter.duration) {
          diagnostics.add(
            MusicalConversionDiagnostic(
              duration.isPositive ? 'measure_overflow' : 'empty_measure',
              'Source measure duration $duration cannot fit ${source.timeSignature}; no rebar or truncation performed.',
              measureIndex: m,
            ),
          );
        } else {
          final incomplete = duration < meter.duration;
          measures.add(
            MusicalMeasure(
              id: '$sourceId:m$m',
              onset: measureStart,
              duration: duration,
              timeSignature: meter,
              isIncomplete: incomplete,
            ),
          );
          if (incomplete) {
            diagnostics.add(
              MusicalConversionDiagnostic(
                'incomplete_measure',
                'Preserved incomplete measure ($duration beats) without padding.',
                severity: MusicalDiagnosticSeverity.warning,
                measureIndex: m,
              ),
            );
          }
        }
      }
      if (diagnostics.any(
        (d) => d.severity == MusicalDiagnosticSeverity.error,
      )) {
        return CanonicalConversionResult(null, diagnostics);
      }
      return CanonicalConversionResult(
        CanonicalMusicalDocument(
          timeSignature: meter,
          events: events,
          measures: measures,
          tupletGroups: tuplets,
        ),
        diagnostics,
      );
    } on FormatException catch (error) {
      diagnostics.add(
        MusicalConversionDiagnostic('invalid_time_signature', error.message),
      );
    } on ArgumentError catch (error) {
      diagnostics.add(
        MusicalConversionDiagnostic('invalid_document', '${error.message}'),
      );
    }
    return CanonicalConversionResult(null, diagnostics);
  }

  static (String, String)? _noteProblem(DrumSheetNotationNote note) {
    if (note.tie || note.flam) {
      return (
        'unsupported_ornament',
        'Ties and flams need explicit sustain/grace semantics.',
      );
    }
    if (note.rest) {
      if (note.voices.isNotEmpty ||
          note.voiceStrokes.isNotEmpty ||
          note.sticking.isNotEmpty ||
          note.accent ||
          note.ghost) {
        return (
          'conflicting_rest',
          'A rest cannot carry instrument or articulation data.',
        );
      }
      return null;
    }
    if (note.voices.isEmpty ||
        note.voices.toSet().length != note.voices.length) {
      return ('invalid_voices', 'An event needs unique source voices.');
    }
    final seen = <DrumSheetVoice>{};
    for (final mapping in note.voiceStrokes) {
      if (!note.voices.contains(mapping.voice) || !seen.add(mapping.voice)) {
        return (
          'invalid_voice_strokes',
          'Structured sticking has duplicate or absent voices.',
        );
      }
    }
    final strokes = note.voices.map(note.strokeForVoice).toList();
    final authored = strokes.whereType<DrumSheetStrokeDescriptor>().toList();
    if (note.voiceStrokes.isNotEmpty && authored.isNotEmpty) {
      final accent = authored.any(
        (s) => s.articulation == DrumSheetStrokeArticulation.accent,
      );
      final ghost = authored.every(
        (s) => s.articulation == DrumSheetStrokeArticulation.ghost,
      );
      final sticking = authored.map((s) => s.displayLabel).join();
      if (note.accent != accent ||
          note.ghost != ghost ||
          (note.sticking.isNotEmpty && note.sticking != sticking)) {
        return (
          'conflicting_sticking',
          'Aggregate flags/sticking disagree with voice-specific strokes.',
        );
      }
    } else if (note.sticking.isNotEmpty &&
        (note.voices.length != 1 || strokes.single == null)) {
      return (
        'ambiguous_sticking',
        'Sticking cannot be assigned unambiguously to source voices.',
      );
    } else if ((note.accent && note.ghost) ||
        (note.voices.length > 1 && (note.accent || note.ghost))) {
      return (
        'ambiguous_articulation',
        'Aggregate articulation cannot be assigned unambiguously.',
      );
    }
    return null;
  }

  static InstrumentStrike _strike(
    DrumSheetNotationNote note,
    DrumSheetVoice voice,
  ) {
    final stroke = note.strokeForVoice(voice);
    // Aggregate flags summarize structured strokes; never spread them to other voices.
    final hasStructured = note.voiceStrokes.isNotEmpty;
    final articulation = hasStructured
        ? stroke?.articulation ?? DrumSheetStrokeArticulation.normal
        : note.accent
        ? DrumSheetStrokeArticulation.accent
        : note.ghost
        ? DrumSheetStrokeArticulation.ghost
        : DrumSheetStrokeArticulation.normal;
    return InstrumentStrike(
      voice: switch (voice) {
        DrumSheetVoice.snare => DrumVoiceV1.snare,
        DrumSheetVoice.tom1 => DrumVoiceV1.rackTom,
        DrumSheetVoice.tom2 => DrumVoiceV1.tom2,
        DrumSheetVoice.floorTom => DrumVoiceV1.floorTom,
        DrumSheetVoice.hihat => DrumVoiceV1.hihat,
        DrumSheetVoice.openHiHat => DrumVoiceV1.openHiHat,
        DrumSheetVoice.crash => DrumVoiceV1.crash,
        DrumSheetVoice.ride => DrumVoiceV1.ride,
        DrumSheetVoice.kick => DrumVoiceV1.kick,
      },
      hand: switch (stroke?.hand) {
        null => null,
        DrumSheetStrokeHand.left => MusicalHand.left,
        DrumSheetStrokeHand.right => MusicalHand.right,
      },
      articulation: switch (articulation) {
        DrumSheetStrokeArticulation.normal => StrikeArticulation.normal,
        DrumSheetStrokeArticulation.accent => StrikeArticulation.accent,
        DrumSheetStrokeArticulation.ghost => StrikeArticulation.ghost,
      },
    );
  }

  static MusicalTime _duration(DrumSheetNoteValue value) => switch (value) {
    DrumSheetNoteValue.whole => MusicalTime(4),
    DrumSheetNoteValue.half => MusicalTime(2),
    DrumSheetNoteValue.quarter => MusicalTime(1),
    DrumSheetNoteValue.eighth => MusicalTime(1, 2),
    DrumSheetNoteValue.sixteenth => MusicalTime(1, 4),
    DrumSheetNoteValue.thirtySecond => MusicalTime(1, 8),
  };
}
