import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'pet_adoption_profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final List<FavoritePet> favorites;

  const FavoritesScreen({super.key, required this.favorites});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _filter = 'All';
  late List<FavoritePet> _pets;

  @override
  void initState() {
    super.initState();
    _pets = List.from(widget.favorites);
  }

  List<FavoritePet> get _filtered {
    if (_filter == 'All') return _pets;
    if (_filter == 'Dogs') return _pets.where((p) => p.species == 'Dog').toList();
    if (_filter == 'Cats') return _pets.where((p) => p.species == 'Cat').toList();
    if (_filter == 'Free') return _pets.where((p) => !p.isForSale).toList();
    if (_filter == 'For sale') return _pets.where((p) => p.isForSale).toList();
    return _pets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: AppColors.primary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Expanded(
                  child: Text('FAVORITES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222))),
                ),
                // Paw badge icon
                Stack(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFE0E6),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: const Icon(Icons.pets,
                        color: AppColors.primary, size: 20),
                  ),
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.primary),
                      child: Center(
                        child: Text('${_pets.length}',
                            style: const TextStyle(
                                fontSize: 9, color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Dogs', 'Cats', 'Free', 'For sale']
                    .map((f) {
                  final isSel = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white : const Color(0xFFFFE8EA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF333333)
                                : Colors.transparent,
                            width: isSel ? 1.5 : 0,
                          ),
                        ),
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSel
                                    ? const Color(0xFF222222)
                                    : AppColors.primary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Pet cards
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border,
                              size: 64, color: Color(0xFFDDDDDD)),
                          SizedBox(height: 12),
                          Text('No favorites yet',
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF888888))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final pet = _filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PetAdoptionProfileScreen(
                                  listingId: pet.listingId,
                                ),
                              ),
                            ),
                            child: _FavPetCard(pet: pet),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Favorite Pet Card ─────────────────────────────────────────────

class _FavPetCard extends StatelessWidget {
  final FavoritePet pet;
  const _FavPetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover photo
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity, height: 160,
                child: Image.asset('assets/images/Welcome.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Center(child: Icon(Icons.pets,
                          size: 48, color: Color(0xFFBBBBBB))),
                    )),
              ),
            ),
            // Badge
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pet.isForSale
                      ? const Color(0xFF5399F0)
                      : const Color(0xFF56C14A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(pet.isForSale ? 'FOR SALE' : 'FREE',
                    style: const TextStyle(fontSize: 9, color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            // Avatar
            Positioned(
              bottom: -20, left: 14,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  color: const Color(0xFFFFCDD5),
                ),
                child: ClipOval(child: Image.asset('assets/images/Welcome.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.pets,
                        color: AppColors.primary, size: 24))),
              ),
            ),
            Positioned(
              bottom: -14, left: 44,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF1DA1F2)),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
          ]),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(pet.name, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
                  if (pet.isForSale) ...[
                    const SizedBox(width: 8),
                    Text('₱ ${_fmt(pet.price)}', style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
                  ],
                  const Spacer(),
                  // Heart (already favorited)
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.favorite,
                        color: AppColors.primary, size: 18),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.pets, size: 12, color: Color(0xFF888888)),
                  const SizedBox(width: 4),
                  Text('${pet.breed}  •  ${pet.gender}  •  ${pet.age}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('${pet.location}  •  ${pet.barangay}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  if (pet.vetVerified)
                    _Chip(label: 'Vet Verified',
                        color: const Color(0xFF5399F0), textColor: Colors.white),
                  _Chip(label: pet.color,
                      color: const Color(0xFFFFE8EA), textColor: AppColors.primary),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFCDD5),
                      border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
                    ),
                    child: ClipOval(child: Image.asset('assets/images/profile.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.person,
                            size: 14, color: AppColors.primary))),
                  ),
                  const SizedBox(width: 8),
                  Text(pet.ownerName, style: const TextStyle(
                      fontSize: 12, color: Color(0xFF555555))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('VIEW PET OWNER PROFILE →',
                        style: TextStyle(fontSize: 8, color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int price) =>
      price >= 1000 ? '${(price / 1000).toStringAsFixed(0)},000' : '$price';
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, textColor;
  const _Chip({required this.label, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(fontSize: 10, color: textColor,
        fontWeight: FontWeight.w600)),
  );
}

// ── Data model ────────────────────────────────────────────────────

class FavoritePet {
  final String listingId;
  final String name, breed, gender, age, location, barangay, color;
  final String ownerName, species;
  final int price;
  final bool vetVerified, isForSale;

  const FavoritePet({
    required this.listingId,
    required this.name, required this.breed, required this.gender,
    required this.age, required this.location, required this.barangay,
    required this.color, required this.ownerName, required this.species,
    required this.price, required this.vetVerified, required this.isForSale,
  });
}
