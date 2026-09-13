import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/breed_options.dart';
import '../../services/cabuyao_barangay_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/pet_media_validation_service.dart';
import '../../services/pet_eligibility_policy.dart';
import '../../services/pet_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../../widgets/breedr_video_card.dart';
import 'adoption_interview_screen.dart';

class EditPetListingScreen extends StatefulWidget {
  const EditPetListingScreen({
    super.key,
    required this.petId,
    required this.petData,
  });

  final String petId;
  final Map<String, dynamic> petData;

  @override
  State<EditPetListingScreen> createState() => _EditPetListingScreenState();
}

class _EditAgeSelector extends StatelessWidget {
  const _EditAgeSelector({
    required this.age,
    required this.unit,
    required this.onAgeChanged,
    required this.onUnitChanged,
  });

  final int age;
  final String unit;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final maximum = PetEligibilityPolicy.maxForUnit(unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AGE',
          style: TextStyle(fontSize: 12, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Decrease age',
                    onPressed: age > 1 ? () => onAgeChanged(age - 1) : null,
                    icon: const Icon(
                      Icons.remove,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$age',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Increase age',
                    onPressed: age < maximum
                        ? () => onAgeChanged(age + 1)
                        : null,
                    icon: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: PetAgeValue.units.map((value) {
                final selected = value == unit;
                return InkWell(
                  onTap: () => onUnitChanged(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFF888888),
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditPetListingScreenState extends State<EditPetListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _colorController;
  late final TextEditingController _aboutController;
  late final TextEditingController _priceController;

  late String _species;
  late String _breedSize;
  late String _gender;
  late int _age;
  late String _ageUnit;
  late String _primaryBreed;
  late String _secondaryBreed;
  late bool _isMixedBreed;
  late String _barangay;
  late String _purpose;
  late String _adoptionType;
  late bool _noOtherPets;
  late bool _priceNegotiable;
  late bool _sameBreedOnly;
  late bool _vetVerifiedOnly;

  late String _profilePhotoUrl;
  File? _newProfilePhoto;
  late List<String> _existingImages;
  late List<String> _existingVideos;
  final List<File> _newImages = [];
  final List<File> _newVideos = [];
  late List<Map<String, dynamic>> _questions;
  bool _questionsDirty = false;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.petData;
    final adoption = _map(data['adoptionDetails']);
    final breeding = _map(data['breedingPreferences']);
    _nameController = TextEditingController(text: _text(data['name']));
    final parsedAge = PetAgeValue.tryParse(_text(data['age']));
    _age = parsedAge?.value ?? 1;
    _ageUnit = parsedAge?.unit ?? 'years old';
    _colorController = TextEditingController(text: _text(data['color']));
    _aboutController = TextEditingController(text: _text(data['about']));
    _priceController = TextEditingController(
      text: _number(adoption['price'] ?? data['price']).toStringAsFixed(0),
    );
    _species = _text(data['species'], fallback: 'Dog');
    if (_species != 'Cat') _species = 'Dog';
    _breedSize = _text(data['breedSize'], fallback: 'Small');
    _gender = _text(data['gender'], fallback: 'Male');
    _isMixedBreed = data['isMixedBreed'] == true;
    _primaryBreed = _text(
      data['primaryBreed'],
      fallback: _text(
        data['breed'],
        fallback: _species == 'Cat' ? 'Puspin' : 'Aspin',
      ),
    );
    _secondaryBreed = _text(data['secondaryBreed']);
    _barangay =
        CabuyaoBarangayService.canonicalName(_text(data['locationName'])) ??
        CabuyaoBarangayService.barangays.first;
    _purpose = _text(
      data['normalizedPurpose'] ?? data['purpose'],
      fallback: 'adoption',
    ).toLowerCase();
    _adoptionType = _text(
      adoption['adoptionType'] ?? data['adoptionType'],
      fallback: 'FREE',
    ).toUpperCase();
    _noOtherPets = (adoption['noOtherPets'] ?? data['noOtherPets']) != false;
    _priceNegotiable =
        (adoption['priceNegotiable'] ?? data['priceNegotiable']) != false;
    _sameBreedOnly = breeding['sameBreedOnly'] != false;
    _vetVerifiedOnly = breeding['vetVerifiedOnly'] != false;
    _profilePhotoUrl = _text(data['petProfilePhoto'] ?? data['profilePhoto']);
    _existingImages = _stringList(data['additionalImages']);
    _existingVideos = _stringList(data['additionalVideos']);
    _questions = _mapList(data['interviewQuestions']);

    for (final controller in [
      _nameController,
      _colorController,
      _aboutController,
      _priceController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _aboutController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  void _change(VoidCallback action) {
    setState(() {
      action();
      _dirty = true;
    });
  }

  String get _requiredPartnerGender =>
      _gender.toLowerCase() == 'male' ? 'Female' : 'Male';

  Future<bool> _canLeave() async {
    if (_saving) return false;
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text('Your edits have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<File?> _pickSingleImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    final file = File(path);
    final error = await _imageError(file);
    if (error != null) {
      _showMessage(error);
      return null;
    }
    return file;
  }

  Future<String?> _imageError(File file) async {
    if (!PetMediaValidation.isImagePath(file.path)) {
      return 'Only JPG, JPEG, and PNG images are allowed.';
    }
    if (!PetMediaValidation.isImageSizeAllowed(await file.length())) {
      return 'Each image must be 5 MB or smaller.';
    }
    return null;
  }

  Future<void> _replaceProfilePhoto() async {
    try {
      final file = await _pickSingleImage();
      if (file != null) _change(() => _newProfilePhoto = file);
    } catch (_) {
      _showMessage('Unable to open your photos. Please try again.');
    }
  }

  Future<void> _addMedia() async {
    final remaining =
        10 -
        _existingImages.length -
        _existingVideos.length -
        _newImages.length -
        _newVideos.length;
    if (remaining <= 0) {
      _showMessage('You can upload up to 10 additional photos or videos.');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4'],
        allowMultiple: true,
        withData: false,
      );
      if (result == null) return;
      final files = result.paths.whereType<String>().map(File.new).toList();
      final acceptedImages = <File>[];
      final acceptedVideos = <File>[];
      var hasCover = _existingImages.isNotEmpty || _newImages.isNotEmpty;
      String? rejection;
      for (final file in files.take(remaining)) {
        if (!PetMediaValidation.isAllowedMediaPath(file.path)) {
          rejection = 'Only JPG, JPEG, PNG, and MP4 files are allowed.';
          continue;
        }
        if (PetMediaValidation.isImagePath(file.path)) {
          final error = await _imageError(file);
          if (error != null) {
            rejection = error;
            continue;
          }
          acceptedImages.add(file);
          hasCover = true;
        } else {
          if (!PetMediaValidation.isVideoSizeAllowed(await file.length())) {
            rejection = 'Videos must be 50 MB or smaller.';
            continue;
          }
          if (!hasCover) {
            rejection = 'The first additional upload must be a cover photo.';
            continue;
          }
          acceptedVideos.add(file);
        }
      }
      if (acceptedImages.isNotEmpty || acceptedVideos.isNotEmpty) {
        _change(() {
          _newImages.addAll(acceptedImages);
          _newVideos.addAll(acceptedVideos);
        });
      }
      if (files.length > remaining) {
        rejection = 'Only $remaining more media file(s) could be added.';
      }
      if (rejection != null) _showMessage(rejection);
    } catch (_) {
      _showMessage('Unable to open your media files. Please try again.');
    }
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Please correct the highlighted fields before saving.');
      return;
    }
    if (_profilePhotoUrl.isEmpty && _newProfilePhoto == null) {
      _showMessage('A pet profile photo is required.');
      return;
    }
    final additionalImageCount = _existingImages.length + _newImages.length;
    final additionalVideoCount = _existingVideos.length + _newVideos.length;
    if (additionalVideoCount > 0 && additionalImageCount == 0) {
      _showMessage('Add a cover photo before adding pet videos.');
      return;
    }
    final price =
        double.tryParse(_priceController.text.trim().replaceAll(',', '')) ?? 0;
    if (_purpose == 'adoption' && _adoptionType == 'FOR SALE' && price <= 0) {
      _showMessage('Enter a selling price greater than PHP 0.');
      return;
    }
    if (_questions.length > 10) {
      _showMessage('You can add up to 10 adoption questions only.');
      return;
    }
    final age = PetAgeValue(_age, _ageUnit);
    final eligibility = PetEligibilityPolicy.validate(
      purpose: _purpose,
      age: age,
      gender: _gender,
      breedSize: _breedSize,
      petName: _nameController.text.trim(),
    );
    if (eligibility != null) {
      await _showEligibilityIssue(eligibility);
      return;
    }
    final normalizedQuestions = _questions
        .map((question) => _text(question['text']).toLowerCase())
        .where((question) => question.isNotEmpty)
        .toList();
    if (normalizedQuestions.toSet().length != normalizedQuestions.length) {
      _showMessage('Remove duplicate adoption questions before saving.');
      return;
    }

    final identityChanged =
        _nameController.text.trim() != _text(widget.petData['name']) ||
        _species != _text(widget.petData['species'], fallback: 'Dog') ||
        _gender != _text(widget.petData['gender'], fallback: 'Male');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save listing changes?'),
        content: Text(
          identityChanged
              ? 'You changed identifying information for this pet. Confirm that this is still the same animal. Existing requests, chats, and health records will remain attached.'
              : 'The updated details will immediately appear to other users. Existing requests, matches, chats, and verified health records will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final breed = mixedBreedDisplayName(
        isMixedBreed: _isMixedBreed,
        primaryBreed: _primaryBreed,
        secondaryBreed: _secondaryBreed,
      );
      await PetService.instance.updatePetListing(
        petId: widget.petId,
        originalPurpose: _purpose,
        editableFields: {
          'name': _nameController.text.trim(),
          'species': _species,
          'breed': breed,
          'primaryBreed': _primaryBreed,
          'secondaryBreed': _isMixedBreed ? _secondaryBreed : '',
          'isMixedBreed': _isMixedBreed,
          'breedTags': breedTagsFor(
            isMixedBreed: _isMixedBreed,
            primaryBreed: _primaryBreed,
            secondaryBreed: _secondaryBreed,
          ),
          'breedSize': _breedSize,
          'age': age.displayText,
          'gender': _gender,
          'color': _colorController.text.trim(),
          'about': _aboutController.text.trim(),
          'locationName': CabuyaoBarangayService.format(_barangay),
          'breedingPreferences': _purpose == 'breeding'
              ? {
                  'preferredGender': _requiredPartnerGender,
                  'sameBreedOnly': _sameBreedOnly,
                  'vetVerifiedOnly': _vetVerifiedOnly,
                }
              : null,
          'adoptionDetails': _purpose == 'adoption'
              ? {
                  'adoptionType': _adoptionType,
                  'price': _adoptionType == 'FOR SALE' ? price : 0,
                  'noOtherPets': _noOtherPets,
                  'priceNegotiable': _priceNegotiable,
                }
              : null,
          'interviewQuestions': _questions.asMap().entries.map((entry) {
            return {...entry.value, 'order': entry.key};
          }).toList(),
          if (_questionsDirty)
            'interviewQuestionsVersion':
                _number(widget.petData['interviewQuestionsVersion']).toInt() +
                1,
        },
        newProfilePhoto: _newProfilePhoto,
        existingProfilePhotoUrl: _profilePhotoUrl,
        existingImageUrls: _existingImages,
        existingVideoUrls: _existingVideos,
        newImageFiles: _newImages,
        newVideoFiles: _newVideos,
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet listing updated successfully.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        PetListingUpdateException() => error.message,
        DuplicatePetListingException() =>
          'You already have an active listing with these pet details.',
        CloudinaryUploadException() => error.message,
        FirebaseException() when error.code == 'permission-denied' =>
          'You do not have permission to edit this listing. Confirm that you are signed in as its owner.',
        FirebaseException() when error.code == 'unavailable' =>
          'Breedr cannot reach the server right now. Check your connection and try again.',
        FirebaseException() when error.code == 'network-request-failed' =>
          'The update could not be sent. Check your internet connection and try again.',
        _ => 'Unable to update this listing right now. Please try again.',
      };
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showEligibilityIssue(PetEligibilityIssue issue) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.pets_outlined,
          color: AppColors.primary,
          size: 38,
        ),
        title: Text(issue.title, textAlign: TextAlign.center),
        content: Text(issue.message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Update details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breeds = breedNamesForSpecies(_species);
    if (!breeds.contains(_primaryBreed)) {
      _primaryBreed = breeds.first;
    }
    if (_secondaryBreed.isNotEmpty && !breeds.contains(_secondaryBreed)) {
      _secondaryBreed = '';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _canLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF0F5),
          foregroundColor: AppColors.primary,
          title: const Text('Edit Pet Listing'),
          leading: IconButton(
            onPressed: _saving
                ? null
                : () async {
                    if (await _canLeave() && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _sectionTitle('Profile photo'),
                Center(
                  child: Stack(
                    children: [
                      ClipOval(
                        child: _newProfilePhoto != null
                            ? Image.file(
                                _newProfilePhoto!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : BreedrNetworkImage(
                                imageUrl: _profilePhotoUrl,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          onPressed: _replaceProfilePhoto,
                          icon: const Icon(Icons.edit),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle('Pet information'),
                _textField(
                  _nameController,
                  'Pet name',
                  maxLength: 40,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return "Enter your pet's name.";
                    if (text.length < 2) {
                      return 'Pet name must contain at least 2 characters.';
                    }
                    return null;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        label: 'Species',
                        value: _species,
                        items: const ['Dog', 'Cat'],
                        onChanged: (value) => _change(() {
                          _species = value;
                          _primaryBreed = value == 'Cat' ? 'Puspin' : 'Aspin';
                          _secondaryBreed = '';
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdown(
                        label: 'Gender',
                        value: _gender,
                        items: const ['Male', 'Female'],
                        onChanged: (value) => _change(() => _gender = value),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mixed breed'),
                  value: _isMixedBreed,
                  onChanged: (value) => _change(() {
                    _isMixedBreed = value;
                    if (!value) _secondaryBreed = '';
                  }),
                ),
                _dropdown(
                  label: 'Primary breed',
                  value: _primaryBreed,
                  items: breeds,
                  onChanged: (value) => _change(() {
                    _primaryBreed = value;
                    if (_secondaryBreed == value) _secondaryBreed = '';
                  }),
                ),
                if (_isMixedBreed)
                  _dropdown(
                    label: 'Secondary breed',
                    value: _secondaryBreed,
                    items: ['', ...breeds.where((b) => b != _primaryBreed)],
                    itemLabel: (value) =>
                        value.isEmpty ? 'Not specified' : value,
                    onChanged: (value) =>
                        _change(() => _secondaryBreed = value),
                  ),
                _dropdown(
                  label: 'Breed size',
                  value: _breedSize,
                  items: const ['Small', 'Medium', 'Large'],
                  onChanged: (value) => _change(() => _breedSize = value),
                ),
                _EditAgeSelector(
                  age: _age,
                  unit: _ageUnit,
                  onAgeChanged: (value) => _change(() => _age = value),
                  onUnitChanged: (value) => _change(() {
                    _ageUnit = value;
                    final maximum = PetEligibilityPolicy.maxForUnit(value);
                    if (_age > maximum) _age = maximum;
                  }),
                ),
                const SizedBox(height: 16),
                _textField(
                  _colorController,
                  'Color / markings',
                  maxLength: 60,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? "Describe your pet's color or markings."
                      : null,
                ),
                _textField(
                  _aboutController,
                  'About your pet',
                  maxLines: 4,
                  maxLength: 500,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Tell users about your pet.';
                    if (text.length < 10) {
                      return 'Please provide at least 10 characters.';
                    }
                    return null;
                  },
                ),
                _dropdown(
                  label: 'Pet location',
                  value: _barangay,
                  items: CabuyaoBarangayService.barangays,
                  itemLabel: CabuyaoBarangayService.format,
                  onChanged: (value) => _change(() => _barangay = value),
                ),
                _readOnlyField(
                  'Listing purpose',
                  _purpose == 'breeding' ? 'Breeding' : 'Adoption',
                ),
                const SizedBox(height: 18),
                _sectionTitle('Listing preferences'),
                if (_purpose == 'breeding') ...[
                  _readOnlyField(
                    'Preferred partner gender',
                    _requiredPartnerGender,
                  ),
                  _toggle(
                    'Same breed only',
                    _sameBreedOnly,
                    (value) => _change(() => _sameBreedOnly = value),
                  ),
                  _toggle(
                    'Vet verified only',
                    _vetVerifiedOnly,
                    (value) => _change(() => _vetVerifiedOnly = value),
                  ),
                ] else ...[
                  _dropdown(
                    label: 'Adoption type',
                    value: _adoptionType,
                    items: const ['FREE', 'FOR SALE'],
                    itemLabel: (value) => value == 'FREE' ? 'Free' : 'For sale',
                    onChanged: (value) => _change(() => _adoptionType = value),
                  ),
                  if (_adoptionType == 'FOR SALE') ...[
                    _textField(
                      _priceController,
                      'Price (PHP)',
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      ],
                      validator: (value) {
                        final price = double.tryParse(
                          (value ?? '').trim().replaceAll(',', ''),
                        );
                        if (price == null || price <= 0) {
                          return 'Enter an amount greater than PHP 0.';
                        }
                        return null;
                      },
                    ),
                    _toggle(
                      'Price is negotiable',
                      _priceNegotiable,
                      (value) => _change(() => _priceNegotiable = value),
                    ),
                  ],
                  _toggle(
                    'No other pets preferred',
                    _noOtherPets,
                    (value) => _change(() => _noOtherPets = value),
                  ),
                ],
                const SizedBox(height: 18),
                _mediaEditor(),
                if (_purpose == 'adoption') ...[
                  const SizedBox(height: 18),
                  _questionEditor(),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: !_dirty || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaEditor() {
    final count =
        _existingImages.length +
        _existingVideos.length +
        _newImages.length +
        _newVideos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Additional photos and videos')),
            Text('$count / 10'),
          ],
        ),
        const Text(
          'JPG/PNG images: max 5 MB • MP4 videos: max 50 MB',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        ..._existingImages.asMap().entries.map(
          (entry) => _remoteImageRow(entry.key, entry.value),
        ),
        ..._newImages.asMap().entries.map(
          (entry) => _localImageRow(entry.key, entry.value),
        ),
        ..._existingVideos.asMap().entries.map(
          (entry) => _remoteVideoRow(entry.key, entry.value),
        ),
        ..._newVideos.asMap().entries.map(
          (entry) => _localVideoRow(entry.key, entry.value),
        ),
        OutlinedButton.icon(
          onPressed: count >= 10 ? null : _addMedia,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add photos or videos'),
        ),
      ],
    );
  }

  Widget _remoteImageRow(int index, String url) => _mediaRow(
    leading: BreedrNetworkImage(
      imageUrl: url,
      width: 72,
      height: 72,
      borderRadius: BorderRadius.circular(10),
    ),
    title: index == 0 ? 'Cover photo' : 'Existing photo',
    onRemove: () => _change(() => _existingImages.removeAt(index)),
  );

  Widget _localImageRow(int index, File file) => _mediaRow(
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
    ),
    title: _existingImages.isEmpty && index == 0
        ? 'New cover photo'
        : 'New photo',
    onRemove: () => _change(() => _newImages.removeAt(index)),
  );

  Widget _remoteVideoRow(int index, String url) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          BreedrVideoCard(url: url),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _change(() => _existingVideos.removeAt(index)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove video'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _localVideoRow(int index, File file) => _mediaRow(
    leading: const SizedBox(
      width: 72,
      height: 72,
      child: ColoredBox(
        color: Color(0xFF292929),
        child: Icon(Icons.videocam, color: Colors.white),
      ),
    ),
    title: file.uri.pathSegments.last,
    onRemove: () => _change(() => _newVideos.removeAt(index)),
  );

  Widget _mediaRow({
    required Widget leading,
    required String title,
    required VoidCallback onRemove,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline),
      ),
    ),
  );

  Future<void> _openQuestionEditor() async {
    final updated = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdoptionInterviewScreen.edit(initialQuestions: _questions),
      ),
    );
    if (updated == null || !mounted) return;
    _change(() {
      _questions = updated;
      _questionsDirty = true;
    });
  }

  Widget _questionEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Adoption interview questions'),
      const Text(
        'Questions are edited with their answer type and options. Existing applications keep the questions originally answered.',
        style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
      ),
      const SizedBox(height: 10),
      if (_questions.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No interview questions added.'),
          ),
        ),
      ..._questions.asMap().entries.map((entry) {
        final question = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Text('${entry.key + 1}')),
            title: Text(
              _text(question['text']),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_questionTypeLabel(_text(question['type']))} • ${question['required'] == false ? 'Optional' : 'Required'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openQuestionEditor,
          ),
        );
      }),
      OutlinedButton.icon(
        onPressed: _openQuestionEditor,
        icon: const Icon(Icons.edit_note),
        label: Text(
          _questions.isEmpty ? 'Add interview questions' : 'Manage questions',
        ),
      ),
    ],
  );

  String _questionTypeLabel(String type) => switch (type) {
    'multipleChoice' => 'Multiple choice',
    'yesNo' => 'Yes / No',
    'rating' => '1–5 rating',
    _ => 'Text answer',
  };

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _decoration(label),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? 'Please complete $label.'
              : null,
    ),
  );

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String)? itemLabel,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _decoration(label),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                itemLabel?.call(item) ?? item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    ),
  );

  Widget _readOnlyField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InputDecorator(
      decoration: _decoration(label),
      child: Row(
        children: [
          Expanded(child: Text(value)),
          const Icon(Icons.lock_outline, size: 18),
        ],
      ),
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
        letterSpacing: .5,
      ),
    ),
  );

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  static List<String> _stringList(dynamic value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
      : <String>[];
}
