import 'package:flutter/material.dart';

import '../application/qr_payload_router.dart';
import '../domain/qr_payload_classifier.dart';
import '../domain/wifi_network.dart';

class WifiJoinDialog extends StatefulWidget {
  const WifiJoinDialog({required this.payload, this.comparisonCode, super.key});
  final ClassifiedQrPayload payload;
  final String? comparisonCode;
  @override
  State<WifiJoinDialog> createState() => _WifiJoinDialogState();
}

class _WifiJoinDialogState extends State<WifiJoinDialog> {
  static const router = QrPayloadRouter();
  late final network = WifiNetworkDetails.fromFields(
    widget.payload.routeArguments,
  );
  late final capabilities = router.wifiCapabilities();
  bool _joining = false;
  bool _revealed = false;
  String? _message;
  WifiJoinOutcome? _outcome;

  Future<void> _openSettings() async {
    if (_joining) return;
    setState(() => _joining = true);
    final opened = await router.openWifiSettings();
    if (!mounted) return;
    setState(() {
      _joining = false;
      if (!opened) {
        _message = 'Open Settings > Wi-Fi and select this network to connect.';
      }
    });
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _message = null;
    });
    final outcome = await router.joinWifi(widget.payload);
    if (!mounted) return;
    setState(() {
      _joining = false;
      _outcome = outcome;
      _message = switch (outcome) {
        WifiJoinOutcome.saved =>
          'Network saved. Android will try to connect. Check Wi-Fi settings for connection status.',
        WifiJoinOutcome.alreadySaved =>
          'This network is already saved. Android may keep your current connection. Select this network in Wi-Fi settings to switch.',
        WifiJoinOutcome.accepted =>
          'The Wi-Fi request was accepted. Check Settings for connection status.',
        WifiJoinOutcome.alreadyAssociated =>
          'This device is already associated with the network. Internet access has not been verified.',
        WifiJoinOutcome.cancelled => 'Wi-Fi request cancelled.',
        WifiJoinOutcome.unsupported =>
          'This device cannot join this network from the app. Configure it in Wi-Fi settings.',
        WifiJoinOutcome.busy =>
          'Another Wi-Fi request is still open. Finish it before trying again.',
        WifiJoinOutcome.failed =>
          'The Wi-Fi request failed. Check the credentials and try again, or use Wi-Fi settings.',
      };
    });
    if (outcome == WifiJoinOutcome.alreadySaved) {
      final caps = await capabilities;
      if (mounted && caps.canOpenSettings) await _openSettings();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WifiJoinCapabilities>(
    future: capabilities,
    builder: (context, snapshot) {
      final caps = snapshot.data;
      final supported = caps?.supports(network) ?? false;
      return AlertDialog(
        icon: const Icon(Icons.wifi),
        title: const Text('Join Wi-Fi network'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Network name'),
              SelectableText(network.ssid),
              const SizedBox(height: 12),
              Text(network.securityLabel),
              if (network.hidden) const Text('Hidden network'),
              if (network.password.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Password: ${_revealed ? network.password : '********'}',
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _revealed = !_revealed),
                      tooltip: _revealed ? 'Hide password' : 'Reveal password',
                      icon: Icon(
                        _revealed ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ],
                ),
              if (widget.comparisonCode case final code?) ...[
                const SizedBox(height: 12),
                Text('Content comparison code: $code'),
                const Text(
                  'Compare with a trusted code from the network owner if available.',
                ),
              ],
              const SizedBox(height: 12),
              if (network.problem case final problem?)
                Text(problem)
              else if (caps == null)
                const Text('Checking device support...')
              else if (!supported)
                const Text(
                  'Automatic joining is unavailable for this device or security type. Open Settings > Wi-Fi to configure it manually.',
                )
              else
                const Text(
                  'Your device may ask you to approve the network. Saving credentials does not confirm a connection or internet access.',
                ),
              if (_message case final message?) ...[
                const SizedBox(height: 12),
                Text(message),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _joining ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (caps?.canOpenSettings == true)
            if (_outcome == WifiJoinOutcome.alreadySaved)
              FilledButton(
                onPressed: _joining ? null : _openSettings,
                child: const Text('Select network in Wi-Fi settings'),
              )
            else
              TextButton(
                onPressed: _joining ? null : _openSettings,
                child: const Text('Open Wi-Fi settings'),
              ),
          if (supported && _outcome != WifiJoinOutcome.alreadySaved)
            FilledButton(
              onPressed: _joining ? null : _join,
              child: Text(_joining ? 'Waiting for device...' : 'Join network'),
            ),
        ],
      );
    },
  );
}
