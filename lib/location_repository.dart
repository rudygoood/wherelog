import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Repository v5 - app matches JSON naming
/// JSON v5 structure:
/// - storageGenerals: [{id: stogen_001, name: Garage}, ...]
/// - storageSpecifics: [{id: stospec_001, generalId: stogen_001, name: Bin 1}, ...]
/// - storageItems: [{id: stoitem_001, name: ..., specificId: stospec_001, ...}, ...]
/// - inventoryGenerals: [{id: invgen_001, name: Attic}, ...]
/// - inventorySpecifics: [{id: invspec_001, generalId: invgen_001, name: Bin 1}, ...]
/// - inventoryItems: [{id: invitem_001, name: ..., specificId: invspec_001, ...}, ...]
/// - poiItems: []
/// No hardcoded Attic/Garage tree - all in JSON

class LocationRepository {
  static final LocationRepository _instance = LocationRepository._internal();
  factory LocationRepository() => _instance;
  LocationRepository._internal();

  // v5 - source of truth
  List<Map<String, dynamic>> _storageGenerals = [];
  List<Map<String, dynamic>> _storageSpecifics = [];
  List<Map<String, dynamic>> _storageItems = [];
  List<Map<String, dynamic>> _inventoryGenerals = [];
  List<Map<String, dynamic>> _inventorySpecifics = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _poiItems = [];
  bool _loaded = false;

  // v5 getters - these are what main.dart v5 expects
  List<Map<String, dynamic>> get storageGenerals => _storageGenerals;
  List<Map<String, dynamic>> get storageSpecifics => _storageSpecifics;
  List<Map<String, dynamic>> get storageItems => _storageItems;
  List<Map<String, dynamic>> get inventoryGenerals => _inventoryGenerals;
  List<Map<String, dynamic>> get inventorySpecifics => _inventorySpecifics;
  List<Map<String, dynamic>> get inventoryItems => _inventoryItems;
  List<Map<String, dynamic>> get poiItems => _poiItems;

