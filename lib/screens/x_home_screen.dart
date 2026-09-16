import 'package:flutter/material.dart';
import '../widgets/folder_tabs.dart';
import '../widgets/storage_tab.dart';
import '../widgets/poi_tab.dart';
import '../widgets/inventory_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedFolder = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhereLog'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Storage', icon: Icon(Icons.storage)),
            Tab(text: 'Places', icon: Icon(Icons.place)),
            Tab(text: 'Inventory', icon: Icon(Icons.inventory)),
          ],
        ),
      ),
      body: Column(
        children: [
          FolderTabs(
            selected: selectedFolder,
            onSelected: (f) => setState(() => selectedFolder = f),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StorageTab(folder: selectedFolder),
                const PoiTab(),
                InventoryTab(folder: selectedFolder),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}