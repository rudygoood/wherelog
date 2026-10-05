import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

enum PhotoDetailsVariant { storage, inventory, poi }

class PhotoDetailsSection extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final PhotoDetailsVariant variant;
  final File? photoFile;
  final VoidCallback onPhotoAdd;
  final VoidCallback onPhotoView;
  final VoidCallback onPhotoEdit;
  final TextEditingController valueController;
  final TextEditingController? qtyController;
  final TextEditingController? serialController;
  final TextEditingController? addressController;
  final VoidCallback? onPickMap;
  final DateTime? acquiredDate;
  final VoidCallback? onPickAcquiredDate;
  final String? storageKey;

  const PhotoDetailsSection({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.variant,
    required this.photoFile,
    required this.onPhotoAdd,
    required this.onPhotoView,
    required this.onPhotoEdit,
    required this.valueController,
    this.qtyController,
    this.serialController,
    this.addressController,
    this.onPickMap,
    this.acquiredDate,
    this.onPickAcquiredDate,
    this.storageKey,
  });

  @override
  State<PhotoDetailsSection> createState() => _PhotoDetailsSectionState();
}

class _PhotoDetailsSectionState extends State<PhotoDetailsSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
    _load();
  }

  Future<void> _load() async {
    if (widget.storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(widget.storageKey!);
    if (saved != null && mounted) setState(() => _expanded = saved);
  }

  Future<void> _handleToggle() async {
    setState(() => _expanded = !_expanded);
    if (widget.storageKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(widget.storageKey!, _expanded);
    }
    widget.onToggle();
  }

  String get _title {
    switch (widget.variant) {
      case PhotoDetailsVariant.poi:
        return 'PHOTO & ADDRESS';
      default:
        return 'PHOTO & DETAILS';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_title, style: AppText.dialogSection),
            const SizedBox(width: 12),
            InkWell(
              onTap: _handleToggle,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(_expanded ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          if (widget.variant == PhotoDetailsVariant.poi) _buildPoiLayout() else _buildStandardLayout(),
        ],
      ],
    );
  }

  Widget _buildStandardLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: AspectRatio(aspectRatio: 1, child: _buildPhotoBoxSquare())),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildFields())),
      ],
    );
  }

  Widget _buildPoiLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 16 / 10, child: _buildPhotoBoxSquare()),
        const SizedBox(height: 12),
        const Text('ADDRESS (optional)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        TextField(
          controller: widget.addressController,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Optional address from map - single string',
            hintStyle: const TextStyle(color: AppColors.textDisabled),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: IconButton(icon: const Icon(Icons.map, color: AppColors.textSecondary), onPressed: widget.onPickMap),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoBoxSquare() {
    final bool hasPhoto = widget.photoFile != null;
    return InkWell(
      onTap: () => hasPhoto ? widget.onPhotoView() : widget.onPhotoAdd(),
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button - 1),
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: Image.file(widget.photoFile!, fit: BoxFit.contain)),
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.buttonBg, borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility, size: 10, color: Colors.white),
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
                        onTap: widget.onPhotoEdit,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.border),
                          ),
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

  Widget _buildDistinctPlaceholder() {
    return Container(
      color: AppColors.scaffoldDark,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(opacity: 0.68, child: Image.asset('assets/icon/app_icon.png', width: 64, height: 64, fit: BoxFit.contain)),
          const SizedBox(height: 6),
          const Text('No Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 11)),
          const Text('Tap to add', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _buildFields() {
    if (widget.variant == PhotoDetailsVariant.storage) {
      return [
        const Text('Quantity', style: AppText.dialogSection),
        const SizedBox(height: 4),
        TextField(
          controller: widget.qtyController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        const Text('VALUE (\$)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        TextField(
          controller: widget.valueController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
        ),
      ];
    } else {
      return [
        const Text('Serial Number', style: AppText.dialogSection),
        const SizedBox(height: 4),
        TextField(
          controller: widget.serialController,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        const Text('VALUE (\$)', style: AppText.dialogSection),
        const SizedBox(height: 4),
        TextField(
          controller: widget.valueController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        const Text('ACQUISITION DATE', style: AppText.dialogSection),
        const SizedBox(height: 4),
        InkWell(
          onTap: widget.onPickAcquiredDate,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.acquiredDate == null ? 'Optional' : '${widget.acquiredDate!.month}/${widget.acquiredDate!.day}/${widget.acquiredDate!.year}',
                    style: TextStyle(
                      color: widget.acquiredDate == null ? AppColors.textDisabled : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: widget.acquiredDate == null ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ];
    }
  }
}
