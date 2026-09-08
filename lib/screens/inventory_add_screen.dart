import 'package:flutter/material.dart';
import '../location_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class InventoryAddScreen extends StatefulWidget {
  const InventoryAddScreen({super.key});
  @override State<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends State<InventoryAddScreen> {
  final tier1Controller = TextEditingController();
  final tier2Controller = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final serialController = TextEditingController();
  DateTime? acquiredDate;
  String acquiredStatus = 'New'; // New/Used
  File? photoFile;
  final _picker = ImagePicker();
  List<String> addedLog = [];

  final LocationRepository _locationRepo = LocationRepository();
  Map<String, List<String>> get storageTier2ByTier1 => _locationRepo.inventoryData;
  List<String> get storageTier1List => _locationRepo.inventoryTier1List;
  List<String> getTier2ForCurrentTier1() => _locationRepo.inventoryTier2For(tier1Controller.text.trim());
  Future<void> addTier1(String name) async {
    final t = name.trim();
    if (t.isEmpty || _locationRepo.isDuplicateInventoryTier1(t)) return;
    await _locationRepo.addInventoryTier1(t);
    setState(() {});
  }

  Future<void> addTier2(String parent, String name) async {
    final p = parent.trim(); final t = name.trim();
    if (p.isEmpty || t.isEmpty || _locationRepo.isDuplicateInventoryTier2(p, t)) return;
    await _locationRepo.addInventoryTier2(p, t);
    setState(() {});
  }

  bool isDuplicateTier1(String name) => _locationRepo.isDuplicateInventoryTier1(name);
  bool isDuplicateTier2(String parent, String name) => _locationRepo.isDuplicateInventoryTier2(parent, name);

  String get concatenatedLocation {
    final t1 = tier1Controller.text.trim(); final t2 = tier2Controller.text.trim();
    if (t1.isNotEmpty && t2.isNotEmpty) return '$t1 / $t2';
    return t1.isNotEmpty ? t1 : t2;
  }
  @override void initState() {
    super.initState();
    _locationRepo.load().then((_) => setState(() {}));

    super.initState();
    tier1Controller.addListener(() => setState(() {}));
  }
  Future<void> handleAdd() async {
    if (itemNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Item')));
      return;
    }
    if (tier1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick General location')));
      return;
    }
    final loc = concatenatedLocation.isEmpty ? tier1Controller.text.trim() : concatenatedLocation;
    final item = {
      'name': itemNameController.text.trim(),
      'place': tier1Controller.text.trim(),
      'bin': tier2Controller.text.trim(),
      'tier1': tier1Controller.text.trim(),
      'tier2': tier2Controller.text.trim(),
      'location': loc,
      'notes': notesController.text.trim(),
      'serial': serialController.text.trim(),
      'status': acquiredStatus,
      'acquiredDate': acquiredDate?.toIso8601String(),
      'photo': photoFile?.path,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _locationRepo.addInventoryItem(item);
    setState(() {
      addedLog.add('${itemNameController.text.trim()} @ $loc [${acquiredStatus}${serialController.text.isNotEmpty ? ' S/N:${serialController.text.trim()}' : ''}]');
    });
    itemNameController.clear(); notesController.clear(); serialController.clear();
    setState(()=> photoFile = null);
  }
  Future<void> openNotesEditor() async {
    final temp = TextEditingController(text: notesController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: Material(
            borderRadius: BorderRadius.circular(12), color: Colors.white,
            child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children:[
              Row(children:[Text('Edit Notes', style: TextStyle(fontWeight: FontWeight.bold)), Spacer(), IconButton(icon: Icon(Icons.close), onPressed: ()=>Navigator.pop(c))]),
              TextField(controller: temp, autofocus: true, minLines:6, maxLines:12, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              SizedBox(height:12),
              Row(children:[Expanded(child: OutlinedButton(onPressed: ()=>Navigator.pop(c), child: Text('Cancel'))), SizedBox(width:12), Expanded(child: ElevatedButton(onPressed: ()=>Navigator.pop(c, temp.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white), child: Text('Save')))]),
            ])),
          ),
        ),
      ),
    );
    if (result != null) setState(()=> notesController.text = result);
  }
  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: acquiredDate ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(()=> acquiredDate = picked);
  }
  Future<void> openTier1Picker() async {
    final r = await showDialog<String>(
      context: context,
      builder: (c) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: _InvTierPickerSheet(title: 'Location (General)', existing: storageTier1List, hint: 'Search...'),
          ),
        ),
      ),
    );
    if (r != null) setState(()=> tier1Controller.text = r);
  }

  Future<void> openTier2Picker() async {
    if (tier1Controller.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pick General first'))); return; }
    final r = await showDialog<String>(
      context: context,
      builder: (c) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: _InvTierPickerSheet(title: 'Location (Specific)', existing: getTier2ForCurrentTier1(), hint: 'Search...', allowBlank: true),
          ),
        ),
      ),
    );
    if (r != null) setState(()=> tier2Controller.text = r);
  }

  Widget buildDialogField({required String value, required String hint, required VoidCallback onTap, bool enabled=true}) {
    final isEmpty = value.isEmpty;
    return InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(10), child: Container(height: 44, padding: EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(color: enabled ? Colors.white : Colors.grey.shade100, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)), child: Row(children:[Expanded(child: Text(isEmpty?hint:value, style: TextStyle(color: isEmpty?Colors.black38:Colors.black87, fontSize:15, fontWeight: isEmpty?FontWeight.normal:FontWeight.w600), overflow: TextOverflow.ellipsis)), Icon(Icons.more_horiz, size:20, color: Colors.black54)])));
  }
  Widget buildPhotoBox() {
    return InkWell(onTap: () async {
      final src = await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Wrap(children:[ListTile(leading: Icon(Icons.photo_camera), title: Text('Take Photo'), onTap: ()=>Navigator.pop(c, ImageSource.camera)), ListTile(leading: Icon(Icons.photo_library), title: Text('Choose from Gallery'), onTap: ()=>Navigator.pop(c, ImageSource.gallery))])) );
      if (src != null) { final XFile? img = await _picker.pickImage(source: src, imageQuality:80, maxWidth:1024); if (img != null) setState(()=> photoFile = File(img.path)); }
    }, child: Container(width: double.infinity, height: 140, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)), child: photoFile == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.add_a_photo_outlined, size:32, color: Colors.black38), SizedBox(height:6), Text('Add Photo (optional)', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600))]) : ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.file(photoFile!, width: double.infinity, height: 140, fit: BoxFit.cover))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F3EE),
      appBar: AppBar(backgroundColor: Color(0xFFF5F3EE), elevation:0, leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.black87), onPressed: ()=>Navigator.pop(context)), title: RichText(text: TextSpan(style: TextStyle(fontSize:22, fontWeight: FontWeight.w900), children:[TextSpan(text:'Where', style:TextStyle(color:Colors.black87)), TextSpan(text:'Log', style:TextStyle(color:Color(0xFFB91C1C))), TextSpan(text:' - Inventory Add', style: TextStyle(color:Colors.black54, fontSize:14, fontWeight:FontWeight.w600))]))),
      body: SingleChildScrollView(padding: EdgeInsets.fromLTRB(16,8,16,16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Container(width: double.infinity, padding: EdgeInsets.symmetric(horizontal:10, vertical:8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: Text('Location: ${concatenatedLocation.isEmpty ? '—' : concatenatedLocation}', style: TextStyle(fontFamily:'monospace', fontWeight:FontWeight.bold, fontSize:13))),
        SizedBox(height:10),
        Row(children:[Expanded(child: buildDialogField(value: tier1Controller.text, hint:'General', onTap: openTier1Picker)), SizedBox(width:10), Expanded(child: buildDialogField(value: tier2Controller.text, hint:'Specific', onTap: openTier2Picker, enabled: tier1Controller.text.isNotEmpty))]),
        SizedBox(height:18),
        Text('PHOTO', style: TextStyle(fontWeight:FontWeight.bold, fontSize:12)), SizedBox(height:4), buildPhotoBox(),
        SizedBox(height:18),
        Text('ITEM', style: TextStyle(fontWeight:FontWeight.bold, fontSize:12)), SizedBox(height:4),
        TextField(controller: itemNameController, decoration: InputDecoration(hintText:'Item Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled:true, fillColor:Colors.white)),
        SizedBox(height:14),
        Row(children:[
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text('ACQUIRED DATE', style: TextStyle(fontWeight:FontWeight.bold, fontSize:12)), SizedBox(height:4), InkWell(onTap: pickDate, child: Container(height:44, padding: EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)), child: Row(children:[Expanded(child: Text(acquiredDate == null ? 'Pick Date' : '${acquiredDate!.month}/${acquiredDate!.day}/${acquiredDate!.year}', style: TextStyle(color: acquiredDate==null?Colors.black38:Colors.black87, fontWeight: FontWeight.w600))), Icon(Icons.calendar_today, size:18, color: Colors.black54)])))])),
          SizedBox(width:10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text('STATUS', style: TextStyle(fontWeight:FontWeight.bold, fontSize:12)), SizedBox(height:4), Container(height:44, padding: EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: acquiredStatus, isExpanded:true, items: ['New','Used'].map((s)=> DropdownMenuItem(value:s, child: Text(s))).toList(), onChanged: (v){ if(v!=null) setState(()=> acquiredStatus = v); })))])),
        ]),
        SizedBox(height:14),
        Text('SERIAL #', style: TextStyle(fontWeight:FontWeight.bold, fontSize:12)), SizedBox(height:4),
        TextField(controller: serialController, decoration: InputDecoration(hintText:'Serial Number (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled:true, fillColor:Colors.white)),
        SizedBox(height:14),
        Row(children:[Text('NOTES', style: TextStyle(fontWeight:FontWeight.bold, fontSize:12)), Spacer(), InkWell(onTap: openNotesEditor, child: Padding(padding: EdgeInsets.symmetric(horizontal:6, vertical:2), child: Row(children:[Icon(Icons.open_in_full, size:14, color: Colors.black54), SizedBox(width:4), Text('Expand', style: TextStyle(fontSize:11, color: Colors.black54, fontWeight: FontWeight.w600))])))]),
        SizedBox(height:4),
        TextField(controller: notesController, minLines:3, maxLines:3, decoration: InputDecoration(hintText:'Additional details (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled:true, fillColor:Colors.white)),
        SizedBox(height:16),
        Row(children:[Expanded(child: Text('Location does not reset so you can add multiple items, but you can change it when needed.', style: TextStyle(fontSize:11, fontWeight: FontWeight.w600))), SizedBox(width:12), ElevatedButton(onPressed: handleAdd, style: ElevatedButton.styleFrom(backgroundColor:Colors.black87, foregroundColor:Colors.white), child: Text('+ Add Item'))]),
        if (addedLog.isNotEmpty) ...[SizedBox(height:18), Text('ADDED THIS SESSION', style: TextStyle(fontWeight:FontWeight.bold, fontSize:11)), ...addedLog.map((l)=> Padding(padding: EdgeInsets.only(bottom:3), child: Text('• $l', style: TextStyle(fontFamily:'monospace', fontSize:12))))],
      ])),
    );
  }
}

class _InvTierPickerSheet extends StatelessWidget {
  final String title; final List<String> existing; final String hint; final bool allowBlank;
  const _InvTierPickerSheet({required this.title, required this.existing, required this.hint, this.allowBlank=false});
  @override Widget build(BuildContext context) {
    return DraggableScrollableSheet(initialChildSize:0.85, minChildSize:0.5, maxChildSize:0.95, expand:false, builder: (c, scroll)=> Padding(padding: EdgeInsets.all(16), child: Column(children:[
      Row(children:[Text(title, style: TextStyle(fontWeight:FontWeight.bold, fontSize:16)), Spacer(), IconButton(icon: Icon(Icons.close), onPressed: ()=>Navigator.pop(context))]),
      TextField(decoration: InputDecoration(hintText: hint, prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      SizedBox(height:8),
      if (allowBlank) ListTile(title: Text('(None)'), onTap: ()=>Navigator.pop(context, '')),
      Expanded(child: ListView.builder(controller: scroll, itemCount: existing.length, itemBuilder: (c,i){ final e=existing[i]; return ListTile(title: Text(e), onTap: ()=>Navigator.pop(context, e)); })),
    ])));
  }
}
