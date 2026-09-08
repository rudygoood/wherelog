class StorageFolder {
  final String name;
  final String icon;
  StorageFolder({required this.name, required this.icon});
}

class StorageItem {
  String name;
  String folder;
  String note;
  StorageItem({required this.name, required this.folder, this.note = ''});
}

class PoiItem {
  String name;
  double lat;
  double lng;
  PoiItem({required this.name, required this.lat, required this.lng});
}

class InventoryItem {
  String name;
  String location;
  InventoryItem({required this.name, required this.location});
}