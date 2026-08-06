import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/pet_listing_data.dart';
import '../../services/pet_registration_draft_service.dart';
import '../../services/pet_service.dart';
import '../../widgets/breedr_network_image.dart';
import 'pet_published_screen.dart';

const _blue = Color(0xFF5399F0);
const _darkBlue = Color(0xFF0050B4);
const _green = Color(0xFF56C14A);
const _red = Color(0xFFF43845);
const _orange = Color(0xFFF2AA58);

class PetReviewScreen extends StatefulWidget {
  final PetListingData petData;

  const PetReviewScreen({
    super.key,
    required this.petData,
  });

  @override
  State<PetReviewScreen> createState() => _PetReviewScreenState();
}

class _PetReviewScreenState extends State<PetReviewScreen> {
  int _currentPhoto = 1;
  bool _isPublishing = false;

  int get _totalPhotos {
    final total = widget.petData.additionalPhotoFiles.length;
    return total == 0 ? 1 : total;
  }

  Future<void> _publishPet() async {
    setState(() => _isPublishing = true);

    try {
      final result = await PetService.instance.publishPet(widget.petData);
      await PetRegistrationDraftService.instance.clearDraft();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PetPublishedScreen(
            petData: widget.petData,
            profilePhotoUrl: result.profilePhotoUrl,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Pet publish error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_publishErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  String _publishErrorMessage(Object error) {
    if (error is DuplicatePetListingException) {
      return 'You already have an active listing for ${error.petName}.';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Unable to publish this pet because your account does not have permission.';
        case 'unavailable':
          return 'The server is unavailable right now. Please try again in a moment.';
        case 'network-request-failed':
          return 'Please check your internet connection and try again.';
      }
    }

    final message = error.toString().toLowerCase();
    if (message.contains('logged in') || message.contains('sign in')) {
      return 'Please sign in again before publishing your pet.';
    }
    if (message.contains('network') || message.contains('socket')) {
      return 'Please check your internet connection and try again.';
    }

    return 'Unable to publish your pet right now. Please try again.';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppColors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _PetStepBar(currentStep: 5),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('Step 5 of 5',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: IntrinsicHeight(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Review Profile',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary)),
                                  SizedBox(height: 6),
                                  Text(
                                    'Take a moment to review your details before finishing. Once published, other pet owners nearby can see and request ${widget.petData.name}.',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF666666),
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Pet Profile Card ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _PetProfileCard(petData: widget.petData),
                    ),

                    const SizedBox(height: 20),

                    // ── Info Grid ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _InfoRow2Col('Species', widget.petData.species,
                              'Breed', widget.petData.breed),
                          const SizedBox(height: 12),
                          _InfoRow2Col('Age', widget.petData.age, 'Gender',
                              widget.petData.gender),
                          const SizedBox(height: 12),
                          _InfoRow2Col('Color', widget.petData.color, 'Size',
                              widget.petData.breedSize),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // About section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ABOUT ${widget.petData.name.toUpperCase()}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF444444),
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 12),
                          _SpeechBubble(text: widget.petData.about),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFEEEEEE), height: 1),
                    const SizedBox(height: 20),

