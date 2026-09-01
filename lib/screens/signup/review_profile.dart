import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../onboarding/account_created_screen.dart';
import '../../models/onboarding_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/cloudinary_service.dart';
import '../../services/cabuyao_barangay_service.dart';
import '../auth/login_screen.dart';
import 'dart:io';

class Step3Welcome extends StatefulWidget {
  final OnboardingData onboardingData;

  const Step3Welcome({super.key, required this.onboardingData});

  @override
  State<Step3Welcome> createState() => _Step3WelcomeState();
}

class _Step3WelcomeState extends State<Step3Welcome> {
  int _currentPhotoIndex = 0;
  bool _isCreatingAccount = false;
  int get _totalPhotos => widget.onboardingData.additionalPhotoFiles.length;

  Future<void> _createAccount() async {
    if (_isCreatingAccount) return;

    final validationMessage = _validationMessage();
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() => _isCreatingAccount = true);

    try {
      debugPrint('Preparing Firebase Auth user...');

      User? user;

      if (widget.onboardingData.authProvider.toLowerCase() == 'google') {
        user = FirebaseAuth.instance.currentUser;
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: widget.onboardingData.email,
              password: widget.onboardingData.password,
            );
        user = credential.user;
      }

      if (user == null) {
        throw Exception('Failed to create user');
      }

      //cloudinary image uploading
      final cloudinary = CloudinaryService();

      var profilePhotoUrl = widget.onboardingData.profilePhoto ?? '';

      if (widget.onboardingData.profilePhotoFile != null) {
        debugPrint('Uploading profile photo...');

        profilePhotoUrl = await cloudinary.uploadImageOrThrow(
          widget.onboardingData.profilePhotoFile!,
        );

        debugPrint('Profile uploaded: $profilePhotoUrl');
      }

      List<String> additionalPhotoUrls = [];

      for (final photo in widget.onboardingData.additionalPhotoFiles) {
        final url = await cloudinary.uploadImageOrThrow(photo);
        additionalPhotoUrls.add(url);
      }

      debugPrint('Additional uploaded: ${additionalPhotoUrls.length}');
      final coverPhotoUrl = additionalPhotoUrls.isNotEmpty
          ? additionalPhotoUrls.first
          : '';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'authProvider': widget.onboardingData.authProvider,

        'fullName': widget.onboardingData.fullName,
        'userName': widget.onboardingData.userName,
        'email': widget.onboardingData.email,

        'bio': widget.onboardingData.bio,
        'homeType': widget.onboardingData.homeType,

        'childrenAtHome': widget.onboardingData.childrenAtHome,
        'otherPetsAtHome': widget.onboardingData.otherPetsAtHome,

        'locationName': widget.onboardingData.locationName,

        'latitude': widget.onboardingData.latitude,
        'longitude': widget.onboardingData.longitude,

        'profilePhoto': profilePhotoUrl,

        'additionalImages': additionalPhotoUrls,
        'additionalPhotos': additionalPhotoUrls,
        'additionalPhotoUrls': additionalPhotoUrls,
        'coverPhoto': coverPhotoUrl,

        'hasProfilePhoto': profilePhotoUrl.isNotEmpty,

        'profileCompleted':
            profilePhotoUrl.isNotEmpty &&
            widget.onboardingData.bio != null &&
            widget.onboardingData.bio!.isNotEmpty &&
            widget.onboardingData.homeType != null &&
            widget.onboardingData.locationName != null,

        'isActive': widget.onboardingData.isActive,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AccountCreatedScreen(
            fullName: widget.onboardingData.fullName,
            profilePhotoUrl: profilePhotoUrl,
          ),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Account auth error: ${e.code} ${e.message}');

      if (!mounted) return;

