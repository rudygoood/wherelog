import 'package:flutter/material.dart';
import '../models/models.dart';

class StorageTab extends StatelessWidget {
  final String folder;
  const StorageTab({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    final items = [
      StorageItem(name: 'Christmas Lights', folder: 'Attic'),
      StorageItem(name: 'Camping Tent', folder: 'Garage'),
      StorageItem(name: 'Old Photos', folder: 'Basement'),
    ].where((e) => folder == 'All' || e.folder == folder).toList();

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: const Icon(Icons.inventory_2),
          title: Text(items[i].name),
          subtitle: Text(items[i].folder),
        );
      },
    );
  }
}