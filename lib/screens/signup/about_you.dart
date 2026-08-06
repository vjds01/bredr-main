import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import 'review_profile.dart';
import '../../models/onboarding_data.dart';
import '../../services/location_service.dart';

class Step2ReviewProfile extends StatefulWidget {
  final OnboardingData onboardingData;
  const Step2ReviewProfile({
    super.key,
    required this.onboardingData,
  });

  @override
  State<Step2ReviewProfile> createState() => _Step2ReviewProfileState();
}

class _Step2ReviewProfileState extends State<Step2ReviewProfile> {
  bool _childrenAtHome = false;
  bool _otherPetsAtHome = true;
  String? _selectedHomeType;
  final _aboutCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _isDetectingLocation = false;
  double? _latitude;
  double? _longitude;

  File? _profilePhoto;
  List<File> _additionalPhotosFiles = [];

  final _homeTypes = [
    'House with Yard',
    'Farm',
    'Apartment / Condo',
    'Townhouse',
    'House (No Yard)',
  ];

  @override
  void initState() {
    super.initState();

    _locationCtrl.text =
        widget.onboardingData.locationName ??
        LocationService.instance.locationName ??
        '';
    _latitude =
        widget.onboardingData.latitude ?? LocationService.instance.latitude;
    _longitude =
        widget.onboardingData.longitude ?? LocationService.instance.longitude;

    debugPrint(
        'Step2 Location: ${LocationService.instance.locationName}');
    debugPrint(
        'Step2 Lat: ${LocationService.instance.latitude}');
    debugPrint(
        'Step2 Lng: ${LocationService.instance.longitude}');
  }

