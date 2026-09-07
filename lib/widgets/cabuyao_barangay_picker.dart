import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

import '../services/cabuyao_barangay_service.dart';
import '../theme/app_colors.dart';

Future<String?> resolveDetectedCabuyaoBarangay(
  BuildContext context, {
  required double latitude,
  required double longitude,
  required double accuracyMeters,
  Placemark? placemark,
}) async {
  final detection = await CabuyaoBarangayService.detect(
    latitude: latitude,
    longitude: longitude,
    placemark: placemark,
    accuracyMeters: accuracyMeters,
  );
  if (!context.mounted) return null;
  if (!detection.needsConfirmation) return detection.suggestedLocation;

  final explanation = detection.sourcesDisagree
      ? 'Your GPS boundary and device address suggest different barangays. Please confirm the correct one.'
      : detection.hasLowAccuracy
      ? 'Your GPS accuracy is about ${accuracyMeters.round()} meters. Please confirm your barangay.'
      : 'We confirmed that you are in Cabuyao, but your device could not identify the exact barangay.';

  return showCabuyaoBarangayPicker(
    context,
    suggestedLocation: detection.suggestedLocation,
    explanation: explanation,
  );
}

Future<String?> showCabuyaoBarangayPicker(
  BuildContext context, {
  String? suggestedLocation,
  String? explanation,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => _CabuyaoBarangayPicker(
      suggestedLocation: suggestedLocation,
      explanation: explanation,
    ),
  );
}

class _CabuyaoBarangayPicker extends StatelessWidget {
  const _CabuyaoBarangayPicker({this.suggestedLocation, this.explanation});

  final String? suggestedLocation;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  suggestedLocation == null
                      ? 'Select your barangay'
                      : 'Confirm your barangay',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  explanation ??
                      'We confirmed that you are in Cabuyao, but your device could not identify the exact barangay.',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: CabuyaoBarangayService.barangays.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final barangay = CabuyaoBarangayService.barangays[index];
                    final formatted = CabuyaoBarangayService.format(barangay);
                    final isSuggested =
                        CabuyaoBarangayService.canonicalName(formatted) ==
                        CabuyaoBarangayService.canonicalName(suggestedLocation);
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text('Brgy. $barangay'),
                      subtitle: const Text('Cabuyao, Laguna'),
                      trailing: isSuggested
                          ? const Chip(label: Text('Suggested'))
                          : null,
                      onTap: () => Navigator.pop(context, formatted),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
