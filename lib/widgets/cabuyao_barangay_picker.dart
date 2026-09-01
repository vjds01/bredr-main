import 'package:flutter/material.dart';

import '../services/cabuyao_barangay_service.dart';
import '../theme/app_colors.dart';

Future<String?> showCabuyaoBarangayPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _CabuyaoBarangayPicker(),
  );
}

class _CabuyaoBarangayPicker extends StatelessWidget {
  const _CabuyaoBarangayPicker();

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
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Select your barangay',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'We confirmed that you are in Cabuyao, but your device could not identify the exact barangay.',
                  style: TextStyle(color: AppColors.textGrey, height: 1.4),
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
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text('Brgy. $barangay'),
                      subtitle: const Text('Cabuyao, Laguna'),
                      onTap: () => Navigator.pop(
                        context,
                        CabuyaoBarangayService.format(barangay),
                      ),
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
