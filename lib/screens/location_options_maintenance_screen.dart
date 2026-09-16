import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../location_repository.dart';

/// Location Options Maintenance - from scratch
/// Header + 2 tabs (Storage / Inventory)
/// 2-tier: General (required) -> Specific (optional)
/// e.g. Garage -> Top Shelf, Garage -> "Yellow Box" (real data contains "Bin 1", "Bin 2" as Specific names)
/// Sentinel: Specific with name=="" means item lives directly in General

class LocationMaintenanceScreen extends StatefulWidget {
  const LocationMaintenanceScreen({super.key});
  @override
  State<LocationMaintenanceScreen> createState() => _LocationMaintenanceScreenState();
}

class _LocationMaintenanceScreenState extends State<LocationMaintenanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LocationRepository _repo = LocationRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EE),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Location Options', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Storage Options'),
            Tab(icon: Icon(Icons.chair_alt_outlined), text: 'Inventory Options'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TreeTab(isStorage: true),
          _TreeTab(isStorage: false),
        ],
      ),
    );
  }
}

class _TreeTab extends StatefulWidget {
  final bool isStorage;
  const _TreeTab({required this.isStorage});
  @override
  State<_TreeTab> createState() => _TreeTabState();
}

class _TreeTabState extends State<_TreeTab> {
  final LocationRepository _repo = LocationRepository();
  Set<String> expanded = {};
  String? editingGeneralId;
  String? editingSpecificId;
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _newGeneralController = TextEditingController();
  final Map<String, TextEditingController> _newSpecificControllers = {};

  bool get isStorage => widget.isStorage;
  List<Map<String, dynamic>> get generals => isStorage ? _repo.storageGenerals : _repo.inventoryGenerals;
  List<Map<String, dynamic>> get specifics => isStorage ? _repo.storageSpecifics : _repo.inventorySpecifics;
  List<Map<String, dynamic>> get items => isStorage ? _repo.storageItems : _repo.inventoryItems;

  int _itemCountForSpecific(String specId) => items.where((it) => it['specificId']?.toString() == specId).length;
  int _itemCountForGeneral(String genId) {
    final specIds = specifics.where((s) => s['generalId'] == genId).map((s) => s['id'].toString()).toSet();
    return items.where((it) => specIds.contains(it['specificId']?.toString())).length;
  }

