import 'dart:convert';
import 'dart:io';

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
}