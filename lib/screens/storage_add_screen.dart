
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/app_header.dart';
import '../wherelog_repository.dart';
import '../widgets/notes_section.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageAddScreen extends StatefulWidget {
  const StorageAddScreen({super.key});
  @override
  State<StorageAddScreen> createState() => _StorageAddScreenState();
}

class _StorageAddScreenState extends State<StorageAddScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  List<String> addedItemsLog = [];
  bool _notesExpanded = false;
  bool _photoDetailsExpanded = true;
  File? photoFile;
  final _picker = ImagePicker();
  final _repo = WhereLogRepository();

  void showCenterNotice(String msg) {
    showDialog(context: context, builder: (c) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)), child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 48, color: Colors.green.shade600), const SizedBox(height: 12), Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(c), style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))), child: const Text('OK')))]))));
    if (msg.startsWith('Added:')) {
      Future.delayed(const Duration(milliseconds: 1300), () { if (mounted) { try { if (Navigator.canPop(context)) Navigator.pop(context); } catch (_) {} } });
    }
  }

  String get fullLocationDisplay {
    final g = generalController.text.trim();
    final s = specificController.text.trim();
    if (g.isNotEmpty && s.isNotEmpty) return '$g / $s';
    return g.isNotEmpty ? g : s;
  }

  @override
  void initState() {
    super.initState();
    _repo.load().then((_) => setState(() {}));
    generalController.addListener(() => setState(() {}));
    specificController.addListener(() => setState(() {}));
    generalFocus.addListener(() => setState(() {}));
    specificFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    generalFocus.dispose(); specificFocus.dispose();
    generalController.dispose(); specificController.dispose();
    itemNameController.dispose(); notesController.dispose(); qtyController.dispose(); valueController.dispose();
    super.dispose();
  }

  Future<void> handleAdd() async {
    if (itemNameController.text.trim().isEmpty) { showCenterNotice('Enter Stored Item'); return; }
    if (generalController.text.trim().isEmpty) { showCenterNotice('Pick General'); return; }
    final gName = generalController.text.trim();
    final sName = specificController.text.trim();
    final generalId = _repo.generalIdForName(gName);
    if (generalId.isEmpty) { showCenterNotice('General not found'); return; }
    String specificId = '';
    if (sName.isNotEmpty) {
      final spec = _repo.storageSpecifics.firstWhere((s) => s['generalId']==generalId && (s['name']??'')==sName, orElse: ()=>{});
      specificId = spec['id']?.toString() ?? '';
      if (specificId.isEmpty) {
        await _repo.addStorageSpecific(generalId, sName);
        final spec2 = _repo.storageSpecifics.firstWhere((s) => s['generalId']==generalId && (s['name']??'')==sName, orElse: ()=>{});
        specificId = spec2['id']?.toString() ?? '';
      }
    } else {
      final sentinel = _repo.storageSpecifics.firstWhere((s) => s['generalId']==generalId && (s['name']?.toString()??'').isEmpty, orElse: ()=>{});
      specificId = sentinel['id']?.toString() ?? '';
    }
    if (specificId.isEmpty) { showCenterNotice('Specific not found'); return; }
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());
    final item = {
      'name': itemNameController.text.trim(),
      'generalId': generalId,
      'specificId': specificId,
      'qty': qty,
      'value': valueAmt,
      'valueAmount': valueText,
      'notes': notesController.text.trim(),
      'photo': photoFile?.path,
      'photoPath': photoFile?.path,
    };
    await _repo.addStorageItem(item);
    setState(() { addedItemsLog.add('${item['name']} x$qty @ $fullLocationDisplay${photoFile!=null?' 📷':''}'); });
    itemNameController.clear();
    showCenterNotice('Added: ${item['name']}');
  }

  Future<void> openPhotoSheet() async {
    showModalBottomSheet(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: Icon(Icons.camera_alt), title: Text('Take Photo'), onTap: () async { Navigator.pop(c); final f = await _picker.pickImage(source: ImageSource.camera); if (f!=null) setState(()=>photoFile=File(f.path)); }),
      ListTile(leading: Icon(Icons.photo_library), title: Text('Choose from Gallery'), onTap: () async { Navigator.pop(c); final f = await _picker.pickImage(source: ImageSource.gallery); if (f!=null) setState(()=>photoFile=File(f.path)); }),
      if (photoFile!=null) ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Remove Photo', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(c); setState(()=>photoFile=null); }),
    ])));
  }
  void openFullPhotoViewer(File f) { showDialog(context: context, builder: (c)=>Dialog(child: Image.file(f))); }
  Widget _buildDistinctPlaceholder() => Center(child: Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textDisabled));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Add Storage'),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16,8,16,16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RequiredSection(source: RequiredSectionSource.storage, generalController: generalController, specificController: specificController, itemNameController: itemNameController, generalFocus: generalFocus, specificFocus: specificFocus, repo: _repo, itemHint: 'Stored Item'),
        const SizedBox(height:14),
        PhotoDetailsSection(isExpanded: _photoDetailsExpanded, onToggle: ()=>setState(()=>_photoDetailsExpanded=!_photoDetailsExpanded), variant: PhotoDetailsVariant.storage, storageKey: 'photoDetailsExpanded_storage_add', photoFile: photoFile, onPhotoAdd: openPhotoSheet, onPhotoView: ()=>photoFile!=null?openFullPhotoViewer(photoFile!):null, onPhotoEdit: openPhotoSheet, valueController: valueController, qtyController: qtyController),
        const SizedBox(height:14),
        NotesSection(storageKey: 'notesExpanded_storage_add', controller: notesController, isExpanded: _notesExpanded, onToggle: ()=>setState(()=>_notesExpanded=!_notesExpanded)),
        const SizedBox(height:16),
        Row(children: [const Expanded(child: Text('General / Specific does not reset so you can add multiple items, but you can change it when needed.', style: TextStyle(fontSize: 11, color: AppColors.buttonBg, fontWeight: FontWeight.w600, height: 1.3))), const SizedBox(width:12), SizedBox(height:36, child: ElevatedButton(onPressed: handleAdd, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white, padding: EdgeInsets.symmetric(horizontal:16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))), child: const Text('+ Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))]),
        if (addedItemsLog.isNotEmpty) ...[const SizedBox(height:18), const Text('ADDED THIS SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.buttonBg)), const SizedBox(height:6), ...addedItemsLog.map((l)=>Padding(padding: const EdgeInsets.only(bottom:3), child: Text('• $l', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.buttonBg))))],
      ])),
    );
  }
}
