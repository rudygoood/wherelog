import 'package:flutter/material.dart';
import '../location_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageAddScreen extends StatefulWidget {
  const StorageAddScreen({super.key});
  @override
  State<StorageAddScreen> createState() => _StorageAddScreenState();
}

class _StorageAddScreenState extends State<StorageAddScreen> {
  final tier1Controller = TextEditingController();
  final tier2Controller = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  final tier1Focus = FocusNode();
  final tier2Focus = FocusNode();
  List<String> addedItemsLog = [];
  File? photoFile;
  final _picker = ImagePicker();
  final _locationRepo = LocationRepository();

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
    if (msg.startsWith('Added:')) {
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

  @override
  void initState() {
    super.initState();
    _locationRepo.load().then((_) => setState(() {}));
    tier1Controller.addListener(() => setState(() {}));
    tier2Controller.addListener(() => setState(() {}));
    tier1Focus.addListener(() => setState(() {}));
    tier2Focus.addListener(() => setState(() {}));
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

  Future<void> handleAdd() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Stored Item');
      return;
    }
    if (tier1Controller.text.trim().isEmpty) {
      showCenterNotice('Pick General location');
      return;
    }
    final loc = concatenatedLocation.isEmpty ? tier1Controller.text.trim() : concatenatedLocation;
    final hasPhoto = photoFile != null ? ' 📷' : '';
    final addedName = itemNameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());
    final item = {
      'name': addedName,
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
      'photo': photoFile?.path,
      'createdAt': DateTime.now().toIso8601String(),
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
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
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
            const SizedBox(height: 18),
            const Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 4),
            TextField(
              controller: itemNameController,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Stored Item',
                hintStyle: const TextStyle(color: Colors.black38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            // Square thumbnail half-width beside vertically stacked Quantity/Value - consistent border matching other fields
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AspectRatio(aspectRatio: 1, child: buildPhotoBoxSquare()),
                ),
                const SizedBox(width: 12),
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
            TextField(controller: notesController, minLines: 3, maxLines: 3, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(hintText: 'Additional details (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Location does not reset so you can add multiple items, but you can change it when needed.', style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.3))),
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
