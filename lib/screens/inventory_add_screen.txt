
import 'package:flutter/material.dart';
import '../location_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class InventoryAddScreen extends StatefulWidget {
  const InventoryAddScreen({super.key});
  @override
  State<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends State<InventoryAddScreen> {
  final tier1Controller = TextEditingController();
  final tier2Controller = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final serialController = TextEditingController();
  final valueController = TextEditingController();
  DateTime? acquisitionDate;
  DateTime? acquiredDate;
  final tier1Focus = FocusNode();
  final tier2Focus = FocusNode();
  List<String> addedItemsLog = [];
  File? photoFile;
  final _picker = ImagePicker();
  final _locationRepo = LocationRepository();

  List<String> get inventoryTier1List => _locationRepo.inventoryTier1List;
  List<String> getTier2ForCurrentTier1() {
    final p = tier1Controller.text.trim();
    if (p.isEmpty) return [];
    return _locationRepo.inventoryTier2For(p);
  }
  bool isDuplicateTier1(String name) => _locationRepo.isDuplicateInventoryTier1(name);
  bool isDuplicateTier2(String parent, String name) => _locationRepo.isDuplicateInventoryTier2(parent, name);

  String? findSimilarTier2(String parent, String newName) {
    final list = _locationRepo.inventoryData[parent] ?? [];
    final nl = newName.toLowerCase();
    for (final ex in list) {
      if (ex.toLowerCase().contains(nl) || nl.contains(ex.toLowerCase())) {
        if (ex.toLowerCase() != nl) return ex;
      }
    }
    return null;
  }

  void showCenterNotice(String msg) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green.shade600),
              const SizedBox(height: 12),
              Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(c),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (msg.startsWith('Added:')) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) {
          try { if (Navigator.canPop(context)) Navigator.pop(context); } catch (_) {}
        }
      });
    }
  }

  String get concatenatedLocation {
    final t1 = tier1Controller.text.trim();
    final t2 = tier2Controller.text.trim();
    if (t1.isNotEmpty && t2.isNotEmpty) return '$t1 / $t2';
    return t1.isNotEmpty ? t1 : t2;
  }

  @override
  void initState() {
    super.initState();
    _locationRepo.load().then((_) => setState(() {}));
    tier1Controller.addListener(() => setState(() {}));
  }

  Future<void> handleAdd() async {
    final addedName = itemNameController.text.trim();
    if (addedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Item Name')));
      return;
    }
    if (tier1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick General Location')));
      return;
    }
    final loc = concatenatedLocation.isEmpty ? tier1Controller.text.trim() : concatenatedLocation;
    final hasPhoto = photoFile != null ? ' [Photo]' : '';
    final serialText = serialController.text.trim();
    final item = {
      'name': addedName,
      'tier1': tier1Controller.text.trim(),
      'tier2': tier2Controller.text.trim(),
      'place': tier1Controller.text.trim(),
      'bin': tier2Controller.text.trim(),
      'location': loc,
      'serial_number': serialText,
      'serial': serialText,
      'acquisition_date': acquiredDate?.toIso8601String(),
      'acquiredDate': acquiredDate?.toIso8601String(),
      'notes': notesController.text.trim(),
      'photo': photoFile?.path,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _locationRepo.addInventoryItem(item);
    setState(() {
      final dateLabel = acquiredDate != null ? ' ${acquiredDate!.month}/${acquiredDate!.day}/${acquiredDate!.year}' : '';
      final serialLabel = serialText.isNotEmpty ? ' S/N:$serialText' : '';
      addedItemsLog.add('$addedName$serialLabel$dateLabel @ $loc$hasPhoto');
    });
    itemNameController.clear();
    notesController.clear();
    serialController.clear();
    setState(() {
      photoFile = null;
      acquiredDate = null;
    });
    showCenterNotice('Added: $addedName @ $loc$hasPhoto');
  }

  Future<void> pickAcquiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: acquiredDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => acquiredDate = picked);
  }

  Future<void> openNotesEditor() async {
    final tempCtrl = TextEditingController(text: notesController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [Text('Edit Notes', style: TextStyle(fontWeight: FontWeight.bold)), Spacer(), IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(c))]),
                TextField(controller: tempCtrl, autofocus: true, minLines: 6, maxLines: 12, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                SizedBox(height: 12),
                Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: Text('Cancel'))), SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, tempCtrl.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white), child: Text('Save')))]),
              ]),
            ),
          ),
        ),
      ),
    );
    if (result != null) setState(() => notesController.text = result);
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
            child: _TierPickerSheet(title: 'Location (General)', existing: inventoryTier1List, hint: 'Search or add...'),
          ),
        ),
      ),
    );
    if (r != null) setState(() => tier1Controller.text = r);
  }

  Future<void> openTier2Picker() async {
    if (tier1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pick General first')));
      return;
    }
    final r = await showDialog<String>(
      context: context,
      builder: (c) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: _TierPickerSheet(title: 'Location (Specific)', existing: getTier2ForCurrentTier1(), hint: 'Search or add...', allowBlank: true),
          ),
        ),
      ),
    );
    if (r != null) setState(() => tier2Controller.text = r);
  }

  Widget buildDialogField({required String value, required String hint, required VoidCallback onTap, bool enabled = true}) {
    final isEmpty = value.isEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: enabled ? Colors.white : Colors.grey.shade100, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [Expanded(child: Text(isEmpty ? hint : value, style: TextStyle(color: isEmpty ? Colors.black38 : Colors.black87, fontSize: 15, fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600), overflow: TextOverflow.ellipsis)), Icon(Icons.more_horiz, size: 20, color: Colors.black54)]),
      ),
    );
  }

  Widget buildPhotoAndSerialDate() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo - square half width
        Expanded(
          child: InkWell(
            onTap: () async {
              final src = await showModalBottomSheet<ImageSource>(
                context: context,
                builder: (c) => SafeArea(child: Wrap(children: [ListTile(leading: Icon(Icons.photo_camera), title: Text('Take Photo'), onTap: () => Navigator.pop(c, ImageSource.camera)), ListTile(leading: Icon(Icons.photo_library), title: Text('Choose from Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery))])) );
              if (src != null) {
                final XFile? img = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1024);
                if (img != null) setState(() => photoFile = File(img.path));
              }
            },
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)),
                child: photoFile == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.black38),
                        SizedBox(height: 4),
                        Text('Add Photo', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600, fontSize: 12)),
                        Text('(optional)', style: TextStyle(color: Colors.black26, fontSize: 10)),
                      ])
                    : ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.file(photoFile!, fit: BoxFit.cover)),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Serial + Date column
        Expanded(
          child: Column(
            children: [
              Align(alignment: Alignment.centerLeft, child: Text('Serial Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              SizedBox(height: 6),
              TextField(
                controller: serialController,
                decoration: InputDecoration(hintText: 'Optional', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white),
              ),
              SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Acquisition Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              SizedBox(height: 6),
              InkWell(
                onTap: pickAcquiredDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(child: Text(acquiredDate == null ? 'Optional' : '${acquiredDate!.month}/${acquiredDate!.day}/${acquiredDate!.year}', style: TextStyle(color: acquiredDate == null ? Colors.black38 : Colors.black87, fontSize: 14, fontWeight: acquiredDate == null ? FontWeight.normal : FontWeight.w600))),
                    Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
                  ]),
                ),
              ),
              SizedBox(height: 8),
              // Status chips New/Used
              Row(children: [
                SizedBox(width: 8),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F3EE),
        elevation: 0,
        title: Text('Add Inventory', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Colors.black),
        actions: [IconButton(icon: Icon(Icons.check, color: Colors.black), onPressed: handleAdd)],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          TextField(controller: itemNameController, decoration: InputDecoration(hintText: 'What are you storing?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white)),
          SizedBox(height: 16),
          buildPhotoAndSerialDate(),
          SizedBox(height: 16),
          Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          buildDialogField(value: tier1Controller.text, hint: 'General (e.g., House, Garage)', onTap: openTier1Picker),
          SizedBox(height: 10),
          buildDialogField(value: tier2Controller.text, hint: 'Specific (e.g., Shelf, Drawer) - Optional', onTap: openTier2Picker, enabled: tier1Controller.text.trim().isNotEmpty),
          SizedBox(height: 16),
          Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          InkWell(onTap: openNotesEditor, borderRadius: BorderRadius.circular(10), child: Container(width: double.infinity, padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)), child: Text(notesController.text.isEmpty ? 'Optional - tap to add' : notesController.text, style: TextStyle(color: notesController.text.isEmpty ? Colors.black38 : Colors.black87)))),
          SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: handleAdd, icon: Icon(Icons.add), label: Text('Add Inventory Item'), style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          if (addedItemsLog.isNotEmpty) ...[
            SizedBox(height: 24),
            Text('Recently Added', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...addedItemsLog.reversed.map((e) => Card(child: ListTile(title: Text(e, style: TextStyle(fontSize: 13))))),
          ],
        ]),
      ),
    );
  }
}