  List<Map<String, dynamic>> _specificsForGeneral(String genId) => specifics.where((s) => s['generalId'] == genId && s['name'].toString().trim().isNotEmpty).toList()..sort((a,b)=>a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

  Map<String, dynamic>? _sentinelForGeneral(String genId) {
    try { return specifics.firstWhere((s) => s['generalId']==genId && s['name'].toString().trim().isEmpty); } catch(_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: generals.length,
            itemBuilder: (c, idx) {
              final g = generals[idx];
              final genId = g['id'].toString();
              final genName = g['name'].toString();
              final isExp = expanded.contains(genId);
              final childSpecifics = _specificsForGeneral(genId);
              final itemCount = _itemCountForGeneral(genId);
              final canDeleteGeneral = itemCount==0 && childSpecifics.isEmpty;
              final isEditingGen = editingGeneralId==genId;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(children: [
                  ListTile(
                    leading: IconButton(icon: Icon(isExp?Icons.expand_less:Icons.chevron_right), onPressed: () => setState(()=> isExp?expanded.remove(genId):expanded.add(genId))),
                    title: isEditingGen
                      ? TextField(controller: _editController, autofocus: true, onSubmitted: (v) => _renameGeneral(genId, v), decoration: const InputDecoration(hintText: 'General name', border: OutlineInputBorder(), isDense: true))
                      : Text(genName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${childSpecifics.length} specifics • $itemCount items', style: const TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!kIsWeb) IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => setState((){ editingGeneralId=genId; _editController.text=genName; })),
                      if (!kIsWeb) IconButton(icon: Icon(Icons.delete_outline, size: 18, color: canDeleteGeneral?Colors.red:Colors.black12), onPressed: canDeleteGeneral?()=>_deleteGeneral(genId):null),
                    ]),
                  ),
                  if (isExp) ...[
                    const Divider(height: 1),
                    ...childSpecifics.map((b) {
                      final specId = b['id'].toString();
                      final specName = b['name'].toString();
                      final count = _itemCountForSpecific(specId);
                      final canDeleteSpecific = count==0;
                      final isEditingSpecific = editingSpecificId==specId;
                      return Padding(
                        padding: const EdgeInsets.only(left: 40, right: 8, top: 4, bottom: 4),
                        child: ListTile(
                          dense: true,
                          tileColor: const Color(0xFFF9F6F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
                          title: isEditingSpecific
                            ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameSpecific(specId, v), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Specific name'))
                            : Text(specName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('$count items in $genName / $specName', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!kIsWeb) IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: ()=>setState((){ editingSpecificId=specId; _editController.text=specName; })),
                            if (!kIsWeb) IconButton(icon: Icon(Icons.close, size: 16, color: canDeleteSpecific?Colors.red:Colors.black12), onPressed: canDeleteSpecific?()=>_deleteSpecific(specId):null),
                          ]),
                        ),
                      );
                    }),
                    Builder(builder: (_) {
                      final sentinel = _sentinelForGeneral(genId);
                      if (sentinel==null) return const SizedBox.shrink();
                      final sCount = _itemCountForSpecific(sentinel['id'].toString());
                      if (sCount==0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 40, right: 8, top: 4),
                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.info_outline, size: 14), const SizedBox(width: 6), Text('$sCount items directly in $genName (no specific)', style: const TextStyle(fontSize: 11))])),
                      );
                    }),
                    if (!kIsWeb) Padding(
                      padding: const EdgeInsets.fromLTRB(40, 8, 8, 8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: _newSpecificControllers.putIfAbsent(genId, ()=>TextEditingController()), decoration: InputDecoration(hintText: 'New specific for $genName... e.g. Bin 2', isDense: true, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), onSubmitted: (v)=>_addSpecific(genId, v))),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: ()=>_addSpecific(genId, _newSpecificControllers[genId]?.text??''), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), child: const Text('Add Specific')),
                      ]),
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
        if (!kIsWeb) Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            child: Row(children: [
              Expanded(child: TextField(controller: _newGeneralController, decoration: InputDecoration(hintText: isStorage?'New storage general (e.g. Garage)...':'New inventory general...', border: const OutlineInputBorder(), isDense: true), onSubmitted: (v)=>_addGeneral(v))),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: ()=>_addGeneral(_newGeneralController.text), icon: const Icon(Icons.add), label: const Text('Add General'), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _addGeneral(String name) async {
    final t = name.trim();
    if (t.isEmpty) return;
    if (isStorage) {
      if (_repo.isDuplicateStorageTier1(t)) { _snack('General "$t" already exists'); return; }
      await _repo.addStorageTier1(t);
    } else {
      if (_repo.isDuplicateInventoryTier1(t)) { _snack('General "$t" already exists'); return; }
      await _repo.addInventoryTier1(t);
    }
    _newGeneralController.clear();
    setState((){});
  }

  Future<void> _addSpecific(String genId, String name) async {
    final t = name.trim();
    if (t.isEmpty) return;
    final gen = generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{});
    final genName = gen['name']?.toString()??'';
    if (isStorage) {
      if (_repo.isDuplicateStorageTier2(genName, t)) { _snack('Specific "$t" already exists in $genName'); return; }
      await _repo.addStorageTier2(genName, t);
    } else {
      if (_repo.isDuplicateInventoryTier2(genName, t)) { _snack('Specific "$t" already exists in $genName'); return; }
      await _repo.addInventoryTier2(genName, t);
    }
    _newSpecificControllers[genId]?.clear();
    setState(()=>expanded.add(genId));
  }

  Future<void> _renameGeneral(String genId, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) { setState(()=>editingGeneralId=null); return; }
    final idx = generals.indexWhere((g)=>g['id']==genId);
    if (idx<0) return;
    final oldName = generals[idx]['name'].toString();
    if (t.toLowerCase()==oldName.toLowerCase()) { setState(()=>editingGeneralId=null); return; }
    if (isStorage && _repo.isDuplicateStorageTier1(t) || !isStorage && _repo.isDuplicateInventoryTier1(t)) { _snack('General "$t" already exists'); return; }
    generals[idx]['name']=t;
    await _repo.save();
    setState(()=>editingGeneralId=null);
  }

  Future<void> _renameSpecific(String specId, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) { setState(()=>editingSpecificId=null); return; }
    final idx = specifics.indexWhere((s)=>s['id']==specId);
    if (idx<0) return;
    final old = specifics[idx]['name'].toString();
    if (t.toLowerCase()==old.toLowerCase()) { setState(()=>editingSpecificId=null); return; }
    final genId = specifics[idx]['generalId'].toString();
    final gen = generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{});
    final genName = gen['name']?.toString()??'';
    if (isStorage && _repo.isDuplicateStorageTier2(genName, t) || !isStorage && _repo.isDuplicateInventoryTier2(genName, t)) { _snack('Specific "$t" already exists in $genName'); return; }
    specifics[idx]['name']=t;
    await _repo.save();
    setState(()=>editingSpecificId=null);
  }

  Future<void> _deleteGeneral(String genId) async {
    final gen = generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{});
    final genName = gen['name'].toString();
    final childSpecifics = _specificsForGeneral(genId);
    final itemCount = _itemCountForGeneral(genId);
    if (itemCount>0 || childSpecifics.isNotEmpty) { _snack('Cannot delete $genName: has ${childSpecifics.length} specifics, $itemCount items'); return; }
    final confirm = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete General "$genName"?'), content: const Text('General has no specifics and no items. This cannot be undone.'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if (confirm!=true) return;
    specifics.removeWhere((s)=>s['generalId']==genId);
    generals.removeWhere((g)=>g['id']==genId);
    await _repo.save();
    setState((){ expanded.remove(genId); });
  }

  Future<void> _deleteSpecific(String specId) async {
    final spec = specifics.firstWhere((s)=>s['id']==specId, orElse: ()=>{});
    final specName = spec['name'].toString();
    final genId = spec['generalId'].toString();
    final gen = generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{});
    final genName = gen['name']?.toString()??'';
    final count = _itemCountForSpecific(specId);
    if (count>0) { _snack('Cannot delete $genName / $specName: $count items reference it'); return; }
    final confirm = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete Specific "$genName / $specName"?'), content: const Text('Specific has no items. Delete?'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if (confirm!=true) return;
    specifics.removeWhere((s)=>s['id']==specId);
    await _repo.save();
    setState((){});
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
