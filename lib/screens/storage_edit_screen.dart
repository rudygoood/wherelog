import 'package:flutter/material.dart';
import '../location_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageEditScreen extends StatefulWidget {
  final int itemIndex;
  const StorageEditScreen({super.key, required this.itemIndex});
  @override
  State<StorageEditScreen> createState() => _StorageEditScreenState();
}

class _StorageEditScreenState extends State<StorageEditScreen> {
  final tier1Controller = TextEditingController();
  final tier2Controller = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  final tier1Focus = FocusNode();
  final tier2Focus = FocusNode();
  File? photoFile;
  String? existingPhotoPath;
  Map<String, dynamic>? _originalItem;
  final _picker = ImagePicker();
  final _locationRepo = LocationRepository();
  bool _isLoading = true;

  List<String> get storageTier1List => _locationRepo.storageTier1List;
  List<String> getTier2ForCurrentTier1() {
    final p = tier1Controller.text.trim();
    if (p.isEmpty) return [];
    return _locationRepo.storageTier2For(p);
  }
  bool isDuplicateTier1(String name) => _locationRepo.isDuplicateStorageTier1(name);
  bool isDuplicateTier2(String parent, String name) => _locationRepo.isDuplicateStorageTier2(parent, name);

  String? findSimilarTier2(String parent, String newName) {
    final list = _locationRepo.storageData[parent] ?? [];
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

  Future<void> addTier1(String name) async {
    final t = name.trim();
    if (t.isEmpty || isDuplicateTier1(t)) return;
    await _locationRepo.addStorageTier1(t);
    setState(() {});
    showCenterNotice('Added Place: $t');
  }

  Future<void> addTier2(String parent, String name) async {
    final p = parent.trim();
    final t = name.trim();
    if (p.isEmpty || t.isEmpty || isDuplicateTier2(p, t)) return;
    await _locationRepo.addStorageTier2(p, t);
    setState(() {});
    showCenterNotice('Added Bin: $t for $p');
  }

  String get concatenatedLocation {
    final t1 = tier1Controller.text.trim();
    final t2 = tier2Controller.text.trim();
    if (t1.isNotEmpty && t2.isNotEmpty) return '$t1 / $t2';
    return t1.isNotEmpty ? t1 : t2;
  }

  Map<String, dynamic> _initialSnapshot = {};

  bool _hasUnsavedChanges() {
    if (_originalItem == null) return false;
    final current = {
      'name': itemNameController.text.trim(),
      'tier1': tier1Controller.text.trim(),
      'tier2': tier2Controller.text.trim(),
      'notes': notesController.text.trim(),
      'qty': qtyController.text.trim(),
      'value': valueController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath ?? '',
    };
    final orig = _initialSnapshot;
    return current['name'] != orig['name'] ||
        current['tier1'] != orig['tier1'] ||
        current['tier2'] != orig['tier2'] ||
        current['notes'] != orig['notes'] ||
        current['qty'] != orig['qty'] ||
        current['value'] != orig['value'] ||
        current['photo'] != orig['photo'];
  }

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
    tier1Controller.addListener(() => setState(() {}));
    tier2Controller.addListener(() => setState(() {}));
    tier1Focus.addListener(() => setState(() {}));
    tier2Focus.addListener(() => setState(() {}));
    _locationRepo.load().then((_) {
      if (_locationRepo.storageItems.length > widget.itemIndex) {
        final item = _locationRepo.storageItems[widget.itemIndex];
        _originalItem = Map<String, dynamic>.from(item);
        tier1Controller.text = (item['tier1'] ?? item['place'] ?? '').toString();
        tier2Controller.text = (item['tier2'] ?? item['bin'] ?? '').toString();
        itemNameController.text = (item['name'] ?? '').toString();
        notesController.text = (item['notes'] ?? '').toString();
        final q = item['qty'] ?? item['quantity'] ?? 1;
        qtyController.text = q.toString();
        final vAmt = item['valueAmount'] ?? (item['value'] != null ? item['value'].toString() : '');
        valueController.text = vAmt.toString();
        existingPhotoPath = item['photo']?.toString();
        _initialSnapshot = {
          'name': itemNameController.text.trim(),
          'tier1': tier1Controller.text.trim(),
          'tier2': tier2Controller.text.trim(),
          'notes': notesController.text.trim(),
          'qty': qtyController.text.trim(),
          'value': valueController.text.trim(),
          'photo': existingPhotoPath ?? '',
        };
      }
      setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    tier1Focus.dispose();
    tier2Focus.dispose();
    tier1Controller.dispose();
    tier2Controller.dispose();
    itemNameController.dispose();
    notesController.dispose();
    qtyController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Future<void> openTier1Picker() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => _TierPickerSheet(
        title: 'General - Place',
        existing: storageTier1List,
        hint: 'Search or type new Place',
        allowBlank: false,
        onAddNew: (name) => addTier1(name),
        isDuplicate: isDuplicateTier1,
      ),
    );
    if (r != null) setState(() => tier1Controller.text = r);
  }

  Future<void> openTier2Picker() async {
    if (tier1Controller.text.trim().isEmpty) return;
    final parent = tier1Controller.text.trim();
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => _TierPickerSheet(
        title: 'Specific - Bin for $parent',
        existing: getTier2ForCurrentTier1(),
        hint: 'Search or type new Bin',
        allowBlank: true,
        onAddNew: (name) => addTier2(parent, name),
        isDuplicate: (name) => isDuplicateTier2(parent, name),
      ),
    );
    if (r != null) setState(() => tier2Controller.text = r);
  }