      if (e.code == 'email-already-in-use') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(
              initialMessage:
                  'An account with this email already exists. Please log in instead.',
            ),
          ),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_accountCreationMessage(e))));
    } on FirebaseException catch (e) {
      debugPrint('Account profile save error: ${e.code} ${e.message}');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_profileSaveMessage(e))));
    } catch (e) {
      debugPrint('Account creation error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is CloudinaryUploadException
                ? 'Unable to upload your photos. Please check your internet connection and try again.'
                : 'Unable to create your account right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingAccount = false);
      }
    }
  }

  String? _validationMessage() {
    final data = widget.onboardingData;
    if (data.fullName.trim().isEmpty) return 'Your full name is required.';
    if (data.userName.trim().isEmpty) return 'Your username is required.';
    if (data.email.trim().isEmpty) return 'Your email address is required.';
    if (data.authProvider.toLowerCase() == 'email' &&
        data.password.length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    if (data.profilePhotoFile == null &&
        (data.profilePhoto?.trim().isEmpty ?? true)) {
      return 'Please upload a profile photo.';
    }
    if (!CabuyaoBarangayService.isCanonicalLocation(data.locationName) ||
        data.latitude == null ||
        data.longitude == null) {
      return 'Your Cabuyao barangay could not be verified.';
    }
    if (data.homeType?.trim().isEmpty ?? true) {
      return 'Please select your type of home.';
    }
    if (data.bio?.trim().isEmpty ?? true) {
      return 'Please complete the About Me field.';
    }
    return null;
  }

  String _accountCreationMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please log in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters long.';
      case 'operation-not-allowed':
        return 'Email sign-up is currently unavailable. Please contact support.';
      case 'too-many-requests':
        return 'Too many sign-up attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      default:
        return 'Unable to create your account right now. Please try again.';
    }
  }

  String _profileSaveMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Your account was created, but the profile could not be saved. Please contact support.';
      case 'unavailable':
        return 'The server is unavailable right now. Please try again in a moment.';
      default:
        return 'Unable to save your profile right now. Please try again.';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back arrow
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Step progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _StepProgressBar(currentStep: 3),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Step 3 of 3',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title + subtitle with left accent bar
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
                                children: const [
                                  Text(
                                    'Review Profile',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Take a moment to review your details before finishing. This helps ensure everything is accurate for pet owners viewing your profile.',
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
                    ),

                    const SizedBox(height: 20),

                    // Cover photo banner
                    SizedBox(
                      width: double.infinity,
                      height: 180,
                      child: _ProfileCoverPreview(
                        coverPhoto:
                            widget
                                .onboardingData
                                .additionalPhotoFiles
                                .isNotEmpty
                            ? widget.onboardingData.additionalPhotoFiles.first
                            : null,
                      ),
                    ),

                    // Profile section
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Welcome1.png — right side decoration
                        Positioned(
                          right: 0,
                          top: 10,
                          child: Image.asset(
                            'assets/images/Welcome1.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Left content: avatar + name + location + tags
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Circular avatar overlapping cover
                              Transform.translate(
                                offset: const Offset(0, -36),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child:
                                        widget
                                                .onboardingData
                                                .profilePhotoFile !=
                                            null
                                        ? Image.file(
                                            widget
                                                .onboardingData
                                                .profilePhotoFile!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.asset(
                                            'assets/images/profile.png',
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),

                              // Name
                              Transform.translate(
                                offset: const Offset(0, -24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          widget.onboardingData.fullName,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.pets,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.onboardingData.locationName ??
                                              'No location',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        if (widget.onboardingData.homeType !=
                                            null)
                                          _Tag(widget.onboardingData.homeType!),

                                        if (widget
                                            .onboardingData
                                            .childrenAtHome)
                                          const _Tag('Has kids'),

                                        if (widget
                                            .onboardingData
                                            .otherPetsAtHome)
                                          const _Tag('Has pets'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // ABOUT ME
                          const _SectionLabel('ABOUT ME'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.onboardingData.bio ?? 'No bio yet.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF555555),
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '\u201d\u201d',
                                  style: TextStyle(
                                    fontSize: 28,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // HOME INFORMATION
                          const _SectionLabel('HOME INFORMATION'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                            ),
                            child: Column(
                              children: [
                                _InfoRow(
                                  'Home Type',
                                  widget.onboardingData.homeType ?? 'Not set',
                                ),

                                const Divider(
                                  height: 1,
                                  color: Color(0xFFF0F0F0),
                                ),

                                _InfoRow(
                                  'Location',
                                  widget.onboardingData.locationName ??
                                      'Not set',
                                ),

                                const Divider(
                                  height: 1,
                                  color: Color(0xFFF0F0F0),
                                ),

                                _InfoRow(
                                  'Pets at Home',
                                  widget.onboardingData.otherPetsAtHome
                                      ? 'YES'
                                      : 'NO',
                                ),

                                const Divider(
                                  height: 1,
                                  color: Color(0xFFF0F0F0),
                                ),

                                _InfoRow(
                                  'Kids at Home',
                                  widget.onboardingData.childrenAtHome
                                      ? 'YES'
                                      : 'NO',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // MORE PHOTO OF YOU fix this, photos should preview here
                          Row(
                            children: [
                              const Text(
                                'MORE PHOTO OF YOU',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF444444),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _totalPhotos == 0
                                    ? '0 / 0'
                                    : '${_currentPhotoIndex + 1} / $_totalPhotos',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Photo carousel with tilted card
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _NavArrow(
                                icon: Icons.chevron_left,
                                onTap: () => setState(() {
                                  if (_currentPhotoIndex > 0) {
                                    _currentPhotoIndex--;
                                  }
                                }),
                              ),
                              const SizedBox(width: 12),
                              // Stacked tilted cards
                              SizedBox(
                                width: 200,
                                height: 270,
                                child: Stack(
                                  children: [
                                    // Pink shadow card — behind, tilted right
                                    Positioned(
                                      top: 14,
                                      left: 20,
                                      right: 0,
                                      bottom: 0,
                                      child: Transform.rotate(
                                        angle: 0.07,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.55,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Main card — blue border + dashed overlay, slight left tilt
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 14,
                                      bottom: 14,
                                      child: Transform.rotate(
                                        angle: -0.04,
                                        child: _DashedCard(
                                          imageFile: _totalPhotos > 0
                                              ? widget
                                                    .onboardingData
                                                    .additionalPhotoFiles[_currentPhotoIndex]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _NavArrow(
                                icon: Icons.chevron_right,
                                onTap: () => setState(() {
                                  if (_currentPhotoIndex <
                                      widget
                                              .onboardingData
                                              .additionalPhotoFiles
                                              .length -
                                          1) {
                                    _currentPhotoIndex++;
                                  }
                                }),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Create My Account — pinned bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCreatingAccount ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCreatingAccount
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating your account...'),
                          ],
                        )
                      : const Text(
                          'Create My Account',
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
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────

class _ProfileCoverPreview extends StatelessWidget {
  final File? coverPhoto;

  const _ProfileCoverPreview({required this.coverPhoto});

  @override
  Widget build(BuildContext context) {
    if (coverPhoto != null) {
      return Image.file(
        coverPhoto!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.asset(
      'assets/images/Welcome.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF888888),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white54, size: 48),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
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

// Card with blue border + dashed overlay
class _DashedCard extends StatelessWidget {
  final File? imageFile;

  const _DashedCard({this.imageFile});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _DashedRectPainter(
              color: const Color(0xFF666666),
              radius: 20,
              dashW: 8,
              gapW: 6,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4FC3F7), width: 3),
              ),
              child: imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.file(
                        imageFile!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.pets,
                        size: 72,
                        color: Color(0xFFBBBBBB),
                      ),
                    ),
            ),
          ),
        );
      },
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

// Step progress bar
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
      child: Icon(
        Icons.pets,
        size: 26,
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
