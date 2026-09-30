import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/app_header.dart';
import '../location_repository.dart';

/// Location Options v6 - SINGLE GENERALS
/// Before: 2 tabs with duplicate generals (Garage in Storage + Garage in Inventory = 2 entries)
/// Now: Single list of 10 unique generals, each shows storage specifics + inventory specifics counts

class LocationMaintenanceScreen extends StatefulWidget {
  const LocationMaintenanceScreen({super.key});
  @override
  State<LocationMaintenanceScreen> createState() => _LocationMaintenanceScreenState();
}

class _LocationMaintenanceScreenState extends State<LocationMaintenanceScreen> {
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F3EE);
    return const Scaffold(
      backgroundColor: bg,
      appBar: AppHeader(screenName: 'Location Options'),
      body: _SingleGeneralTree(),
    );
  }
}

class _SingleGeneralTree extends StatefulWidget {
  const _SingleGeneralTree();
  @override
  State<_SingleGeneralTree> createState() => _SingleGeneralTreeState();
}

class _SingleGeneralTreeState extends State<_SingleGeneralTree> {
  final LocationRepository _repo = LocationRepository();
  Set<String> expanded = {};
  String? editingGeneralId;
  String? editingSpecificId;
  String editingSpecificType = 'storage'; // 'storage' or 'inventory'
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _newGeneralController = TextEditingController();
  final Map<String, TextEditingController> _newStorageSpecificControllers = {};
  final Map<String, TextEditingController> _newInventorySpecificControllers = {};

  List<Map<String, dynamic>> get generals => _repo.generals;
  List<Map<String, dynamic>> get storageSpecifics => _repo.storageSpecifics;
  List<Map<String, dynamic>> get inventorySpecifics => _repo.inventorySpecifics;
  List<Map<String, dynamic>> get storageItems => _repo.storageItems;
  List<Map<String, dynamic>> get inventoryItems => _repo.inventoryItems;

  int _itemCountForStorageSpecific(String specId) => storageItems.where((it) => it['specificId']?.toString() == specId).length;
  int _itemCountForInventorySpecific(String specId) => inventoryItems.where((it) => it['specificId']?.toString() == specId).length;

  int _itemCountForGeneral(String genId) {
    final stoSpecIds = storageSpecifics.where((s) => s['generalId'] == genId).map((s) => s['id'].toString()).toSet();
    final invSpecIds = inventorySpecifics.where((s) => s['generalId'] == genId).map((s) => s['id'].toString()).toSet();
    final stoCount = storageItems.where((it) => stoSpecIds.contains(it['specificId']?.toString())).length;
    final invCount = inventoryItems.where((it) => invSpecIds.contains(it['specificId']?.toString())).length;
    return stoCount + invCount;
  }

