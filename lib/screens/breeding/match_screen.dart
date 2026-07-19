import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';

class MatchScreen extends StatelessWidget {
  final String matchedPetName;
  final String currentPetPhoto;
  final String currentPetSpecies;
  final String matchedPetPhoto;
  final String matchedPetSpecies;
  final VoidCallback onKeepSwiping;
  final VoidCallback onSayHello;

  const MatchScreen({
    super.key,
    required this.matchedPetName,
    required this.currentPetPhoto,
    required this.currentPetSpecies,
    required this.matchedPetPhoto,
    required this.matchedPetSpecies,
    required this.onKeepSwiping,
    required this.onSayHello,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE0EC), Color(0xFFFFF0F5), Color(0xFFFFE0EC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Confetti / ribbons area + photos
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative ribbons (painted)
                    const Positioned.fill(child: _RibbonPainter()),

                    // Two tilted pet photos
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 380,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Right photo (back, tilted right)
                            Positioned(
                              right: 20,
                              top: 20,
                              child: Transform.rotate(
                                angle: 0.12,
                                child: _PhotoCard(
                                  width: 180,
                                  height: 240,
                                  photoUrl: matchedPetPhoto,
                                  species: matchedPetSpecies,
                                ),
                              ),
                            ),
                            // Left photo (front, tilted left)
                            Positioned(
                              left: 20,
                              top: 60,
                              child: Transform.rotate(
                                angle: -0.08,
                                child: _PhotoCard(
                                  width: 190,
                                  height: 250,
                                  photoUrl: currentPetPhoto,
                                  species: currentPetSpecies,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                child: Column(
                  children: [
                    const Text(
                      'CONGRATULATIONS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "IT'S A MATCH!",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Start a conversation now with $matchedPetName's owner",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        // Keep Swiping
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: onKeepSwiping,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Keep Swiping',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Say Hello
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: onSayHello,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Say Hello',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.waving_hand_outlined, size: 22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _PhotoCard extends StatelessWidget {
  final double width, height;
  final String photoUrl;
  final String species;

  const _PhotoCard({
    required this.width,
    required this.height,
    required this.photoUrl,
    required this.species,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BreedrNetworkImage(
          imageUrl: photoUrl,
          fallback: _PetPhotoPlaceholder(species: species),
        ),
      ),
    );
  }
}

class _PetPhotoPlaceholder extends StatelessWidget {
  final String species;

  const _PetPhotoPlaceholder({required this.species});

  @override
  Widget build(BuildContext context) {
    final isCat = species.toLowerCase() == 'cat';

    return Container(
      color: const Color(0xFFFFDDE6),
      child: Center(
        child: Icon(
          isCat ? Icons.cruelty_free : Icons.pets,
          size: 54,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// Ribbon/confetti painter
class _RibbonPainter extends StatelessWidget {
  const _RibbonPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RibbonCustomPainter());
  }
}

class _RibbonCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Heart at top center
    _drawHeart(canvas, Offset(size.width / 2, 40), 28,
        const Color(0xFFF43845).withValues(alpha: 0.9));

    // Small hearts scattered
    _drawHeart(canvas, Offset(size.width * 0.25, 80), 12,
        AppColors.primary.withValues(alpha: 0.6));
    _drawHeart(canvas, Offset(size.width * 0.75, 100), 10,
        AppColors.primary.withValues(alpha: 0.5));
    _drawHeart(canvas, Offset(size.width * 0.15, 160), 8,
        AppColors.primary.withValues(alpha: 0.4));
    _drawHeart(canvas, Offset(size.width * 0.85, 180), 9,
        AppColors.primary.withValues(alpha: 0.45));

    // Paw marks
    _drawPaw(canvas, Offset(size.width * 0.55, 55), 7,
        AppColors.primary.withValues(alpha: 0.35));
    _drawPaw(canvas, Offset(size.width * 0.7, 75), 6,
        AppColors.primary.withValues(alpha: 0.3));

    // Ribbon strokes (orange/red curved lines)
    final ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Left ribbon (orange)
    ribbonPaint.color = const Color(0xFFF2AA58).withValues(alpha: 0.85);
    final leftPath = Path();
    leftPath.moveTo(size.width * 0.05, 20);
    leftPath.cubicTo(size.width * 0.1, 60, size.width * 0.05, 100,
        size.width * 0.15, 130);
    canvas.drawPath(leftPath, ribbonPaint);

    // Right ribbon (red)
    ribbonPaint.color = const Color(0xFFF43845).withValues(alpha: 0.75);
    final rightPath = Path();
    rightPath.moveTo(size.width * 0.95, 20);
    rightPath.cubicTo(size.width * 0.9, 60, size.width * 0.95, 100,
        size.width * 0.85, 130);
    canvas.drawPath(rightPath, ribbonPaint);

    // Top left ribbon (orange)
    ribbonPaint.color = const Color(0xFFF2AA58).withValues(alpha: 0.7);
    final tlPath = Path();
    tlPath.moveTo(size.width * 0.1, 10);
    tlPath.cubicTo(size.width * 0.25, 40, size.width * 0.2, 70,
        size.width * 0.3, 90);
    canvas.drawPath(tlPath, ribbonPaint);

    // Top right ribbon (red)
    ribbonPaint.color = const Color(0xFFF43845).withValues(alpha: 0.65);
    final trPath = Path();
    trPath.moveTo(size.width * 0.9, 10);
    trPath.cubicTo(size.width * 0.75, 40, size.width * 0.8, 70,
        size.width * 0.7, 90);
    canvas.drawPath(trPath, ribbonPaint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
        center.dx - size, center.dy - size * 0.3,
        center.dx - size, center.dy + size * 0.5,
        center.dx, center.dy + size);
    path.cubicTo(
        center.dx + size, center.dy + size * 0.5,
        center.dx + size, center.dy - size * 0.3,
        center.dx, center.dy + size * 0.3);
    canvas.drawPath(path, paint);
  }

  void _drawPaw(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(Offset(c.dx - r * 0.7, c.dy - r * 0.9), r * 0.42, p);
    canvas.drawCircle(Offset(c.dx, c.dy - r * 1.1), r * 0.42, p);
    canvas.drawCircle(Offset(c.dx + r * 0.7, c.dy - r * 0.9), r * 0.42, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
