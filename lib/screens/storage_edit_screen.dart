import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../wherelog_repository.dart';
import '../widgets/notes_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/app_header.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageEditScreen extends StatefulWidget {
  final int itemIndex;
  const StorageEditScreen({super.key, required this.itemIndex});
  @override
  State<StorageEditScreen> createState() => _StorageEditScreenState();
}

class _StorageEditScreenState extends State<StorageEditScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  File? photoFile;
  String? existingPhotoPath;
  Map<String, dynamic>? _originalItem;
  final _picker = ImagePicker();
  final _repo = WhereLogRepository();
  bool _isLoading = true;
  bool _notesExpanded = false;
  bool _photoDetailsExpanded = true;

  void showCenterNotice(String msg) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
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
      'generalCtrl': generalController.text.trim(),
      'specificCtrl': specificController.text.trim(),
      'notes': notesController.text.trim(),
      'qty': qtyController.text.trim(),
      'value': valueController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath ?? '',
    };
    final orig = _initialSnapshot;
    return current['name'] != orig['name'] ||
        current['generalCtrl'] != orig['generalCtrl'] ||
        current['specificCtrl'] != orig['specificCtrl'] ||
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
    generalController.addListener(() => setState(() {}));
    specificController.addListener(() => setState(() {}));
    generalFocus.addListener(() => setState(() {}));
    specificFocus.addListener(() => setState(() {}));
    _repo.load().then((_) {
      if (_repo.storageItems.length > widget.itemIndex) {
        final item = _repo.storageItems[widget.itemIndex];
        _originalItem = Map<String, dynamic>.from(item);

        // v9 clean: resolve names from generalId / specificId only
        String gName = '';
        String sName = '';
        final genId = (item['generalId'] ?? '').toString();
        final specId = (item['specificId'] ?? '').toString();

        if (genId.isNotEmpty) {
          gName = _repo.generalNameForId(genId);
        }
        if (specId.isNotEmpty) {
          try {
            final spec = _repo.storageSpecifics.firstWhere(
              (s) => s['id'] == specId,
              orElse: () => <String, dynamic>{},
            );
            sName = (spec['name'] ?? '').toString();
            if (gName.isEmpty) {
              final gidFromSpec = spec['generalId']?.toString() ?? '';
              if (gidFromSpec.isNotEmpty) {
                gName = _repo.generalNameForId(gidFromSpec);
              }
            }
          } catch (_) {}
        }

        generalController.text = gName;
        specificController.text = sName;
        itemNameController.text = (item['name'] ?? '').toString();
        notesController.text = (item['notes'] ?? '').toString();
        final q = item['qty'] ?? 1;
        qtyController.text = q.toString();
        final vAmt = item['valueAmount'] ?? (item['value'] != null ? item['value'].toString() : '');
        valueController.text = vAmt.toString();
        existingPhotoPath = (item['photoPath'] ?? item['photo'])?.toString();
        _initialSnapshot = {
          'name': itemNameController.text.trim(),
          'generalCtrl': generalController.text.trim(),
          'specificCtrl': specificController.text.trim(),
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

  Future<void> handleSave() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Stored Item');
      return;
    }
    if (generalController.text.trim().isEmpty) {
      showCenterNotice('Pick General');
      return;
    }
    final savedName = itemNameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());

    // v9: resolve IDs using clean helpers (no tier synonyms)
    String generalId = '';
    String specificId = '';
    try {
      final gName = generalController.text.trim();
      final sName = specificController.text.trim();
      generalId = _repo.generalIdForName(gName);

      if (generalId.isNotEmpty && sName.isNotEmpty) {
        final spec = _repo.storageSpecifics.firstWhere(
          (s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').toLowerCase() == sName.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        specificId = spec['id']?.toString() ?? '';
        if (specificId.isEmpty) {
          await _repo.addStorageSpecific(generalId, sName);
          final spec2 = _repo.storageSpecifics.firstWhere(
            (s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').toLowerCase() == sName.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          specificId = spec2['id']?.toString() ?? '';
        }
      } else if (generalId.isNotEmpty) {
        // optional specific blank: use empty-name sentinel if present
        final sentinel = _repo.storageSpecifics.firstWhere(
          (s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').trim().isEmpty,
          orElse: () => <String, dynamic>{},
        );
        specificId = sentinel['id']?.toString() ?? '';
        // if still empty, keep as empty specific but ensure repo has at least list; v9 allows empty sentinel, create if missing handled by addGeneral
      }
    } catch (_) {}

    final orig = _originalItem ?? {};
    final nowIso = DateTime.now().toIso8601String();
    // Clean v9 payload: ONLY generalId/specificId, no legacy synonyms
    final updated = {
      'id': orig['id'],
      'name': savedName,
      'generalId': generalId,
      'specificId': specificId,
      'qty': qty,
      'value': valueAmt,
      'valueAmount': valueText,
      'notes': notesController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath,
      'photoPath': photoFile?.path ?? existingPhotoPath,
      'createdAt': orig['createdAt'] ?? nowIso,
      'modifyDate': nowIso,
      'updatedAt': nowIso,
    };

    await _repo.updateStorageItem(widget.itemIndex, updated);
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: AppColors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteStorageItem(widget.itemIndex);
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
        backgroundColor: AppColors.buttonBg,
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
                    icon: const Icon(Icons.edit, color: AppColors.white),
                    tooltip: 'Replace',
                    onPressed: () {
                      Navigator.pop(c);
                      openPhotoSheet();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => Navigator.pop(c),
                  ),
                ],
              ),
            ),
            const Positioned(
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
      color: AppColors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.68, child: Image.asset('assets/icon/app_icon.png', width: 64, height: 64, fit: BoxFit.contain)),
            const SizedBox(height: 6),
            const Text('No Photo', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 11)),
            const Text('Tap to add', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
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
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.textDisabled), borderRadius: BorderRadius.circular(AppRadius.button)),
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
                        decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(5)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 11, color: AppColors.white),
                            SizedBox(width: 2),
                            Text('View', style: TextStyle(color: AppColors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
                          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.edit, size: 12, color: AppColors.textSecondary),
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
        backgroundColor: AppColors.scaffold,
        appBar: const AppHeader(screenName: 'Edit Storage'),
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
        backgroundColor: AppColors.scaffold,
        appBar: const AppHeader(screenName: 'Edit Storage'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RequiredSection(
              source: RequiredSectionSource.storage,
              generalController: generalController,
              specificController: specificController,
              itemNameController: itemNameController,
              generalFocus: generalFocus,
              specificFocus: specificFocus,
              repo: _repo,
              itemHint: 'Stored Item',
            ),
            const SizedBox(height: 14),
            PhotoDetailsSection(
              storageKey: 'photoDetailsExpanded_storage_edit',
              isExpanded: _photoDetailsExpanded,
              onToggle: () => setState(() => _photoDetailsExpanded = !_photoDetailsExpanded),
              variant: PhotoDetailsVariant.storage,
              photoFile: photoFile,
              onPhotoAdd: openPhotoSheet,
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              onPhotoEdit: openPhotoSheet,
              valueController: valueController,
              qtyController: qtyController,
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 14),
            NotesSection(
              storageKey: 'notesExpanded_storage_edit',
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: SizedBox(height: 44, child: OutlinedButton(onPressed: () async { final ok = await _confirmDiscard(); if (ok && mounted) Navigator.pop(context); }, child: const Text('Cancel')))),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 44, child: ElevatedButton(onPressed: handleSave, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white), child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold))))),
            ]),
          ]),
        ),
      ),
    );
  }
}
