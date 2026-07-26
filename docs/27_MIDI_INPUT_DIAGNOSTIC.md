# MIDI Input Diagnostic

This document describes the first Drumcabulary MIDI-input scaffold for macOS.
The goal is only to prove this path:

LEKATO drum kit -> USB MIDI -> macOS CoreMIDI -> Drumcabulary

This scaffold does not score performances, record takes, sync lessons, provide
coaching, or run lesson-driven lighting.

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
- `lib/features/midi/drum_voice_led_command_mapper.dart`
- `lib/features/midi/midi_led_forwarder.dart`
- `lib/features/midi/serial_led_controller.dart`

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
| 45 | tom 2 |
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
- Capture a short MIDI pattern and view its generated Drumcabulary pattern
  string, notation preview, and estimated BPM.
- Copy the bounded event log to the clipboard.
- Clear the bounded event log.

If the only visible device is `Session 1`, the app is seeing CoreMIDI's network
session rather than the LEKATO USB kit. Pad strikes from a kit connected to the
Mac will not arrive through that endpoint. Run the macOS app, confirm the kit
still appears as `edrum` in macOS Audio MIDI Setup or GarageBand, then use
`Rescan` until `edrum` appears in the diagnostic device selector.

If the diagnostic is running in the iOS simulator, the simulator may show
CoreMIDI network sessions while still not exposing the Mac's USB MIDI kit. Use
the macOS target for this USB MIDI proof.

A local USB hardware check can still see the LEKATO as `EDRUM` while the app
does not show it as a CoreMIDI input endpoint. In that case the USB layer is
working, but the app runtime is not connected to the USB CoreMIDI source.

The Latest Event panel shows both raw packet count and parsed event count:

- Raw packets `0`: no MIDI data is reaching the app from the selected endpoint.
- Raw packets greater than `0` with parsed events `0`: bytes are arriving, but
  they are not currently being parsed as supported note/control events.

Example log line:

`18:42:11.327 | edrum | Ch 10 | Note On | Note 38 | Velocity 104 | snare`

Diagnostic timestamps are app receipt times. They are intended for live
inspection, not durable performance analysis.

## MIDI Pattern Capture BPM Estimate

`MidiPatternCaptureController` estimates BPM from recent captured Note On
onsets. It consumes mapped `RawMidiEvent` + `DrumInputEvent` pairs so capture
does not depend on the diagnostic screen as its owner. It groups
near-simultaneous hits first, so a kick and snare landing together count as one
timing point.

The current temporary production surface is the rich MIDI Pattern Capture card
at the end of Settings on desktop platforms. It uses the shared MIDI input
service, writes generated voice-first notation into an editable text field, and
renders that text with the shared notation preview. The raw MIDI diagnostic
screen keeps the same rich capture behavior.

Current MVP rules:

- Note Off events and Note On velocity `0` events are ignored.
- The estimate uses a rolling average of recent onset intervals.
- The estimate assumes the generated default capture pattern uses eighth-note
  spacing, so two captured event gaps equal one quarter-note beat.
- Capture emits voice-first notation such as `[HH K]`, `[OHH]`, and `[S]`.
- Capture uses MIDI velocity to classify hand-played voices into normal,
  accented, and ghosted strokes. Normal hits omit sticking; accented and
  ghosted captures emit semantic voice-first stroke notation such as
  `[S:^R(L)(L)]`. Initial thresholds are velocity `<= 63` for ghost strokes
  and `>= 100` for accented strokes.
- The estimate is shown for quick authoring feedback only. It is not assessment,
  scoring, or a full tempo-grid inference engine.

## USB Serial LED Bridge

The MIDI diagnostic screen includes a minimal LED Controller section for the
ESP32-S3 proof of concept:

LEKATO drum kit -> USB MIDI -> Drumcabulary -> USB serial -> ESP32 -> LEDs

This is diagnostic-only. It does not add lesson playback, pattern-driven
lighting, color editing, persistence, Bluetooth, networking, or production LED
configuration.

### Serial Package

Drumcabulary uses `flutter_libserialport` `^0.6.0`.

Selection reasons:

