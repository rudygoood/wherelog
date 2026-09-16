import 'package:flutter/material.dart';
import 'location_options_maintenance_screen.dart';

/// App Menu Shell - replaces the old single _openLocationsSheet button
/// Header + list of actions. Location Options Maintenance is the first real item.

class AppMenuShell extends StatelessWidget {
  const AppMenuShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.menu, color: Colors.white)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WhereLog Menu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text('Location Options = General → Specific (Specific optional, sentinel = General-only)', style: TextStyle(fontSize: 11, color: Colors.black54)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          // Menu items
          _menuTile(
            context,
            icon: Icons.account_tree_outlined,
            title: 'Location Options Maintenance',
            subtitle: '2 tabs: Storage Generals/Specifics & Inventory Generals/Specifics • expand/collapse • add/edit/delete when not referenced',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocationMaintenanceScreen()));
            },
          ),
          _menuTile(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Storage (tab)',
            subtitle: 'Quick jump to Storage tab — already in main screen',
            onTap: () => Navigator.pop(context),
            enabled: false,
          ),
          _menuTile(
            context,
            icon: Icons.chair_alt_outlined,
            title: 'Inventory (tab)',
            subtitle: 'Quick jump to Inventory tab — already in main screen',
            onTap: () => Navigator.pop(context),
            enabled: false,
          ),
          const Divider(height: 24),
          _menuTile(
            context,
            icon: Icons.settings_outlined,
            title: 'Data & Export (planned)',
            subtitle: 'Future: backup, export JSON, import, clear',
            onTap: () {},
            enabled: false,
          ),
          _menuTile(
            context,
            icon: Icons.info_outline,
            title: 'About (planned)',
            subtitle: 'Version, data paths, web read-only note',
            onTap: () {},
            enabled: false,
          ),
          const SizedBox(height: 12),
          const Text('Terminology: General/Specific (not Tier, not Place/Bin except in example data like "Bin 2"). Location Options is collective term.', style: TextStyle(fontSize: 10, color: Colors.black45, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _menuTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool enabled = true}) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? Colors.black : Colors.black26),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: enabled ? Colors.black : Colors.black38, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: enabled ? Colors.black54 : Colors.black26)),
      trailing: enabled ? const Icon(Icons.chevron_right, size: 18) : null,
      onTap: enabled ? onTap : null,
      dense: true,
    );
  }
}

// Helper to open from HomeScreen:
// void _openAppMenu(BuildContext context) {
//   showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const AppMenuShell());
// }
