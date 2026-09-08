
import 'package:flutter/material.dart';
import '../location_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class InventoryEditScreen extends StatefulWidget {
  final int itemIndex;
  const InventoryEditScreen({super.key, required this.itemIndex});
  @override State<InventoryEditScreen> createState() => _InventoryEditScreenState();
}

class _InventoryEditScreenState extends State<InventoryEditScreen> {
  final tier1Controller = TextEditingController();
  final tier2Controller = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  File? photoFile; String? existingPhotoPath;
  final _picker = ImagePicker();
  final LocationRepository _repo = LocationRepository();

  @override
  void initState() {
    super.initState();
    _repo.load().then((_) => setState(() {}));
    final item = _repo.inventoryItems[widget.itemIndex];
    tier1Controller.text = item['tier1'] ?? item['place'] ?? '';
    tier2Controller.text = item['tier2'] ?? item['bin'] ?? '';
    itemNameController.text = item['name'] ?? '';
    notesController.text = item['notes'] ?? '';
    existingPhotoPath = item['photo'];
  }

  Future<void> openTier1Picker() async {
    final r = await showDialog<String>(context: context, builder: (c) => _TierSheet(title:'Location (General)', existing: _repo.inventoryTier1List));
    if (r != null) setState(()=> tier1Controller.text = r);
  }
  Future<void> openTier2Picker() async {
    if (tier1Controller.text.trim().isEmpty) return;
    final r = await showDialog<String>(context: context, builder: (c) => _TierSheet(title:'Location (Specific)', existing: _repo.inventoryTier2For(tier1Controller.text.trim()), allowBlank:true));
    if (r != null) setState(()=> tier2Controller.text = r);
  }
  Future<void> openNotesEditor() async {
    final temp = TextEditingController(text: notesController.text);
    final result = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: Text('Notes'), content: TextField(controller: temp, minLines:4, maxLines:8), actions:[TextButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c, temp.text), child: Text('Save'))]));
    if (result != null) setState(()=> notesController.text = result);
  }
  Future<void> handleReplacePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Wrap(children:[ListTile(leading: Icon(Icons.photo_camera), title: Text('Take Photo'), onTap: ()=>Navigator.pop(c, ImageSource.camera)), ListTile(leading: Icon(Icons.photo_library), title: Text('Gallery'), onTap: ()=>Navigator.pop(c, ImageSource.gallery))])) );
    if (src == null) return;
    final XFile? img = await _picker.pickImage(source: src, imageQuality:80, maxWidth:1024);
    if (img != null) setState(()=> photoFile = File(img.path));
  }
  Future<void> handleSave() async {
    final updated = {
      'name': itemNameController.text.trim(),
      'tier1': tier1Controller.text.trim(),
      'tier2': tier2Controller.text.trim(),
      'place': tier1Controller.text.trim(),
      'bin': tier2Controller.text.trim(),
      'notes': notesController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath,
    };
    await _repo.updateInventoryItem(widget.itemIndex, updated);
    if (mounted) Navigator.pop(context);
  }
  Future<void> handleDelete() async {
    final ok = await showDialog<bool>(context: context, builder: (c)=> AlertDialog(title: Text('Delete?'), content: Text('Delete this inventory item?'), actions:[TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: Text('Delete'))]));
    if (ok == true) { await _repo.deleteInventoryItem(widget.itemIndex); if (mounted) Navigator.pop(context); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Inventory'), actions:[IconButton(icon: Icon(Icons.delete), onPressed: handleDelete)]),
      body: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(children:[
        TextField(controller: itemNameController, decoration: InputDecoration(labelText:'Item Name', border: OutlineInputBorder())),
        SizedBox(height:12),
        Row(children:[Expanded(child: InkWell(onTap: openTier1Picker, child: Container(height:44, padding: EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8)), child: Align(alignment: Alignment.centerLeft, child: Text(tier1Controller.text.isEmpty?'General':tier1Controller.text))))), SizedBox(width:8), Expanded(child: InkWell(onTap: openTier2Picker, child: Container(height:44, padding: EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8)), child: Align(alignment: Alignment.centerLeft, child: Text(tier2Controller.text.isEmpty?'Specific':tier2Controller.text)))))]),
        SizedBox(height:12),
        TextField(controller: notesController, readOnly:true, onTap: openNotesEditor, decoration: InputDecoration(labelText:'Notes', border: OutlineInputBorder(), suffixIcon: Icon(Icons.edit))),
        SizedBox(height:12),
        if (photoFile != null) Image.file(photoFile!, height:160) else if (existingPhotoPath != null && File(existingPhotoPath!).existsSync()) Image.file(File(existingPhotoPath!), height:160) else Container(height:100, color: Colors.grey.shade200, child: Center(child: Icon(Icons.photo))),
        SizedBox(height:8),
        OutlinedButton.icon(onPressed: handleReplacePhoto, icon: Icon(Icons.photo), label: Text('Replace Photo')),
        SizedBox(height:20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: handleSave, child: Text('Save'))),
      ])),
    );
  }
}

class _TierSheet extends StatelessWidget {
  final String title; final List<String> existing; final bool allowBlank;
  const _TierSheet({required this.title, required this.existing, this.allowBlank=false});
  @override Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children:[
      Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height:8),
      if (allowBlank) ListTile(title: Text('(None)'), onTap: ()=>Navigator.pop(context,'')),
      ...existing.map((e)=> ListTile(title: Text(e), onTap: ()=>Navigator.pop(context,e))),
      Divider(),
      ListTile(title: Text('Cancel'), onTap: ()=>Navigator.pop(context)),
    ]));
  }
}