- It is backed by `libserialport`.
- It supports macOS USB serial devices.
- It provides serial port discovery.
- It exposes human-readable port metadata where available.
- It supports direct byte writes to a selected port.
- It keeps this proof of concept out of custom native plugin work.

The package wraps the `libserialport` Dart API. The current lockfile resolves
`flutter_libserialport` to `0.6.0` and `libserialport` to `0.3.0+1`.

### Serial Data Flow

1. `SerialLedController` discovers `/dev/cu.*` serial ports.
2. The user selects the ESP32 port, expected to look like `/dev/cu.usbmodem...`.
3. `SerialLedController` opens the selected port at `115200 8N1` with no flow
   control.
4. `MidiDiagnosticScreen` receives mapped `MidiDiagnosticEvent` values from the
   existing MIDI path.
5. `MidiLedForwarder` ignores Note Off and velocity-zero events.
6. `DrumVoiceLedCommandMapper` maps the `DrumVoice` to a newline-terminated
   firmware command.
7. `SerialLedController` writes the command bytes to the ESP32.

MIDI and serial lifecycles are independent. Disconnecting the LEKATO does not
disconnect serial. Disconnecting or unplugging the ESP32 does not stop MIDI
input or MIDI Pattern Capture.

### Serial Settings

- Baud rate: `115200`
- Data bits: `8`
- Parity: none
- Stop bits: `1`
- Flow control: none
- Encoding: UTF-8/ASCII text
- Terminator: newline

### LED Command Mapping

| DrumVoice | Serial command |
| --- | --- |
| snare | `SNARE\n` |
| kick | `KICK\n` |
| hiHatClosed | `HIHAT\n` |
| hiHatOpen | `HIHAT\n` |
| hiHatPedal | `HIHAT\n` |
| tom1 | `TOM1\n` |
| tom2 | `TOM2\n` |
| floorTom | `FLOORTOM\n` |
| crash | `CRASH\n` |
| ride | `RIDE\n` |
| unknown | no command |

Unknown voices remain visible in the MIDI event log but are not forwarded to
the ESP32.

### Opening And Using The LED Controller

Run the app on macOS and click the USB icon in the top app bar to open:

`MIDI Input Diagnostic`

In the LED Controller section:

1. Connect the ESP32-S3 by USB.
2. Click `Refresh`.
3. Select the `/dev/cu.usbmodem...` serial port.
4. Click `Connect`.
5. Click `Test LEDs` to send a semantic `FLASH` frame followed by `CLEAR`.
6. Connect the LEKATO MIDI device in the MIDI device section.
7. Enable `Forward MIDI Hits`.
8. Strike pads on the LEKATO.

Each mapped Note On hit sends one immediate serial command. Simultaneous MIDI
voices send separate commands in event order.

If Arduino Serial Monitor or another app has the port open, the connect action
should surface a port-in-use/open failure. Close the other app, refresh, then
connect again.

## macOS Setup

The project already targets macOS `10.15`, which matches the Darwin plugin
macOS deployment target.

No microphone permissions are required. This feature consumes MIDI data, not
audio.

The macOS app includes the serial and USB device sandbox entitlements:

`com.apple.security.device.serial`

`com.apple.security.device.usb`

The serial entitlement is required for App Sandbox serial-device access. The
USB entitlement remains in place for USB hardware access, including USB MIDI
hardware exposed through CoreMIDI.

If a development build still cannot open `/dev/cu.usbmodem...`, verify that no
other process has the port open and test whether App Sandbox is blocking direct
serial access in that local signing configuration. No microphone permission is
added.

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
- MIDI pad strikes do not identify which limb hit the pad. Capture currently
  uses a simple default hand heuristic for expressive strokes: accents use `R`
  and ghosts use `L`. Normal captures still omit sticking.
- Unknown MIDI notes remain visible and map to `unknown`.
- Device reconnection is handled by rescan/setup-change behavior; if automatic
  reconnection does not restore input immediately, use `Rescan` and `Connect`.
- The LED bridge does not read ESP32 responses or acknowledgments.
- Serial reconnect is explicit: refresh the port list, select the ESP32 port,
  and connect again.
- LED forwarding is diagnostic-only and requires both an active serial
  connection and the `Forward MIDI Hits` toggle.