                    // ── Health Records ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${widget.petData.name.toUpperCase()} PET HEALTH RECORD',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF444444),
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 12),
                          if (widget.petData.healthRecords.isEmpty)
                            const Text(
                              'No health records added.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                              ),
                            )
                          else
                            ...widget.petData.healthRecords.map(
                              (record) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _HealthRecordRow(
                                  type: record.type,
                                  file: record.fileName,
                                  imageFile: record.file,
                                  fileUrl: record.fileUrl,
                                  dateIssued: record.dateIssued,
                                  clinic: record.clinic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFEEEEEE), height: 1),
                    const SizedBox(height: 20),

                    // ── More Photos ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(children: [
                        Text('MORE PHOTOS OF ${widget.petData.name.toUpperCase()}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF444444),
                                letterSpacing: 0.8)),
                        const Spacer(),
                        Text('$_currentPhoto / $_totalPhotos',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Photo carousel
                    _PhotoCarousel(
                      petData: widget.petData,
                      current: _currentPhoto,
                      total: _totalPhotos,
                      onChanged: (page) => setState(() {
                        _currentPhoto = page + 1;
                      }),
                      onPrev: () => setState(() {
                        if (_currentPhoto > 1) _currentPhoto--;
                      }),
                      onNext: () => setState(() {
                        if (_currentPhoto < _totalPhotos) _currentPhoto++;
                      }),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Save and Publish button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPublishing ? null : _publishPet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isPublishing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save and Publish Pet Profile',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pet Profile Card (Tinder-style) ──────────────────────────────

class _PetProfileCard extends StatelessWidget {
  final PetListingData petData;

  const _PetProfileCard({
    required this.petData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Photo area with speech bubble overlay
            Stack(
              children: [
                // Pet photo
                Container(
                  width: double.infinity,
                  height: 280,
                  color: const Color(0xFFE0E0E0),
                  child: petData.profilePhotoFile != null
                      ? Image.file(
                          petData.profilePhotoFile!,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Icon(Icons.pets,
                              size: 80, color: Color(0xFFBBBBBB)),
                        ),
                ),
                // Price badge top right
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _darkBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        petData.isAdoption
                            ? 'PHP ${petData.price.toStringAsFixed(0)}'
                            : 'BREEDING',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                // Speech bubble
                Positioned(
                  top: 20,
                  right: 16,
                  child: _SpeechBubbleOverlay(
                    text: petData.about,
                  ),
                ),
                // Bottom info overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(petData.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const Text('  |  ',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 18)),
                          Text(petData.age,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          const SizedBox(width: 6),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _blue,
                            ),
                          ),
                          const Spacer(),
                          // Profile mini avatar
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                              color: const Color(0xFFFFCDD5),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/profile.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Download icon
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                              border: Border.all(
                                  color: Colors.white54, width: 1),
                            ),
                            child: const Icon(Icons.download_outlined,
                                color: Colors.white, size: 18),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.pets,
                              size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('${petData.breed}  |  ${petData.breedSize}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.location_on,
                              size: 12, color: _orange),
                          const SizedBox(width: 4),
                          Text(petData.locationName,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          if (petData.hasHealthRecords)
                            const _BadgeChip(
                              label: 'Vet Verified',
                              color: _blue,
                              textColor: Colors.white),
                          _BadgeChip(
                              label: petData.color,
                              color: const Color(0xFFEEEEEE),
                              textColor: const Color(0xFF555555)),
                          _BadgeChip(
                              label:
                                  petData.isAdoption ? 'FOR SALE' : 'BREEDING',
                              color: petData.isAdoption ? _red : _blue,
                              textColor: Colors.white),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Action buttons (X and heart)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // X button
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _red.withValues(alpha: 0.5), width: 2),
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.close, color: _red, size: 30),
                  ),
                  // Heart/paw button
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, _orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.pets,
                        color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _BadgeChip(
      {required this.label,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Speech Bubble (overlay on photo) ─────────────────────────────

class _SpeechBubbleOverlay extends StatelessWidget {
  final String text;
  const _SpeechBubbleOverlay({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: _blue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF333333),
              height: 1.4)),
    );
  }
}

// ── Speech Bubble (standalone for About section) ──────────────────

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: _blue.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF444444),
                  height: 1.6,
                  fontStyle: FontStyle.italic)),
        ),
        const SizedBox(height: 6),
        // Small bubble tail
        Container(
          width: 20,
          height: 14,
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _blue.withValues(alpha: 0.4), width: 1.5),
          ),
        ),
      ],
    );
  }
}

// ── Info 2-column row ─────────────────────────────────────────────

class _InfoRow2Col extends StatelessWidget {
  final String label1;
  final String value1;
  final String label2;
  final String value2;
  const _InfoRow2Col(this.label1, this.value1, this.label2, this.value2);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _InfoCell(label: label1, value: value1)),
      Expanded(child: _InfoCell(label: label2, value: value2)),
    ]);
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333))),
    ]);
  }
}

// ── Health Record Row ─────────────────────────────────────────────

