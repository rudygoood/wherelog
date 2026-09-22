import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/gps_location_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/notes_section.dart';
import '../location_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PoiEditScreen extends StatefulWidget {
  final int itemIndex;
  const PoiEditScreen({super.key, required this.itemIndex});
  @override
  State<PoiEditScreen> createState() => _PoiEditScreenState();
}

class _PoiEditScreenState extends State<PoiEditScreen> {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final addressController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final valueController = TextEditingController();
  File? photoFile;
  final _picker = ImagePicker();
  final _repo = LocationRepository();
  bool _notesExpanded = true;
  bool _photoExpanded = true;
  bool _isGettingLocation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo.load().then((_) {
      if (_repo.poiItems.length > widget.itemIndex) {
        final item = _repo.poiItems[widget.itemIndex];
        setState(() {
          nameController.text = (item['name'] ?? '').toString();
          notesController.text = (item['notes'] ?? '').toString();
          addressController.text = (item['address'] ?? '').toString();
          latController.text = (item['lat'] ?? '').toString();
          lngController.text = (item['lng'] ?? '').toString();
          if ((item['photo'] ?? item['photoPath'] ?? '').toString().isNotEmpty) {
            try { photoFile = File((item['photo'] ?? item['photoPath']).toString()); } catch (_) {}
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    notesController.dispose();
    addressController.dispose();
    latController.dispose();
    lngController.dispose();
    valueController.dispose();
    super.dispose();
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
              const Icon(Icons.place, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(c),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> captureCurrentGps() async {
    setState(() => _isGettingLocation = true);
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      showCenterNotice('To enable live GPS, add to pubspec.yaml:\n  geolocator: ^10.1.0\n  geocoding: ^2.1.1\n\nThen uncomment capture code.');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> pickFromMapProgram() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (c) => _MapPickSheet(
        initialLat: latController.text,
        initialLng: lngController.text,
        initialAddress: addressController.text,
      ),
    );
    if (result != null) {
      setState(() {
        if (result['lat'] != null) latController.text = result['lat']!;
        if (result['lng'] != null) lngController.text = result['lng']!;
        if (result['address'] != null) addressController.text = result['address']!;
      });
    }
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
        child: Stack(children: [
          Center(child: Image.file(file, fit: BoxFit.contain)),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(c)),
          ),
        ]),
      ),
    );
  }

  Future<void> handleSave() async {
    if (nameController.text.trim().isEmpty) {
      showCenterNotice('Enter Place Name');
      return;
    }
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) {
      showCenterNotice('Enter valid GPS coordinates');
      return;
    }
    final nowIso = DateTime.now().toIso8601String();
    final item = {
      'id': 'poi_${DateTime.now().millisecondsSinceEpoch}',
      'name': nameController.text.trim(),
      'lat': lat,
      'lng': lng,
      'address': addressController.text.trim(),
      'notes': notesController.text.trim(),
      'photo': photoFile?.path,
      'photoPath': photoFile?.path,
      'createdAt': nowIso,
      'modifyDate': nowIso,
      'updatedAt': nowIso,
    };
    await _repo.updatePoiItem(widget.itemIndex, item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F0E9),
        appBar: const AppHeader(screenName: 'Edit Place of Interest'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0E9),
      appBar: const AppHeader(screenName: 'Edit Place of Interest'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GpsLocationSection(
              nameController: nameController,
              latController: latController,
              lngController: lngController,
              isGettingLocation: _isGettingLocation,
              onCurrentGps: captureCurrentGps,
              onPickMap: pickFromMapProgram,
            ),
            const SizedBox(height: 16),
            PhotoDetailsSection(
              isExpanded: _photoExpanded,
              onToggle: () => setState(() => _photoExpanded = !_photoExpanded),
              variant: PhotoDetailsVariant.poi,
              photoFile: photoFile,
              onPhotoAdd: openPhotoSheet,
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              onPhotoEdit: openPhotoSheet,
              valueController: valueController,
              addressController: addressController,
              onPickMap: pickFromMapProgram,
              storageKey: 'photoDetailsExpanded_poi_edit',
            ),
            const SizedBox(height: 16),
            NotesSection(
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
              storageKey: 'notesExpanded_poi_edit',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPickSheet extends StatefulWidget {
  final String initialLat;
  final String initialLng;
  final String initialAddress;
  const _MapPickSheet({required this.initialLat, required this.initialLng, required this.initialAddress});
  @override
  State<_MapPickSheet> createState() => _MapPickSheetState();
}

class _MapPickSheetState extends State<_MapPickSheet> {
  late TextEditingController latCtrl;
  late TextEditingController lngCtrl;
  late TextEditingController addrCtrl;
  @override
  void initState() {
    super.initState();
    latCtrl = TextEditingController(text: widget.initialLat);
    lngCtrl = TextEditingController(text: widget.initialLng);
    addrCtrl = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    latCtrl.dispose();
    lngCtrl.dispose();
    addrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pick Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, {'lat': latCtrl.text, 'lng': lngCtrl.text, 'address': addrCtrl.text}),
                child: const Text('Use This Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
