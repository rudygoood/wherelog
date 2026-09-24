import 'package:flutter/material.dart';
import 'location_options_maintenance_screen.dart';
import 'settings_screen.dart';

class AppMenuShell extends StatelessWidget {
  const AppMenuShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Menu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _menuTile(context, icon: Icons.account_tree_outlined, title: 'Location Options', subtitle: 'Generals & Specifics • Storage / Inventory', onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocationMaintenanceScreen())); }),
                  const Divider(height: 12, thickness: 0.5),
                  _menuTile(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Preferences, defaults',
                    onTap: () async {
                      final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      if (result is List<String> && result.length == 3 && context.mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                  ),
                  _menuTile(context, icon: Icons.upload_outlined, title: 'Data Export', subtitle: 'Backup, export JSON, import, clear', enabled: false),
                  _menuTile(context, icon: Icons.contact_support_outlined, title: 'Contact / Support', subtitle: 'Feedback, report issue', enabled: false),
                  _menuTile(context, icon: Icons.help_outline, title: 'Help', subtitle: 'How to use WhereLog', enabled: false),
                  const Divider(height: 12, thickness: 0.5),
                  _menuTile(context, icon: Icons.info_outline, title: 'About', subtitle: 'Version, data paths', enabled: false),
                  _menuTile(context, icon: Icons.exit_to_app, title: 'Close WhereLog', subtitle: 'Exit application', onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext context, {required IconData icon, required String title, required String subtitle, VoidCallback? onTap, bool enabled = true}) {
    return ListTile(
      enabled: enabled,
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(icon, size: 20, color: enabled ? Colors.black : Colors.black38),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: enabled ? Colors.black : Colors.black45)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 10.5, color: enabled ? Colors.black87 : Colors.black45, height: 1.2)),
      trailing: enabled ? const Icon(Icons.chevron_right, size: 16) : null,
      onTap: enabled ? onTap : null,
    );
  }
}
