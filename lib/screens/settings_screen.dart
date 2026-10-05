import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final svc = SettingsService();
  String theme = 'system';
  bool collapse = false;
  List<String> tabOrder = ['Storage','Inventory','POI'];
  bool confirmDelete = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    theme = await svc.getTheme();
    collapse = await svc.getCollapse();
    tabOrder = await svc.getTabOrder();
    confirmDelete = await svc.getConfirmDelete();
    setState(() {});
  }

  Widget _buildThemeButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 4),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? AppColors.buttonBg : AppColors.white,
          foregroundColor: selected ? AppColors.white : Colors.black87,
          side: BorderSide(color: selected ? AppColors.buttonBg : AppColors.border, width: selected ? 1.8 : 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
          elevation: selected ? 1 : 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size(0, 28),
        ),
        child: Text(label, 
          style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 11)),
      ),
    );
  }

  Widget _buildTabOrderButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: selected ? AppColors.buttonBg : AppColors.white,
            foregroundColor: selected ? AppColors.white : Colors.black87,
            side: BorderSide(color: selected ? AppColors.buttonBg : AppColors.border, width: selected ? 1.5 : 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            elevation: selected ? 1 : 0,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size(0, 26),
          ),
          child: Text(label, 
            style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 11, letterSpacing: 0.1)),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(screenName: 'App Settings'),
      backgroundColor: AppColors.scaffold,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Display Mode', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            children: [
              _buildThemeButton(label: 'System', selected: theme=='system', onTap: (){setState(()=>theme='system'); svc.setTheme('system');}),
              _buildThemeButton(label: 'Light', selected: theme=='light', onTap: (){setState(()=>theme='light'); svc.setTheme('light');}),
              _buildThemeButton(label: 'Dark', selected: theme=='dark', onTap: (){setState(()=>theme='dark'); svc.setTheme('dark');}),
            ],
          ),

          const Divider(height: 28),

          SwitchListTile(
            title: const Text('Notes Collapsed is Default', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            subtitle: Text(collapse ? 'Collapsed by default' : 'Expanded by default', style: const TextStyle(fontSize: 10.5)),
            value: collapse,
            onChanged: (v){ setState(()=>collapse=v); svc.setCollapse(v); },
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(height: 28),

          const Text('Main Screen Tab order', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const Text('Tap to select order', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...SettingsService.allOrders.map((order) {
            final label = order.join(' • ');
            final isSelected = order.join(',') == tabOrder.join(',');
            return _buildTabOrderButton(
              label: label,
              selected: isSelected,
              onTap: (){ setState(()=>tabOrder=order); svc.setTabOrder(order); },
            );
          }),

          const Divider(height: 28),

          SwitchListTile(
            title: const Text('Confirm Deletes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            subtitle: Text(confirmDelete ? 'Confirm before delete' : 'Deletes immediately, no undo', style: const TextStyle(fontSize: 10.5)),
            value: confirmDelete,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) async {
              if (!v) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Turn off delete confirmation?'),
                    content: const Text('If off, items are deleted immediately with no undo.'),
                    actions: [
                      TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')),
                      TextButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Turn Off Anyway')),
                    ],
                  ),
                );
                if (ok != true) return;
              }
              setState(()=>confirmDelete=v);
              svc.setConfirmDelete(v);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