  List<Map<String, dynamic>> _storageSpecificsForGeneral(String genId) => storageSpecifics.where((s) => s['generalId'] == genId && s['name'].toString().trim().isNotEmpty).toList()..sort((a,b)=>a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
  List<Map<String, dynamic>> _inventorySpecificsForGeneral(String genId) => inventorySpecifics.where((s) => s['generalId'] == genId && s['name'].toString().trim().isNotEmpty).toList()..sort((a,b)=>a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

  InputDecoration _fieldDec(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    hintStyle: const TextStyle(fontSize: 13, color: Colors.black54),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black54)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFE8E0D5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
            Expanded(child: Text('${generals.length} Generals (shared) — Storage and Inventory specifics are separate', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(6),
            itemCount: generals.length,
            itemBuilder: (c, idx) {
              final g = generals[idx];
              final genId = g['id'].toString();
              final genName = g['name'].toString();
              final isExp = expanded.contains(genId);
              final stoSpecifics = _storageSpecificsForGeneral(genId);
              final invSpecifics = _inventorySpecificsForGeneral(genId);
              final itemCount = _itemCountForGeneral(genId);
              final canDeleteGeneral = itemCount==0 && stoSpecifics.isEmpty && invSpecifics.isEmpty;
              final isEditingGen = editingGeneralId==genId;
              return Card(
                margin: const EdgeInsets.only(bottom: 3),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.black12, width: 0.5)),
                child: Column(children: [
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    leading: IconButton(icon: Icon(isExp?Icons.expand_less:Icons.chevron_right, size: 18), onPressed: ()=>setState(()=>isExp?expanded.remove(genId):expanded.add(genId)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    title: isEditingGen ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameGeneral(genId, v), decoration: _fieldDec('General name'), style: const TextStyle(fontSize: 13)) : Text(genName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    subtitle: Text('${stoSpecifics.length} Storage / ${invSpecifics.length} Inventory specifics - $itemCount items', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if(!isEditingGen) IconButton(icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.black54), onPressed: ()=>setState(()=>{editingGeneralId=genId, _editController.text=genName}), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      if(isEditingGen) IconButton(icon: const Icon(Icons.check, size: 16, color: Colors.green), onPressed: ()=>_renameGeneral(genId, _editController.text), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      if(isEditingGen) IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.black54), onPressed: ()=>setState(()=>editingGeneralId=null), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      IconButton(icon: Icon(Icons.delete_outline, size: 14, color: canDeleteGeneral?Colors.red:Colors.black26), onPressed: canDeleteGeneral?()=>_deleteGeneral(genId):null, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ]),
                  ),
                  if(isExp) ...[
                    // Storage specifics section
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)),
                      child: Row(children: [
                        const Icon(Icons.inventory_2_outlined, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text('Storage Specifics (${stoSpecifics.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ]),
                    ),
                    ...stoSpecifics.map((s) {
                      final specId = s['id'].toString();
                      final specName = s['name'].toString();
                      final count = _itemCountForStorageSpecific(specId);
                      final canDelete = count==0;
                      final isEditing = editingSpecificId==specId && editingSpecificType=='storage';
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 2, 8, 2),
                        child: Row(children: [
                          Expanded(child: isEditing ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameSpecific(specId, v, 'storage'), decoration: _fieldDec('Specific name'), style: const TextStyle(fontSize: 12)) : Text('• $specName ($count items)', style: const TextStyle(fontSize: 12))),
                          if(!isEditing) IconButton(icon: const Icon(Icons.edit_outlined, size: 12, color: Colors.black54), onPressed: ()=>setState(()=>{editingSpecificId=specId, editingSpecificType='storage', _editController.text=specName}), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          if(isEditing) IconButton(icon: const Icon(Icons.check, size: 14, color: Colors.green), onPressed: ()=>_renameSpecific(specId, _editController.text, 'storage'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          IconButton(icon: Icon(Icons.delete_outline, size: 12, color: canDelete?Colors.red:Colors.black26), onPressed: canDelete?()=>_deleteSpecific(specId, 'storage'):null, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ]),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 3, 8, 5),
                      child: Row(children: [
                        Expanded(child: TextField(controller: _newStorageSpecificControllers.putIfAbsent(genId, ()=>TextEditingController()), decoration: _fieldDec('New Storage Specific'), style: const TextStyle(fontSize: 12), onSubmitted: (v)=>_addSpecific(genId, v, 'storage'))),
                        const SizedBox(width: 6),
                        ElevatedButton(onPressed: ()=>_addSpecific(genId, _newStorageSpecificControllers[genId]?.text??'', 'storage'), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('+ Add', style: TextStyle(fontSize: 12))),
                      ]),
                    ),
                    // Inventory specifics section
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(6)),
                      child: Row(children: [
                        const Icon(Icons.chair_alt_outlined, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text('Inventory Specifics (${invSpecifics.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ]),
                    ),
                    ...invSpecifics.map((s) {
                      final specId = s['id'].toString();
                      final specName = s['name'].toString();
                      final count = _itemCountForInventorySpecific(specId);
                      final canDelete = count==0;
                      final isEditing = editingSpecificId==specId && editingSpecificType=='inventory';
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 2, 8, 2),
                        child: Row(children: [
                          Expanded(child: isEditing ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameSpecific(specId, v, 'inventory'), decoration: _fieldDec('Specific name'), style: const TextStyle(fontSize: 12)) : Text('• $specName ($count items)', style: const TextStyle(fontSize: 12))),
                          if(!isEditing) IconButton(icon: const Icon(Icons.edit_outlined, size: 12, color: Colors.black54), onPressed: ()=>setState(()=>{editingSpecificId=specId, editingSpecificType='inventory', _editController.text=specName}), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          if(isEditing) IconButton(icon: const Icon(Icons.check, size: 14, color: Colors.green), onPressed: ()=>_renameSpecific(specId, _editController.text, 'inventory'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          IconButton(icon: Icon(Icons.delete_outline, size: 12, color: canDelete?Colors.red:Colors.black26), onPressed: canDelete?()=>_deleteSpecific(specId, 'inventory'):null, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ]),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 3, 8, 8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: _newInventorySpecificControllers.putIfAbsent(genId, ()=>TextEditingController()), decoration: _fieldDec('New Inventory Specific'), style: const TextStyle(fontSize: 12), onSubmitted: (v)=>_addSpecific(genId, v, 'inventory'))),
                        const SizedBox(width: 6),
                        ElevatedButton(onPressed: ()=>_addSpecific(genId, _newInventorySpecificControllers[genId]?.text??'', 'inventory'), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('+ Add', style: TextStyle(fontSize: 12))),
                      ]),
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
        if (!kIsWeb) Container(
          color: const Color(0xFFF5F3EE),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: SafeArea(
            child: Row(children: [
              Expanded(child: TextField(controller: _newGeneralController, decoration: _fieldDec('New General (shared)'), style: const TextStyle(fontSize: 13), onSubmitted: (v)=>_addGeneral(v))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: ()=>_addGeneral(_newGeneralController.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), minimumSize: const Size(0, 38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('+ Add', style: TextStyle(fontSize: 13))),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _addGeneral(String name) async {
    final t=name.trim(); if(t.isEmpty) return;
    if(_repo.isDuplicateTier1(t)){_snack('General "$t" already exists'); return;}
    await _repo.addTier1(t);
    _newGeneralController.clear(); setState((){});
  }
  Future<void> _addSpecific(String genId, String name, String type) async {
    final t=name.trim(); if(t.isEmpty) return;
    final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name']?.toString()??'';
    if(type=='storage'){
      if(_repo.isDuplicateStorageTier2(genName, t)){_snack('Storage Specific "$t" already exists in $genName'); return;}
      await _repo.addStorageTier2(genName, t);
      _newStorageSpecificControllers[genId]?.clear();
    } else {
      if(_repo.isDuplicateInventoryTier2(genName, t)){_snack('Inventory Specific "$t" already exists in $genName'); return;}
      await _repo.addInventoryTier2(genName, t);
      _newInventorySpecificControllers[genId]?.clear();
    }
    setState(()=>expanded.add(genId));
  }
  Future<void> _renameGeneral(String genId, String newName) async {
    final t=newName.trim(); if(t.isEmpty){setState(()=>editingGeneralId=null); return;}
    final idx=generals.indexWhere((g)=>g['id']==genId); if(idx<0) return;
    final oldName=generals[idx]['name'].toString(); if(t.toLowerCase()==oldName.toLowerCase()){setState(()=>editingGeneralId=null); return;}
    if(_repo.isDuplicateTier1(t)){_snack('General "$t" already exists'); return;}
    generals[idx]['name']=t; await _repo.save(); setState(()=>editingGeneralId=null);
  }
  Future<void> _renameSpecific(String specId, String newName, String type) async {
    final t=newName.trim(); if(t.isEmpty){setState(()=>editingSpecificId=null); return;}
    final list = type=='storage' ? storageSpecifics : inventorySpecifics;
    final idx=list.indexWhere((s)=>s['id']==specId); if(idx<0) return;
    final old=list[idx]['name'].toString(); if(t.toLowerCase()==old.toLowerCase()){setState(()=>editingSpecificId=null); return;}
    final genId=list[idx]['generalId'].toString(); final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name']?.toString()??'';
    if(type=='storage' && _repo.isDuplicateStorageTier2(genName, t) || type=='inventory' && _repo.isDuplicateInventoryTier2(genName, t)){_snack('Specific "$t" already exists in $genName'); return;}
    list[idx]['name']=t; await _repo.save(); setState(()=>editingSpecificId=null);
  }
  Future<void> _deleteGeneral(String genId) async {
    final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name'].toString();
    final stoSpecifics=_storageSpecificsForGeneral(genId); final invSpecifics=_inventorySpecificsForGeneral(genId); final itemCount=_itemCountForGeneral(genId);
    if(itemCount>0 || stoSpecifics.isNotEmpty || invSpecifics.isNotEmpty){_snack('Cannot delete $genName: has ${stoSpecifics.length} storage + ${invSpecifics.length} inventory specifics, $itemCount items'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete General "$genName"?'), content: const Text('General has no specifics and no items. This cannot be undone.'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if(confirm!=true) return;
    storageSpecifics.removeWhere((s)=>s['generalId']==genId);
    inventorySpecifics.removeWhere((s)=>s['generalId']==genId);
    generals.removeWhere((g)=>g['id']==genId);
    await _repo.save(); setState(()=>{expanded.remove(genId)});
  }
  Future<void> _deleteSpecific(String specId, String type) async {
    final list = type=='storage' ? storageSpecifics : inventorySpecifics;
    final spec=list.firstWhere((s)=>s['id']==specId, orElse: ()=>{}); final specName=spec['name'].toString(); final genId=spec['generalId'].toString(); final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name']?.toString()??'';
    final count = type=='storage' ? _itemCountForStorageSpecific(specId) : _itemCountForInventorySpecific(specId);
    if(count>0){_snack('Cannot delete $genName / $specName: $count items reference it'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete Specific "$genName / $specName"?'), content: const Text('Specific has no items. Delete?'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if(confirm!=true) return;
    list.removeWhere((s)=>s['id']==specId); await _repo.save(); setState((){});
  }
  void _snack(String msg)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