  @override
  void dispose() {
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable GPS, then tap Detect again.'),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to continue.'),
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
              'Please allow location permission in settings, then try again.',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final locationName = _locationNameFromPlacemark(
        placemarks.isNotEmpty ? placemarks.first : null,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationCtrl.text = locationName;
      });

      LocationService.instance.latitude = position.latitude;
      LocationService.instance.longitude = position.longitude;
      LocationService.instance.locationName = locationName;
    } catch (e) {
      debugPrint('Onboarding location detection error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_locationErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  String _locationNameFromPlacemark(Placemark? place) {
    if (place == null) return 'Detected location';

    final parts = [
      place.subLocality,
      place.locality,
      place.administrativeArea,
    ]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .toList();

    return parts.isEmpty ? 'Detected location' : parts.toSet().join(', ');
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

    return 'Unable to detect your location right now. Please try again.';
  }

  void _goNext() {

  debugPrint(
    'Profile photo: ${_profilePhoto?.path}',
  );

  debugPrint(
    'Additional photos: ${_additionalPhotosFiles.length}',
  );
  
  final locationName = _locationCtrl.text.trim();
  if (locationName.isEmpty || _latitude == null || _longitude == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please detect your location before continuing.'),
      ),
    );
    return;
  }

  final updatedData = widget.onboardingData.copyWith(
    bio: _aboutCtrl.text.trim(),
    homeType: _selectedHomeType,
    childrenAtHome: _childrenAtHome,
    otherPetsAtHome: _otherPetsAtHome,
    locationName: locationName,
    latitude: _latitude,
    longitude: _longitude,

    profilePhotoFile: _profilePhoto,
    additionalPhotoFiles: _additionalPhotosFiles,
  );

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Step3Welcome(
        onboardingData: updatedData,
      ),
    ),
  );
}

  void _addAdditionalPhotos(List<File> files) {
    if (files.isEmpty) return;

    final remaining = 10 - _additionalPhotosFiles.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 10 additional photos.')),
      );
      return;
    }

    final selected = files.take(remaining).toList();
    setState(() => _additionalPhotosFiles.addAll(selected));

    if (files.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $remaining more photo${remaining == 1 ? '' : 's'} can be added. Extra photos were skipped.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back arrow
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppColors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Step progress bar
                    _StepProgressBar(currentStep: 2),

                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Step 2 of 3',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Left accent bar + title block
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'About you',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tell us a bit about yourself. This helps adopters and breeders understand your living situation and experience with pets.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF666666),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // UPLOAD PROFILE PHOTO
                    _SectionHeader(
                      icon: Icons.image_outlined,
                      label: 'UPLOAD PROFILE PHOTO',
                    ),
                    const SizedBox(height: 10),
                    _ProfilePhotoUpload(
                      image: _profilePhoto,
                      onImageSelected: (file) {
                        setState(() {
                          _profilePhoto = file;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // YOUR LOCATION
                    _SectionHeader(
                      icon: Icons.location_on_outlined,
                      label: 'YOUR LOCATION',
                    ),
                    const SizedBox(height: 10),
                    _LocationField(
                      controller: _locationCtrl,
                      isDetecting: _isDetectingLocation,
                      onDetectLocation: _detectLocation,
                    ),
                    const SizedBox(height: 6),
                    _InfoNote(
                        'Only your barangay is shown to others. Your exact address is never shared.'),

                    const SizedBox(height: 20),

                    // TYPE OF HOME
                    _SectionHeader(
                      icon: Icons.home_outlined,
                      label: 'TYPE OF HOME',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _homeTypes.map((type) {
                        final selected = _selectedHomeType == type;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedHomeType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xFFDDDDDD),
                              ),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF444444),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    _InfoNote(
                        'Helps match you with pets suited to your living space.'),

                    const SizedBox(height: 20),

                    // HOUSEHOLD
                    _SectionHeader(
                      icon: Icons.house_outlined,
                      label: 'HOUSEHOLD',
                    ),
                    const SizedBox(height: 10),
                    _ToggleRow(
                      title: 'Children at home',
                      subtitle: 'Help match kid-friendly pets',
                      value: _childrenAtHome,
                      onChanged: (v) =>
                          setState(() => _childrenAtHome = v),
                    ),
                    _ToggleRow(
                      title: 'Other pets at home',
                      subtitle: 'Help match pet-friendly pets',
                      value: _otherPetsAtHome,
                      onChanged: (v) =>
                          setState(() => _otherPetsAtHome = v),
                    ),

                    const SizedBox(height: 20),

                    // ABOUT ME
                    _SectionHeader(
                      icon: Icons.notes_outlined,
                      label: 'ABOUT ME',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aboutCtrl,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF333333)),
                      decoration: InputDecoration(
                        hintText: 'Tell something about yourself...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFBBBBBB), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // UPLOAD ADDITIONAL PHOTOS
                    Row(
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            color: Color(0xFF444444), size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'UPLOAD ADDITIONAL PHOTOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF444444),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_additionalPhotosFiles.length} / 10',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Additional photos carousel card
                    _AdditionalPhotosCard(
                      photos: _additionalPhotosFiles,
                      onImagesSelected: _addAdditionalPhotos,
                    ),

                    const SizedBox(height: 8),
                    _InfoNote(
                        'You may also add up to 10 additional photos of yourself, your home, or your pets. The first upload will be set as the background of your profile.'),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Continue to next step - pinned bottom
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF444444), size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF444444),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;

  const _InfoNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF888888),
        height: 1.35,
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDetecting;
  final VoidCallback onDetectLocation;

  const _LocationField({
    required this.controller,
    required this.isDetecting,
    required this.onDetectLocation,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
        hintText: 'Tap Detect to set your location',
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: isDetecting ? null : onDetectLocation,
            icon: isDetecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 16),
            label: Text(isDetecting ? 'Detecting' : 'Detect'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoUpload extends StatefulWidget {
  final File? image;
  final ValueChanged<File> onImageSelected;

  const _ProfilePhotoUpload({
    required this.image,
    required this.onImageSelected,
  });

  @override
  State<_ProfilePhotoUpload> createState() => _ProfilePhotoUploadState();
}

class _ProfilePhotoUploadState extends State<_ProfilePhotoUpload> {
  Future<void> _pick(ImageSource source) async {
    final xFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
    );

    if (xFile != null) {
      widget.onImageSelected(File(xFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: _DashedRectPainter(
          color: AppColors.primary,
          radius: 16,
          dashW: 6,
          gapW: 5,
        ),
        child: Column(
          children: [
            if (widget.image != null)
              ClipOval(
                child: Image.file(
                  widget.image!,
                  width: 86,
                  height: 86,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8A9A), Color(0xFFFF4D6D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _pick(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'UPLOAD A PHOTO',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              height: 44,
              child: OutlinedButton(
                onPressed: () => _pick(ImageSource.camera),
                style: OutlinedButton.styleFrom(
                  side:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'TAKE A PHOTO',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Additional photos horizontal carousel
class _AdditionalPhotosCard extends StatelessWidget {
  final List<File> photos;
  final ValueChanged<List<File>> onImagesSelected;

  const _AdditionalPhotosCard({
    required this.photos,
    required this.onImagesSelected,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = photos.length < 10 ? photos.length + 1 : photos.length;

    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final isAddTile = index == photos.length && photos.length < 10;

          return SizedBox(
            width: 220,
            child: isAddTile
                ? _AdditionalPhotoUploadTile(onImagesSelected: onImagesSelected)
                : _AdditionalPhotoPreview(photo: photos[index]),
          );
        },
      ),
    );
  }
}

class _AdditionalPhotoPreview extends StatelessWidget {
  final File photo;

  const _AdditionalPhotoPreview({
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.file(
        photo,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _AdditionalPhotoUploadTile extends StatefulWidget {
  final ValueChanged<List<File>> onImagesSelected;

  const _AdditionalPhotoUploadTile({
    required this.onImagesSelected,
  });

  @override
  State<_AdditionalPhotoUploadTile> createState() =>
      _AdditionalPhotoUploadTileState();
}

class _AdditionalPhotoUploadTileState extends State<_AdditionalPhotoUploadTile> {
  Future<void> _pickGallery() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 75);
    if (picked.isEmpty) return;

    widget.onImagesSelected(
      picked.map((image) => File(image.path)).toList(),
    );
  }

  Future<void> _pickCamera() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );

    if (xFile != null) {
      widget.onImagesSelected([File(xFile.path)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: const Color(0xFF888888),
        radius: 18,
        dashW: 7,
        gapW: 5,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A9A), Color(0xFFFF4D6D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: const [
                  Center(
                    child: Icon(Icons.person, color: Colors.white, size: 38),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child:
                        Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _pickGallery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'UPLOAD',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: _pickCamera,
                style: OutlinedButton.styleFrom(
                  side:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'TAKE A PHOTO',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Dashed border painter
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashW;
  final double gapW;

  const _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.dashW,
    required this.gapW,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashW).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashW + gapW;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Step progress bar (reused from step1)
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(child: _StepLine(active: currentStep > 1)),
                const SizedBox(width: 72),
                Expanded(child: _StepLine(active: currentStep > 2)),
                const SizedBox(width: 36),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepDot(step: 1, current: currentStep),
              const Spacer(),
              _StepDot(step: 2, current: currentStep),
              const Spacer(),
              _StepDot(step: 3, current: currentStep),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final int current;
  const _StepDot({required this.step, required this.current});

  @override
  Widget build(BuildContext context) {
    final isActive = step <= current;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : const Color(0xFFFFF0F5),
        border: Border.all(
          color: isActive ? AppColors.primary : const Color(0xFFFFB3C1),
          width: isActive ? 0 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Icon(Icons.pets,
          size: 26,
          color: isActive ? Colors.white : const Color(0xFFFFB3C1)),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : const Color(0xFFFFCDD5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
