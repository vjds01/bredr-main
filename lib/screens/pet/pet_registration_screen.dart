import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../models/breed_options.dart';
import '../../models/pet_listing_data.dart';
import '../../services/location_service.dart';
import '../../services/cabuyao_barangay_service.dart';
import '../../services/pet_registration_draft_service.dart';
import 'pet_purpose_screen.dart';

class PetRegistrationScreen extends StatefulWidget {
  const PetRegistrationScreen({super.key});

  @override
  State<PetRegistrationScreen> createState() => _PetRegistrationScreenState();
}

class _PetRegistrationScreenState extends State<PetRegistrationScreen> {
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  String? _species = 'Dog';
  String? _breedSize = 'Small';
  String? _gender = 'Male';
  int _age = 1;
  String _ageUnit = 'years old';
  bool _isMixedBreed = false;
  String _primaryBreed = 'Aspin';
  String _secondaryBreed = '';
  String _selectedBarangay = '';
  File? _profilePhoto;
  final List<File> _additionalPhotos = [];
  final List<File> _additionalVideos = [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  PetListingData? _restoredDraft;
  bool _restoringDraft = true;

  @override
  void initState() {
    super.initState();
    _selectedBarangay = _canonicalLocation(
      LocationService.instance.locationName,
    );
    _selectedLatitude = LocationService.instance.latitude;
    _selectedLongitude = LocationService.instance.longitude;
    _nameCtrl.addListener(_saveDraft);
    _colorCtrl.addListener(_saveDraft);
    _aboutCtrl.addListener(_saveDraft);
    _restoreDraft();
    _resolvePetLocation();
  }

  Future<void> _resolvePetLocation() async {
    final latitude = LocationService.instance.latitude;
    final longitude = LocationService.instance.longitude;
    if (latitude == null || longitude == null) return;
    final detected = await CabuyaoBarangayService.fromCoordinates(
      latitude,
      longitude,
    );
    if (!mounted || detected == null) return;
    setState(() {
      _selectedBarangay = detected;
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });
    _saveDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await PetRegistrationDraftService.instance.loadDraft();

    if (!mounted) return;

    if (draft != null && _hasDraftContent(draft)) {
      final parsedAge = _parseAge(draft.age);

      setState(() {
        _restoredDraft = draft;
        _nameCtrl.text = draft.name;
        _colorCtrl.text = draft.color;
        _aboutCtrl.text = draft.about;
        _species = draft.species;
        _breedSize = draft.breedSize;
        _gender = draft.gender;
        _age = parsedAge.$1;
        _ageUnit = parsedAge.$2;
        _isMixedBreed = draft.isMixedBreed;
        _primaryBreed = draft.primaryBreed.isNotEmpty
            ? draft.primaryBreed
            : (draft.species == 'Cat' ? 'Puspin' : 'Aspin');
        _secondaryBreed = draft.secondaryBreed;
        final restoredLocation = _canonicalLocation(draft.locationName);
        if (_selectedBarangay.isEmpty && restoredLocation.isNotEmpty) {
          _selectedBarangay = restoredLocation;
          _selectedLatitude = draft.latitude;
          _selectedLongitude = draft.longitude;
        }
        _profilePhoto = draft.profilePhotoFile;
        _additionalPhotos
          ..clear()
          ..addAll(draft.additionalPhotoFiles);
        _additionalVideos
          ..clear()
          ..addAll(draft.additionalVideoFiles);
        _restoringDraft = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your saved pet draft was restored.')),
      );
      return;
    }

    setState(() => _restoringDraft = false);
  }

  String _canonicalLocation(String? value) {
    final barangay = CabuyaoBarangayService.canonicalName(value);
    return barangay == null ? '' : CabuyaoBarangayService.format(barangay);
  }

  bool _hasDraftContent(PetListingData draft) {
    return draft.name.isNotEmpty ||
        draft.color.isNotEmpty ||
        draft.about.isNotEmpty ||
        draft.profilePhotoFile != null ||
        draft.additionalPhotoFiles.isNotEmpty ||
        draft.additionalVideoFiles.isNotEmpty ||
        draft.purpose != null ||
        draft.healthRecords.isNotEmpty ||
        draft.interviewQuestions.isNotEmpty;
  }

  (int, String) _parseAge(String ageText) {
    final match = RegExp(r'(\d+)\s+(.+)').firstMatch(ageText);
    if (match == null) return (_age, _ageUnit);

    return (
      int.tryParse(match.group(1) ?? '') ?? _age,
      match.group(2) ?? _ageUnit,
    );
  }

  PetListingData _currentPetData() {
    return (_restoredDraft ?? const PetListingData()).copyWith(
      name: _nameCtrl.text.trim(),
      species: _species ?? 'Dog',
      breed: mixedBreedDisplayName(
        isMixedBreed: _isMixedBreed,
        primaryBreed: _primaryBreed,
        secondaryBreed: _secondaryBreed,
      ),
      primaryBreed: _primaryBreed,
      secondaryBreed: _secondaryBreed,
      isMixedBreed: _isMixedBreed,
      breedSize: _breedSize ?? 'Small',
      age: '$_age $_ageUnit',
      gender: _gender ?? 'Male',
      color: _colorCtrl.text.trim(),
      about: _aboutCtrl.text.trim(),
      locationName: _selectedBarangay,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
      profilePhotoFile: _profilePhoto,
      additionalPhotoFiles: List<File>.from(_additionalPhotos),
      additionalVideoFiles: List<File>.from(_additionalVideos),
    );
  }

  Future<void> _saveDraft() async {
    if (_restoringDraft) return;
    await PetRegistrationDraftService.instance.saveDraft(_currentPetData());
  }

  void _addAdditionalMedia(List<File> files) {
    if (files.isEmpty) return;

    final remaining = 10 - _additionalPhotos.length - _additionalVideos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 10 additional photos or videos.'),
        ),
      );
      return;
    }

