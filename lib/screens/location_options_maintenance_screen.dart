import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/app_header.dart';
import '../location_repository.dart';

class LocationMaintenanceScreen extends StatefulWidget {
  const LocationMaintenanceScreen({super.key});
  @override
  State<LocationMaintenanceScreen> createState() => _LocationMaintenanceScreenState();
}

class _LocationMaintenanceScreenState extends State<LocationMaintenanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F3EE);
    return Scaffold(
      backgroundColor: bg,
      appBar: const AppHeader(screenName: 'Location Options'),
      body: Column(
        children: [
          Material(
            color: bg,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black45,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              indicatorColor: Colors.transparent,
              indicatorWeight: 0.0001,
              dividerColor: Colors.black12,
              tabs: const [
                Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Storage'),
                Tab(icon: Icon(Icons.chair_alt_outlined, size: 20), text: 'Inventory'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _TreeTab(isStorage: true),
                _TreeTab(isStorage: false),
              ],
            ),
          ),
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(6),
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
                    subtitle: Text('${childSpecifics.length} Specific locations - $itemCount items', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!kIsWeb) IconButton(icon: const Icon(Icons.edit_outlined, size: 14), onPressed: ()=>setState(()=>{editingGeneralId=genId, _editController.text=genName}), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26)),
                      if (!kIsWeb) IconButton(icon: Icon(Icons.close, size: 14, color: canDeleteGeneral?Colors.red:Colors.black12), onPressed: canDeleteGeneral?()=>_deleteGeneral(genId):null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26)),
                    ]),
                  ),
                  if (isExp) ...[
                    const Divider(height: 1, color: Colors.black12),
                    ...childSpecifics.map((b) {
                      final specId = b['id'].toString();
                      final specName = b['name'].toString();
                      final count = _itemCountForSpecific(specId);
                      final canDeleteSpecific = count==0;
                      final isEditingSpecific = editingSpecificId==specId;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 4, 0),
                        child: ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          title: isEditingSpecific ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameSpecific(specId, v), decoration: _fieldDec('Specific name'), style: const TextStyle(fontSize: 12)) : Text(specName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                          subtitle: Text('$count items', style: const TextStyle(fontSize: 9.5, color: Colors.black87)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!kIsWeb) IconButton(icon: const Icon(Icons.edit_outlined, size: 12), onPressed: ()=>setState(()=>{editingSpecificId=specId, _editController.text=specName}), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 22)),
                            if (!kIsWeb) IconButton(icon: Icon(Icons.close, size: 12, color: canDeleteSpecific?Colors.red:Colors.black12), onPressed: canDeleteSpecific?()=>_deleteSpecific(specId):null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 22)),
                          ]),
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 3, 8, 5),
                      child: Row(children: [
                        Expanded(child: TextField(controller: _newSpecificControllers.putIfAbsent(genId, ()=>TextEditingController()), decoration: _fieldDec('New Specific Option'), style: const TextStyle(fontSize: 12), onSubmitted: (v)=>_addSpecific(genId, v))),
                        const SizedBox(width: 6),
                        ElevatedButton(onPressed: ()=>_addSpecific(genId, _newSpecificControllers[genId]?.text??''), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(0, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('+ Add', style: TextStyle(fontSize: 12))),
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
              Expanded(child: TextField(controller: _newGeneralController, decoration: _fieldDec('New General Option'), style: const TextStyle(fontSize: 13), onSubmitted: (v)=>_addGeneral(v))),
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
    if(isStorage){ if(_repo.isDuplicateStorageTier1(t)){_snack('General "$t" already exists'); return;} await _repo.addStorageTier1(t);} else { if(_repo.isDuplicateInventoryTier1(t)){_snack('General "$t" already exists'); return;} await _repo.addInventoryTier1(t);}
    _newGeneralController.clear(); setState((){});
  }
  Future<void> _addSpecific(String genId, String name) async {
    final t=name.trim(); if(t.isEmpty) return;
    final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name']?.toString()??'';
    if(isStorage){ if(_repo.isDuplicateStorageTier2(genName, t)){_snack('Specific "$t" already exists in $genName'); return;} await _repo.addStorageTier2(genName, t);} else { if(_repo.isDuplicateInventoryTier2(genName, t)){_snack('Specific "$t" already exists in $genName'); return;} await _repo.addInventoryTier2(genName, t);}
    _newSpecificControllers[genId]?.clear(); setState(()=>expanded.add(genId));
  }
  Future<void> _renameGeneral(String genId, String newName) async {
    final t=newName.trim(); if(t.isEmpty){setState(()=>editingGeneralId=null); return;}
    final idx=generals.indexWhere((g)=>g['id']==genId); if(idx<0) return;
    final oldName=generals[idx]['name'].toString(); if(t.toLowerCase()==oldName.toLowerCase()){setState(()=>editingGeneralId=null); return;}
    if(isStorage && _repo.isDuplicateStorageTier1(t) || !isStorage && _repo.isDuplicateInventoryTier1(t)){_snack('General "$t" already exists'); return;}
    generals[idx]['name']=t; await _repo.save(); setState(()=>editingGeneralId=null);
  }
  Future<void> _renameSpecific(String specId, String newName) async {
    final t=newName.trim(); if(t.isEmpty){setState(()=>editingSpecificId=null); return;}
    final idx=specifics.indexWhere((s)=>s['id']==specId); if(idx<0) return;
    final old=specifics[idx]['name'].toString(); if(t.toLowerCase()==old.toLowerCase()){setState(()=>editingSpecificId=null); return;}
    final genId=specifics[idx]['generalId'].toString(); final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name']?.toString()??'';
    if(isStorage && _repo.isDuplicateStorageTier2(genName, t) || !isStorage && _repo.isDuplicateInventoryTier2(genName, t)){_snack('Specific "$t" already exists in $genName'); return;}
    specifics[idx]['name']=t; await _repo.save(); setState(()=>editingSpecificId=null);
  }
  Future<void> _deleteGeneral(String genId) async {
    final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name'].toString();
    final childSpecifics=_specificsForGeneral(genId); final itemCount=_itemCountForGeneral(genId);
    if(itemCount>0 || childSpecifics.isNotEmpty){_snack('Cannot delete $genName: has ${childSpecifics.length} specifics, $itemCount items'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete General "$genName"?'), content: const Text('General has no specifics and no items. This cannot be undone.'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if(confirm!=true) return; specifics.removeWhere((s)=>s['generalId']==genId); generals.removeWhere((g)=>g['id']==genId); await _repo.save(); setState(()=>{expanded.remove(genId)});
  }
  Future<void> _deleteSpecific(String specId) async {
    final spec=specifics.firstWhere((s)=>s['id']==specId, orElse: ()=>{}); final specName=spec['name'].toString(); final genId=spec['generalId'].toString(); final gen=generals.firstWhere((g)=>g['id']==genId, orElse: ()=>{}); final genName=gen['name']?.toString()??''; final count=_itemCountForSpecific(specId);
    if(count>0){_snack('Cannot delete $genName / $specName: $count items reference it'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete Specific "$genName / $specName"?'), content: const Text('Specific has no items. Delete?'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
    if(confirm!=true) return; specifics.removeWhere((s)=>s['id']==specId); await _repo.save(); setState((){});
  }
  void _snack(String msg)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