class _TierPickerSheet extends StatefulWidget {
  final String title;
  final List<String> existing;
  final String hint;
  final bool allowBlank;
  const _TierPickerSheet({required this.title, required this.existing, required this.hint, this.allowBlank = false});
  @override State<_TierPickerSheet> createState() => _TierPickerSheetState();
}
class _TierPickerSheetState extends State<_TierPickerSheet> {
  final searchCtrl = TextEditingController();
  late List<String> filtered;
  @override void initState() { super.initState(); filtered = widget.existing; searchCtrl.addListener(() { final q = searchCtrl.text.toLowerCase(); setState(() { filtered = widget.existing.where((e) => e.toLowerCase().contains(q)).toList(); }); }); }
  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Spacer(), IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
        TextField(controller: searchCtrl, decoration: InputDecoration(hintText: widget.hint, prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
        SizedBox(height: 12),
        ConstrainedBox(constraints: BoxConstraints(maxHeight: 300), child: ListView.builder(shrinkWrap: true, itemCount: filtered.length + (widget.allowBlank ? 1 : 0), itemBuilder: (c,i){
          if (widget.allowBlank && i==0) return ListTile(title: Text('(None)', style: TextStyle(color: Colors.black54)), onTap: () => Navigator.pop(context, ''));
          final idx = widget.allowBlank ? i-1 : i;
          final name = filtered[idx];
          return ListTile(title: Text(name), onTap: () => Navigator.pop(context, name));
        })),
        if (searchCtrl.text.trim().isNotEmpty && !widget.existing.map((e)=>e.toLowerCase()).contains(searchCtrl.text.trim().toLowerCase())) ...[
          Divider(),
          ListTile(leading: Icon(Icons.add), title: Text('Add \"${searchCtrl.text.trim()}\"'), onTap: () => Navigator.pop(context, searchCtrl.text.trim())),
        ],
      ]),
    );
  }
}
