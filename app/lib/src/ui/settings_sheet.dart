import 'package:flutter/material.dart';

import 'setup_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Change the Wise token, or disconnect and remove everything from this device.
Future<void> showSettingsSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    // Scrolls, so nothing is cut off with large text on a small phone.
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Change Wise token'),
            subtitle: const Text('Use a new read-only token', style: Styles.meta),
            onTap: () {
              Navigator.of(sheet).pop();
              openSetup(context, replacing: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Palette.spend),
            title: const Text('Disconnect', style: TextStyle(color: Palette.spend)),
            subtitle: const Text('Remove the token and saved data from this device', style: Styles.meta),
            onTap: () async {
              Navigator.of(sheet).pop();
              if (await _confirmDisconnect(context) && context.mounted) {
                await AppScope.read(context).disconnect();
              }
            },
          ),
        ],
      ),
    ),
  ),
);

Future<bool> _confirmDisconnect(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Disconnect Wise?'),
        content: const Text(
          'This removes your token and saved data from this device. You can connect again any time.',
          style: Styles.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: Palette.spend),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    ) ??
    false;
