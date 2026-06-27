import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/pet_listing_data.dart';
import '../home_screen.dart';
import 'pet_registration_screen.dart';

class PetPublishedScreen extends StatelessWidget {
  final PetListingData petData;
  final String profilePhotoUrl;

  const PetPublishedScreen({
    super.key,
    required this.petData,
    this.profilePhotoUrl = '',
  });

  bool get isAdoption => petData.isAdoption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Stack(
          children: [
            // Scattered paw marks background
            const Positioned.fill(child: _PawTrail()),

            Column(
              children: [
                // Back arrow
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppColors.primary, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Pet avatar circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: profilePhotoUrl.isNotEmpty
                                ? Image.network(
                                    profilePhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const _PublishedPetPlaceholder(),
                                  )
                                : petData.profilePhotoFile != null
                                    ? Image.file(
                                        petData.profilePhotoFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : const _PublishedPetPlaceholder(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Published title
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              height: 1.2,
                            ),
                            children: [
                              TextSpan(text: '${petData.name} is\nnow live!'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          isAdoption
                              ? "${petData.name}'s adoption profile is now visible to other pet owners nearby."
                              : 'Your pet profile is published. Other pet owners can now discover ${petData.name} nearby.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Pet info card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFFFCDD5), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(petData.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary)),
                                const SizedBox(width: 8),
                                if (isAdoption)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF43845),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('FOR SALE',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                if (isAdoption) const SizedBox(width: 6),
                                // LIVE badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF56C14A)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.circle,
                                          size: 7,
                                          color: Color(0xFF56C14A)),
                                      SizedBox(width: 4),
                                      Text('LIVE',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF56C14A),
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.pets,
                                    size: 13, color: Color(0xFF888888)),
                                const SizedBox(width: 4),
                                Text(
                                    '${petData.breed}  |  ${petData.gender}  |  ${petData.age}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF666666))),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.location_on,
                                    size: 13, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(petData.locationName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF666666))),
                              ]),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // What happens next card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFFFCDD5), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('What happens next?',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                              const SizedBox(height: 14),
                              ...(isAdoption
                                      ? _adoptionSteps(petData.name)
                                      : _breedingSteps(petData.name))
                                  .map(
                                (s) => _NextStep(
                                  icon: s.icon,
                                  text: s.text,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (route) => false,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                              isAdoption ? 'View Adoption' : 'Explore Breeding',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const PetRegistrationScreen()),
                            (route) => false,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Register Another Pet',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step data ─────────────────────────────────────────────────────

class _StepData {
  final IconData icon;
  final String text;
  const _StepData(this.icon, this.text);
}

class _PublishedPetPlaceholder extends StatelessWidget {
  const _PublishedPetPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFCDD5),
      child: const Icon(
        Icons.pets,
        color: AppColors.primary,
        size: 56,
      ),
    );
  }
}

List<_StepData> _breedingSteps(String petName) {
  return [
    _StepData(Icons.favorite,
        '$petName will appear in the Breeding tab for compatible pets nearby.'),
    _StepData(Icons.notifications_outlined,
        "When another owner likes $petName, you'll be notified."),
    const _StepData(Icons.favorite_border,
        'Like them back to create a Match - a chat opens automatically to arrange the meetup.'),
    _StepData(Icons.share_outlined,
        "Share $petName's health documents in chat to build trust with the other owner."),
  ];
}

List<_StepData> _adoptionSteps(String petName) {
  return [
    _StepData(Icons.notifications_outlined,
        "You'll be notified when someone answers your interview questions and requests to adopt $petName."),
    const _StepData(Icons.assignment_outlined,
        'Review their answers in My Listings and approve or decline.'),
    const _StepData(Icons.chat_bubble_outline,
        'Once approved, a chat opens to negotiate and arrange the meetup.'),
    _StepData(Icons.pets,
        'After handover, mark $petName as Adopted to close the listing.'),
  ];
}
// ── Next Step Row ─────────────────────────────────────────────────

class _NextStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NextStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                      height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paw trail background ──────────────────────────────────────────

class _PawTrail extends StatelessWidget {
  const _PawTrail();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PawTrailPainter());
  }
}

class _PawTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final positions = [
      // top right diagonal trail
      _P(size.width * 0.88, size.height * 0.03, 14, 0.3),
      _P(size.width * 0.78, size.height * 0.07, 11, 0.22),
      _P(size.width * 0.70, size.height * 0.12, 13, 0.28),
      _P(size.width * 0.60, size.height * 0.17, 10, 0.2),
      // left side trail
      _P(size.width * 0.08, size.height * 0.22, 16, 0.28),
      _P(size.width * 0.14, size.height * 0.30, 12, 0.22),
      _P(size.width * 0.06, size.height * 0.38, 14, 0.25),
      _P(size.width * 0.12, size.height * 0.46, 10, 0.18),
      // scattered
      _P(size.width * 0.82, size.height * 0.55, 12, 0.2),
      _P(size.width * 0.90, size.height * 0.62, 10, 0.15),
    ];

    for (final p in positions) {
      _drawPaw(canvas, Offset(p.x, p.y), p.r, p.o);
    }
  }

  void _drawPaw(Canvas canvas, Offset c, double r, double opacity) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, paint);
    final tr = r * 0.42;
    canvas.drawCircle(Offset(c.dx - r * 0.65, c.dy - r * 0.9), tr, paint);
    canvas.drawCircle(Offset(c.dx, c.dy - r * 1.1), tr, paint);
    canvas.drawCircle(Offset(c.dx + r * 0.65, c.dy - r * 0.9), tr, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _P {
  final double x, y, r, o;
  const _P(this.x, this.y, this.r, this.o);
}