class _HealthRecordRow extends StatelessWidget {
  final String type;
  final String file;
  final File? imageFile;
  final String fileUrl;
  final String dateIssued;
  final String clinic;
  const _HealthRecordRow({
    required this.type,
    required this.file,
    this.imageFile,
    this.fileUrl = '',
    this.dateIssued = '',
    this.clinic = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.description_outlined, size: 20, color: _blue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333))),
            Text(file,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888888))),
          ]),
        ),
        // VACC mini doc
        Container(
          width: 36,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FFF0),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _green.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('VACC',
                    style: TextStyle(
                        fontSize: 5,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              const Icon(Icons.article_outlined, size: 14, color: _green),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showPreview(context),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.visibility_outlined, size: 12, color: _orange),
            SizedBox(width: 4),
            Text('VIEW',
                style: TextStyle(
                    fontSize: 10,
                    color: _orange,
                    fontWeight: FontWeight.bold)),
              ]),
          ),
        ),
      ]),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(type,
                        style: const TextStyle(
                            color: _blue,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(file, style: const TextStyle(color: Color(0xFF666666))),
              if (dateIssued.isNotEmpty)
                Text('Issued: $dateIssued',
                    style: const TextStyle(color: Color(0xFF666666))),
              if (clinic.isNotEmpty)
                Text('Clinic: $clinic',
                    style: const TextStyle(color: Color(0xFF666666))),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                    child: imageFile != null
                        ? Image.file(imageFile!, fit: BoxFit.cover)
                        : fileUrl.isNotEmpty
                        ? BreedrNetworkImage(
                            imageUrl: fileUrl,
                            fit: BoxFit.cover,
                            fallback: Container(
                              height: 180,
                              color: const Color(0xFFEAF3FF),
                              child: const Center(
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 54,
                                  color: _blue,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 180,
                            color: const Color(0xFFEAF3FF),
                            child: const Center(
                              child: Icon(Icons.description_outlined,
                                  size: 54, color: _blue),
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

// ── Photo Carousel ────────────────────────────────────────────────

class _PhotoCarousel extends StatelessWidget {
  final PetListingData petData;
  final int current;
  final int total;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PhotoCarousel({
    required this.petData,
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final photos = petData.additionalPhotoFiles.isNotEmpty
        ? petData.additionalPhotoFiles
        : [
            if (petData.profilePhotoFile != null) petData.profilePhotoFile!,
          ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavArrow(icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          height: 260,
          child: PageView.builder(
            key: ValueKey(current),
            controller: PageController(initialPage: current - 1),
            physics: const BouncingScrollPhysics(),
            itemCount: total,
            onPageChanged: onChanged,
            itemBuilder: (context, index) {
              final photo = index < photos.length ? photos[index] : null;

              return _ReviewPhotoCard(photo: photo);
            },
          ),
        ),
        const SizedBox(width: 12),
        _NavArrow(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _ReviewPhotoCard extends StatelessWidget {
  final File? photo;

  const _ReviewPhotoCard({
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Positioned(
        top: 14,
        left: 18,
        right: 0,
        bottom: 0,
        child: Transform.rotate(
          angle: 0.06,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 14,
        bottom: 14,
        child: Transform.rotate(
          angle: -0.03,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: photo != null
                ? Image.file(
                    photo!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: const Color(0xFFE0E0E0),
                    child: const Center(
                      child: Icon(Icons.pets,
                          size: 64, color: Color(0xFFBBBBBB)),
                    ),
                  ),
          ),
        ),
      ),
    ]);
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.5),
          color: Colors.white,
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

// ── 5-step progress bar ───────────────────────────────────────────

class _PetStepBar extends StatelessWidget {
  final int currentStep;
  const _PetStepBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: Row(children: [
            const SizedBox(width: 28),
            Expanded(child: _StepLine(active: currentStep > 1)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 2)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 3)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 4)),
            const SizedBox(width: 28),
          ]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 1; i <= 5; i++)
              _StepDot(step: i, current: currentStep),
          ],
        ),
      ]),
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
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : const Color(0xFFFFF0F5),
        border: Border.all(
          color: isActive ? AppColors.primary : const Color(0xFFFFB3C1),
          width: isActive ? 0 : 2,
        ),
        boxShadow: isActive
            ? [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 18, spreadRadius: 2)]
            : [],
      ),
      child: Icon(Icons.pets, size: 22,
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
