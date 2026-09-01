import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/adoption_service.dart';
import '../../services/breeding_match_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/evidence_picker_helper.dart';
import '../../widgets/breedr_network_image.dart';
import '../owner/owner_ratings_screen.dart';

class OwnerProfileScreen extends StatefulWidget {
  final String ownerId;
  final String fallbackName;
  final String fallbackPhoto;
  final String ratingPurpose;
  final bool showReportAction;

  const OwnerProfileScreen({
    super.key,
    required this.ownerId,
    this.fallbackName = 'Pet Owner',
    this.fallbackPhoto = '',
    this.ratingPurpose = 'adoption',
    this.showReportAction = true,
  });

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final PageController _photoController = PageController(
    viewportFraction: 0.68,
  );
  int _photoIndex = 0;

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          if (widget.showReportAction &&
              UserSessionService.instance.currentUser?.uid != widget.ownerId)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'report') _showReportUserSheet();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, color: Color(0xFFE93535), size: 18),
                      SizedBox(width: 8),
                      Text('Report this Profile'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.ownerId)
            .snapshots(),
        builder: (context, ownerSnapshot) {
          if (ownerSnapshot.hasError) {
            return const _OwnerEmpty(
              icon: Icons.cloud_off_outlined,
              title: 'Profile unavailable',
              message: 'Check your connection and try again.',
            );
          }
          if (!ownerSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final data = ownerSnapshot.data?.data();
          if (data == null) {
            return const _OwnerEmpty(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message: 'This pet owner profile could not be found.',
            );
          }
          return _profile(data);
        },
      ),
    );
  }

  Future<void> _showReportUserSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportUserSheet(
        reportedUserId: widget.ownerId,
        fallbackName: widget.fallbackName,
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
            'We have received your report. We will review it and take appropriate action if needed.',
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

  Widget _profile(Map<String, dynamic> data) {
    final name = data['fullName'] as String? ?? widget.fallbackName;
    final photo = data['profilePhoto'] as String? ?? widget.fallbackPhoto;
    final userName = data['userName'] as String? ?? '';
    final location = data['locationName'] as String? ?? 'Location not set';
    final bio =
        data['bio'] as String? ??
        'This pet owner has not added an introduction yet.';
    final homeType = data['homeType'] as String? ?? 'Not set';
    final hasKids = data['childrenAtHome'] as bool? ?? false;
    final hasPets = data['otherPetsAtHome'] as bool? ?? false;
    final images = _imageListFromAny(
      data['additionalImages'] ??
          data['additionalPhotos'] ??
          data['additionalPhotoUrls'],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFFFFD9E1),
              backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
              child: photo.isEmpty
                  ? const Icon(Icons.person, size: 45, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (userName.isNotEmpty)
                    Text(
                      '@$userName',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 11,
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
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 7,
          children: [
            _OwnerTag(homeType),
            if (hasKids) const _OwnerTag('Has kids'),
            if (hasPets) const _OwnerTag('Has pets'),
          ],
        ),
        const SizedBox(height: 20),
        _OwnerStats(ownerId: widget.ownerId, purpose: widget.ratingPurpose),
        const SizedBox(height: 22),
        const _OwnerSectionTitle('ABOUT ME'),
        const SizedBox(height: 9),
        _OwnerBox(child: Text(bio, textAlign: TextAlign.center)),
        const SizedBox(height: 22),
        const _OwnerSectionTitle('HOME INFORMATION'),
        const SizedBox(height: 9),
        _OwnerBox(
          child: Column(
            children: [
              _OwnerInfoRow('Home Type', homeType),
              _OwnerInfoRow('Location', location),
              _OwnerInfoRow('Pets at Home', hasPets ? 'YES' : 'NO'),
              _OwnerInfoRow('Kids at Home', hasKids ? 'YES' : 'NO'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: _OwnerSectionTitle('MORE PHOTOS OF THE OWNER'),
            ),
            Text(
              images.isEmpty
                  ? '0 / 0'
                  : '${_photoIndex + 1} / ${images.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (images.isEmpty)
          const _OwnerEmpty(
            icon: Icons.photo_outlined,
            title: 'No additional photos',
            message: 'This owner has not shared more photos yet.',
            compact: true,
          )
        else
          SizedBox(
            height: 270,
            child: PageView.builder(
              controller: _photoController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _photoIndex = index);
              },
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BreedrNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    fallback: const ColoredBox(
                      color: Color(0xFFFFE4EA),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.primary,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        _OwnerSectionTitle(
          '${widget.ratingPurpose == 'breeding' ? 'BREEDING' : 'ADOPTION'} RATINGS',
        ),
        const SizedBox(height: 9),
        _PurposeRatingsCard(
          ownerId: widget.ownerId,
          ownerName: name,
          ownerPhoto: photo,
          purpose: widget.ratingPurpose,
        ),
      ],
    );
  }
}

class _ReportUserSheet extends StatefulWidget {
  final String reportedUserId;
  final String fallbackName;

  const _ReportUserSheet({
    required this.reportedUserId,
    required this.fallbackName,
  });

  @override
  State<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<_ReportUserSheet> {
  final _detailController = TextEditingController();
  final _evidenceFiles = <SelectedEvidenceFile>[];
  String _reason = 'Suspicious or scam behavior';
  String? _errorMessage;
  bool _submitting = false;

  static const _reasons = [
    (
      'Suspicious or scam behavior',
      'Requesting money or personal info inappropriately',
    ),
    (
      'Fake or impersonating account',
      'Profile information appears false or stolen',
    ),
    (
      'Harassment or abusive behavior',
      'Sending threatening or offensive messages',
    ),
    ('Animal abuse or neglect', 'Evidence or mistreating pets in their care'),
    ('Misleading pet information', 'Providing false details about their pets'),
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
      await AdoptionService.instance.reportUser(
        reportedUserId: widget.reportedUserId,
        reportedUserName: widget.fallbackName,
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
      if (mounted) {
        _showError(
          error.code == 'permission-denied'
              ? 'You do not have permission to submit this report.'
              : 'Unable to submit this report right now.',
        );
      }
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
                        'Report this User',
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
                Text(
                  'Why are you reporting ${widget.fallbackName}? Select the most appropriate reason.',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                  ),
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
                          'Your report is anonymous. This user will not know who reported them.',
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

class _OwnerStats extends StatelessWidget {
  final String ownerId;
  final String purpose;

  const _OwnerStats({required this.ownerId, required this.purpose});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance.watchPublishedReviewsForUser(
        ownerId,
      ),
      builder: (context, reviewSnapshot) {
        final reviews = reviewSnapshot.data?.docs ?? const [];
        final purposeReviews = reviews
            .where((document) => document.data()['purpose'] == purpose)
            .toList();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pets')
              .where('ownerId', isEqualTo: ownerId)
              .snapshots(),
          builder: (context, petSnapshot) {
            return Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: _average(purposeReviews),
                    label: purpose == 'breeding'
                        ? 'Breeding Rating'
                        : 'Adoption Rating',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Stat(
                    value: '${purposeReviews.length}',
                    label: purposeReviews.length == 1 ? 'Review' : 'Reviews',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Stat(
                    value: '${petSnapshot.data?.docs.length ?? 0}',
                    label: 'Pets Listed',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _average(List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews) {
    final ratings = reviews
        .map((document) => document.data()['overall'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    if (ratings.isEmpty) return 'New';
    return (ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(
      1,
    );
  }
}

class _PurposeRatingsCard extends StatelessWidget {
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;
  final String purpose;

  const _PurposeRatingsCard({
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance.watchPublishedReviewsForUser(
        ownerId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _OwnerEmpty(
            icon: Icons.cloud_off_outlined,
            title: 'Ratings unavailable',
            message: 'Reviews could not be loaded right now.',
            compact: true,
          );
        }
        final reviews = (snapshot.data?.docs ?? const [])
            .where((document) => document.data()['purpose'] == purpose)
            .toList();
        final ratings = reviews
            .map((document) => document.data()['overall'])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList();
        final average = ratings.isEmpty
            ? null
            : ratings.reduce((a, b) => a + b) / ratings.length;
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OwnerRatingsScreen(
                ownerId: ownerId,
                fallbackName: ownerName,
                fallbackPhoto: ownerPhoto,
                initialFilter: OwnerReviewFilter.all,
                purpose: purpose,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EA),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFFFAFC0)),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      average?.toStringAsFixed(1) ?? 'New',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      ratings.isEmpty
                          ? 'No reviews yet'
                          : '${ratings.length} ${ratings.length == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'View all $purpose reviews',
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFB5C2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

List<String> _imageListFromAny(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

class _OwnerTag extends StatelessWidget {
  final String text;

  const _OwnerTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _OwnerBox extends StatelessWidget {
  final Widget child;

  const _OwnerBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F4),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFAAAAAA)),
      ),
      child: child,
    );
  }
}

class _OwnerInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _OwnerInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerSectionTitle extends StatelessWidget {
  final String text;

  const _OwnerSectionTitle(this.text);

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

class _OwnerEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  const _OwnerEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 34 : 58, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
