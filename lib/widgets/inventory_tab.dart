import 'package:flutter/material.dart';
import '../models/models.dart';

class InventoryTab extends StatelessWidget {
  final String folder;
  const InventoryTab({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    final items = [
      InventoryItem(name: 'Light Bulbs', location: 'Garage Shelf'),
      InventoryItem(name: 'Batteries', location: 'Bin A'),
    ];

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: const Icon(Icons.check_box),
          title: Text(items[i].name),
          subtitle: Text(items[i].location),
        );
      },
    );
  }
}