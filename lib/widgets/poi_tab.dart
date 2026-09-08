import 'package:flutter/material.dart';
import '../models/models.dart';

class PoiTab extends StatelessWidget {
  const PoiTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      PoiItem(name: 'My Parking Spot', lat: 0, lng: 0),
      PoiItem(name: 'Hidden Key', lat: 0, lng: 0),
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue[50],
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 18),
              const SizedBox(width: 8),
              const Text('Refresh · now'),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Update'))
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              return ListTile(
                leading: const Icon(Icons.place),
                title: Text(items[i].name),
                subtitle: const Text('Tap to navigate'),
              );
            },
          ),
        ),
      ],
    );
  }
}