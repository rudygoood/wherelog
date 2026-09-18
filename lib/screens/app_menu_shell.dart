import 'package:flutter/material.dart';
import 'location_options_maintenance_screen.dart';
import 'settings_screen.dart';

/// App Menu - standard drawer from RIGHT (endDrawer)
/// Must be used as Scaffold.endDrawer, not bottomSheet.
/// Scrollable, tight spacing.

class AppMenuShell extends StatelessWidget {
  const AppMenuShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: 320,
      child: SafeArea(
        child: Column(
          children: [
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _menuTile(
                    context,
                    icon: Icons.account_tree_outlined,
                    title: 'Location Options',
                    subtitle: 'Generals & Specifics • Storage / Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocationMaintenanceScreen()));
                    },
                  ),
                  const Divider(height: 12, thickness: 0.5),
                  _menuTile(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Preferences, defaults',
                    enabled: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  _menuTile(context, icon: Icons.upload_outlined, title: 'Data Export', subtitle: 'Backup, export JSON, import, clear', enabled: false),
                  _menuTile(context, icon: Icons.contact_support_outlined, title: 'Contact / Support', subtitle: 'Feedback, report issue', enabled: false),
                  _menuTile(context, icon: Icons.help_outline, title: 'Help', subtitle: 'How to use WhereLog', enabled: false),
                  const Divider(height: 12, thickness: 0.5),
                  _menuTile(context, icon: Icons.info_outline, title: 'About', subtitle: 'Version, data paths', enabled: false),
                  _menuTile(
                    context,
                    icon: Icons.exit_to_app,
                    title: 'Close WhereLog',
                    subtitle: 'Exit application',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext context, {required IconData icon, required String title, required String subtitle, VoidCallback? onTap, bool enabled = true}) {
    final bool isEnabled = enabled ? true : (title == 'Location Options' || title == 'Close WhereLog');
    final bool actuallyEnabled = (title == 'Location Options' || title == 'Close WhereLog') ? true : enabled;
    return ListTile(
      enabled: actuallyEnabled,
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(icon, size: 20, color: actuallyEnabled ? Colors.black : Colors.black38),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: actuallyEnabled ? Colors.black : Colors.black45)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 10.5, color: actuallyEnabled ? Colors.black87 : Colors.black45, height: 1.2)),
      trailing: actuallyEnabled ? const Icon(Icons.chevron_right, size: 16) : null,
      onTap: actuallyEnabled ? onTap : null,
    );
  }
}
