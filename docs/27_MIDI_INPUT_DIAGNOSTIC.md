# MIDI Input Diagnostic

This document describes the first Drumcabulary MIDI-input scaffold for macOS.
The goal is only to prove this path:

LEKATO drum kit -> USB MIDI -> macOS CoreMIDI -> Drumcabulary

This scaffold does not score performances, record takes, sync lessons, control
LEDs, or provide coaching.

## Package

Drumcabulary uses `flutter_midi_command` `^1.0.3`.

Selection reasons:

- Supports macOS through CoreMIDI.
- Supports MIDI device discovery.
- Emits setup-change events for device connect/disconnect.
- Supports connecting and disconnecting devices.
- Exposes raw MIDI packet delivery.
- Can support iOS later through the same Darwin package.
- Does not require a custom native CoreMIDI plugin for this first scaffold.

Bluetooth MIDI is not enabled in this implementation. The diagnostic uses USB
MIDI through the native platform transport.

The local project was verified with Flutter `3.41.9` and Dart `3.11.5`, which
satisfy the package requirements of Flutter `>=3.24.0` and Dart `>=3.7.0`.

## Data Flow

1. `MidiInputService` asks `flutter_midi_command` for available MIDI devices.
2. The user selects and connects a device in the diagnostic screen.
3. `flutter_midi_command` emits raw MIDI packets from CoreMIDI.
4. `RawMidiMessageParser` converts packet bytes into `RawMidiEvent` values.
5. `DrumKitMapper` maps MIDI note numbers to `DrumInputEvent` values.
6. `MidiDiagnosticScreen` displays the raw MIDI data and mapped drum voice.

The raw MIDI layer and the drum mapping layer are intentionally separate.
Future scoring or practice features should consume the mapped drum events, not
reach into the plugin or UI directly.

## Files

- `lib/features/midi/midi_input_models.dart`
- `lib/features/midi/raw_midi_message_parser.dart`
- `lib/features/midi/drum_kit_mapper.dart`
- `lib/features/midi/bounded_midi_event_log.dart`
- `lib/features/midi/midi_input_service.dart`
- `lib/features/midi/midi_diagnostic_screen.dart`

## Device Mapping

`DrumKitMapper` currently uses an in-memory General MIDI starter map:

| Note | Voice |
| --- | --- |
| 36 | kick |
| 38 | snare |
| 40 | snare |
| 42 | hi-hat closed |
| 44 | hi-hat pedal |
| 46 | hi-hat open |
| 43 | floor tom |
| 47 | tom 2 |
| 48 | tom 1 |
| 49 | crash |
| 51 | ride |

These values are placeholders. The LEKATO CPD-1000 should be mapped from the
actual event log produced by the diagnostic screen. Unknown notes are not
filtered; they appear as `unknown`.

## Opening The Diagnostic

Run the app on macOS and click the USB icon in the top app bar.

The screen is named:

`MIDI Input Diagnostic`

Use the screen to:

- Refresh available devices.
- Select `edrum` when the LEKATO module appears.
- Connect or disconnect the selected device.
- Strike pads and read note, velocity, channel, message type, timestamp, and
  mapped voice.
- Clear the bounded event log.

Example log line:

`18:42:11.327 | edrum | Ch 10 | Note On | Note 38 | Velocity 104 | snare`

Diagnostic timestamps are app receipt times. They are intended for live
inspection, not durable performance analysis.

## macOS Setup

The project already targets macOS `10.15`, which matches the Darwin plugin
macOS deployment target.

No microphone permissions are required. This feature consumes MIDI data, not
audio.

No extra macOS entitlement was added for this scaffold. USB MIDI is handled
through CoreMIDI by the Flutter package. If a signed release build later cannot
see USB MIDI devices under sandboxing, re-check macOS sandbox requirements for
CoreMIDI and USB access before adding entitlements.

## LEKATO Mapping Worksheet

Use the diagnostic event log to fill this out.

| Pad / Control | MIDI Channel | Note Number | Typical Velocity | Notes |
| --- | --- | --- | --- | --- |
| Snare | | | | |
| Snare rim | | | | |
| Tom 1 | | | | |
| Tom 2 | | | | |
| Floor tom | | | | |
| Hi-hat closed | | | | |
| Hi-hat open | | | | |
| Hi-hat pedal | | | | |
| Crash | | | | |
| Ride | | | | |
| Kick | | | | |

## Known Limitations

- The note map is in memory only.
- The LEKATO-specific map has not been authored yet.
- The diagnostic does not persist recordings or mappings.
- The diagnostic does not infer left hand or right hand. A MIDI pad strike does
  not identify which limb hit the pad.
- Unknown MIDI notes remain visible and map to `unknown`.
- Device reconnection is handled by rescan/setup-change behavior; if automatic
  reconnection does not restore input immediately, use `Rescan` and `Connect`.