  // Backward compat computed Maps for old screens that still use storageData/inventoryData
  // Built from generals/specifics
  Map<String, List<String>> get storageData {
    final map = <String, List<String>>{};
    final genIdToName = <String, String>{};
    for (var g in _storageGenerals) {
      final id = g['id']?.toString() ?? '';
      final name = g['name']?.toString() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        genIdToName[id] = name;
        map[name] = [];
      }
    }
    for (var s in _storageSpecifics) {
      final genId = s['generalId']?.toString() ?? '';
      final name = s['name']?.toString() ?? '';
      if (name.trim().isEmpty) continue;
      final genName = genIdToName[genId];
      if (genName != null) {
        map.putIfAbsent(genName, () => []);
        if (!map[genName]!.contains(name)) map[genName]!.add(name);
      }
    }
    return map;
  }

  Map<String, List<String>> get inventoryData {
    final map = <String, List<String>>{};
    final genIdToName = <String, String>{};
    for (var g in _inventoryGenerals) {
      final id = g['id']?.toString() ?? '';
      final name = g['name']?.toString() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        genIdToName[id] = name;
        map[name] = [];
      }
    }
    for (var s in _inventorySpecifics) {
      final genId = s['generalId']?.toString() ?? '';
      final name = s['name']?.toString() ?? '';
      if (name.trim().isEmpty) continue;
      final genName = genIdToName[genId];
      if (genName != null) {
        map.putIfAbsent(genName, () => []);
        if (!map[genName]!.contains(name)) map[genName]!.add(name);
      }
    }
    return map;
  }

  List<String> get storageTier1List => storageData.keys.toList()..sort();
  List<String> get inventoryTier1List => inventoryData.keys.toList()..sort();
  List<String> storageTier2For(String tier1) => storageData[tier1] ?? [];
  List<String> inventoryTier2For(String tier1) => inventoryData[tier1] ?? [];

  Future<File> _getFile() async {
    // Try Windows Documents folder first (user's real file), then app documents
    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final docFile = File('$userProfile\\Documents\\wherelog_data.json');
        if (await docFile.exists()) {
          return docFile;
        }
      }
    } catch (_) {}
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/wherelog_data.json');
  }

  Future<void> _loadFromAssetAndSave() async {
    try {
      final assetString = await rootBundle.loadString('assets/data/wherelog_data.json');
      final json = jsonDecode(assetString);
      if (json is Map) {
        _parseJson(Map<String, dynamic>.from(json));
      }
      await save();
    } catch (e) {
      // Asset not found - leave empty
      _storageGenerals = [];
      _storageSpecifics = [];
      _inventoryGenerals = [];
      _inventorySpecifics = [];
    }
  }

  void _parseJson(Map<String, dynamic> json) {
    // v5 format - direct
    if (json['storageGenerals'] is List) {
      _storageGenerals = (json['storageGenerals'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (json['storageSpecifics'] is List) {
      _storageSpecifics = (json['storageSpecifics'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (json['storageItems'] is List) {
      _storageItems = (json['storageItems'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (json['inventoryGenerals'] is List) {
      _inventoryGenerals = (json['inventoryGenerals'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (json['inventorySpecifics'] is List) {
      _inventorySpecifics = (json['inventorySpecifics'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (json['inventoryItems'] is List) {
      _inventoryItems = (json['inventoryItems'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (json['poiItems'] is List) {
      _poiItems = (json['poiItems'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    // Backward compat: old format with storageLocations Map
    if (json['storageLocations'] is Map && _storageGenerals.isEmpty) {
      _migrateOldMapToV5(json['storageLocations'] as Map, true);
    }
    if (json['inventoryLocations'] is Map && _inventoryGenerals.isEmpty) {
      _migrateOldMapToV5(json['inventoryLocations'] as Map, false);
    }
    if (json['locations'] is Map && _storageGenerals.isEmpty && _inventoryGenerals.isEmpty) {
      _migrateOldMapToV5(json['locations'] as Map, true);
      _migrateOldMapToV5(json['locations'] as Map, false);
    }
  }

  void _migrateOldMapToV5(Map oldMap, bool isStorage) {
    int gCounter = isStorage ? _storageGenerals.length + 1 : _inventoryGenerals.length + 1;
    int sCounter = isStorage ? _storageSpecifics.length + 1 : _inventorySpecifics.length + 1;
    String newGenId() {
      final prefix = isStorage ? 'stogen_' : 'invgen_';
      return '${prefix}${gCounter.toString().padLeft(3, '0')}';
    }
    String newSpecId() {
      final prefix = isStorage ? 'stospec_' : 'invspec_';
      return '${prefix}${sCounter.toString().padLeft(3, '0')}';
    }

    oldMap.forEach((genName, specs) {
      final genId = newGenId();
      gCounter++;
      final genMap = {'id': genId, 'name': genName.toString()};
      if (isStorage) {
        _storageGenerals.add(genMap);
      } else {
        _inventoryGenerals.add(genMap);
      }
      // sentinel empty
      final sentinelId = newSpecId();
      sCounter++;
      final sentinel = {'id': sentinelId, 'generalId': genId, 'name': ''};
      if (isStorage) {
        _storageSpecifics.add(sentinel);
      } else {
        _inventorySpecifics.add(sentinel);
      }
      if (specs is List) {
        for (var s in specs) {
          final specName = s.toString();
          if (specName.trim().isEmpty) continue;
          final specId = newSpecId();
          sCounter++;
          final specMap = {'id': specId, 'generalId': genId, 'name': specName};
          if (isStorage) {
            _storageSpecifics.add(specMap);
          } else {
            _inventorySpecifics.add(specMap);
          }
        }
      }
    });
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json is Map) _parseJson(Map<String, dynamic>.from(json));
      } else {
        await _loadFromAssetAndSave();
      }
    } catch (e) {
      try {
        await _loadFromAssetAndSave();
      } catch (_) {}
    }
    _loaded = true;
  }

  Future<void> save() async {
    try {
      final file = await _getFile();
      final json = {
        'storageGenerals': _storageGenerals,
        'storageSpecifics': _storageSpecifics,
        'storageItems': _storageItems,
        'inventoryGenerals': _inventoryGenerals,
        'inventorySpecifics': _inventorySpecifics,
        'inventoryItems': _inventoryItems,
        'poiItems': _poiItems,
        'version': 5,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {}
  }

  bool isDuplicateStorageTier1(String name) {
    final t = name.trim().toLowerCase();
    return _storageGenerals.any((g) => (g['name']?.toString().toLowerCase() ?? '') == t);
  }
  bool isDuplicateInventoryTier1(String name) {
    final t = name.trim().toLowerCase();
    return _inventoryGenerals.any((g) => (g['name']?.toString().toLowerCase() ?? '') == t);
  }
  bool isDuplicateStorageTier2(String parent, String name) {
    final t = name.trim().toLowerCase();
    final gen = _storageGenerals.firstWhere((g) => g['name']?.toString().toLowerCase() == parent.trim().toLowerCase(), orElse: () => {});
    if (gen.isEmpty) return false;
    final genId = gen['id']?.toString() ?? '';
    return _storageSpecifics.any((s) => s['generalId'] == genId && (s['name']?.toString().toLowerCase() ?? '') == t);
  }
  bool isDuplicateInventoryTier2(String parent, String name) {
    final t = name.trim().toLowerCase();
    final gen = _inventoryGenerals.firstWhere((g) => g['name']?.toString().toLowerCase() == parent.trim().toLowerCase(), orElse: () => {});
    if (gen.isEmpty) return false;
    final genId = gen['id']?.toString() ?? '';
    return _inventorySpecifics.any((s) => s['generalId'] == genId && (s['name']?.toString().toLowerCase() ?? '') == t);
  }

  Future<void> addStorageTier1(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateStorageTier1(t)) return;
    final id = 'stogen_${(_storageGenerals.length + 1).toString().padLeft(3, '0')}';
    _storageGenerals.add({'id': id, 'name': t});
    final sentinelId = 'stospec_${(_storageSpecifics.length + 1).toString().padLeft(3, '0')}';
    _storageSpecifics.add({'id': sentinelId, 'generalId': id, 'name': ''});
    await save();
  }
  Future<void> addInventoryTier1(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateInventoryTier1(t)) return;
    final id = 'invgen_${(_inventoryGenerals.length + 1).toString().padLeft(3, '0')}';
    _inventoryGenerals.add({'id': id, 'name': t});
    final sentinelId = 'invspec_${(_inventorySpecifics.length + 1).toString().padLeft(3, '0')}';
    _inventorySpecifics.add({'id': sentinelId, 'generalId': id, 'name': ''});
    await save();
  }
  Future<void> addStorageTier2(String parent, String name) async {
    final p = parent.trim(); final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateStorageTier2(p, t)) return;
    final gen = _storageGenerals.firstWhere((g) => g['name'] == p, orElse: () => {});
    if (gen.isEmpty) return;
    final genId = gen['id']?.toString() ?? '';
    final specId = 'stospec_${(_storageSpecifics.length + 1).toString().padLeft(3, '0')}';
    _storageSpecifics.add({'id': specId, 'generalId': genId, 'name': t});
    await save();
  }
  Future<void> addInventoryTier2(String parent, String name) async {
    final p = parent.trim(); final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateInventoryTier2(p, t)) return;
    final gen = _inventoryGenerals.firstWhere((g) => g['name'] == p, orElse: () => {});
    if (gen.isEmpty) return;
    final genId = gen['id']?.toString() ?? '';
    final specId = 'invspec_${(_inventorySpecifics.length + 1).toString().padLeft(3, '0')}';
    _inventorySpecifics.add({'id': specId, 'generalId': genId, 'name': t});
    await save();
  }
  Future<void> addStorageItem(Map<String, dynamic> item) async {
    _storageItems.add(item);
    await save();
  }
  Future<void> addInventoryItem(Map<String, dynamic> item) async {
    _inventoryItems.add(item);
    await save();
  }

  Future<void> updateStorageItem(int index, Map<String, dynamic> item) async {
    if (index >=0 && index < _storageItems.length) {
      _storageItems[index] = item;
      await save();
    }
  }
  Future<void> deleteStorageItem(int index) async {
    if (index >=0 && index < _storageItems.length) {
      _storageItems.removeAt(index);
      await save();
    }
  }
  Future<void> updateInventoryItem(int index, Map<String, dynamic> item) async {
    if (index >=0 && index < _inventoryItems.length) {
      _inventoryItems[index] = item;
      await save();
    }
  }
  Future<void> deleteInventoryItem(int index) async {
    if (index >=0 && index < _inventoryItems.length) {
      _inventoryItems.removeAt(index);
      await save();
    }
  }
  Future<void> addPoiItem(Map<String, dynamic> item) async {
    _poiItems.add(item);
    await save();
  }
  Future<void> updatePoiItem(int index, Map<String, dynamic> item) async {
    if (index >=0 && index < _poiItems.length) {
      _poiItems[index] = item;
      await save();
    }
  }
  Future<void> deletePoiItem(int index) async {
    if (index >=0 && index < _poiItems.length) {
      _poiItems.removeAt(index);
      await save();
    }
  }
}
