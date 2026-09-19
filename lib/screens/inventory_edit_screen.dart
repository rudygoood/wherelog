import 'package:flutter/material.dart';
import '../location_repository.dart';
import '../widgets/notes_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class InventoryEditScreen extends StatefulWidget {
  final int itemIndex;
  const InventoryEditScreen({super.key, required this.itemIndex});
  @override
  State<InventoryEditScreen> createState() => _InventoryEditScreenState();
}

class _InventoryEditScreenState extends State<InventoryEditScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final serialController = TextEditingController();
  DateTime? acquiredDate;
  final valueController = TextEditingController();
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  File? photoFile;
  String? existingPhotoPath;
  Map<String, dynamic>? _originalItem;
  final _picker = ImagePicker();
  final _locationRepo = LocationRepository();
  bool _notesExpanded = false;
  bool _photoDetailsExpanded = true; // start state from app setting
  bool _isLoading = true;


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
    if (msg.startsWith('Added:') || msg.startsWith('Saved:')) {
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
  String get concatenatedLocation => fullLocationDisplay;

  Map<String, dynamic> _initialSnapshot = {};

  bool _hasUnsavedChanges() {
    if (_originalItem == null) return false;
    final current = {
      'name': itemNameController.text.trim(),
      'general': generalController.text.trim(),
      'specific': specificController.text.trim(),
      'notes': notesController.text.trim(),
      'serial': serialController.text.trim(),
      'serial_number': serialController.text.trim(),
      'value': valueController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath ?? '',
    };
    final orig = _initialSnapshot;
    return current['name'] != orig['name'] ||
        current['general'] != orig['general'] ||
        current['specific'] != orig['specific'] ||
        current['notes'] != orig['notes'] ||
        current['serial'] != orig['serial'] ||
        current['value'] != orig['value'] ||
        current['photo'] != orig['photo'];
  }

  Future<void> pickAcquiredDate() async { final now = DateTime.now(); final picked = await showDatePicker(context: context, initialDate: acquiredDate ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setState(() => acquiredDate = picked); }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges()) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Discard them and leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep Editing')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
        ],
      ),
    );
    return res == true;
  }

  @override
  void initState() {
    super.initState();
    generalController.addListener(() => setState(() {}));
    specificController.addListener(() => setState(() {}));
    generalFocus.addListener(() => setState(() {}));
    specificFocus.addListener(() => setState(() {}));
    _locationRepo.load().then((_) {
      if (_locationRepo.inventoryItems.length > widget.itemIndex) {
        final item = _locationRepo.inventoryItems[widget.itemIndex];
        _originalItem = Map<String, dynamic>.from(item);

        // v5: try to resolve general/specific from specificId first (stable JSON)
        String gName = '';
        String sName = '';
        final specId = (item['specificId'] ?? '').toString();
        if (specId.isNotEmpty) {
          try {
            final spec = _locationRepo.inventorySpecifics.firstWhere((s) => s['id'] == specId, orElse: () => {});
            sName = (spec['name'] ?? '').toString();
            final genId = spec['generalId']?.toString() ?? '';
            if (genId.isNotEmpty) {
              final gen = _locationRepo.inventoryGenerals.firstWhere((g) => g['id'] == genId, orElse: () => {});
              gName = (gen['name'] ?? '').toString();
            }
          } catch (_) {}
        }
        if (gName.isEmpty) {
          gName = (item['general'] ?? item['tier1'] ?? item['place'] ?? '').toString();
        }
        if (sName.isEmpty) {
          sName = (item['specific'] ?? item['tier2'] ?? item['bin'] ?? '').toString();
        }

        generalController.text = gName;
        specificController.text = sName;
        itemNameController.text = (item['name'] ?? '').toString();
        notesController.text = (item['notes'] ?? '').toString();
        serialController.text = (item['serial_number'] ?? item['serial'] ?? '').toString();
        final dateStr = item['acquisition_date'] ?? item['acquiredDate'];
        if (dateStr != null) { try { acquiredDate = DateTime.parse(dateStr.toString()); } catch (_) {} }
        final vAmt = item['valueAmount'] ?? (item['value'] != null ? item['value'].toString() : '');
        valueController.text = vAmt.toString();
        existingPhotoPath = (item['photoPath'] ?? item['photo'])?.toString();
        _initialSnapshot = {
          'name': itemNameController.text.trim(),
          'general': generalController.text.trim(),
          'specific': specificController.text.trim(),
          'notes': notesController.text.trim(),
          'serial': serialController.text.trim(),
          'acquiredDate': acquiredDate?.toIso8601String() ?? '',
          'value': valueController.text.trim(),
          'photo': existingPhotoPath ?? '',
          'value': valueController.text.trim(),
          'photo': existingPhotoPath ?? '',
        };
      }
      setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    generalFocus.dispose();
    specificFocus.dispose();
    generalController.dispose();
    specificController.dispose();
    itemNameController.dispose();
    notesController.dispose();
    serialController.dispose();
    valueController.dispose();
    super.dispose();
  }



  Future<void> handleSave() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Inventory Item');
      return;
    }
    if (generalController.text.trim().isEmpty) {
      showCenterNotice('Pick General');
      return;
    }
    final loc = fullLocationDisplay.isEmpty ? generalController.text.trim() : fullLocationDisplay;
    final savedName = itemNameController.text.trim();
    final serialText = serialController.text.trim();
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());

    // resolve IDs for stable JSON
    String generalId = '';
    String specificId = '';
    try {
      final gName = generalController.text.trim();
      final sName = specificController.text.trim();
      final gen = _locationRepo.inventoryGenerals.firstWhere((g) => (g['name']?.toString() ?? '') == gName, orElse: () => {});
      generalId = gen['id']?.toString() ?? '';
      if (sName.isNotEmpty) {
        final spec = _locationRepo.inventorySpecifics.firstWhere((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '') == sName, orElse: () => {});
        specificId = spec['id']?.toString() ?? '';
        if (specificId.isEmpty) {
          await _locationRepo.addInventoryTier2(gName, sName);
          final spec2 = _locationRepo.inventorySpecifics.firstWhere((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '') == sName, orElse: () => {});
          specificId = spec2['id']?.toString() ?? '';
        }
      } else {
        final sentinel = _locationRepo.inventorySpecifics.firstWhere((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').isEmpty, orElse: () => {});
        specificId = sentinel['id']?.toString() ?? '';
      }
    } catch (_) {}

    final orig = _originalItem ?? {};
    final nowIso = DateTime.now().toIso8601String();
    final updated = {
      'id': orig['id'],
      'name': savedName,
      'generalId': generalId,
      'specificId': specificId,
      'general': generalController.text.trim(),
      'specific': specificController.text.trim(),
      'tier1': generalController.text.trim(),
      'tier2': specificController.text.trim(),
      'place': generalController.text.trim(),
      'bin': specificController.text.trim(),
      'location': loc,
      'serial_number': serialText,
      'serial': serialText,
      'acquisition_date': acquiredDate?.toIso8601String(),
      'acquiredDate': acquiredDate?.toIso8601String(),
      'value': valueAmt,
      'valueAmount': valueText,
      'notes': notesController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath,
      'photoPath': photoFile?.path ?? existingPhotoPath,
      'createdAt': orig['createdAt'] ?? nowIso,
      'modifyDate': nowIso,
      'updatedAt': nowIso,
    };
    for (final k in orig.keys) {
      if (!updated.containsKey(k)) {
        updated[k] = orig[k];
      }
    }
    await _locationRepo.updateInventoryItem(widget.itemIndex, updated);
    if (!mounted) return;
    showCenterNotice('Saved: $savedName');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> handleDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "${itemNameController.text.trim()}" ? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _locationRepo.deleteInventoryItem(widget.itemIndex);
      if (mounted) Navigator.pop(context, true);
    }
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
    final hasAnyPhoto = photoFile != null || (existingPhotoPath != null && existingPhotoPath!.isNotEmpty);
    final src = await showModalBottomSheet<dynamic>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Take Photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          if (hasAnyPhoto) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove Photo'), onTap: () => Navigator.pop(c, 'remove')),
        ]),
      ),
    );
    if (src == 'remove') {
      setState(() {
        photoFile = null;
        existingPhotoPath = null;
      });
      return;
    }
    if (src == null) return;
    if (src is ImageSource) {
      final XFile? img = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1024);
      if (img != null) setState(() => photoFile = File(img.path));
    }
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
              child: Center(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: 'Replace',
                    onPressed: () {
                      Navigator.pop(c);
                      openPhotoSheet();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(c),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Pinch to zoom — tap ✕ to close',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
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
    final File? existingFile = (existingPhotoPath != null && existingPhotoPath!.isNotEmpty) ? File(existingPhotoPath!) : null;
    final bool existingExists = existingFile != null && existingFile.existsSync();
    final File? displayFile = photoFile ?? (existingExists ? existingFile : null);
    final bool hasPhoto = displayFile != null;
    return InkWell(
      onTap: () {
        if (hasPhoto) {
          openFullPhotoViewer(displayFile!);
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
                    Center(
                      child: Image.file(displayFile!, fit: BoxFit.contain),
                    ),
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 11, color: Colors.white),
                            SizedBox(width: 2),
                            Text('View', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: InkWell(
                        onTap: openPhotoSheet,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.black26)),
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

  Widget buildPhotoBox() => buildPhotoBoxSquare();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
                const TextSpan(text: ' - Edit Inventory', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3EE),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F3EE),
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () async { final ok = await _confirmDiscard(); if (ok && context.mounted) Navigator.pop(context); }),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              children: [
                const TextSpan(text: 'Where', style: TextStyle(color: Colors.black87)),
                const TextSpan(text: 'Log', style: TextStyle(color: Color(0xFFB91C1C))),
                const TextSpan(text: ' - Edit Inventory', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          actions: [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: handleDelete)],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RequiredSection(
              source: RequiredSectionSource.inventory,
              generalController: generalController,
              specificController: specificController,
              itemNameController: itemNameController,
              generalFocus: generalFocus,
              specificFocus: specificFocus,
              locationRepo: _locationRepo,
              itemHint: 'Inventory Item',
            ),
            const SizedBox(height: 14),
                        PhotoDetailsSection(
              storageKey: 'photoDetailsExpanded_inventory_edit',
              isExpanded: _photoDetailsExpanded,
              onToggle: () => setState(() => _photoDetailsExpanded = !_photoDetailsExpanded),
              variant: PhotoDetailsVariant.inventory,
              photoFile: photoFile,
              onPhotoAdd: openPhotoSheet,
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              onPhotoEdit: openPhotoSheet,
              valueController: valueController,
              serialController: serialController,
              acquiredDate: acquiredDate,
              onPickAcquiredDate: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: acquiredDate ?? now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) setState(() => acquiredDate = picked);
              },
            ),
            const SizedBox(height: 14),const SizedBox(height: 14),
            NotesSection(
              storageKey: 'notesExpanded_inventory_edit',
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: SizedBox(height: 44, child: OutlinedButton(onPressed: () async { final ok = await _confirmDiscard(); if (ok && mounted) Navigator.pop(context); }, child: const Text('Cancel')))),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: handleSave, style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white), child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold))))),
            ]),
          ]),
        ),
      ),
    );
  }
}
