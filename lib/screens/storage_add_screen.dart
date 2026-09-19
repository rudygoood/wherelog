import 'package:flutter/material.dart';
import '../widgets/photo_details_section.dart';
import '../location_repository.dart';
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
  // RENAMED: tier1/tier2 -> general/specific (JSON stays v5: storageGenerals/storageSpecifics/specificId)
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
  final _locationRepo = LocationRepository();

  // Backward compat getters map to v5 repo methods


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



  String get fullLocationDisplay {
    final g = generalController.text.trim();
    final s = specificController.text.trim();
    if (g.isNotEmpty && s.isNotEmpty) return '$g / $s';
    return g.isNotEmpty ? g : s;
  }

  // legacy alias for old calls
  String get concatenatedLocation => fullLocationDisplay;

  @override
  void initState() {
    super.initState();
    _locationRepo.load().then((_) => setState(() {}));
    generalController.addListener(() => setState(() {}));
    specificController.addListener(() => setState(() {}));
    generalFocus.addListener(() => setState(() {}));
    specificFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    generalFocus.dispose();
    specificFocus.dispose();
    generalController.dispose();
    specificController.dispose();
    itemNameController.dispose();
    notesController.dispose();
    qtyController.dispose();
    valueController.dispose();
    super.dispose();
  }



  // keep old method names as aliases so no other file breaks
  Future<void> handleAdd() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Stored Item');
      return;
    }
    if (generalController.text.trim().isEmpty) {
      showCenterNotice('Pick General');
      return;
    }
    final loc = fullLocationDisplay.isEmpty ? generalController.text.trim() : fullLocationDisplay;
    final hasPhoto = photoFile != null ? ' 📷' : '';
    final addedName = itemNameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());

    // v5 ID resolution - JSON keys stay stable
    final gName = generalController.text.trim();
    final sName = specificController.text.trim();
    String specificId = '';
    String generalId = '';
    try {
      final gen = _locationRepo.storageGenerals.firstWhere((g) => (g['name']?.toString() ?? '') == gName, orElse: () => {});
      generalId = gen['id']?.toString() ?? '';
      if (sName.isNotEmpty) {
        final spec = _locationRepo.storageSpecifics.firstWhere((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '') == sName, orElse: () => {});
        specificId = spec['id']?.toString() ?? '';
      } else {
        final sentinel = _locationRepo.storageSpecifics.firstWhere((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').isEmpty, orElse: () => {});
        specificId = sentinel['id']?.toString() ?? '';
      }
    } catch (_) {}

    final nowIso = DateTime.now().toIso8601String();
    final item = {
      'name': addedName,
      // v5 stable JSON
      'generalId': generalId,
      'specificId': specificId,
      // denormalized + legacy for backward compat - never change JSON structure again
      'general': gName,
      'specific': sName,
      'tier1': gName,
      'tier2': sName,
      'place': gName,
      'bin': sName,
      'location': loc,
      'qty': qty,
      'quantity': qty,
      'value': valueAmt,
      'valueAmount': valueText,
      'notes': notesController.text.trim(),
      'photo': photoFile?.path,
      'photoPath': photoFile?.path,
      'createdAt': nowIso,
      'modifyDate': nowIso, // NEW
      'updatedAt': nowIso,
    };
    await _locationRepo.addStorageItem(item);
    setState(() {
      addedItemsLog.add('$addedName x$qty @ $loc$hasPhoto');
    });
    itemNameController.clear();
    notesController.clear();
    qtyController.text = '1';
    valueController.clear();
    setState(() => photoFile = null);
    showCenterNotice('Added: $addedName x$qty @ $loc$hasPhoto');
  }

  Future<void> openNotesEditor() async {
    final tempCtrl = TextEditingController(text: notesController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(controller: tempCtrl, minLines: 4, maxLines: 8),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, tempCtrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) setState(() => notesController.text = result);
  }

  Future<void> openPhotoSheet() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Take Photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          if (photoFile != null) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove Photo'), onTap: () => Navigator.pop(c, null)),
        ]),
      ),
    );
    if (src == null && photoFile != null) {
      setState(() => photoFile = null);
      return;
    }
    if (src == null) return;
    final XFile? img = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1024);
    if (img != null) setState(() => photoFile = File(img.path));
  }


  Future<void> openFullPhotoViewer(File file) async {
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.file(file, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.white), tooltip: 'Replace', onPressed: () { Navigator.pop(c); openPhotoSheet(); }),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(c)),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(child: Text('Pinch to zoom — tap ✕ to close', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistinctPlaceholder() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.68, child: Image.asset('assets/icon/app_icon.png', width: 64, height: 64, fit: BoxFit.contain)),
            const SizedBox(height: 6),
            const Text('No Photo', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 11)),
            const Text('Tap to add', style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget buildPhotoBoxSquare() {
    final bool hasPhoto = photoFile != null;
    return InkWell(
      onTap: () {
        if (hasPhoto) {
          openFullPhotoViewer(photoFile!);
        } else {
          openPhotoSheet();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black38), borderRadius: BorderRadius.circular(10)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: Image.file(photoFile!, fit: BoxFit.contain)),
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.zoom_in, size: 11, color: Colors.white), SizedBox(width: 2), Text('View', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: InkWell(
                        onTap: openPhotoSheet,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.black12)),
                          child: const Icon(Icons.edit, size: 12, color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                )
              : _buildDistinctPlaceholder(),
        ),
      ),
    );
  }

  Widget buildPhotoBox() {
    return InkWell(
      onTap: openPhotoSheet,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
        child: photoFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.black38),
                  SizedBox(height: 6),
                  Text('Add Photo (optional)', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Tap to take or choose', style: TextStyle(color: Colors.black26, fontSize: 11)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(photoFile!, width: double.infinity, height: 110, fit: BoxFit.cover),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F3EE),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            children: [
              const TextSpan(text: 'Where', style: TextStyle(color: Colors.black87)),
              const TextSpan(text: 'Log', style: TextStyle(color: Color(0xFFB91C1C))),
              const TextSpan(text: ' - Add Storage', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RequiredSection(
              source: RequiredSectionSource.storage,
              generalController: generalController,
              specificController: specificController,
              itemNameController: itemNameController,
              generalFocus: generalFocus,
              specificFocus: specificFocus,
              locationRepo: _locationRepo,
              itemHint: 'Stored Item',
            ),
            const SizedBox(height: 14),
            PhotoDetailsSection(
              isExpanded: _photoDetailsExpanded,
              onToggle: () => setState(() => _photoDetailsExpanded = !_photoDetailsExpanded),
              variant: PhotoDetailsVariant.storage,
              storageKey: 'photoDetailsExpanded_storage_add',
              photoFile: photoFile,
              onPhotoAdd: openPhotoSheet,
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              onPhotoEdit: openPhotoSheet,
              valueController: valueController,
              qtyController: qtyController,
            ),
            const SizedBox(height: 14),
            NotesSection(
              storageKey: 'notesExpanded_storage_add',
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('General / Specific does not reset so you can add multiple items, but you can change it when needed.', style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.3))),
                const SizedBox(width: 12),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: handleAdd,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('+ Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (addedItemsLog.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('ADDED THIS SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
              const SizedBox(height: 6),
              ...addedItemsLog.map((l) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $l', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black87)))),
            ],
          ],
        ),
      ),
    );
  }
}