    final selected = files.take(remaining).toList();
    final acceptedPhotos = <File>[];
    final acceptedVideos = <File>[];
    var hasCoverPhoto = _additionalPhotos.isNotEmpty;
    var rejectedLargeVideo = false;
    var rejectedVideoCover = false;
    for (final file in selected) {
      final isVideo = file.path.toLowerCase().endsWith('.mp4');
      if (isVideo) {
        if (file.lengthSync() > 50 * 1024 * 1024) {
          rejectedLargeVideo = true;
          continue;
        }
        if (!hasCoverPhoto) {
          rejectedVideoCover = true;
          continue;
        }
        acceptedVideos.add(file);
      } else {
        acceptedPhotos.add(file);
        hasCoverPhoto = true;
      }
    }

    setState(() {
      _additionalPhotos.addAll(acceptedPhotos);
      _additionalVideos.addAll(acceptedVideos);
    });
    _saveDraft();

    if (rejectedVideoCover) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The first additional upload must be a cover photo.'),
        ),
      );
    } else if (rejectedLargeVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Videos must be 50 MB or smaller.')),
      );
    }

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

  void _removeAdditionalPhoto(File file) {
    setState(() => _additionalPhotos.remove(file));
    _saveDraft();
  }

  void _removeAdditionalVideo(File file) {
    setState(() => _additionalVideos.remove(file));
    _saveDraft();
  }

  Future<bool> _confirmExit() async {
    final hasInput = _hasDraftContent(_currentPetData());
    if (!hasInput) return true;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this pet draft?'),
        content: const Text('You can continue filling this pet profile later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );

    if (action == 'discard') {
      await PetRegistrationDraftService.instance.clearDraft();
      return true;
    }

    if (action == 'save') {
      await _saveDraft();
      return true;
    }

    return false;
  }

  void _showBreedPicker({required bool secondary}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BreedPickerSheet(
        selected: secondary ? _secondaryBreed : _primaryBreed,
        species: _species ?? 'Dog',
        onSelect: (b) => setState(() {
          if (secondary) {
            _secondaryBreed = b;
          } else {
            _primaryBreed = b;
            if (_secondaryBreed == b) _secondaryBreed = '';
          }
          _saveDraft();
        }),
      ),
    );
  }

  void _selectSpecies(String? species) {
    if (species == null) return;

    setState(() {
      _species = species;
      _primaryBreed = species == 'Cat' ? 'Puspin' : 'Aspin';
      _secondaryBreed = '';
    });
    _saveDraft();
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        current: _selectedBarangay,
        onSelect: (b) async {
          setState(() => _selectedBarangay = b);
          final coordinates =
              await CabuyaoBarangayService.representativeCoordinatesFor(b);
          if (coordinates != null && mounted) {
            setState(() {
              _selectedLatitude = coordinates.$1;
              _selectedLongitude = coordinates.$2;
            });
          }
          _saveDraft();
        },
      ),
    );
  }

  void _goNext() {
    if (_profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a pet profile photo.')),
      );
      return;
    }

    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your pet's name.")),
      );
      return;
    }

    if (!CabuyaoBarangayService.isCanonicalLocation(_selectedBarangay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your Cabuyao barangay.')),
      );
      return;
    }

    if (_primaryBreed.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your pet's breed.")),
      );
      return;
    }

    if (_colorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your pet's color or markings."),
        ),
      );
      return;
    }

    if (_aboutCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the About Your Pet field.'),
        ),
      );
      return;
    }

    final petData = _currentPetData();
    PetRegistrationDraftService.instance.saveDraft(petData);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetPurposeScreen(petData: petData)),
    );
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_saveDraft);
    _colorCtrl.removeListener(_saveDraft);
    _aboutCtrl.removeListener(_saveDraft);
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (await _confirmExit() && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 5-step progress bar
                      _PetStepBar(currentStep: 1),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Step 1 of 5',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
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
                                    'Register New Pet',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Tell us about your pet so others can get to know them better. Accurate details help ensure better matches and responsible connections with potential adopters.',
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
                      _PetPhotoUpload(
                        initialImage: _profilePhoto,
                        onImageSelected: (file) {
                          setState(() => _profilePhoto = file);
                          _saveDraft();
                        },
                      ),
                      const SizedBox(height: 20),
                      // NAME
                      _FieldLabel('NAME'),
                      const SizedBox(height: 8),
                      _InputField(
                        controller: _nameCtrl,
                        hint: 'Enter your pet name...',
                        prefixIcon: Icons.pets,
                      ),
                      const SizedBox(height: 20),
                      // LOCATION
                      _FieldLabel('LOCATION'),
                      const SizedBox(height: 8),
                      _LocationCard(
                        barangay: _selectedBarangay,
                        onChangeTap: _showLocationPicker,
                      ),
                      const SizedBox(height: 6),
                      _InfoNote(
                        'This is your current barangay. You can change it if your pet is in another area',
                      ),
                      const SizedBox(height: 20),
                      // SPECIES
                      _FieldLabel('SPECIES'),
                      const SizedBox(height: 8),
                      _ChipGroup(
                        options: const ['Dog', 'Cat'],
                        selected: _species,
                        onSelect: _selectSpecies,
                      ),
                      const SizedBox(height: 20),
                      // SELECT YOUR PET BREED
                      _FieldLabel('BREED TYPE'),
                      const SizedBox(height: 8),
                      _ChipGroup(
                        options: const ['Purebred', 'Mixed Breed'],
                        selected: _isMixedBreed ? 'Mixed Breed' : 'Purebred',
                        onSelect: (v) {
                          setState(() {
                            _isMixedBreed = v == 'Mixed Breed';
                            if (!_isMixedBreed) _secondaryBreed = '';
                          });
                          _saveDraft();
                        },
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(
                        _isMixedBreed
                            ? 'PRIMARY BREED'
                            : 'SELECT YOUR PET BREED',
                      ),
                      const SizedBox(height: 8),
                      _BreedField(
                        value: _primaryBreed,
                        onTap: () => _showBreedPicker(secondary: false),
                      ),
                      if (_isMixedBreed) ...[
                        const SizedBox(height: 12),
                        _FieldLabel('SECONDARY BREED'),
                        const SizedBox(height: 8),
                        _BreedField(
                          value: _secondaryBreed.isEmpty
                              ? 'Optional secondary breed'
                              : _secondaryBreed,
                          muted: _secondaryBreed.isEmpty,
                          onTap: () => _showBreedPicker(secondary: true),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // BREED SIZE
                      _FieldLabel('BREED SIZE'),
                      const SizedBox(height: 8),
                      _ChipGroup(
                        options: const ['Small', 'Medium', 'Large'],
                        selected: _breedSize,
                        onSelect: (v) {
                          setState(() => _breedSize = v);
                          _saveDraft();
                        },
                      ),
                      const SizedBox(height: 20),
                      // AGE
                      _FieldLabel('AGE'),
                      const SizedBox(height: 8),
                      _AgeSelector(
                        age: _age,
                        unit: _ageUnit,
                        onAgeChanged: (v) {
                          setState(() => _age = v);
                          _saveDraft();
                        },
                        onUnitChanged: (v) {
                          setState(() => _ageUnit = v);
                          _saveDraft();
                        },
                      ),
                      const SizedBox(height: 20),
                      // GENDER
                      _FieldLabel('GENDER'),
                      const SizedBox(height: 8),
                      _GenderSelector(
                        selected: _gender,
                        onSelect: (v) {
                          setState(() => _gender = v);
                          _saveDraft();
                        },
                      ),
                      const SizedBox(height: 20),
                      // COLOR / MARKINGS
                      _FieldLabel('COLOR / MARKINGS'),
                      const SizedBox(height: 8),
                      _InputField(
                        controller: _colorCtrl,
                        hint: 'e.g. Golden, White & Brown',
                        prefixIcon: Icons.palette_outlined,
                      ),
                      const SizedBox(height: 20),
                      // ABOUT YOUR PET
                      _FieldLabel('ABOUT YOUR PET'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aboutCtrl,
                        maxLines: 4,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tell something about your pet...',
                          hintStyle: const TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // UPLOAD ADDITIONAL PHOTOS / VIDEOS
                      Row(
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Color(0xFF444444),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'UPLOAD ADDITIONAL PHOTOS/VIDEOS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF444444),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_additionalPhotos.length + _additionalVideos.length} / 10',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _PetAdditionalPhotosCard(
                        photos: _additionalPhotos,
                        videos: _additionalVideos,
                        onMediaSelected: _addAdditionalMedia,
                        onRemovePhoto: _removeAdditionalPhoto,
                        onRemoveVideo: _removeAdditionalVideo,
                      ),
                      const SizedBox(height: 8),
                      _InfoNote(
                        'Add up to 10 photos or MP4 videos. The first additional upload is the cover photo and must be an image. Videos must be 50 MB or smaller.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Continue button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
                      'Continue to next step →',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<File?> _pickImageFile(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return null;
    return File(path);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open files. Please try again.'),
        ),
      );
    }
    return null;
  }
}

Future<List<File>> _pickAdditionalMediaFiles(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return const [];

    return result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .map(File.new)
        .toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open files. Please try again.'),
        ),
      );
    }
    return const [];
  }
}

