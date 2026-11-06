import 'package:flutter/material.dart';

import '../domain/structured_qr_payload.dart';

class StructuredQrFields extends StatefulWidget {
  const StructuredQrFields({
    required this.type,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final QrCreationType type;
  final ValueChanged<StructuredQrDraft> onChanged;
  final bool enabled;
  @override
  State<StructuredQrFields> createState() => _StructuredQrFieldsState();
}

class _StructuredQrFieldsState extends State<StructuredQrFields> {
  final _controllers = <String, TextEditingController>{};
  DateTime? _start;
  DateTime? _end;
  bool _utc = false;
  void _changed() => widget.onChanged(
    StructuredQrDraft(
      type: widget.type,
      fields: {for (final e in _controllers.entries) e.key: e.value.text},
      start: _start,
      end: _end,
      useUtc: _utc,
    ),
  );
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final initial = (start ? _start : _end) ?? _start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted) return;
    // Hold wall-clock components without local DST normalization until validation.
    final value = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
    _changed();
  }

  Widget _field(
    String key,
    String label, {
    bool multiline = false,
    TextInputType? keyboard,
  }) {
    final controller = _controllers.putIfAbsent(key, TextEditingController.new);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        key: ValueKey('structured-$key'),
        controller: controller,
        enabled: widget.enabled,
        autocorrect: false,
        enableSuggestions: false,
        minLines: 1,
        maxLines: multiline ? 4 : 1,
        keyboardType:
            keyboard ??
            (multiline ? TextInputType.multiline : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _changed(),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _timeButton(bool start) {
    final value = start ? _start : _end;
    final label = start ? 'Start date and time' : 'End date and time';
    String pad(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: widget.enabled ? () => _pickTime(start) : null,
        icon: const Icon(Icons.calendar_month),
        label: Text(
          value == null
              ? label
              : '$label: ${value.year}-${pad(value.month)}-${pad(value.day)} ${pad(value.hour)}:${pad(value.minute)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: switch (widget.type) {
      QrCreationType.contact => [
        _field('name', 'Name'),
        _field(
          'phone',
          'Phone number (optional)',
          keyboard: TextInputType.phone,
        ),
        _field(
          'email',
          'Email address (optional)',
          keyboard: TextInputType.emailAddress,
        ),
        const Text(
          'People can review this contact before adding it to their address book.',
        ),
      ],
      QrCreationType.event => [
        _field('title', 'Event title'),
        _timeButton(true),
        _timeButton(false),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use UTC time'),
          subtitle: Text(
            _utc
                ? 'Times are interpreted as UTC.'
                : 'Times use the scanning device’s local time zone.',
          ),
          value: _utc,
          onChanged: widget.enabled
              ? (value) {
                  setState(() => _utc = value);
                  _changed();
                }
              : null,
        ),
        _field('location', 'Event location (optional)'),
        _field('description', 'Description (optional)', multiline: true),
        const Text(
          'One timed event. For an event shared across time zones, use UTC.',
        ),
      ],
      QrCreationType.location => [
        _field(
          'latitude',
          'Latitude (−90 to 90)',
          keyboard: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        _field(
          'longitude',
          'Longitude (−180 to 180)',
          keyboard: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        const Text(
          'Use a decimal point. Scanning opens these coordinates in a compatible maps app after confirmation.',
        ),
      ],
      QrCreationType.email => [
        _field(
          'email',
          'Recipient email address',
          keyboard: TextInputType.emailAddress,
        ),
        _field('subject', 'Subject (optional)'),
        _field('body', 'Email body (optional)', multiline: true),
        const Text(
          'Scanning prepares an email. Nothing is sent automatically.',
        ),
      ],
      QrCreationType.phone => [
        _field('phone', 'Phone number', keyboard: TextInputType.phone),
        const Text(
          'Include the country code when sharing internationally. Scanning opens the dialer after confirmation.',
        ),
      ],
      QrCreationType.sms => [
        _field(
          'phone',
          'Recipient phone number',
          keyboard: TextInputType.phone,
        ),
        _field('body', 'Message (optional)', multiline: true),
        const Text(
          'Scanning prepares a text message. Nothing is sent automatically.',
        ),
      ],
      _ => [],
    },
  );
}
