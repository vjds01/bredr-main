import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';
import 'how_location_used_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';
import '../../services/cabuyao_access_service.dart';
import '../../widgets/cabuyao_barangay_picker.dart';
import '../../widgets/onboarding_background.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({
    super.key,
    this.destination,
    this.returnResult = false,
  }) : assert(destination == null || !returnResult);

  final Widget? destination;
  final bool returnResult;

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoading = false;

  Future<void> _enableLocation() async {
    setState(() => _isLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable GPS, then tap Enable Location again'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to continue'),
          ),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please allow location permission in settings, then come back',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!CabuyaoAccessService.instance.isWithinCabuyao(position)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Breedr is currently available only within Cabuyao, Laguna.',
            ),
          ),
        );
        return;
      }

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final locationName = await resolveDetectedCabuyaoBarangay(
        context,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        placemark: place,
      );
      if (locationName == null) return;

      //saving location
      LocationService.instance.latitude = position.latitude;
      LocationService.instance.longitude = position.longitude;
      LocationService.instance.accuracyMeters = position.accuracy;
      LocationService.instance.locationName = locationName;

      debugPrint("Latitude: ${position.latitude}");
      debugPrint("Longitude: ${position.longitude}");
      debugPrint("Location: '${place?.subLocality}, ${place?.locality}'");

      if (!mounted) return;

      if (widget.returnResult) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => widget.destination ?? const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Location detection error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_locationErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _locationErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('permission')) {
      return 'Location permission is required to continue.';
    }
    if (message.contains('service') || message.contains('disabled')) {
      return 'Please enable GPS, then try again.';
    }
    if (message.contains('network') || message.contains('timed out')) {
      return 'Unable to detect your location. Please check your connection and try again.';
    }
    if (message.contains('barangay-unavailable')) {
      return 'We could not identify your Cabuyao barangay. Please move to an open area and try again.';
    }

    return 'Unable to detect your location right now. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OnboardingBackground(
        safeArea: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back arrow
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 36),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 54),
                child: Text(
                  'Find pets near\nyou in Cabuyao',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.08,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              const Center(child: _MapIllustration()),
              const Spacer(flex: 3),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    _LocationButton(
                      label: _isLoading
                          ? 'Getting Location...'
                          : 'Enable Location',
                      filled: true,
                      onPressed: _isLoading ? null : _enableLocation,
                    ),
                    const SizedBox(height: 16),
                    _LocationButton(
                      label: 'Not Now',
                      filled: false,
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    widget.destination ?? const LoginScreen(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HowLocationUsedScreen(),
                        ),
                      ),
                      child: const Text(
                        'How is my location used?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 76),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  const _LocationButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }
}

class _MapIllustration extends StatelessWidget {
  const _MapIllustration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/location_permission_art.png',
      width: 285,
      height: 285,
      fit: BoxFit.contain,
    );
  }
}
