import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GpsLocationSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final bool isGettingLocation;
  final VoidCallback onCurrentGps;
  final VoidCallback onPickMap;

  const GpsLocationSection({
    super.key,
    required this.nameController,
    required this.latController,
    required this.lngController,
    required this.isGettingLocation,
    required this.onCurrentGps,
    required this.onPickMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GPS LOCATION (required)', style: AppText.dialogSection),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: '38.123456',
                        hintStyle: const TextStyle(color: AppColors.textDisabled),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: '-78.123456',
                        hintStyle: const TextStyle(color: AppColors.textDisabled),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: isGettingLocation ? null : onCurrentGps,
                        // no inline backgroundColor — uses AppTheme buttonBg 6A6A6A + disabled B0B0B0
                        child: isGettingLocation
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Device GPS', style: AppText.buttonSmall),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onPickMap,
                        // themed
                        child: const Text('Map GPS', style: AppText.buttonSmall),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('PLACE NAME (required)', style: AppText.dialogSection),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Great campsite',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
