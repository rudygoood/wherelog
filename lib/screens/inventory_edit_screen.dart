import 'package:flutter/material.dart';
import '../location_repository.dart';
import '../widgets/notes_section.dart';
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
  bool _notesExpanded = false; // start state from app setting
  bool _isLoading = true;

  List<String> get inventoryGeneralList => _locationRepo.inventoryTier1List;
  List<String> getSpecificsForCurrentGeneral() {
    final p = generalController.text.trim();
    if (p.isEmpty) return [];
    return _locationRepo.inventoryTier2For(p);
  }
  bool isDuplicateGeneral(String name) => _locationRepo.isDuplicateInventoryTier1(name);
  bool isDuplicateSpecific(String parent, String name) => _locationRepo.isDuplicateInventoryTier2(parent, name);

  String? findSimilarSpecific(String parent, String newName) {
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
    if (msg.startsWith('Added:') || msg.startsWith('Saved:')) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) {
          try { if (Navigator.canPop(context)) Navigator.pop(context); } catch (_) {}
        }
      });
    }
  }

  Future<void> addGeneral(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateGeneral(t)) return;
    await _locationRepo.addInventoryTier1(t);
    setState(() {});
    showCenterNotice('Added General: $t');
  }

  Future<void> addSpecific(String parent, String name) async {
    final p = parent.trim();
    final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateSpecific(p, t)) return;
    await _locationRepo.addInventoryTier2(p, t);
    setState(() {});
    showCenterNotice('Added Specific: $t for $p');
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

  Future<void> openGeneralPicker() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => _GeneralSpecificPickerSheet(
        title: 'General',
        existing: inventoryGeneralList,
        hint: 'Search or type new General',
        allowBlank: false,
        onAddNew: (name) => addGeneral(name),
        isDuplicate: isDuplicateGeneral,
      ),
    );
    if (r != null) setState(() => generalController.text = r);
  }

  Future<void> openSpecificPicker() async {
    if (generalController.text.trim().isEmpty) return;
    final parent = generalController.text.trim();
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => _GeneralSpecificPickerSheet(
        title: 'Specific for $parent',
        existing: getSpecificsForCurrentGeneral(),
        hint: 'Search or type new Specific',
        allowBlank: true,
        onAddNew: (name) => addSpecific(parent, name),
        isDuplicate: (name) => isDuplicateSpecific(parent, name),
      ),
    );
    if (r != null) setState(() => specificController.text = r);
  }

  Future<void> openTier1Picker() => openGeneralPicker();
  Future<void> openTier2Picker() => openSpecificPicker();

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

  Widget buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isTier1,
    required bool enabled,
    required VoidCallback onPickerTap,
    required VoidCallback onAddTap,
    required List<String> existing,
  }) {
    final filter = controller.text.toLowerCase().trim();
    final filtered = filter.isEmpty ? existing : existing.where((e) => e.toLowerCase().contains(filter)).toList();
    final showDropdown = focusNode.hasFocus && filtered.isNotEmpty;
    final bool canAdd = controller.text.trim().isNotEmpty && (isTier1 ? !isDuplicateGeneral(controller.text.trim()) : !isDuplicateSpecific(generalController.text.trim(), controller.text.trim()));
    String? similar;
    if (!isTier1 && controller.text.trim().isNotEmpty) {
      similar = findSimilarSpecific(generalController.text.trim(), controller.text.trim());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: enabled ? Colors.white : Colors.black12,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onTap: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              height: 36,
              child: OutlinedButton(
                onPressed: enabled ? onPickerTap : null,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Icon(Icons.expand_more, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: canAdd ? onAddTap : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAdd ? Colors.black87 : Colors.black12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('+ Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        if (showDropdown)
          Container(
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
            constraints: BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length > 6 ? 6 : filtered.length,
              itemBuilder: (c, i) {
                final e = filtered[i];
                final bool isExact = e.toLowerCase() == filter;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    controller.text = e;
                    controller.selection = TextSelection.fromPosition(TextPosition(offset: e.length));
                    setState(() {});
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (focusNode.hasFocus) focusNode.unfocus();
                    });
                  },
                  child: ListTile(
                    dense: true,
                    title: Text(e, style: TextStyle(fontWeight: isExact ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                    trailing: isExact ? Icon(Icons.check, size: 16, color: Colors.black87) : null,
                  ),
                );
              },
            ),
          ),
                if (similar != null)
          Padding(
            padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Similar to "$similar" exists — select it from the list above', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
          ),
      ],
    );
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
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: AspectRatio(aspectRatio: 1, child: buildPhotoBoxSquare())),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Serial Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                const SizedBox(height: 4),
                TextField(controller: serialController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true)),
                const SizedBox(height: 12),
                const Text('VALUE (\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                const SizedBox(height: 4),
                TextField(controller: valueController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600), decoration: InputDecoration(prefixIcon: const Icon(Icons.attach_money, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true)),
                const SizedBox(height: 12),
                const Text('ACQUISITION DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                const SizedBox(height: 4),
                InkWell(onTap: pickAcquiredDate, borderRadius: BorderRadius.circular(10), child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: Text(acquiredDate == null ? 'Optional' : '${acquiredDate!.month}/${acquiredDate!.day}/${acquiredDate!.year}', style: TextStyle(color: acquiredDate == null ? Colors.black38 : Colors.black87, fontSize: 13, fontWeight: acquiredDate == null ? FontWeight.normal : FontWeight.w600))), const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54)]))),
              ])),
            ]),
            const SizedBox(height: 14),
            NotesSection(
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

class _GeneralSpecificPickerSheet extends StatefulWidget {
  final String title;
  final List<String> existing;
  final String hint;
  final bool allowBlank;
  final void Function(String) onAddNew;
  final bool Function(String) isDuplicate;
  const _GeneralSpecificPickerSheet({required this.title, required this.existing, required this.hint, required this.allowBlank, required this.onAddNew, required this.isDuplicate});
  @override
  State<_GeneralSpecificPickerSheet> createState() => _GeneralSpecificPickerSheetState();
}

class _GeneralSpecificPickerSheetState extends State<_GeneralSpecificPickerSheet> {
  late TextEditingController searchController;
  String filter = '';
  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    searchController.addListener(() => setState(() => filter = searchController.text));
  }
  @override
  Widget build(BuildContext context) {
    final filtered = widget.existing.where((e) => filter.isEmpty || e.toLowerCase().contains(filter.toLowerCase())).toList();
    final bool canAdd = filter.trim().isNotEmpty && !widget.isDuplicate(filter.trim());
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (c, scroll) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
          TextField(controller: searchController, decoration: InputDecoration(hintText: widget.hint, prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 8),
          if (canAdd) ListTile(leading: const Icon(Icons.add, color: Colors.black87), title: Text('Add "$filter" as new', style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { widget.onAddNew(filter.trim()); Navigator.pop(context, filter.trim()); }),
          if (widget.allowBlank) ListTile(title: const Text('(None)'), onTap: () => Navigator.pop(context, '')),
          Expanded(child: ListView.builder(controller: scroll, itemCount: filtered.length, itemBuilder: (c, i) => ListTile(title: Text(filtered[i]), onTap: () => Navigator.pop(context, filtered[i])))),
        ]),
      ),
    );
  }
}
