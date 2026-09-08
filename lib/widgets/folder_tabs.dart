import 'package:flutter/material.dart';

class FolderTabs extends StatelessWidget {
  final String selected;
  final Function(String) onSelected;
  const FolderTabs({super.key, required this.selected, required this.onSelected});

  final folders = const ['All', 'Attic', 'Basement', 'Garage', 'Bin A', 'Bin B'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: folders.length,
        itemBuilder: (context, i) {
          final f = folders[i];
          final isSel = f == selected;
          return Padding(
            padding: const EdgeInsets.all(6),
            child: ChoiceChip(
              label: Text(f),
              selected: isSel,
              onSelected: (_) => onSelected(f),
            ),
          );
        },
      ),
    );
  }
}