import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class MapPet {
  final String name;
  const MapPet(this.name);
}

class LocationFilteringScreen extends StatefulWidget {
  final List<MapPet> pets;
  final int selectedPetIndex;
  final ValueChanged<int> onPetSelected;
  final int bottomNavIndex;
  final ValueChanged<int> onBottomNavTap;

  const LocationFilteringScreen({
    super.key,
    required this.pets,
    required this.selectedPetIndex,
    required this.onPetSelected,
    required this.bottomNavIndex,
    required this.onBottomNavTap,
  });

  @override
  State<LocationFilteringScreen> createState() => _LocationFilteringScreenState();
}

class _LocationFilteringScreenState extends State<LocationFilteringScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedPetIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — same as breeding screen
            _TopBar(
              pets: widget.pets,
              selectedIndex: _selectedIndex,
              onPetSelected: (i) => setState(() => _selectedIndex = i),
            ),
            // Filter button
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune, size: 16, color: Color(0xFF444444)),
                    SizedBox(width: 6),
                    Text('Filter', style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF444444))),
                  ]),
                ),
              ),
            ),
            // Map
            Expanded(
              child: Stack(
                children: [
                  // Map background
                  Positioned.fill(child: CustomPaint(painter: _MapPainter())),

                  // Pet avatars scattered on map
                  _PetPin(left: 0.08, top: 0.18, size: 52,
                      borderColor: const Color(0xFFE8A0D0)),
                  _PetPin(left: 0.72, top: 0.22, size: 48,
                      borderColor: const Color(0xFFB0C4DE)),
                  _PetPin(left: 0.78, top: 0.52, size: 48,
                      borderColor: const Color(0xFFB0C4DE)),
                  _PetPin(left: 0.62, top: 0.72, size: 52,
                      borderColor: const Color(0xFFE8A0D0)),
                  _PetPin(left: 0.06, top: 0.62, size: 48,
                      borderColor: const Color(0xFFE8A0D0)),
                  _PetPin(left: 0.06, top: 0.82, size: 52,
                      borderColor: const Color(0xFFE8A0D0)),

                  // User avatar in center with label
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User avatar with pink glow border
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/Welcome1.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFFFFCDD5),
                                child: const Icon(Icons.person,
                                    color: AppColors.primary, size: 50),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Label
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Finding pets near you...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom nav
            _BottomNav(
              selectedIndex: widget.bottomNavIndex,
              onTap: widget.onBottomNavTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pet pin on map ────────────────────────────────────────────────

class _PetPin extends StatelessWidget {
  final double left, top, size;
  final Color borderColor;

  const _PetPin({
    required this.left,
    required this.top,
    required this.size,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Subtract top bar height approx
    final mapHeight = screenSize.height * 0.65;
    return Positioned(
      left: screenSize.width * left,
      top: mapHeight * top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2.5),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/Welcome.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFFFFE0E6),
              child: const Icon(Icons.pets,
                  color: AppColors.primary, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Map background painter ────────────────────────────────────────

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF5F0E8));

    // Green areas
    final green = Paint()..color = const Color(0xFFD8EDD4)..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.04, size.height * 0.08,
                size.width * 0.22, size.height * 0.18),
            const Radius.circular(10)),
        green);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.55, size.height * 0.55,
                size.width * 0.3, size.height * 0.2),
            const Radius.circular(10)),
        green);

    // River (blue curved)
    final river = Paint()
      ..color = const Color(0xFFADD8E6)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final riverPath = Path();
    riverPath.moveTo(size.width * 0.38, 0);
    riverPath.cubicTo(
        size.width * 0.42, size.height * 0.25,
        size.width * 0.32, size.height * 0.55,
        size.width * 0.38, size.height);
    canvas.drawPath(riverPath, river);

    // Roads
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Main horizontal road
    canvas.drawLine(Offset(0, size.height * 0.42),
        Offset(size.width, size.height * 0.46), road);

    // SLEX diagonal
    road.strokeWidth = 8;
    canvas.drawLine(Offset(size.width * 0.62, 0),
        Offset(size.width * 0.68, size.height), road);

    // Secondary roads
    road.strokeWidth = 5;
    canvas.drawLine(Offset(0, size.height * 0.68),
        Offset(size.width * 0.58, size.height * 0.72), road);
    canvas.drawLine(Offset(size.width * 0.18, 0),
        Offset(size.width * 0.22, size.height * 0.5), road);

    // Road outline (slightly darker)
    final roadOutline = Paint()
      ..color = const Color(0xFFE8E0D0)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.42),
        Offset(size.width, size.height * 0.46), roadOutline);

    // Labels
    _drawLabel(canvas, 'Nestlé\nPhilippines',
        Offset(size.width * 0.05, size.height * 0.12), 9);
    _drawLabel(canvas, 'Cabuyao',
        Offset(size.width * 0.38, size.height * 0.62), 13,
        bold: true);
    _drawLabel(canvas, 'SLEX',
        Offset(size.width * 0.64, size.height * 0.38), 10,
        bold: true);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, double fontSize,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF888888),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Top bar ───────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final List<MapPet> pets;
  final int selectedIndex;
  final ValueChanged<int> onPetSelected;

  const _TopBar({
    required this.pets,
    required this.selectedIndex,
    required this.onPetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Text('Swiping as:',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
          const SizedBox(width: 8),
          ...List.generate(pets.length, (i) {
            final isSel = i == selectedIndex;
            return GestureDetector(
              onTap: () => onPetSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: isSel
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFFFE0E6) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSel
                              ? AppColors.primary
                              : const Color(0xFFDDDDDD),
                          width: 2),
                      color: const Color(0xFFFFCDD5),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/images/Welcome.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                              Icons.pets, size: 16, color: AppColors.primary)),
                    ),
                  ),
                  if (isSel) ...[
                    const SizedBox(width: 6),
                    Text(pets[i].name,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.favorite, label: 'Breeding'),
      _NavItem(icon: Icons.pets, label: 'Adoption'),
      _NavItem(icon: Icons.chat_bubble_outline, label: 'Chat'),
      _NavItem(icon: Icons.notifications_outlined, label: 'Notif'),
      _NavItem(icon: Icons.person_outline, label: 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isSel = i == selectedIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(items[i].icon, size: 24,
                      color: isSel
                          ? AppColors.primary
                          : const Color(0xFF888888)),
                  const SizedBox(height: 3),
                  Text(items[i].label, style: TextStyle(
                      fontSize: 10,
                      color: isSel
                          ? AppColors.primary
                          : const Color(0xFF888888),
                      fontWeight: isSel
                          ? FontWeight.bold
                          : FontWeight.normal)),
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
