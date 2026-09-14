import 'package:flutter/material.dart';
import 'screens/storage_add_screen.dart';
import 'screens/storage_edit_screen.dart';
import 'location_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'data/migrate_json.dart';


Future<void> migrateWherelogData() async {
  final docDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
  final file = File('${docDir.path}\\wherelog_data.json');
  if (!file.existsSync()) return;

  final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

  // Already clean?
  if (raw.containsKey('storageGenerals') && raw.containsKey('storageSpecifics')) {
    print("Already clean, skipping");
    return;
  }

  int gCounter = 1, sCounter = 1, iCounter = 1;
  String newGenId() => 'stogen_${(gCounter++).toString().padLeft(3,'0')}';
  String newSpecId() => 'stospec_${(sCounter++).toString().padLeft(3,'0')}';
  String newItemId() => 'stoitem_${(iCounter++).toString().padLeft(3,'0')}';

  final generalsByName = <String, String>{}; // name -> id
  final specificsByKey = <String, String>{}; // "genId|specName" -> id
  final List<Map<String,dynamic>> newGenerals = [];
  final List<Map<String,dynamic>> newSpecifics = [];
  final List<Map<String,dynamic>> newItems = [];

  // helper to get or create general
  String getOrCreateGeneral(String name) {
    name = name.trim();
    if (name.isEmpty) name = "Unsorted";
    final key = name.toLowerCase();
    if (generalsByName.containsKey(key)) return generalsByName[key]!;
    final id = newGenId();
    generalsByName[key] = id;
    newGenerals.add({"id": id, "name": name});
    // sentinel for "general only"
    final sentinelId = newSpecId();
    specificsByKey["$id|"] = sentinelId;
    newSpecifics.add({"id": sentinelId, "generalId": id, "name": ""});
    return id;
  }

  String getOrCreateSpecific(String genId, String specName) {
    specName = specName.trim();
    final key = "$genId|${specName.toLowerCase()}";
    if (specificsByKey.containsKey(key)) return specificsByKey[key]!;
    final id = newSpecId();
    specificsByKey[key] = id;
    newSpecifics.add({"id": id, "generalId": genId, "name": specName});
    return id;
  }

  // old storageLocations may be Map<String, List> or List<Map>
  final oldLocs = raw['storageLocations'];
  if (oldLocs is Map) {
    oldLocs.forEach((gen, specs) {
      final genId = getOrCreateGeneral(gen.toString());
      if (specs is List) {
        for (var s in specs) getOrCreateSpecific(genId, s.toString());
      }
    });
  } else if (oldLocs is List) {
    for (var e in oldLocs) {
      if (e is Map) {
        final g = (e['general']?? e['tier1']?? '').toString();
        final s = (e['specific']?? e['place']?? e['bin']?? '').toString();
        final genId = getOrCreateGeneral(g);
        if (s.trim().isNotEmpty) getOrCreateSpecific(genId, s);
      }
    }
  }

  // old storageItems with many possible field names
  final oldItems = (raw['storageItems'] as List?)?? [];
  for (var e in oldItems) {
    if (e is! Map) continue;
    final name = (e['name']?? 'Unnamed').toString();
    final g = (e['general']?? e['tier1']?? e['location']?? e['place']?? '').toString();
    final s = (e['specific']?? e['tier2']?? e['bin']?? '').toString();
    final genId = getOrCreateGeneral(g);
    final specId = s.trim().isEmpty
     ? specificsByKey["$genId|"]!
      : getOrCreateSpecific(genId, s);

    newItems.add({
      "id": (e['id']?.toString().isNotEmpty == true)? e['id'] : newItemId(),
      "name": name,
      "specificId": specId,
      "notes": (e['notes']?? '').toString(),
      "image": e['image'],
      "createdAt": e['createdAt']?? DateTime.now().toIso8601String(),
    });
  }

  final clean = {
    "storageGenerals": newGenerals,
    "storageSpecifics": newSpecifics,
    "storageItems": newItems,
    // prepare inventory for later, empty but same shape
    "inventoryGenerals": raw['inventoryGenerals']?? [],
    "inventorySpecifics": raw['inventorySpecifics']?? [],
    "inventoryItems": raw['inventoryItems']?? [],
    "poiItems": raw['poiItems']?? [],
    "version": 3,
  };

  // backup
  await File('${file.path}.bak').writeAsString(await file.readAsString());
  await file.writeAsString(const JsonEncoder.withIndent(' ').convert(clean));
  print("Migrated: ${newGenerals.length} generals, ${newSpecifics.length} specifics, ${newItems.length} items. Backup: wherelog_data.json.bak");
}void main() async {
  await migrateWherelogData();  WidgetsFlutterBinding.ensureInitialized();
  await LocationRepository().load();
  runApp(WhereLogApp());
}

class WhereLogApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhereLog',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFF5F3EE),
        fontFamily: 'Inter',
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;
  String _searchQuery = '';
  bool _searchMode = false;
  String _sortBy = 'Recent';
  String _filterBy = 'All';
  final TextEditingController _searchController = TextEditingController();
  final LocationRepository _repo = LocationRepository();

  List<Place> places = [];
  List<Item> items = [];

  List<Place> _placesFromRepo() {
    // NEW: Use v5 JSON naming - storageGenerals/storageSpecifics + inventoryGenerals/inventorySpecifics
    // No hardcoded Attic/Garage fallback - app matches JSON naming
    final Map<String, List<String>> generalsMap = {};

    // Helper to add generals/specifics from repo
    void addGeneralsAndSpecifics(List generals, List specifics) {
      final Map<String, String> genIdToName = {};
      for (var g in generals) {
        if (g is Map) {
          final id = g['id']?.toString() ?? '';
          final name = g['name']?.toString() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            genIdToName[id] = name;
            generalsMap.putIfAbsent(name, () => []);
          }
        }
      }
      for (var s in specifics) {
        if (s is Map) {
          final genId = s['generalId']?.toString() ?? '';
          final name = s['name']?.toString() ?? '';
          if (name.trim().isEmpty) continue; // skip sentinel empty specifics
          final genName = genIdToName[genId];
          if (genName != null) {
            generalsMap.putIfAbsent(genName, () => []);
            if (!generalsMap[genName]!.contains(name)) {
              generalsMap[genName]!.add(name);
            }
          }
        }
      }
    }

    // Use new v5 naming from repo - storageGenerals/storageSpecifics are source of truth
    if (_repo.storageGenerals != null) {
      addGeneralsAndSpecifics(_repo.storageGenerals, _repo.storageSpecifics ?? []);
    }
    if (_repo.inventoryGenerals != null) {
      addGeneralsAndSpecifics(_repo.inventoryGenerals, _repo.inventorySpecifics ?? []);
    }

    // Fallback for old repo that still has storageData map (during transition)
    if (generalsMap.isEmpty) {
      try {
        _repo.storageData?.forEach((k, v) {
          generalsMap[k] = (generalsMap[k] ?? [])..addAll(List<String>.from(v));
        });
        _repo.inventoryData?.forEach((k, v) {
          generalsMap[k] = (generalsMap[k] ?? [])..addAll(List<String>.from(v));
        });
      } catch (_) {}
    }

    if (generalsMap.isEmpty) {
      debugPrint('WARNING: _placesFromRepo empty - check Documents/wherelog_data.json has storageGenerals/inventoryGenerals (v5)');
      return [];
    }

    final list = <Place>[];
    generalsMap.forEach((place, binsSet) {
      list.add(Place(name: place, bins: binsSet.map((b) => Bin(name: b)).toList()));
    });
    return list;
  }

  List<Item> _itemsFromRepo() {
    // NEW: Use v5 JSON naming - storageItems have specificId, resolve via storageSpecifics/storageGenerals
    // No hardcoded Holiday Wreaths - app matches JSON
    if (_repo.storageItems.isEmpty) {
      debugPrint('WARNING: storageItems empty - check Documents/wherelog_data.json v5');
      return [];
    }

    // Build lookup for v5: specificId -> {place, bin}
    final Map<String, Map<String, String>> specLookup = {};
    try {
      final Map<String, String> genIdToName = {};
      for (var g in (_repo.storageGenerals ?? [])) {
        if (g is Map) genIdToName[g['id']?.toString() ?? ''] = g['name']?.toString() ?? '';
      }
      for (var s in (_repo.storageSpecifics ?? [])) {
        if (s is Map) {
          final specId = s['id']?.toString() ?? '';
          final genId = s['generalId']?.toString() ?? '';
          final specName = s['name']?.toString() ?? '';
          final genName = genIdToName[genId] ?? '';
          if (specId.isNotEmpty) {
            specLookup[specId] = {'place': genName, 'bin': specName};
          }
        }
      }
    } catch (e) {
      debugPrint('specLookup build failed: $e');
    }

    return _repo.storageItems.map((m) {
      final id = m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      String place = '';
      String? bin;
      // v5 naming: specificId
      final specId = m['specificId']?.toString();
      if (specId != null && specLookup.containsKey(specId)) {
        place = specLookup[specId]!['place'] ?? '';
        final b = specLookup[specId]!['bin'] ?? '';
        bin = b.isEmpty ? null : b;
      } else {
        // fallback old naming during transition
        place = m['place'] ?? m['tier1'] ?? m['general'] ?? '';
        bin = (m['bin'] == null || m['bin'].toString().isEmpty || m['bin'] == '(None)') ? null : m['bin'].toString();
        if (place.isEmpty) place = m['tier1']?.toString() ?? '';
        if (bin == null) bin = m['tier2']?.toString();
      }
      return Item(
        id: id,
        name: m['name'] ?? 'Unnamed',
        qty: (m['qty'] is int) ? m['qty'] : int.tryParse(m['qty']?.toString() ?? '1') ?? 1,
        place: place.isEmpty ? 'Garage' : place,
        bin: bin,
        emoji: '📦',
        imagePath: m['image']?.toString(),
      );
    }).toList();
  }

  int _findRepoIndexForItem(Item item) {
    // Find by id first, then by name+place+bin
    int idx =
        _repo.storageItems.indexWhere((m) => m['id']?.toString() == item.id);
    if (idx >= 0) return idx;
    idx = _repo.storageItems.indexWhere((m) => (m['name'] == item.name &&
        (m['place'] == item.place || m['tier1'] == item.place) &&
        (m['bin'] == item.bin || m['tier2'] == item.bin)));
    return idx;
  }

  List<Item> _inventoryItemsFromRepo() {
    if (_repo.inventoryItems.isEmpty) {
      debugPrint('WARNING: inventoryItems empty - check Documents/wherelog_data.json v5');
      return [];
    }
    final Map<String, Map<String, String>> specLookup = {};
    try {
      final Map<String, String> genIdToName = {};
      for (var g in (_repo.inventoryGenerals ?? [])) {
        if (g is Map) genIdToName[g['id']?.toString() ?? ''] = g['name']?.toString() ?? '';
      }
      for (var s in (_repo.inventorySpecifics ?? [])) {
        if (s is Map) {
          final specId = s['id']?.toString() ?? '';
          final genId = s['generalId']?.toString() ?? '';
          final specName = s['name']?.toString() ?? '';
          final genName = genIdToName[genId] ?? '';
          if (specId.isNotEmpty) {
            specLookup[specId] = {'place': genName, 'bin': specName};
          }
        }
      }
    } catch (e) {
      debugPrint('inventory specLookup failed: $e');
    }
    return _repo.inventoryItems.map((m) {
      final id = m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      String place = '';
      String? bin;
      final specId = m['specificId']?.toString();
      if (specId != null && specLookup.containsKey(specId)) {
        place = specLookup[specId]!['place'] ?? '';
        final b = specLookup[specId]!['bin'] ?? '';
        bin = b.isEmpty ? null : b;
      } else {
        place = m['place'] ?? m['tier1'] ?? m['general'] ?? '';
        bin = (m['bin'] == null || m['bin'].toString().isEmpty || m['bin'] == '(None)') ? null : m['bin'].toString();
        if (place.isEmpty) place = m['tier1']?.toString() ?? '';
        if (bin == null) bin = m['tier2']?.toString();
      }
      return Item(
        id: id,
        name: m['name'] ?? 'Unnamed',
        qty: (m['qty'] is int) ? m['qty'] : int.tryParse(m['qty']?.toString() ?? '1') ?? 1,
        place: place.isEmpty ? 'Garage' : place,
        bin: bin,
        emoji: '🪑',
        imagePath: m['image']?.toString(),
      );
    }).toList();
  }

  int _findInventoryRepoIndexForItem(Item item) {
    int idx = _repo.inventoryItems.indexWhere((m) => m['id']?.toString() == item.id);
    if (idx >= 0) return idx;
    idx = _repo.inventoryItems.indexWhere((m) => (m['name'] == item.name &&
        (m['place'] == item.place || m['tier1'] == item.place) &&
        (m['bin'] == item.bin || m['tier2'] == item.bin)));
    return idx;
  }

  List<Item> _inventoryPlaces = [];
  List<Item> _inventoryItemsList = [];


  List<Item> inventoryItemsList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController
        .addListener(() => setState(() => _tabIndex = _tabController.index));
    places = _placesFromRepo();
    items = _itemsFromRepo();
    inventoryItemsList = _inventoryItemsFromRepo();
    _repo.load().then((_) {
      if (mounted)
        setState(() {
          places = _placesFromRepo();
          items = _itemsFromRepo();
          inventoryItemsList = _inventoryItemsFromRepo();
        });
    });
  }

  List<Item> get filteredItems {
    var list = items.where((i) {
      if (_filterBy != 'All' &&
          _filterBy != 'Important' &&
          i.place != _filterBy) return false;
      if (_searchQuery.isNotEmpty &&
          !i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        return false;
      return true;
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a, b) => a.name.compareTo(b.name));
    if (_sortBy == 'Location')
      list.sort(
          (a, b) => '${a.place}/${a.bin}'.compareTo('${b.place}/${b.bin}'));
    if (_sortBy == 'Qty') list.sort((a, b) => b.qty.compareTo(a.qty));
    return list;
  }


  List<Item> get filteredInventoryItems {
    var list = inventoryItemsList.where((i) {
      if (_filterBy != 'All' && _filterBy != 'Important' && i.place != _filterBy) return false;
      if (_searchQuery.isNotEmpty && !i.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a, b) => a.name.compareTo(b.name));
    if (_sortBy == 'Location') list.sort((a, b) => '${a.place}/${a.bin}'.compareTo('${b.place}/${b.bin}'));
    if (_sortBy == 'Qty') list.sort((a, b) => b.qty.compareTo(a.qty));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F3EE),
        elevation: 0,
        title: Row(children: [
          Image.asset('assets/icon/app_icon.png',
              width: 48,
              height: 48,
              errorBuilder: (c, e, s) => Icon(Icons.inventory_2)),
          SizedBox(width: 8),
          RichText(
              text: TextSpan(children: [
            TextSpan(
                text: 'Where',
                style: TextStyle(
                    color: Color(0xFF1E90FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 22)),
            TextSpan(
                text: 'Log',
                style: TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w900,
                    fontSize: 22)),
          ])),
        ]),
        actions: [
          IconButton(
              icon: Icon(Icons.menu, color: Colors.black),
              onPressed: () => _openLocationsSheet())
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFFEDE8DF),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            indicatorPadding: EdgeInsets.symmetric(horizontal: 4),
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.symmetric(horizontal: 2),
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Storage'),
              Tab(icon: Icon(Icons.chair_outlined), text: 'Inventory'),
              Tab(icon: Icon(Icons.location_on_outlined), text: 'POI'),
            ],
          ),
        ),
        if (_tabIndex == 0) _buildSearchFilterBar(),
        Expanded(
            child: TabBarView(controller: _tabController, children: [
          _buildStorageList(),
          ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: _repo.inventoryItems.length,
            itemBuilder: (c, i) {
              final m = _repo.inventoryItems[i];
              return Card(
                  child: ListTile(
                      title: Text(m['name'] ?? 'Unnamed'),
                      subtitle:
                          Text('${m['tier1'] ?? ''} / ${m['tier2'] ?? ''}')));
            },
          ),
          Center(child: Text('POI - coming next')),
        ])),
      ]),
    );
  }

  Widget _buildSearchFilterBar() {
    if (_searchMode) {
      return Container(
        color: Color(0xFFF5F3EE),
        padding: EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: 'SEARCH STORAGE...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24))),
                  onChanged: (v) => setState(() => _searchQuery = v))),
          SizedBox(width: 8),
          ElevatedButton(
              onPressed: () => setState(() {
                    _searchMode = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: Text('DONE', style: TextStyle(color: Colors.white))),
        ]),
      );
    }
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Text('${filteredItems.length} items',
            style: TextStyle(color: Colors.black54)),
        Spacer(),
        IconButton(icon: Icon(Icons.tune), onPressed: () => _openFilterSheet()),
        IconButton(
            icon: Icon(Icons.search),
            onPressed: () => setState(() => _searchMode = true)),
      ]),
    );
  }

  Widget _buildStorageList() {
    return Container(
      color: Color(0xFFF5F3EE),
      child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: filteredItems.length,
        itemBuilder: (c, i) {
          final item = filteredItems[i];
          final locationLabel =
              item.bin == null ? item.place : '${item.place} / ${item.bin}';
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: Color(0xFFFAF6F0),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black12)),
            child: ListTile(
              onTap: () async {
                final repoIdx = _findRepoIndexForItem(item);
                if (repoIdx < 0) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => StorageEditScreen(itemIndex: repoIdx)),
                );
                if (mounted) {
                  await _repo.load();
                  setState(() {
                    places = _placesFromRepo();
                    items = _itemsFromRepo();
                  });
                }
              },
              leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Color(0xFFF5F3EE),
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(
                      child: Text(item.emoji, style: TextStyle(fontSize: 24)))),
              title: Text('(${item.qty}) ${item.name}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Color(0xFFF0EDE8),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(locationLabel,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600))),
              trailing: Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInventoryList() {
    return Container(
      color: Color(0xFFF5F3EE),
      child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: filteredInventoryItems.length,
        itemBuilder: (c, i) {
          final item = filteredInventoryItems[i];
          final locationLabel = item.bin == null ? item.place : '${item.place} / ${item.bin}';
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: Color(0xFFFAF6F0),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black12)),
            child: ListTile(
              onTap: () async {
                final repoIdx = _findInventoryRepoIndexForItem(item);
                if (repoIdx < 0) return;
                // Reuse StorageEditScreen for now or InventoryEditScreen if exists
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StorageEditScreen(itemIndex: repoIdx)),
                );
                if (mounted) {
                  await _repo.load();
                  setState(() {
                    places = _placesFromRepo();
                    inventoryItemsList = _inventoryItemsFromRepo();
                  });
                }
              },
              leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Color(0xFFF5F3EE), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(item.emoji, style: TextStyle(fontSize: 24)))),
              title: Text(item.qty == 1 ? item.name : '(${item.qty}) ${item.name}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Color(0xFFF0EDE8), borderRadius: BorderRadius.circular(12)),
                  child: Text(locationLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              trailing: Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Color(0xFFDCE7FF),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (c) {
          return StatefulBuilder(builder: (c, setModal) {
            return Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text('FILTER & SORT',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                      Spacer(),
                      IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(c))
                    ]),
                    SizedBox(height: 16),
                    Text('SORT BY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        children:
                            ['Recent', 'Name A-Z', 'Location', 'Qty'].map((s) {
                          final sel = _sortBy == s;
                          return ChoiceChip(
                              label: Text(s),
                              selected: sel,
                              onSelected: (_) => setModal(() => _sortBy = s),
                              selectedColor: Color(0xFF0F1E3A),
                              labelStyle: TextStyle(
                                  color: sel ? Colors.white : Colors.black));
                        }).toList()),
                    SizedBox(height: 16),
                    Text('FILTER',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        children: [
                          'All',
                          'Attic',
                          'Garage',
                          'Shed',
                          'Kitchen',
                          'Office',
                          'Important'
                        ].map((f) {
                          final sel = _filterBy == f;
                          return ChoiceChip(
                              label: Text(f),
                              selected: sel,
                              onSelected: (_) => setModal(() => _filterBy = f),
                              selectedColor: Color(0xFF0F1E3A),
                              labelStyle: TextStyle(
                                  color: sel ? Colors.white : Colors.black));
                        }).toList()),
                    SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _filterBy = 'All';
                                  _sortBy = 'Recent';
                                });
                                Navigator.pop(c);
                              },
                              child: Text('RESET'))),
                      SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton(
                              onPressed: () {
                                setState(() {});
                                Navigator.pop(c);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0F1E3A)),
                              child: Text('APPLY • $_filterBy / $_sortBy',
                                  style: TextStyle(color: Colors.white)))),
                    ]),
                  ]),
            );
          });
        });
  }

  void _openLocationsSheet() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (c) {
          return LocationsSheet(places: places);
        });
  }
}

