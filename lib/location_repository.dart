import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Repository with SEPARATE trees for Storage and Inventory
/// Test data now lives in assets/data/wherelog_data.json, NOT hardcoded in Dart
/// On first run, asset JSON is copied to app documents wherelog_data.json
class LocationRepository {
  static final LocationRepository _instance = LocationRepository._internal();
  factory LocationRepository() => _instance;
  LocationRepository._internal();

  Map<String, List<String>> _storageData = {};
  Map<String, List<String>> _inventoryData = {};
  List<Map<String, dynamic>> _storageItems = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _loaded = false;

  Map<String, List<String>> get storageData => _storageData;
  Map<String, List<String>> get inventoryData => _inventoryData;
  List<String> get storageTier1List => _storageData.keys.toList()..sort();
  List<String> get inventoryTier1List => _inventoryData.keys.toList()..sort();
  List<String> storageTier2For(String tier1) => _storageData[tier1] ?? [];
  List<String> inventoryTier2For(String tier1) => _inventoryData[tier1] ?? [];
  List<Map<String, dynamic>> get storageItems => _storageItems;
  List<Map<String, dynamic>> get inventoryItems => _inventoryItems;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/wherelog_data.json');
  }

  Future<void> _loadFromAssetAndSave() async {
    try {
      final assetString = await rootBundle.loadString('assets/data/wherelog_data.json');
      final json = jsonDecode(assetString);
      if (json is Map) {
        _parseJson(json);
      }
      await save();
    } catch (e) {
      // Asset not found - leave empty, will save empty on first add
      _storageData = {};
      _inventoryData = {};
    }
  }

  void _parseJson(Map json) {
    if (json['storageLocations'] is Map) {
      final Map<String, dynamic> locMap = Map<String, dynamic>.from(json['storageLocations']);
      final Map<String, List<String>> parsed = {};
      locMap.forEach((k, v) { if (v is List) parsed[k] = v.map((e) => e.toString()).toList(); });
      _storageData = parsed;
    }
    if (json['inventoryLocations'] is Map) {
      final Map<String, dynamic> locMap = Map<String, dynamic>.from(json['inventoryLocations']);
      final Map<String, List<String>> parsed = {};
      locMap.forEach((k, v) { if (v is List) parsed[k] = v.map((e) => e.toString()).toList(); });
      _inventoryData = parsed;
    }
    // Backward compat old single key
    if (json['locations'] is Map && json['storageLocations'] == null) {
      final Map<String, dynamic> locMap = Map<String, dynamic>.from(json['locations']);
      final Map<String, List<String>> parsed = {};
      locMap.forEach((k, v) { if (v is List) parsed[k] = v.map((e) => e.toString()).toList(); });
      _storageData = Map<String, List<String>>.from(parsed);
      _inventoryData = Map<String, List<String>>.from(parsed);
    }
    if (json['storageItems'] is List) {
      _storageItems = (json['storageItems'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (json['inventoryItems'] is List) {
      _inventoryItems = (json['inventoryItems'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        if (json is Map) _parseJson(json);
      } else {
        // First run - prime from asset JSON
        await _loadFromAssetAndSave();
      }
    } catch (e) {
      // If file read fails, try asset
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
        'storageLocations': _storageData,
        'inventoryLocations': _inventoryData,
        'storageItems': _storageItems,
        'inventoryItems': _inventoryItems,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(json));
    } catch (e) {}
  }

  bool isDuplicateStorageTier1(String name) {
    final t = name.trim().toLowerCase();
    return _storageData.keys.any((k) => k.toLowerCase() == t);
  }
  bool isDuplicateInventoryTier1(String name) {
    final t = name.trim().toLowerCase();
    return _inventoryData.keys.any((k) => k.toLowerCase() == t);
  }
  bool isDuplicateStorageTier2(String parent, String name) {
    final t = name.trim().toLowerCase();
    return (_storageData[parent] ?? []).any((e) => e.toLowerCase() == t);
  }
  bool isDuplicateInventoryTier2(String parent, String name) {
    final t = name.trim().toLowerCase();
    return (_inventoryData[parent] ?? []).any((e) => e.toLowerCase() == t);
  }

  Future<void> addStorageTier1(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateStorageTier1(t)) return;
    _storageData[t] = [];
    await save();
  }
  Future<void> addInventoryTier1(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateInventoryTier1(t)) return;
    _inventoryData[t] = [];
    await save();
  }
  Future<void> addStorageTier2(String parent, String name) async {
    final p = parent.trim(); final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateStorageTier2(p, t)) return;
    _storageData[p] = [...(_storageData[p] ?? []), t];
    await save();
  }
  Future<void> addInventoryTier2(String parent, String name) async {
    final p = parent.trim(); final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateInventoryTier2(p, t)) return;
    _inventoryData[p] = [...(_inventoryData[p] ?? []), t];
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
}