// ── Widgets ───────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF444444),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF444444)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE8EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 13,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFFBBBBBB), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isSelected = selected == o;
        return GestureDetector(
          onTap: () => onSelect(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFDDDDDD),
              ),
            ),
            child: Text(
              o,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF444444),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const _GenderSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GenderChip(
          label: 'Male',
          icon: Icons.male,
          selected: selected == 'Male',
          onTap: () => onSelect('Male'),
        ),
        const SizedBox(width: 12),
        _GenderChip(
          label: 'Female',
          icon: Icons.female,
          selected: selected == 'Female',
          onTap: () => onSelect('Female'),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFDDDDDD),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgeSelector extends StatelessWidget {
  final int age;
  final String unit;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<String> onUnitChanged;
  const _AgeSelector({
    required this.age,
    required this.unit,
    required this.onAgeChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number stepper
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () {
                  if (age > 1) onAgeChanged(age - 1);
                },
                color: AppColors.primary,
              ),
              Text(
                '$age',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => onAgeChanged(age + 1),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Unit selector
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ['years old', 'months old', 'weeks old'].map((u) {
            final sel = unit == u;
            return GestureDetector(
              onTap: () => onUnitChanged(u),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  u,
                  style: TextStyle(
                    fontSize: 13,
                    color: sel ? AppColors.primary : const Color(0xFF888888),
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String barangay;
  final VoidCallback onChangeTap;
  const _LocationCard({required this.barangay, required this.onChangeTap});

  @override
  Widget build(BuildContext context) {
    final parts = barangay.split(',');
    final line1 = parts[0].trim();
    final line2 = parts.length > 1 ? parts[1].trim() : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Current Location',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8EA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Auto Detected',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line1,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          if (line2.isNotEmpty)
            Text(
              line2,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onChangeTap,
              icon: const Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Change Barangay',
                style: TextStyle(fontSize: 13, color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pet profile photo upload with dashed border + dog+camera icon
class _PetPhotoUpload extends StatefulWidget {
  final ValueChanged<File> onImageSelected;
  final File? initialImage;

  const _PetPhotoUpload({required this.onImageSelected, this.initialImage});

  @override
  State<_PetPhotoUpload> createState() => _PetPhotoUploadState();
}

class _PetPhotoUploadState extends State<_PetPhotoUpload> {
  File? _image;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
  }

  @override
  void didUpdateWidget(covariant _PetPhotoUpload oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImage?.path != oldWidget.initialImage?.path) {
      _image = widget.initialImage;
    }
  }

  Future<void> _pickCamera() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xFile != null) {
      _setImage(File(xFile.path));
    }
  }

  Future<void> _pickFile() async {
    final file = await _pickImageFile(context);
    if (file != null) _setImage(file);
  }

  void _setImage(File file) {
    setState(() => _image = file);
    widget.onImageSelected(file);
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
            if (_image != null)
              ClipOval(
                child: Image.file(
                  _image!,
                  width: 80,
                  height: 80,
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: const [
                    Center(
                      child: Icon(Icons.pets, color: Colors.white, size: 42),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 44,
              child: ElevatedButton(
                onPressed: _pickFile,
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
                onPressed: _pickCamera,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
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
            const SizedBox(height: 12),
            const Text(
              'Add in .png & .jpg format only — max 5 mb',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Additional photos stacked card carousel
class _PetAdditionalPhotosCard extends StatelessWidget {
  final List<File> photos;
  final List<File> videos;
  final ValueChanged<List<File>> onMediaSelected;
  final ValueChanged<File> onRemovePhoto;
  final ValueChanged<File> onRemoveVideo;

  const _PetAdditionalPhotosCard({
    required this.photos,
    required this.videos,
    required this.onMediaSelected,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    final mediaCount = photos.length + videos.length;
    final itemCount = mediaCount < 10 ? mediaCount + 1 : mediaCount;

    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final isAddTile = index == mediaCount && mediaCount < 10;
          final isPhoto = index < photos.length;

          return SizedBox(
            width: 220,
            child: isAddTile
                ? _PetDashedCard(onMediaSelected: onMediaSelected)
                : isPhoto
                ? _PetAdditionalPhotoPreview(
                    photo: photos[index],
                    onRemove: () => onRemovePhoto(photos[index]),
                  )
                : _PetAdditionalVideoPreview(
                    video: videos[index - photos.length],
                    onRemove: () =>
                        onRemoveVideo(videos[index - photos.length]),
                  ),
          );
        },
      ),
    );
  }
}

class _PetAdditionalPhotoPreview extends StatelessWidget {
  final File photo;
  final VoidCallback onRemove;

  const _PetAdditionalPhotoPreview({
    required this.photo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _RemovableMediaPreview(
      onRemove: onRemove,
      child: Image.file(photo, fit: BoxFit.cover),
    );
  }
}

class _PetAdditionalVideoPreview extends StatelessWidget {
  final File video;
  final VoidCallback onRemove;

  const _PetAdditionalVideoPreview({
    required this.video,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _RemovableMediaPreview(
      onRemove: onRemove,
      child: Container(
        color: const Color(0xFF333333),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
            const SizedBox(height: 12),
            Text(
              video.uri.pathSegments.last,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemovableMediaPreview extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;

  const _RemovableMediaPreview({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Remove media',
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetDashedCard extends StatefulWidget {
  final ValueChanged<List<File>> onMediaSelected;

  const _PetDashedCard({required this.onMediaSelected});

  @override
  State<_PetDashedCard> createState() => _PetDashedCardState();
}

class _PetDashedCardState extends State<_PetDashedCard> {
  Future<void> _pickCamera() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xFile != null) {
      widget.onMediaSelected([File(xFile.path)]);
    }
  }

  Future<void> _pickFile() async {
    final files = await _pickAdditionalMediaFiles(context);
    if (files.isNotEmpty) widget.onMediaSelected(files);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: CustomPaint(
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
                          child: Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _pickFile,
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
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
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
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
                  const SizedBox(height: 12),
                  const Text(
                    'JPG/PNG images or MP4 videos\nVideos: max 50 MB',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 5-step progress bar
class _PetStepBar extends StatelessWidget {
  final int currentStep;
  const _PetStepBar({required this.currentStep});

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
                const SizedBox(width: 28),
                Expanded(child: _StepLine(active: currentStep > 1)),
                const SizedBox(width: 56),
                Expanded(child: _StepLine(active: currentStep > 2)),
                const SizedBox(width: 56),
                Expanded(child: _StepLine(active: currentStep > 3)),
                const SizedBox(width: 56),
                Expanded(child: _StepLine(active: currentStep > 4)),
                const SizedBox(width: 28),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 1; i <= 5; i++)
                _StepDot(step: i, current: currentStep),
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
      width: 44,
      height: 44,
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
      child: Icon(
        Icons.pets,
        size: 22,
        color: isActive ? Colors.white : const Color(0xFFFFB3C1),
      ),
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
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + dashW).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dashW + gapW;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Breed Picker Bottom Sheet ─────────────────────────────────────

class _BreedPickerSheet extends StatefulWidget {
  final String selected;
  final String species;
  final ValueChanged<String> onSelect;
  const _BreedPickerSheet({
    required this.selected,
    required this.species,
    required this.onSelect,
  });

  @override
  State<_BreedPickerSheet> createState() => _BreedPickerSheetState();
}

class _BreedPickerSheetState extends State<_BreedPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_BreedItem> get _filtered {
    final query = _query.trim().toLowerCase();
    return breedNamesForSpecies(widget.species)
        .where((breed) => query.isEmpty || breed.toLowerCase().contains(query))
        .map((breed) => _BreedItem(breed, widget.species))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Select Breed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      widget.onSelect(_selected);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD5)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search breed name...',
                    hintStyle: TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _query.isEmpty
                      ? 'Showing ${widget.species.toLowerCase()} breeds'
                      : '${_filtered.length} RESULTS FOUND',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ),
            // List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE0E6)),
                ),
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: Color(0xFFFFE0E6),
                    indent: 16,
                  ),
                  itemBuilder: (_, i) {
                    final b = _filtered[i];
                    final isSelected = _selected == b.name;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFE0E6),
                        child: Icon(
                          b.species == 'Cat' ? Icons.cruelty_free : Icons.pets,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: _HighlightText(text: b.name, query: _query),
                      subtitle: Text(
                        b.species,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            )
                          : Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFDDDDDD),
                                  width: 1.5,
                                ),
                              ),
                            ),
                      onTap: () => setState(() => _selected = b.name),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _BreedItem {
  final String name;
  final String species;
  const _BreedItem(this.name, this.species);
}

class _BreedField extends StatelessWidget {
  final String value;
  final bool muted;
  final VoidCallback onTap;

  const _BreedField({
    required this.value,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.pets, color: Color(0xFFBBBBBB), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: muted
                      ? const Color(0xFF999999)
                      : const Color(0xFF333333),
                ),
              ),
            ),
            const Icon(Icons.search, color: Color(0xFFBBBBBB), size: 20),
          ],
        ),
      ),
    );
  }
}

// Highlights matching text in search results
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      );
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx < 0) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// ── Location Picker Bottom Sheet ──────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _LocationPickerSheet({required this.current, required this.onSelect});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late String _selected;

  static final _barangays = CabuyaoBarangayService.barangays
      .map(_BarangayItem.new)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_BarangayItem> get _filtered => _query.isEmpty
      ? _barangays
      : _barangays
            .where((b) => b.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Change Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      widget.onSelect(_selected);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD5)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter barangay...',
                    hintStyle: TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _query.isEmpty
                      ? 'Showing result for "barangay" across all barangay'
                      : 'Showing result for "$_query" across all barangay',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ),
            // List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE0E6)),
                ),
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: Color(0xFFFFE0E6),
                    indent: 16,
                  ),
                  itemBuilder: (_, i) {
                    final b = _filtered[i];
                    final isCurrent =
                        CabuyaoBarangayService.format(b.name) == _selected;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE0E0E0),
                        child: const Icon(
                          Icons.location_city,
                          color: Color(0xFF888888),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            'Brgy. ${b.name}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DA1F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cabuyao, Laguna',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        widget.onSelect(CabuyaoBarangayService.format(b.name));
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _BarangayItem {
  final String name;
  const _BarangayItem(this.name);
}
