
import 'package:flutter/material.dart';
import '../location_repository.dart';
import '../widgets/notes_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PoiAddScreen extends StatefulWidget {
  const PoiAddScreen({super.key});
  @override
  State<PoiAddScreen> createState() => _PoiAddScreenState();
}

class _PoiAddScreenState extends State<PoiAddScreen> {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final addressController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  File? photoFile;
  final _picker = ImagePicker();
  final _repo = LocationRepository();
  bool _notesExpanded = false; // start state from app setting
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _repo.load();
  }

  @override
  void dispose() {
    nameController.dispose();
    notesController.dispose();
    addressController.dispose();
    latController.dispose();
    lngController.dispose();
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

  // Method 2: Current GPS - add geolocator: ^10.1.0 to enable live
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

  Future<void> openNotesEditor() async {
    final temp = TextEditingController(text: notesController.text);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(controller: temp, minLines: 4, maxLines: 8),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, temp.text), child: const Text('Save')),
        ],
      ),
    );
    if (res != null) setState(() => notesController.text = res);
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

  Widget buildPhotoBoxSquare() {
    return InkWell(
      onTap: openPhotoSheet,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(10)),
        child: photoFile != null
            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(photoFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
            : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_a_photo, size: 28, color: Colors.black38), SizedBox(height: 4), Text('Photo', style: TextStyle(fontSize: 11, color: Colors.black38))])),
      ),
    );
  }

  Future<void> handleAdd() async {
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
    await _repo.addPoiItem(item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0E9),
      appBar: AppBar(backgroundColor: Colors.black87, foregroundColor: Colors.white, title: const Text('Add Place of Interest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GPS LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: latController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'Latitude', hintText: '38.123456', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: lngController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'Longitude', hintText: '-78.123456', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _isGettingLocation ? null : captureCurrentGps, icon: _isGettingLocation ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, size: 18), label: const Text('Current GPS', style: TextStyle(fontSize: 12)))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: pickFromMapProgram, icon: const Icon(Icons.map_outlined, size: 18), label: const Text('Pick from Map', style: TextStyle(fontSize: 12)))),
                    ],
                  ),
                  const Align(alignment: Alignment.centerLeft, child: Text('3 ways: manual entry, current GPS, or map picker — concatenated when needed: lat,lng', style: TextStyle(fontSize: 10, color: Colors.black54))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('PLACE NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 4),
            TextField(controller: nameController, style: const TextStyle(fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'e.g. Great campsite', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white)),
            const SizedBox(height: 14),
            const Text('ADDRESS (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 4),
            TextField(controller: addressController, decoration: InputDecoration(hintText: 'Optional address from map - single string', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: Colors.white, suffixIcon: IconButton(icon: const Icon(Icons.map), onPressed: pickFromMapProgram))),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: AspectRatio(aspectRatio: 1, child: buildPhotoBoxSquare())),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NotesSection(
                        controller: notesController,
                        isExpanded: _notesExpanded,
                        onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(onPressed: handleAdd, style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Add POI', style: TextStyle(fontWeight: FontWeight.bold))),
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
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (c, scroll) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [const Text('Pick from Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            Container(height: 200, decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map, size: 48, color: Colors.blueGrey.shade300), const SizedBox(height: 8), const Text('Map View Placeholder - integrate google_maps_flutter'), const Text('Paste address string from map app', style: TextStyle(fontSize: 10, color: Colors.black45))]))),
            const SizedBox(height: 12),
            TextField(controller: latCtrl, decoration: InputDecoration(labelText: 'Latitude', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 8),
            TextField(controller: lngCtrl, decoration: InputDecoration(labelText: 'Longitude', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: InputDecoration(labelText: 'Address (single string from map)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context, {'lat': latCtrl.text, 'lng': lngCtrl.text, 'address': addrCtrl.text}), style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white), child: const Text('Use This Location'))),
          ],
        ),
      ),
    );
  }
}
