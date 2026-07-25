import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../midi/midi_input_models.dart';
import '../midi/midi_input_service.dart';
import '../midi/serial_led_controller.dart';
import '../midi/shared_midi_input_service.dart';
import '../midi/shared_serial_led_controller.dart';
import '../settings/hardware_midi_settings_screen.dart';
import 'hardware_capabilities.dart';

class HardwareStatusHeaderOverlay extends StatefulWidget {
  static const double defaultTop = 32;
  static const double defaultRight = 16;
  static const double cardGap = 16;
  static const double statusButtonHeight = 64;
  static const double contentTopInset =
      defaultTop + statusButtonHeight + cardGap;
  static const double appBarBodyTopInset = contentTopInset - kToolbarHeight;

  final Widget child;
  final double top;
  final double right;

  const HardwareStatusHeaderOverlay({
    super.key,
    required this.child,
    this.top = defaultTop,
    this.right = defaultRight,
  });

  @override
  State<HardwareStatusHeaderOverlay> createState() =>
      _HardwareStatusHeaderOverlayState();
}

class _HardwareStatusHeaderOverlayState
    extends State<HardwareStatusHeaderOverlay> {
  @override
  Widget build(BuildContext context) {
    if (!HardwareCapabilities.supportsDesktopHardware) return widget.child;

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          top: widget.top,
          right: widget.right,
          child: const HardwareStatusHeaderControls(),
        ),
      ],
    );
  }
}

class HardwareStatusHeaderControls extends StatefulWidget {
  const HardwareStatusHeaderControls({super.key});

  @override
  State<HardwareStatusHeaderControls> createState() =>
      _HardwareStatusHeaderControlsState();
}

class _HardwareStatusHeaderControlsState
    extends State<HardwareStatusHeaderControls> {
  MidiInputService? _midiService;
  SerialLedController? _ledController;
  bool _hardwareUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    if (!HardwareCapabilities.supportsDesktopHardware) return;
    _midiService = SharedMidiInputService.instance
      ..addListener(_handleHardwareChanged);
    _ledController = SharedSerialLedController.instance
      ..addListener(_handleHardwareChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final MidiInputService? midiService = _midiService;
      final SerialLedController? ledController = _ledController;
      if (midiService != null) unawaited(midiService.start());
      if (ledController != null) unawaited(ledController.refreshPorts());
    });
  }

  @override
  void dispose() {
    _midiService?.removeListener(_handleHardwareChanged);
    _ledController?.removeListener(_handleHardwareChanged);
    super.dispose();
  }

  void _handleHardwareChanged() {
    if (!mounted || _hardwareUpdateScheduled) return;
    _hardwareUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hardwareUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final MidiInputService? midiService = _midiService;
    final SerialLedController? ledController = _ledController;
    if (midiService == null || ledController == null) {
      return const SizedBox.shrink();
    }

    return _HardwareStatusHeaderRow(
      status: _HardwareStatus.from(
        midiService: midiService,
        ledController: ledController,
      ),
      onOpenDevices: () => unawaited(showHardwareConnectionDialog(context)),
    );
  }
}

class _HardwareStatusHeaderRow extends StatelessWidget {
  final _HardwareStatus status;
  final VoidCallback onOpenDevices;

  const _HardwareStatusHeaderRow({
    required this.status,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: <Widget>[
        _HardwareStatusButton(status: status.midi, onPressed: onOpenDevices),
        _HardwareStatusButton(status: status.led, onPressed: onOpenDevices),
      ],
    );
  }
}

class _HardwareStatusButton extends StatelessWidget {
  final _HardwareDeviceStatus status;
  final VoidCallback onPressed;

  const _HardwareStatusButton({required this.status, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: DrumcabularyTheme.edgeSurface,
          borderRadius: borderRadius,
          border: Border.all(color: DrumcabularyTheme.edgeBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          hoverColor: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.10),
          focusColor: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.14),
          splashColor: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  status.icon,
                  color: DrumcabularyTheme.edgeTextPrimary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        status.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: DrumcabularyTheme.edgeTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: status.connected
                                  ? const Color(0xFF52D273)
                                  : const Color(0xFFFFC857),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(width: 8, height: 8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              status.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: status.connected
                                        ? const Color(0xFF52D273)
                                        : DrumcabularyTheme.edgeTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HardwareStatus {
  final _HardwareDeviceStatus midi;
  final _HardwareDeviceStatus led;

  const _HardwareStatus({required this.midi, required this.led});

  factory _HardwareStatus.from({
    required MidiInputService midiService,
    required SerialLedController ledController,
  }) {
    return _HardwareStatus(
      midi: _HardwareDeviceStatus(
        icon: Icons.graphic_eq_rounded,
        title: midiService.selectedDevice?.name ?? 'MIDI Kit',
        subtitle: _midiStatusLabel(midiService.status),
        connected: midiService.status == MidiInputStatus.connected,
      ),
      led: _HardwareDeviceStatus(
        icon: Icons.radio_button_checked_rounded,
        title: 'LED Controller',
        subtitle: _serialStatusLabel(ledController.status),
        connected: ledController.status == SerialLedConnectionStatus.connected,
      ),
    );
  }
}

class _HardwareDeviceStatus {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool connected;

  const _HardwareDeviceStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connected,
  });
}

String _midiStatusLabel(MidiInputStatus status) {
  return switch (status) {
    MidiInputStatus.connected => 'Connected',
    MidiInputStatus.scanning => 'Scanning',
    MidiInputStatus.connecting => 'Connecting',
    MidiInputStatus.noDevicesFound ||
    MidiInputStatus.disconnected => 'Not Connected',
    MidiInputStatus.connectionError => 'Connection Error',
  };
}

String _serialStatusLabel(SerialLedConnectionStatus status) {
  return switch (status) {
    SerialLedConnectionStatus.connected => 'Connected',
    SerialLedConnectionStatus.connecting => 'Connecting',
    SerialLedConnectionStatus.disconnected => 'Not Connected',
    SerialLedConnectionStatus.connectionError => 'Connection Error',
    SerialLedConnectionStatus.deviceRemoved => 'Device Removed',
  };
}