class Place {
  String name;
  List<Bin> bins;
  Place({required this.name, required this.bins});
}

class Bin {
  String name;
  Bin({required this.name});
}

class Item {
  String id;
  String name;
  int qty;
  String place;
  String? bin;
  String emoji;
  String? imagePath;
  Item(
      {required this.id,
      required this.name,
      required this.qty,
      required this.place,
      this.bin,
      this.emoji = '📦',
      this.imagePath});
}

class LocationsSheet extends StatefulWidget {
  final List<Place> places;
  LocationsSheet({required this.places});
  @override
  State<LocationsSheet> createState() => _LocationsSheetState();
}

class _LocationsSheetState extends State<LocationsSheet> {
  bool editMode = false;
  Set<String> expanded = {'Garage'};
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (c, scroll) {
          return SingleChildScrollView(
              controller: scroll,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: Colors.black, shape: BoxShape.circle),
                            child:
                                Icon(Icons.location_on, color: Colors.white)),
                        SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Locations',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18)),
                              Text('Place / Room → Bin / Area • distinct bins',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54))
                            ])),
                        IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context))
                      ]),
                      SizedBox(height: 12),
                      Row(children: [
                        Chip(label: Text('Storage 5')),
                        SizedBox(width: 8),
                        Chip(label: Text('Inventory 5'))
                      ]),
                      SizedBox(height: 12),
                      Row(children: [
                        Text('MODE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54)),
                        SizedBox(width: 8),
                        Chip(
                            label: Text(editMode ? 'EDIT MODE' : 'VIEW SAFE'),
                            backgroundColor: Colors.black12),
                        Spacer(),
                        Text('default: View',
                            style:
                                TextStyle(fontSize: 11, color: Colors.black54))
                      ]),
                      SizedBox(height: 8),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(24)),
                          padding: EdgeInsets.all(4),
                          child: Row(children: [
                            Expanded(
                                child: ElevatedButton.icon(
                                    onPressed: () =>
                                        setState(() => editMode = false),
                                    icon: Icon(Icons.visibility_outlined),
                                    label: Text('View'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: editMode
                                            ? Colors.white
                                            : Colors.black,
                                        foregroundColor: editMode
                                            ? Colors.black
                                            : Colors.white,
                                        shape: StadiumBorder()))),
                            Expanded(
                                child: ElevatedButton.icon(
                                    onPressed: () =>
                                        setState(() => editMode = true),
                                    icon: Icon(Icons.edit_outlined),
                                    label: Text('Edit'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: editMode
                                            ? Colors.black
                                            : Colors.white,
                                        foregroundColor: editMode
                                            ? Colors.white
                                            : Colors.black,
                                        shape: StadiumBorder()))),
                          ])),
                      SizedBox(height: 12),
                      Text(
                          editMode
                              ? 'Edit: Tap name to edit (Return saves), X deletes (confirm if has bins), blanks: "Type new Place..." + "Type new Bin for Garage..."'
                              : 'View: Safe browsing only — chevron expands, peruse tree, no blanks, no edit, no delete.',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(height: 12),
                      Container(
                          padding: EdgeInsets.all(12),
                          color: Color(0xFFF5F3EE),
                          child: Row(children: [
                            Icon(Icons.error, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    '2 tiers: Place required → Bin optional inside Place. Garage / Bin 1 ≠ Attic / Bin 1.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)))
                          ])),
                      ...widget.places.map((p) {
                        final isExp = expanded.contains(p.name);
                        return Card(
                            margin: EdgeInsets.only(top: 8),
                            child: Column(children: [
                              ListTile(
                                  leading: IconButton(
                                      icon: Icon(isExp
                                          ? Icons.keyboard_arrow_down
                                          : Icons.chevron_right),
                                      onPressed: () => setState(() => isExp
                                          ? expanded.remove(p.name)
                                          : expanded.add(p.name))),
                                  title: Row(children: [
                                    Text(p.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    SizedBox(width: 8),
                                    Chip(label: Text('${p.bins.length}'))
                                  ]),
                                  trailing: editMode
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 18),
                                              SizedBox(width: 8),
                                              Icon(Icons.close,
                                                  color: Colors.red, size: 18)
                                            ])
                                      : null),
                              if (isExp)
                                ...p.bins.map((b) => Padding(
                                    padding: EdgeInsets.only(
                                        left: 40, right: 12, bottom: 8),
                                    child: Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.black12),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Row(children: [
                                          Text('${b.name} - ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800)),
                                          Text('${p.name} / ${b.name}',
                                              style: TextStyle(
                                                  fontFamily: 'monospace'))
                                        ])))),
                            ]));
                      }).toList(),
                      SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Done'))),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                '${widget.places.length} Place • Bin • storage • ${editMode ? 'Edit combined' : 'View safe'}',
                                style: TextStyle(fontWeight: FontWeight.bold)))
                      ])
                    ]),
              ));
        });
  }
}