  Future<void> handleSave() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Stored Item');
      return;
    }
    if (tier1Controller.text.trim().isEmpty) {
      showCenterNotice('Pick General location');
      return;
    }
    final loc = concatenatedLocation.isEmpty ? tier1Controller.text.trim() : concatenatedLocation;
    final savedName = itemNameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());
    final orig = _originalItem ?? {};
    final updated = {
      'name': savedName,
      'tier1': tier1Controller.text.trim(),
      'tier2': tier2Controller.text.trim(),
      'place': tier1Controller.text.trim(),
      'bin': tier2Controller.text.trim(),
      'location': loc,
      'qty': qty,
      'quantity': qty,
      'value': valueAmt,
      'valueAmount': valueText,
      'notes': notesController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath,
      'createdAt': orig['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    // Preserve any extra fields not explicitly edited
    for (final k in orig.keys) {
      if (!updated.containsKey(k)) {
        updated[k] = orig[k];
      }
    }
    await _locationRepo.updateStorageItem(widget.itemIndex, updated);
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
      await _locationRepo.deleteStorageItem(widget.itemIndex);
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
    final bool canAdd = controller.text.trim().isNotEmpty && (isTier1 ? !isDuplicateTier1(controller.text.trim()) : !isDuplicateTier2(tier1Controller.text.trim(), controller.text.trim()));
    String? similar;
    if (!isTier1 && controller.text.trim().isNotEmpty) {
      similar = findSimilarTier2(tier1Controller.text.trim(), controller.text.trim());
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

  // Keep old name as alias for any legacy calls
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
                const TextSpan(text: ' - Edit Storage', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3EE),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F3EE),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              final ok = await _confirmDiscard();
              if (ok && mounted) Navigator.pop(context);
            },
          ),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              children: [
                const TextSpan(text: 'Where', style: TextStyle(color: Colors.black87)),
                const TextSpan(text: 'Log', style: TextStyle(color: Color(0xFFB91C1C))),
                const TextSpan(text: ' - Edit Storage', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: 'Delete', onPressed: handleDelete),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8)),
                child: Text('Location: ${concatenatedLocation.isEmpty ? '—' : concatenatedLocation}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              ),
              const SizedBox(height: 10),
              const Text('GENERAL AREA (required)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
              const SizedBox(height: 4),
              buildLocationField(
                controller: tier1Controller,
                focusNode: tier1Focus,
                hint: 'e.g. Garage, Attic',
                isTier1: true,
                enabled: true,
                onPickerTap: openTier1Picker,
                onAddTap: () => addTier1(tier1Controller.text.trim()),
                existing: storageTier1List,
              ),
              const SizedBox(height: 12),
              const Text('SPECIFIC AREA (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
              const SizedBox(height: 4),
              buildLocationField(
                controller: tier2Controller,
                focusNode: tier2Focus,
                hint: 'e.g. Bin 1, Shelf A (optional)',
                isTier1: false,
                enabled: tier1Controller.text.trim().isNotEmpty,
                onPickerTap: openTier2Picker,
                onAddTap: () => addTier2(tier1Controller.text.trim(), tier2Controller.text.trim()),
                existing: getTier2ForCurrentTier1(),
              ),
              const SizedBox(height: 16),
              const Text('ITEM NAME (required)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
              const SizedBox(height: 4),
              TextField(
                controller: itemNameController,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              // Compact square thumbnail (half-width) beside vertically stacked QTY / VALUE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square thumbnail - half width, square aspect, distinct placeholder using app_icon
                  Expanded(
                    flex: 3,
                    child: AspectRatio(
                      aspectRatio: 1, // consistent square based on half-width
                      child: buildPhotoBoxSquare(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Vertically stacked QTY and VALUE - occupies other half
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('VALUE (\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: valueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.attach_money, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('NOTES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                  Spacer(),
                  InkWell(
                    onTap: openNotesEditor,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(children: [Icon(Icons.open_in_full, size: 14, color: Colors.black54), SizedBox(width: 4), Text('Expand', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600))]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(controller: notesController, minLines: 3, maxLines: 3, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await _confirmDiscard();
                          if (ok && mounted) Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: handleSave,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _TierPickerSheet extends StatefulWidget {
  final String title;
  final List<String> existing;
  final String hint;
  final bool allowBlank;
  final void Function(String) onAddNew;
  final bool Function(String) isDuplicate;
  const _TierPickerSheet({required this.title, required this.existing, required this.hint, required this.allowBlank, required this.onAddNew, required this.isDuplicate});
  @override
  State<_TierPickerSheet> createState() => _TierPickerSheetState();
}

class _TierPickerSheetState extends State<_TierPickerSheet> {
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
          if (canAdd)
            ListTile(
              leading: const Icon(Icons.add, color: Colors.black87),
              title: Text('Add "$filter" as new', style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                widget.onAddNew(filter.trim());
                Navigator.pop(context, filter.trim());
              },
            ),
          if (widget.allowBlank) ListTile(title: const Text('(None)'), onTap: () => Navigator.pop(context, '')),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: filtered.length,
              itemBuilder: (c, i) {
                final e = filtered[i];
                return ListTile(title: Text(e), onTap: () => Navigator.pop(context, e));
              },
            ),
          ),
        ]),
      ),
    );
  }
}
