import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/adoption_models.dart';
import '../../services/adoption_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/pet_media_validation_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/evidence_picker_helper.dart';
import '../../widgets/breedr_network_image.dart';
import '../../widgets/breedr_video_card.dart';
import 'adoption_application_screen.dart';
import 'owner_profile_screen.dart';

class PetAdoptionProfileScreen extends StatefulWidget {
  final String listingId;

  const PetAdoptionProfileScreen({super.key, required this.listingId});

  @override
  State<PetAdoptionProfileScreen> createState() =>
      _PetAdoptionProfileScreenState();
}

class _PetAdoptionProfileScreenState extends State<PetAdoptionProfileScreen> {
  final PageController _photoController = PageController(
    viewportFraction: 0.72,
  );
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _photoIndex = ValueNotifier<int>(0);
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    AdoptionService.instance.recordListingView(widget.listingId).catchError((
      Object error,
    ) {
      debugPrint('Adoption listing view could not be recorded: $error');
    });
  }

  @override
  void dispose() {
    _photoController.dispose();
    _scrollController.dispose();
    _photoIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdoptionListing?>(
      stream: AdoptionService.instance.watchListing(widget.listingId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ProfileState(
            icon: Icons.cloud_off_outlined,
            title: 'Listing unavailable',
            message: 'Check your connection and try opening this pet again.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF7FA),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final listing = snapshot.data;
        if (listing == null) {
          return const _ProfileState(
            icon: Icons.pets_outlined,
            title: 'Listing no longer exists',
            message: 'This pet profile may have been removed by its owner.',
          );
        }
        return _buildProfile(listing);
      },
    );
  }

  Widget _buildProfile(AdoptionListing listing) {
    final currentUserId = UserSessionService.instance.currentUser?.uid;
    final isOwnListing = currentUserId == listing.ownerId;
    final images = PetMediaValidation.uniqueAdditionalUrls(
      listing.additionalImages,
      exclude: listing.profilePhoto,
    );
    if (images.isNotEmpty && _photoIndex.value >= images.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _photoIndex.value >= images.length) {
          _photoIndex.value = images.length - 1;
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: CustomScrollView(
        key: PageStorageKey<String>('adoption-profile-${listing.id}'),
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: const Color(0xFFFFF7FA),
            foregroundColor: AppColors.primary,
            actions: [
              if (!isOwnListing)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'report') _showReportListingSheet(listing);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, color: Color(0xFFE93535), size: 18),
                          SizedBox(width: 8),
                          Text('Report this Listing'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _NetworkPetImage(
                    url: listing.profilePhoto,
                    species: listing.species,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  if (listing.isForSale)
                    Positioned(
                      top: 86,
                      right: 16,
                      child: _PriceBadge(price: listing.price ?? 0),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFD9E1),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 8),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _NetworkPetImage(
                          url: listing.profilePhoto,
                          species: listing.species,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                listing.breed,
                                listing.gender,
                                listing.age,
                              ].where((value) => value.isNotEmpty).join(' | '),
                              style: const TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    listing.locationName.isEmpty
                                        ? 'Location not available'
                                        : listing.locationName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isOwnListing) ...[
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _FavoriteButton(
                            listingId: listing.id,
                            disabled: false,
                            onError: _showMessage,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      if (listing.vetVerified)
                        const _Tag(
                          label: 'Vet Verified',
                          color: Color(0xFF5DBEF0),
                          foreground: Colors.white,
                        ),
                      if (listing.color.isNotEmpty)
                        _Tag(
                          label: listing.color,
                          color: const Color(0xFFFFE1E7),
                        ),
                      _Tag(
                        label: listing.isForSale ? 'For Sale' : 'Free',
                        color: const Color(0xFFFFE8B9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(color: Color(0xFFFFC9D3)),
                  const SizedBox(height: 14),
                  _InfoGrid(listing: listing),
                  const SizedBox(height: 22),
                  _SectionTitle('ABOUT ${listing.name.toUpperCase()}'),
                  const SizedBox(height: 10),
                  _AboutBox(
                    text: listing.about.trim().isEmpty
                        ? '${listing.name} does not have a description yet.'
                        : listing.about,
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    '${listing.name.toUpperCase()} PET HEALTH RECORD',
                  ),
                  const SizedBox(height: 10),
                  if (listing.healthRecords.isEmpty)
                    const _InlineEmpty(
                      icon: Icons.medical_information_outlined,
                      text: 'No health records were added to this listing.',
                    )
                  else
                    ...listing.healthRecords.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _HealthRecordRow(record: record),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _SectionTitle(
                          'MORE PHOTOS OF ${listing.name.toUpperCase()}',
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _photoIndex,
                        builder: (context, index, _) {
                          return Text(
                            images.isEmpty
                                ? '0 / 0'
                                : '${index + 1} / ${images.length}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (images.isEmpty)
                    const _InlineEmpty(
                      icon: Icons.photo_outlined,
                      text: 'No additional photos were added.',
                    )
                  else
                    _PhotoCarousel(
                      images: images,
                      controller: _photoController,
                      currentIndex: _photoIndex,
                      species: listing.species,
                      onChanged: (index) => _photoIndex.value = index,
                    ),
                  if (listing.additionalVideos.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionTitle('VIDEOS OF ${listing.name.toUpperCase()}'),
                    const SizedBox(height: 12),
                    ...listing.additionalVideos.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BreedrVideoCard(url: url),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _SectionTitle('POSTED BY'),
                  const SizedBox(height: 10),
                  _OwnerCard(
                    ownerId: listing.ownerId,
                    fallbackName: listing.ownerName,
                    fallbackPhoto: listing.ownerPhoto,
                  ),
                  if (listing.isForSale) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFFD18A19),
                            size: 19,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              AdoptionPolicy.paymentDisclaimer,
                              style: TextStyle(
                                color: Color(0xFF6B542F),
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: StreamBuilder<AdoptionRequest?>(
            stream: isOwnListing
                ? Stream.value(null)
                : AdoptionService.instance.watchMyRequestForListing(
                    listing.id,
                    listingCycleId: listing.listingCycleId,
                  ),
            builder: (context, requestSnapshot) {
              return _AdoptionActionButton(
                listing: listing,
                request: requestSnapshot.data,
                isOwnListing: isOwnListing,
                isValidating: _validating,
                onAdopt: () => _beginAdoption(listing),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _beginAdoption(AdoptionListing listing) async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      final eligibility = await AdoptionService.instance
          .validateListingForRequest(listing.id);
      if (!mounted) return;
      if (!eligibility.allowed || eligibility.listing == null) {
        _showMessage(
          eligibility.reason ?? 'This pet is no longer available for adoption.',
        );
        return;
      }
      final freshListing = eligibility.listing!;
      final continueToQuestions = await showDialog<bool>(
        context: context,
        builder: (_) => _AdoptConfirmationDialog(listing: freshListing),
      );
      if (continueToQuestions != true || !mounted) return;
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AdoptionApplicationScreen(listing: freshListing),
        ),
      );
      if (submitted == true && mounted) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (error) {
      if (mounted) _showMessage(_firebaseMessage(error));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showReportListingSheet(AdoptionListing listing) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetListingReportSheet(
        target: PetListingReportTarget(
          petId: listing.id,
          petName: listing.name,
          species: listing.species,
          breed: listing.breed,
          purpose: 'adoption',
          profilePhoto: listing.profilePhoto,
          ownerId: listing.ownerId,
          ownerName: listing.ownerName,
        ),
      ),
    );
    if (submitted == true && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Report Submitted', textAlign: TextAlign.center),
          content: const Text(
            'Thanks for helping keep the community safe. We will review this listing as soon as possible.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

class PetListingReportTarget {
  final String petId;
  final String petName;
  final String species;
  final String breed;
  final String purpose;
  final String profilePhoto;
  final String ownerId;
  final String ownerName;

  const PetListingReportTarget({
    required this.petId,
    required this.petName,
    required this.species,
    required this.breed,
    required this.purpose,
    required this.profilePhoto,
    required this.ownerId,
    required this.ownerName,
  });
}

class PetListingReportSheet extends StatefulWidget {
  final PetListingReportTarget target;

  const PetListingReportSheet({super.key, required this.target});

  @override
  State<PetListingReportSheet> createState() => _PetListingReportSheetState();
}

class _PetListingReportSheetState extends State<PetListingReportSheet> {
  final _detailController = TextEditingController();
  final _evidenceFiles = <SelectedEvidenceFile>[];
  String _reason = 'Fake or misleading listing';
  String? _errorMessage;
  bool _submitting = false;

  static const _reasons = [
    (
      'Fake or misleading listing',
      'Photos or details do not match the actual pet',
    ),
    (
      'Suspected animal abuse or neglect',
      'Signs of harm or poor living conditions',
    ),
    (
      'Scam or fraudulent activity',
      'Requesting payment outside the app suspiciously',
    ),
    (
      'Inappropriate or offensive content',
      'Photos or description violate community guidelines',
    ),
    (
      'Prohibited breed or illegal sale',
      'Selling restricted or endangered species',
    ),
    ('Other', 'Describe the issue in your own words'),
  ];

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final remainingSlots = 3 - _evidenceFiles.length;
    if (remainingSlots <= 0) {
      _showError('You can attach up to 3 evidence files only.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp4',
        'mov',
        'm4v',
      ],
    );
    if (picked == null || !mounted) return;

    final selected = <SelectedEvidenceFile>[];
    final existingPaths = _evidenceFiles
        .map((evidence) => evidence.file.path)
        .toSet();
    final existingFingerprints = _evidenceFiles
        .map(
          (evidence) =>
              '${evidence.fileName.toLowerCase()}::${evidence.sizeBytes}',
        )
        .toSet();
    var invalidTypeCount = 0;
    var oversizedCount = 0;
    var duplicateCount = 0;
    var overLimitCount = 0;
    for (final file in picked.files) {
      if (selected.length >= remainingSlots) {
        overLimitCount++;
        continue;
      }
      final path = file.path;
      if (path == null) {
        invalidTypeCount++;
        continue;
      }
      final fingerprint = '${file.name.toLowerCase()}::${file.size}';
      if (existingPaths.contains(path) ||
          existingFingerprints.contains(fingerprint)) {
        duplicateCount++;
        continue;
      }
      final evidence = SelectedEvidenceFile.fromPath(
        path,
        fileName: file.name,
        sizeBytes: file.size,
      );
      if (evidence == null) {
        invalidTypeCount++;
        continue;
      }
      if (!evidence.isValidSize) {
        oversizedCount++;
        continue;
      }
      selected.add(evidence);
      existingPaths.add(path);
      existingFingerprints.add(fingerprint);
    }
    if (selected.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _evidenceFiles.addAll(selected);
      });
    }
    final warnings = <String>[
      if (duplicateCount > 0)
        'Duplicate files are not allowed. A selected evidence file was skipped.',
      if (overLimitCount > 0)
        'Only $remainingSlots more file(s) could be added because reports are limited to 3 files.',
      if (invalidTypeCount > 0)
        'Some files were skipped because only JPG, PNG, WEBP, MP4, MOV, and M4V are accepted.',
      if (oversizedCount > 0)
        'Some files were skipped because each evidence file must be 50 MB or less.',
    ];
    if (warnings.isNotEmpty) {
      _showError(warnings.join(' '));
    }
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _submitting = true;
    });
    try {
      final evidence = <AdoptionEvidenceFile>[];
      for (final file in _evidenceFiles) {
        final url = await CloudinaryService().uploadEvidenceOrThrow(file.file);
        evidence.add(
          AdoptionEvidenceFile(
            url: url,
            fileName: file.fileName,
            fileType: file.fileType,
            mimeType: file.mimeType,
            sizeBytes: file.sizeBytes,
          ),
        );
      }
      final target = widget.target;
      await AdoptionService.instance.reportPetListingSnapshot(
        petId: target.petId,
        petName: target.petName,
        species: target.species,
        breed: target.breed,
        purpose: target.purpose,
        profilePhoto: target.profilePhoto,
        ownerId: target.ownerId,
        ownerName: target.ownerName,
        reason: _reason,
        detail: _detailController.text,
        evidenceFiles: evidence,
      );
      if (mounted) Navigator.pop(context, true);
    } on CloudinaryUploadException catch (error) {
      if (mounted) _showError(error.message);
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_firebaseMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 18),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7D7D7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.flag, color: Color(0xFFE93535), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Report this Pet Listing',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close report',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Help us keep Breedr safe. Select the reason that best describes the issue with this listing.',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 12),
                ),
                const Divider(height: 28),
                RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (value) {
                    if (!_submitting && value != null) {
                      setState(() => _reason = value);
                    }
                  },
                  child: Column(
                    children: _reasons
                        .map(
                          (reason) => RadioListTile<String>(
                            value: reason.$1,
                            enabled: !_submitting,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              reason.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              reason.$2,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(height: 24),
                const Text(
                  'ADDITIONAL DETAIL',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _detailController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Describe what you noticed. The more detail you provide, the faster we can act.',
                    filled: true,
                    fillColor: const Color(0xFFFFF7FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFB5C1)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickEvidence,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _evidenceFiles.isEmpty
                        ? 'Attach Evidence (optional)'
                        : '${_evidenceFiles.length}/3 file(s) attached',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  _ReportInlineMessage(message: _errorMessage!),
                ],
                if (_evidenceFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._evidenceFiles.asMap().entries.map((entry) {
                    final file = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(file.icon, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove evidence',
                            visualDensity: VisualDensity.compact,
                            onPressed: _submitting
                                ? null
                                : () => setState(
                                    () => _evidenceFiles.removeAt(entry.key),
                                  ),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Up to 3 files. JPG, PNG, WEBP, MP4, MOV, or M4V. Max 50 MB each.',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your report is anonymous. The listing owner will not know who reported them.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(_submitting ? 'Submitting...' : 'Submit Report'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancel Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportInlineMessage extends StatelessWidget {
  final String message;

  const _ReportInlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFA9B9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A4D57),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptConfirmationDialog extends StatelessWidget {
  final AdoptionListing listing;

  const _AdoptConfirmationDialog({required this.listing});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFF0F4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primary),
      ),
      title: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD5DE),
            ),
            clipBehavior: Clip.antiAlias,
            child: _NetworkPetImage(
              url: listing.profilePhoto,
              species: listing.species,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ADOPT ${listing.name.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you ready to adopt ${listing.name}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              listing.questions.isEmpty
                  ? 'The owner did not add interview questions. You can review and submit your request next.'
                  : 'Please answer the owner\'s interview questions to help them understand whether your home is suitable for ${listing.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (listing.isForSale) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8B9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  AdoptionPolicy.paymentDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(
            listing.questions.isEmpty ? 'Continue' : 'Continue to Questions',
          ),
        ),
      ],
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final String ownerId;
  final String fallbackName;
  final String fallbackPhoto;

  const _OwnerCard({
    required this.ownerId,
    required this.fallbackName,
    required this.fallbackPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['fullName'] as String? ?? fallbackName;
        final photo = data?['profilePhoto'] as String? ?? fallbackPhoto;
        final userName = data?['userName'] as String? ?? '';
        final location = data?['locationName'] as String? ?? '';
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OwnerProfileScreen(
                ownerId: ownerId,
                fallbackName: name,
                fallbackPhoto: photo,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFFFCAD4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _OwnerPhoto(url: photo),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (userName.isNotEmpty || location.isNotEmpty)
                        Text(
                          [
                            if (userName.isNotEmpty) '@$userName',
                            if (location.isNotEmpty) location,
                          ].join(' | '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HealthRecordRow extends StatelessWidget {
  final Map<String, dynamic> record;

  const _HealthRecordRow({required this.record});

  String get _displayType {
    final rawType = record['type'] as String? ?? 'Health record';
    final otherType = record['otherType']?.toString().trim() ?? '';
    return rawType == 'Other' && otherType.isNotEmpty ? otherType : rawType;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = record['fileName'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF3189F5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: Color(0xFF3189F5)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayType,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showPreview(context),
            icon: const Icon(Icons.visibility_outlined, size: 14),
            label: const Text('VIEW'),
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context) {
    final fileUrl = record['fileUrl'] as String? ?? '';
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayType,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _RecordDetail('File', record['fileName'] as String? ?? ''),
              _RecordDetail(
                'Date issued',
                record['dateIssued'] as String? ?? '',
              ),
              _RecordDetail('Clinic', record['clinic'] as String? ?? ''),
              _RecordDetail(
                'Veterinarian',
                record['veterinarian'] as String? ?? '',
              ),
              const SizedBox(height: 12),
              if (fileUrl.isEmpty)
                const _InlineEmpty(
                  icon: Icons.image_not_supported_outlined,
                  text: 'No document preview is available.',
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: BreedrNetworkImage(
                    imageUrl: fileUrl,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.contain,
                    fallback: const _InlineEmpty(
                      icon: Icons.broken_image_outlined,
                      text: 'The document preview could not be loaded.',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCarousel extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final ValueNotifier<int> currentIndex;
  final String species;
  final ValueChanged<int> onChanged;

  const _PhotoCarousel({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.species,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 285,
      child: ValueListenableBuilder<int>(
        valueListenable: currentIndex,
        builder: (context, index, _) {
          return Row(
            children: [
              IconButton.outlined(
                tooltip: 'Previous photo',
                onPressed: index == 0
                    ? null
                    : () => controller.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: PageView.builder(
                  key: const PageStorageKey<String>(
                    'adoption-profile-photo-carousel',
                  ),
                  controller: controller,
                  itemCount: images.length,
                  onPageChanged: onChanged,
                  itemBuilder: (context, imageIndex) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _NetworkPetImage(
                        url: images[imageIndex],
                        species: species,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Next photo',
                onPressed: index >= images.length - 1
                    ? null
                    : () => controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final String listingId;
  final bool disabled;
  final ValueChanged<String> onError;

  const _FavoriteButton({
    required this.listingId,
    required this.disabled,
    required this.onError,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool? _overrideValue;
  bool _busy = false;

  Future<void> _toggle(bool currentValue) async {
    if (_busy) return;
    final previous = _overrideValue;
    setState(() {
      _busy = true;
      _overrideValue = !currentValue;
    });
    try {
      final saved = await AdoptionService.instance.toggleFavorite(
        widget.listingId,
      );
      if (mounted) setState(() => _overrideValue = saved);
    } on AdoptionServiceException catch (error) {
      if (mounted) setState(() => _overrideValue = previous);
      widget.onError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _overrideValue = previous);
      widget.onError(_firebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: AdoptionService.instance.watchIsFavorite(widget.listingId),
      initialData: false,
      builder: (context, snapshot) {
        final isFavorite = _overrideValue ?? (snapshot.data == true);
        return Tooltip(
          message: isFavorite ? 'Remove from Favorites' : 'Save to Favorites',
          child: Material(
            color: Colors.white.withValues(alpha: 0.95),
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.disabled || _busy
                  ? null
                  : () => _toggle(isFavorite),
              child: SizedBox(
                width: 42,
                height: 42,
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: AppColors.primary,
                        size: 24,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdoptionActionButton extends StatelessWidget {
  final AdoptionListing listing;
  final AdoptionRequest? request;
  final bool isOwnListing;
  final bool isValidating;
  final VoidCallback onAdopt;

  const _AdoptionActionButton({
    required this.listing,
    required this.request,
    required this.isOwnListing,
    required this.isValidating,
    required this.onAdopt,
  });

  @override
  Widget build(BuildContext context) {
    final status = request?.status;
    final canAdopt =
        !isOwnListing && listing.isAvailable && status == null && !isValidating;
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: canAdopt ? onAdopt : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: const Color(0xFFFFCED8),
          disabledForegroundColor: AppColors.primary,
        ),
        child: isValidating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(_adoptionButtonLabel(listing, status, isOwnListing)),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final AdoptionListing listing;

  const _InfoGrid({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoCell(label: 'Species', value: listing.species),
            ),
            Expanded(
              child: _InfoCell(label: 'Breed', value: listing.breed),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _InfoCell(label: 'Age', value: listing.age),
            ),
            Expanded(
              child: _InfoCell(label: 'Gender', value: listing.gender),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _InfoCell(label: 'Color', value: listing.color),
            ),
            Expanded(
              child: _InfoCell(label: 'Size', value: listing.breedSize),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? 'Not provided' : value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final double price;

  const _PriceBadge({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3189F5)),
      ),
      child: Text(
        'PHP ${_formatPrice(price)}',
        style: const TextStyle(
          color: Color(0xFF1478D4),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final Color foreground;

  const _Tag({
    required this.label,
    required this.color,
    this.foreground = const Color(0xFF444444),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AboutBox extends StatelessWidget {
  final String text;

  const _AboutBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F4),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFFFAFC0)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.5),
      ),
    );
  }
}

class _OwnerPhoto extends StatelessWidget {
  final String url;

  const _OwnerPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFFFFD9E1),
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty
          ? const Icon(Icons.person, color: AppColors.primary)
          : null,
    );
  }
}

class _NetworkPetImage extends StatelessWidget {
  final String url;
  final String species;

  const _NetworkPetImage({required this.url, required this.species});

  @override
  Widget build(BuildContext context) {
    return BreedrNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fallback: _PetPlaceholder(species: species),
    );
  }
}

class _PetPlaceholder extends StatelessWidget {
  final String species;

  const _PetPlaceholder({required this.species});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFE4EA),
      child: Center(
        child: Icon(
          species.toLowerCase() == 'cat' ? Icons.cruelty_free : Icons.pets,
          color: AppColors.primary,
          size: 64,
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFAAAAAA), size: 30),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RecordDetail extends StatelessWidget {
  final String label;
  final String value;

  const _RecordDetail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ProfileState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 62, color: AppColors.primary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrice(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _adoptionButtonLabel(
  AdoptionListing listing,
  AdoptionRequestStatus? status,
  bool isOwnListing,
) {
  if (isOwnListing) return 'YOUR ADOPTION LISTING';
  if (!listing.isAvailable) return 'NO LONGER AVAILABLE';
  switch (status) {
    case AdoptionRequestStatus.pending:
      return 'REQUEST SUBMITTED';
    case AdoptionRequestStatus.underReview:
      return 'UNDER REVIEW';
    case AdoptionRequestStatus.approved:
      return 'REQUEST APPROVED';
    case AdoptionRequestStatus.rejected:
      return 'REQUEST DECLINED';
    case AdoptionRequestStatus.withdrawn:
      return 'REQUEST WITHDRAWN';
    case AdoptionRequestStatus.completed:
      return 'ADOPTION COMPLETED';
    case null:
      return 'ADOPT ${listing.name.toUpperCase()}';
  }
}

String _firebaseMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Breedr could not complete this action. Check that the latest Firestore rules are deployed.';
    case 'unavailable':
      return 'The service is temporarily unavailable. Check your connection and try again.';
    default:
      return error.message?.trim().isNotEmpty == true
          ? error.message!
          : 'The action could not be completed. Please try again.';
  }
}
