import 'package:flutter/material.dart';

import '../../scan/domain/wifi_network.dart';
import '../domain/wifi_qr_payload.dart';

class WifiQrFields extends StatefulWidget {
  const WifiQrFields({required this.onChanged, super.key});
  final ValueChanged<WifiQrDraft> onChanged;
  @override
  State<WifiQrFields> createState() => _WifiQrFieldsState();
}

class _WifiQrFieldsState extends State<WifiQrFields> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  WifiSecurity _security = WifiSecurity.wpa2;
  bool _hidden = false;
  bool _reveal = false;
  void _changed() => widget.onChanged(
    WifiQrDraft(
      ssid: _ssid.text,
      password: _password.text,
      security: _security,
      hidden: _hidden,
    ),
  );
  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: _ssid,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Network name (SSID)',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => _changed(),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<WifiSecurity>(
        initialValue: _security,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Wi-Fi security',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: WifiSecurity.wpa2,
            child: Text('WPA / WPA2 Personal'),
          ),
          DropdownMenuItem(
            value: WifiSecurity.wpa3,
            child: Text('WPA3 Personal'),
          ),
          DropdownMenuItem(
            value: WifiSecurity.open,
            child: Text('Open (no password)'),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _security = value);
          _changed();
        },
      ),
      if (_security != WifiSecurity.open) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: !_reveal,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Wi-Fi password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _reveal ? 'Hide password' : 'Reveal password',
              icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _reveal = !_reveal),
            ),
          ),
          onChanged: (_) => _changed(),
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hidden network'),
        value: _hidden,
        onChanged: (value) {
          setState(() => _hidden = value);
          _changed();
        },
      ),
      const Text(
        'Anyone with this QR code can use these Wi-Fi credentials. Keep your hotspot or network turned on when others scan it.',
      ),
    ],
  );
}
