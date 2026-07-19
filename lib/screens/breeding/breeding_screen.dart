import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/breed_options.dart';
import '../../services/breeding_match_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../chat/chats_screen.dart';
import '../owner/owner_ratings_screen.dart';
import 'match_screen.dart';

class BreedingScreen extends StatefulWidget {
  final ValueListenable<int>? activationSignal;

  const BreedingScreen({
    super.key,
    this.activationSignal,
  });

  @override
  State<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends State<BreedingScreen> {
  int _selectedMyPetIndex = 0;
  int _candidateIndex = 0;
  bool _showDetails = false;
  bool _showLocationSearch = false;
  bool _pendingInitialLocationSearch = true;
  int _locationSearchRun = 0;
  String? _selectedSpecies;
  _BreedingFilter _filter = const _BreedingFilter();

  @override
  void initState() {
    super.initState();
    widget.activationSignal?.addListener(_handleBreedingActivated);
  }

  @override
  void didUpdateWidget(covariant BreedingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationSignal == widget.activationSignal) return;
    oldWidget.activationSignal?.removeListener(_handleBreedingActivated);
    widget.activationSignal?.addListener(_handleBreedingActivated);
  }

  @override
  void dispose() {
    widget.activationSignal?.removeListener(_handleBreedingActivated);
    super.dispose();
  }

  void _handleBreedingActivated() {
    if (!mounted) return;
    setState(() {
      _pendingInitialLocationSearch = true;
      _showDetails = false;
    });
  }

  void _startLocationSearch() {
    if (!mounted) return;
    setState(() {
      _pendingInitialLocationSearch = false;
      _showLocationSearch = true;
    });

    final run = ++_locationSearchRun;
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted || run != _locationSearchRun) return;
      setState(() => _showLocationSearch = false);
    });
  }

  bool _isEligibleBreedingCandidate(
    _BreedingPet pet,
    _BreedingPet selectedPet,
    String currentUserId,
  ) {
    final ownerId = pet.ownerId.trim();
    final selectedOwnerId = selectedPet.ownerId.trim();

    if (pet.id == selectedPet.id) return false;
    if (ownerId.isEmpty) return false;
    if (ownerId == currentUserId) return false;
    if (selectedOwnerId.isNotEmpty && ownerId == selectedOwnerId) return false;
    if (pet.species.toLowerCase() != selectedPet.species.toLowerCase()) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final uid = UserSessionService.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF0F5),
        body: SafeArea(
          child: _BreedingEmptyState(
            icon: Icons.lock_outline,
            title: 'Please log in first.',
            subtitle: 'Your breeding matches will appear here after sign in.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pets')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final pets = snapshot.data?.docs
                    .map((doc) => _BreedingPet.fromDoc(doc))
                    .where((pet) => pet.isAvailableForBreeding)
                    .toList() ??
                const <_BreedingPet>[];

            final myPets =
                pets.where((pet) => pet.ownerId.trim() == uid).toList();

            if (_selectedMyPetIndex >= myPets.length) {
              _selectedMyPetIndex = 0;
            }

            final selectedPet =
                myPets.isEmpty ? null : myPets[_selectedMyPetIndex];
            if (_pendingInitialLocationSearch && selectedPet != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_pendingInitialLocationSearch) return;
                _startLocationSearch();
              });
            }
            _selectedSpecies = selectedPet?.species;
            final compatibleCandidates = selectedPet == null
                ? const <_BreedingPet>[]
                : pets
                    .where(
                      (pet) => _isEligibleBreedingCandidate(
                        pet,
                        selectedPet,
                        uid,
                      ),
                    )
                    .where(_filter.matches)
                    .toList();
            if (selectedPet != null) {
              compatibleCandidates.sort(
                (a, b) => a
                    .distanceSortValue(selectedPet)
                    .compareTo(b.distanceSortValue(selectedPet)),
              );
            }

            return StreamBuilder<Set<String>>(
              stream: selectedPet == null
                  ? null
                  : BreedingMatchService.instance
                      .watchSwipedPetIds(selectedPet.id),
              initialData: const <String>{},
              builder: (context, swipeSnapshot) {
                final swipedIds = swipeSnapshot.data ?? const <String>{};
                final candidates = compatibleCandidates
                    .where(
                      (pet) => selectedPet == null
                          ? false
                          : _isEligibleBreedingCandidate(pet, selectedPet, uid),
                    )
                    .where((pet) => !swipedIds.contains(pet.id))
                    .toList();

                if (_candidateIndex >= candidates.length) {
                  _candidateIndex = 0;
                }

                final candidate =
                    candidates.isEmpty ? null : candidates[_candidateIndex];

                return Column(
                  children: [
                    _TopBar(
                      pets: myPets,
                      selectedIndex: _selectedMyPetIndex,
                      onPetSelected: (index) => setState(() {
                        final currentSpecies = myPets.isEmpty
                            ? ''
                            : myPets[_selectedMyPetIndex].species;
                        final nextSpecies = myPets[index].species;
                        _selectedMyPetIndex = index;
                        _candidateIndex = 0;
                        if (currentSpecies != nextSpecies) {
                          _filter = const _BreedingFilter();
                        }
                        _showDetails = false;
                      }),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 16, top: 4, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _FilterButton(onTap: _showFilterSheet),
                      ),
                    ),
                    Expanded(
                      child: (_showLocationSearch ||
                                  _pendingInitialLocationSearch) &&
                              selectedPet != null
                          ? _LocationSearchView(
                              swipingAs: selectedPet,
                              candidates: candidates,
                            )
                          : candidate == null
                              ? _BreedingEmptyState(
                                  icon: Icons.pets,
                                  title: 'No breeding pets yet.',
                                  subtitle: myPets.isEmpty
                                      ? 'Add one of your pets for breeding, then nearby listings from other owners will show here.'
                                      : 'No ${selectedPet?.species.toLowerCase() ?? 'pet'} listings match your current filters.',
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _BreedingPetCard(
                                    pet: candidate,
                                    swipingAs: selectedPet,
                                    showDetails: _showDetails,
                                    onPass: () =>
                                        _onPass(selectedPet!, candidate),
                                    onLike: () =>
                                        _onLike(selectedPet!, candidate),
                                    onToggleDetails: () => setState(
                                      () => _showDetails = !_showDetails,
                                    ),
                                  ),
                                ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _onPass(
    _BreedingPet swipingPet,
    _BreedingPet targetPet,
  ) async {
    setState(() => _showDetails = false);

    try {
      await BreedingMatchService.instance.recordSwipe(
        swiperPetId: swipingPet.id,
        swiperPetName: swipingPet.name,
        swiperPetPhoto: swipingPet.photoUrl,
        swiperOwnerId: swipingPet.ownerId,
        targetPetId: targetPet.id,
        targetPetName: targetPet.name,
        targetPetPhoto: targetPet.photoUrl,
        targetOwnerId: targetPet.ownerId,
        liked: false,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      _logSwipeFailure(
        action: 'pass',
        swipingPet: swipingPet,
        targetPet: targetPet,
        error: error,
        stackTrace: stackTrace,
      );
      _showSwipeError(error);
    }
  }

  Future<void> _onLike(
    _BreedingPet swipingPet,
    _BreedingPet targetPet,
  ) async {
    setState(() => _showDetails = false);

    try {
      final result = await BreedingMatchService.instance.recordSwipe(
        swiperPetId: swipingPet.id,
        swiperPetName: swipingPet.name,
        swiperPetPhoto: swipingPet.photoUrl,
        swiperOwnerId: swipingPet.ownerId,
        targetPetId: targetPet.id,
        targetPetName: targetPet.name,
        targetPetPhoto: targetPet.photoUrl,
        targetOwnerId: targetPet.ownerId,
        liked: true,
      );

      if (!mounted) return;

      if (!result.matched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${targetPet.name} was added to your likes.')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchScreen(
            matchedPetName: targetPet.name,
            currentPetPhoto: swipingPet.photoUrl,
            currentPetSpecies: swipingPet.species,
            matchedPetPhoto: targetPet.photoUrl,
            matchedPetSpecies: targetPet.species,
            onKeepSwiping: () => Navigator.pop(context),
            onSayHello: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatConversationScreen(
                    matchId: result.matchId!,
                    otherPetName: targetPet.name,
                    otherPetPhoto: targetPet.photoUrl,
                    otherOwnerId: targetPet.ownerId,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      _logSwipeFailure(
        action: 'like',
        swipingPet: swipingPet,
        targetPet: targetPet,
        error: error,
        stackTrace: stackTrace,
      );
      _showSwipeError(error);
    }
  }

  void _logSwipeFailure({
    required String action,
    required _BreedingPet swipingPet,
    required _BreedingPet targetPet,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint(
      'Breeding swipe failed. '
      'action=$action '
      'swiperPetId=${swipingPet.id} '
      'swiperOwnerId=${swipingPet.ownerId} '
      'targetPetId=${targetPet.id} '
      'targetOwnerId=${targetPet.ownerId} '
      'error=$error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  void _showSwipeError(Object error) {
    var message = 'Unable to save this swipe. Please try again.';

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        message =
            'Swipe permissions need updating. Please contact support if this continues.';
      } else if (error.code == 'unavailable') {
        message = 'Connection issue. Please check your internet and try again.';
      }
    } else if (error is StateError &&
        error.message.contains('permanently unmatched')) {
      message = 'These pets were previously unmatched and cannot match again.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showFilterSheet() async {
    final species = _selectedSpecies;

    if (species == null || species.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a breeding pet before filtering.')),
      );
      return;
    }

    final filter = await showModalBottomSheet<_BreedingFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        species: species,
        initialFilter: _filter,
      ),
    );

    if (filter == null || !mounted) return;

    setState(() {
      _filter = filter;
      _candidateIndex = 0;
      _showDetails = false;
      _pendingInitialLocationSearch = false;
    });
    _startLocationSearch();
  }
}

class _BreedingPet {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;
  final String name;
  final String species;
  final String breed;
  final List<String> breedTags;
  final String age;
  final String gender;
  final String color;
  final String size;
  final String about;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String photoUrl;
  final List<String> additionalImages;
  final List<Map<String, dynamic>> healthRecords;
  final bool vetVerified;
  final String status;
  final bool isActive;
  final String purpose;

  const _BreedingPet({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
    required this.name,
    required this.species,
    required this.breed,
    required this.breedTags,
    required this.age,
    required this.gender,
    required this.color,
    required this.size,
    required this.about,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.photoUrl,
    required this.additionalImages,
    required this.healthRecords,
    required this.vetVerified,
    required this.status,
    required this.isActive,
    required this.purpose,
  });

  factory _BreedingPet.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawRecords = data['healthRecords'] as List? ?? const [];

    return _BreedingPet(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Pet Owner',
      ownerPhoto: data['ownerPhoto'] as String? ?? '',
      name: data['name'] as String? ?? 'Pet',
      species: data['species'] as String? ?? '',
      breed: data['breed'] as String? ?? '',
      breedTags:
          (data['breedTags'] as List?)?.whereType<String>().toList() ?? const [],
      age: data['age'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      color: data['color'] as String? ?? '',
      size: data['breedSize'] as String? ?? '',
      about: data['about'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      photoUrl: (data['petProfilePhoto'] as String?) ??
          (data['profilePhoto'] as String?) ??
          '',
      additionalImages:
          (data['additionalImages'] as List?)?.cast<String>() ?? const [],
      healthRecords: rawRecords
          .whereType<Map>()
          .map((record) => Map<String, dynamic>.from(record))
          .toList(),
      vetVerified: data['vetVerified'] as bool? ?? rawRecords.isNotEmpty,
      status: data['status'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      purpose: data['purpose'] as String? ?? '',
    );
  }

  bool get isAvailableForBreeding {
    final normalizedPurpose = purpose.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();

    if (normalizedPurpose != 'breeding') return false;
    if (!isActive) return false;
    if (normalizedStatus == 'matched' || normalizedStatus == 'adopted') {
      return false;
    }

    return true;
  }

  String distanceFrom(_BreedingPet? other) {
    if (other?.latitude == null ||
        other?.longitude == null ||
        latitude == null ||
        longitude == null) {
      return 'Nearby';
    }

    final km = _distanceInKm(
      other!.latitude!,
      other.longitude!,
      latitude!,
      longitude!,
    );
    return '${km.toStringAsFixed(1)}km away';
  }

  double distanceSortValue(_BreedingPet? other) {
    if (other?.latitude == null ||
        other?.longitude == null ||
        latitude == null ||
        longitude == null) {
      return double.maxFinite;
    }

    return _distanceInKm(
      other!.latitude!,
      other.longitude!,
      latitude!,
      longitude!,
    );
  }

  bool get hasVaccinationRecord {
    return healthRecords.any((record) {
      final type = (record['type'] as String? ?? '').toLowerCase();
      return type.contains('vacc');
    });
  }

  int? get ageInMonths => _parseAgeInMonths(age);

  static int? _parseAgeInMonths(String value) {
    final lower = value.toLowerCase();
    final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    if (numberMatch == null) return null;

    final number = double.tryParse(numberMatch.group(1)!);
    if (number == null) return null;

    if (lower.contains('week')) return (number / 4.345).round();
    if (lower.contains('month')) return number.round();
    if (lower.contains('year')) return (number * 12).round();
    return number.round();
  }

  static double _distanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

class _BreedingFilter {
  final String breed;
  final int? minAgeMonths;
  final int? maxAgeMonths;
  final bool vaccinatedOnly;
  final bool vetVerifiedOnly;

  const _BreedingFilter({
    this.breed = 'Any Breed',
    this.minAgeMonths,
    this.maxAgeMonths,
    this.vaccinatedOnly = false,
    this.vetVerifiedOnly = false,
  });

  bool matches(_BreedingPet pet) {
    if (breed != 'Any Breed') {
      final target = breed.trim().toLowerCase();
      final petBreeds = [
        pet.breed,
        ...pet.breedTags,
      ].map((value) => value.trim().toLowerCase()).toSet();
      final matchesBreed = petBreeds.contains(target) ||
          petBreeds.any((value) => value.contains(target) || target.contains(value));
      if (!matchesBreed) return false;
    }

    final age = pet.ageInMonths;
    if (minAgeMonths != null && age != null && age < minAgeMonths!) {
      return false;
    }
    if (maxAgeMonths != null && age != null && age > maxAgeMonths!) {
      return false;
    }
    if (vaccinatedOnly && !pet.hasVaccinationRecord) return false;
    if (vetVerifiedOnly && !pet.vetVerified) return false;

    return true;
  }

  _BreedingFilter copyWith({
    String? breed,
    int? minAgeMonths,
    int? maxAgeMonths,
    bool clearMinAge = false,
    bool clearMaxAge = false,
    bool? vaccinatedOnly,
    bool? vetVerifiedOnly,
  }) {
    return _BreedingFilter(
      breed: breed ?? this.breed,
      minAgeMonths: clearMinAge ? null : minAgeMonths ?? this.minAgeMonths,
      maxAgeMonths: clearMaxAge ? null : maxAgeMonths ?? this.maxAgeMonths,
      vaccinatedOnly: vaccinatedOnly ?? this.vaccinatedOnly,
      vetVerifiedOnly: vetVerifiedOnly ?? this.vetVerifiedOnly,
    );
  }
}

class _TopBar extends StatelessWidget {
  final List<_BreedingPet> pets;
  final int selectedIndex;
  final ValueChanged<int> onPetSelected;

  const _TopBar({
    required this.pets,
    required this.selectedIndex,
    required this.onPetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 0, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF5FB),
        border: Border(bottom: BorderSide(color: Color(0xFFFFD3DD))),
      ),
      child: Row(
        children: [
          const Text(
            'Swiping as:',
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFF111111),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 18),
          if (pets.isEmpty)
            const Expanded(
              child: Text(
                'Add a breeding pet',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: List.generate(pets.length, (index) {
                    final pet = pets[index];
                    final selected = index == selectedIndex;

                    return GestureDetector(
                      onTap: () => onPetSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 12),
                        padding: selected
                            ? const EdgeInsets.fromLTRB(6, 6, 18, 6)
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFCAD6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(58),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x66E95C73),
                                    offset: Offset(0, 4),
                                    blurRadius: 7,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SpeciesAvatar(
                              url: pet.photoUrl,
                              species: pet.species,
                              size: selected ? 52 : 58,
                              borderWidth: selected ? 0 : 6,
                            ),
                            if (selected) ...[
                              const SizedBox(width: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 112),
                                child: Text(
                                  pet.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF111111),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FilterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 16, color: Color(0xFF444444)),
            SizedBox(width: 6),
            Text(
              'Filter',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSearchView extends StatelessWidget {
  final _BreedingPet swipingAs;
  final List<_BreedingPet> candidates;

  const _LocationSearchView({
    required this.swipingAs,
    required this.candidates,
  });

  @override
  Widget build(BuildContext context) {
    final pins = candidates.take(6).toList();

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapSearchPainter())),
        ...List.generate(pins.length, (index) {
          const positions = [
            Offset(0.06, 0.16),
            Offset(0.78, 0.23),
            Offset(0.88, 0.58),
            Offset(0.08, 0.62),
            Offset(0.14, 0.84),
            Offset(0.72, 0.76),
          ];
          final position = positions[index % positions.length];
          return _MapPetPin(
            pet: pins[index],
            leftFactor: position.dx,
            topFactor: position.dy,
          );
        }),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BreedrNetworkImage(
                    imageUrl: swipingAs.ownerPhoto,
                    width: 122,
                    height: 122,
                    fallback: const _OwnerPlaceholder(),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Finding pets near you...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPetPin extends StatelessWidget {
  final _BreedingPet pet;
  final double leftFactor;
  final double topFactor;

  const _MapPetPin({
    required this.pet,
    required this.leftFactor,
    required this.topFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment(leftFactor * 2 - 1, topFactor * 2 - 1),
        child: _SpeciesAvatar(
          url: pet.photoUrl,
          species: pet.species,
          size: 48,
          borderWidth: 4,
        ),
      ),
    );
  }
}

class _OwnerPlaceholder extends StatelessWidget {
  const _OwnerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFDDE5),
      child: const Icon(Icons.person, color: AppColors.primary, size: 54),
    );
  }
}

class _MapSearchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF6EFEF),
    );

    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.12 + i * 0.13);
      canvas.drawLine(Offset(-20, y), Offset(size.width + 20, y + 26), road);
    }

    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.08 + i * 0.22);
      canvas.drawLine(Offset(x, -20), Offset(x + 26, size.height + 20), road);
    }

    final river = Paint()
      ..color = const Color(0xFFBDEAF5)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(size.width * 0.58, -10)
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.2,
        size.width * 0.72,
        size.height * 0.3,
        size.width * 0.58,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.7,
        size.width * 0.7,
        size.height * 0.82,
        size.width * 0.63,
        size.height + 10,
      );
    canvas.drawPath(riverPath, river);

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Cabuyao',
        style: TextStyle(
          color: Color(0xFF8D9099),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(size.width * 0.63, size.height * 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BreedingPetCard extends StatefulWidget {
  final _BreedingPet pet;
  final _BreedingPet? swipingAs;
  final bool showDetails;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onToggleDetails;

  const _BreedingPetCard({
    required this.pet,
    required this.swipingAs,
    required this.showDetails,
    required this.onPass,
    required this.onLike,
    required this.onToggleDetails,
  });

  @override
  State<_BreedingPetCard> createState() => _BreedingPetCardState();
}

class _BreedingPetCardState extends State<_BreedingPetCard>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 100;

  double _dragX = 0;
  late final AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.showDetails) return;
    setState(() => _dragX += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.showDetails) return;

    if (_dragX > _swipeThreshold) {
      _animateOut(1);
    } else if (_dragX < -_swipeThreshold) {
      _animateOut(-1);
    } else {
      _snapAnimation = Tween<double>(begin: _dragX, end: 0).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
      );
      _snapAnimation.addListener(() {
        if (mounted) setState(() => _dragX = _snapAnimation.value);
      });
      _snapController.forward(from: 0);
    }
  }

  void _animateOut(double direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    _snapAnimation = Tween<double>(
      begin: _dragX,
      end: direction * screenWidth * 1.4,
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeIn),
    );
    _snapAnimation.addListener(() {
      if (mounted) setState(() => _dragX = _snapAnimation.value);
    });
    _snapController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _dragX = 0);
      direction > 0 ? widget.onLike() : widget.onPass();
    });
  }

  @override
  Widget build(BuildContext context) {
    final angle = (_dragX / 300).clamp(-0.4, 0.4);

    return CustomPaint(
      painter: _DashedRectPainter(
        color: const Color(0xFF999999),
        radius: 34,
        dashWidth: 8,
        gapWidth: 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Container(
          color: Colors.white,
          child: widget.showDetails
              ? _ExpandedPetProfile(
                  pet: widget.pet,
                  swipingAs: widget.swipingAs,
                  onPass: widget.onPass,
                  onLike: widget.onLike,
                  onToggleDetails: widget.onToggleDetails,
                )
              : Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.identity()
                            ..translate(_dragX)
                            ..rotateZ(angle),
                          child: _PhotoHero(
                            pet: widget.pet,
                            swipingAs: widget.swipingAs,
                            expanded: false,
                            onToggleDetails: widget.onToggleDetails,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _ActionButtons(
                        onPass: widget.onPass,
                        onLike: widget.onLike,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ExpandedPetProfile extends StatelessWidget {
  final _BreedingPet pet;
  final _BreedingPet? swipingAs;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onToggleDetails;

  const _ExpandedPetProfile({
    required this.pet,
    required this.swipingAs,
    required this.onPass,
    required this.onLike,
    required this.onToggleDetails,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 430,
            child: _PhotoHero(
              pet: pet,
              swipingAs: swipingAs,
              expanded: true,
              onToggleDetails: onToggleDetails,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoGrid(rows: {
                  'Species': pet.species,
                  'Breed': pet.breed,
                  'Age': pet.age,
                  'Gender': pet.gender,
                  'Color': pet.color,
                  'Size': pet.size,
                }),
                const SizedBox(height: 18),
                const _ThinDivider(),
                const SizedBox(height: 14),
                _SectionTitle('ABOUT ${pet.name.toUpperCase()}'),
                const SizedBox(height: 12),
                _SpeechBubble(
                  text: pet.about.isEmpty
                      ? '${pet.name} has no description yet.'
                      : pet.about,
                ),
                const SizedBox(height: 18),
                const _ThinDivider(),
                const SizedBox(height: 14),
                _SectionTitle('${pet.name.toUpperCase()} PET HEALTH RECORD'),
                const SizedBox(height: 10),
                if (pet.healthRecords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'No health records added yet.',
                      style: TextStyle(color: Color(0xFF777777)),
                    ),
                  )
                else
                  ...pet.healthRecords.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HealthRecordRow(record: record),
                    ),
                  ),
                const SizedBox(height: 12),
                _ActionButtons(onPass: onPass, onLike: onLike),
                const SizedBox(height: 18),
                _OwnerCard(pet: pet),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoHero extends StatelessWidget {
  final _BreedingPet pet;
  final _BreedingPet? swipingAs;
  final bool expanded;
  final VoidCallback onToggleDetails;

  const _PhotoHero({
    required this.pet,
    required this.swipingAs,
    required this.expanded,
    required this.onToggleDetails,
  });

  @override
  Widget build(BuildContext context) {
    final distance = pet.distanceFrom(swipingAs);

    return Stack(
      fit: StackFit.expand,
      children: [
        BreedrNetworkImage(
          imageUrl: pet.photoUrl,
          fallback: const _PetFallbackBlock(),
        ),
        const Positioned(
          top: 18,
          left: 46,
          right: 46,
          child: _PhotoProgressBars(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 110, 78, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0x66383838),
                  Color(0xE61F1F1F),
                ],
                stops: [0, 0.48, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        pet.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '|',
                        style: TextStyle(color: Colors.white60, fontSize: 22),
                      ),
                    ),
                    Text(
                      pet.age,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Icon(Icons.verified,
                        color: Color(0xFF35A4FF), size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                _HeroMeta(
                  icon: Icons.pets,
                  color: Colors.white,
                  text: '${pet.breed} | ${pet.size}',
                ),
                const SizedBox(height: 3),
                _HeroMeta(
                  icon: Icons.location_on,
                  color: const Color(0xFFFFB35A),
                  text: '$distance | ${pet.locationName}',
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (pet.vetVerified)
                      const _Badge(
                        label: 'Vet Verified',
                        color: Color(0xFF2D95E8),
                        textColor: Colors.white,
                      ),
                    if (pet.color.isNotEmpty)
                      _Badge(
                        label: pet.color,
                        color: Colors.white,
                        textColor: const Color(0xFF6A3A3A),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 24,
          child: Column(
            children: [
              _CircleNetworkImage(
                url: pet.ownerPhoto,
                size: 44,
                fallbackIcon: Icons.person,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: onToggleDetails,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border.all(color: Colors.white54, width: 1.5),
                  ),
                  child: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoProgressBars extends StatelessWidget {
  const _PhotoProgressBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        6,
        (index) => Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _HeroMeta({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onLike;

  const _ActionButtons({
    required this.onPass,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        InkWell(
          onTap: onPass,
          customBorder: const CircleBorder(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.close, color: AppColors.primary, size: 38),
          ),
        ),
        InkWell(
          onTap: onLike,
          customBorder: const CircleBorder(),
          child: Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFFFFC59E)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x44FF4D65),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 36),
          ),
        ),
      ],
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final _BreedingPet pet;

  const _OwnerCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(pet.ownerId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final ownerName =
            data?['fullName'] as String? ?? pet.ownerName;
        final handle = data?['userName'] as String? ?? '';
        final location = data?['locationName'] as String? ?? pet.locationName;
        final photoUrl = data?['profilePhoto'] as String? ?? pet.ownerPhoto;
        void openRatings() => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OwnerRatingsScreen(
                  ownerId: pet.ownerId,
                  fallbackName: ownerName,
                  fallbackPhoto: photoUrl,
                  initialFilter: OwnerReviewFilter.breeding,
                ),
              ),
            );

        return InkWell(
          onTap: openRatings,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _CircleNetworkImage(
                      url: photoUrl,
                      size: 52,
                      fallbackIcon: Icons.person,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownerName,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              if (handle.isNotEmpty)
                                _OwnerMeta(
                                  icon: Icons.alternate_email,
                                  text: handle,
                                ),
                              if (location.isNotEmpty)
                                _OwnerMeta(
                                  icon: Icons.location_on_outlined,
                                  text: location,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'View owner ratings',
                      onPressed: openRatings,
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _OwnerStats(ownerId: pet.ownerId),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OwnerStats extends StatelessWidget {
  final String ownerId;

  const _OwnerStats({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance.watchPublishedReviewsForUser(
        ownerId,
      ),
      builder: (context, reviewsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pets')
              .where('ownerId', isEqualTo: ownerId)
              .snapshots(),
          builder: (context, petsSnapshot) {
            final reviews = reviewsSnapshot.data?.docs ?? [];
            final petsListed = petsSnapshot.data?.docs.length ?? 0;
            final average = _averageBreedingRating(reviews);

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        value:
                            average == null ? 'New' : average.toStringAsFixed(1),
                        label: 'Breeding Rating',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatBox(
                        value:
                            reviews.isEmpty ? '0' : reviews.length.toString(),
                        label: reviews.length == 1 ? 'Review' : 'Reviews',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatBox(
                        value: petsListed.toString(),
                        label: 'Pets Listed',
                      ),
                    ),
                  ],
                ),
                if (reviews.isEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD6DD)),
                    ),
                    child: const Text(
                      'No breeding reviews yet. Completed reviews will appear here once available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  double? _averageBreedingRating(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
  ) {
    final ratings = reviews
        .map((document) => document.data()['overall'])
        .whereType<num>()
        .map((rating) => rating.toDouble())
        .toList();
    if (ratings.isEmpty) return null;

    return ratings.reduce((sum, rating) => sum + rating) / ratings.length;
  }
}

class _OwnerMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OwnerMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF888888), size: 12),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F9),
        border: Border.all(color: const Color(0xFFFFB9C5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Map<String, String> rows;

  const _InfoGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 14,
      children: rows.entries
          .map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.value.isEmpty ? 'Not set' : entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
          .toList(),
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
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;

  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 230,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          border: Border.all(color: const Color(0xFF3D8BFF), width: 2),
          borderRadius: BorderRadius.circular(42),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _HealthRecordRow extends StatelessWidget {
  final Map<String, dynamic> record;

  const _HealthRecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final type = record['type'] as String? ?? 'Record';
    final fileName = record['fileName'] as String? ?? '';
    final fileUrl = record['fileUrl'] as String? ?? '';
    final dateIssued = record['dateIssued'] as String? ?? '';
    final clinic = record['clinic'] as String? ?? '';
    final veterinarian = record['veterinarian'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D95E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: Color(0xFF2D95E8), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  fileName,
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
            onPressed: () => _showHealthRecordPreview(
              context,
              type: type,
              fileName: fileName,
              fileUrl: fileUrl,
              dateIssued: dateIssued,
              clinic: clinic,
              veterinarian: veterinarian,
            ),
            icon: const Icon(Icons.visibility_outlined, size: 13),
            label: const Text('VIEW'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD99B42),
              textStyle: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthRecordPreview(
    BuildContext context, {
    required String type,
    required String fileName,
    required String fileUrl,
    required String dateIssued,
    required String clinic,
    required String veterinarian,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _RecordDetailRow(label: 'File', value: fileName),
              _RecordDetailRow(label: 'Date issued', value: dateIssued),
              _RecordDetailRow(label: 'Clinic', value: clinic),
              _RecordDetailRow(label: 'Veterinarian', value: veterinarian),
              const SizedBox(height: 14),
              if (fileUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BreedrNetworkImage(
                    imageUrl: fileUrl,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    fallback: const _RecordFallback(),
                  ),
                )
              else
                const _RecordFallback(),
              const SizedBox(height: 12),
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
      ),
    );
  }
}

class _RecordDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _RecordDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordFallback extends StatelessWidget {
  const _RecordFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: AppColors.primary, size: 34),
          SizedBox(height: 8),
          Text(
            'No image preview available.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CircleNetworkImage extends StatelessWidget {
  final String url;
  final double size;
  final IconData fallbackIcon;

  const _CircleNetworkImage({
    required this.url,
    required this.size,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFCDD5),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: BreedrNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fallback: Icon(
            fallbackIcon,
            color: AppColors.primary,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}

class _SpeciesAvatar extends StatelessWidget {
  final String url;
  final String species;
  final double size;
  final double borderWidth;

  const _SpeciesAvatar({
    required this.url,
    required this.species,
    required this.size,
    this.borderWidth = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFDDE5),
        border: Border.all(
          color: const Color(0xFFFFC9D4),
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: BreedrNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fallback: _SpeciesPlaceholder(species: species),
        ),
      ),
    );
  }
}

class _SpeciesPlaceholder extends StatelessWidget {
  final String species;

  const _SpeciesPlaceholder({required this.species});

  @override
  Widget build(BuildContext context) {
    final isCat = species.toLowerCase() == 'cat';

    return Container(
      color: const Color(0xFFFFE4EC),
      child: Center(
        child: Icon(
          isCat ? Icons.cruelty_free : Icons.pets,
          color: AppColors.primary,
          size: 34,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFFFCDD5));
  }
}

class _PetFallbackBlock extends StatelessWidget {
  const _PetFallbackBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFCDD5),
      child: const Center(
        child: Icon(Icons.pets, color: AppColors.primary, size: 78),
      ),
    );
  }
}

class _BreedingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BreedingEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double gapWidth;

  const _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.gapWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterSheet extends StatefulWidget {
  final String species;
  final _BreedingFilter initialFilter;

  const _FilterSheet({
    required this.species,
    required this.initialFilter,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _selectedBreed;
  late bool _vaccinatedOnly;
  late bool _vetVerifiedOnly;

  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();

  String _minUnit = 'months old';
  String _maxUnit = 'years old';
  String? _warning;

  List<_BreedOption> get _speciesBreeds =>
      _BreedOption.all.where((breed) => breed.species == widget.species).toList();

  List<String> get _quickBreeds {
    final names = _speciesBreeds.map((breed) => breed.name).toList();
    if (widget.species == 'Dog') {
      return [
        'Any Breed',
        'Golden Retriever',
        'Labrador Retriever',
        'Shih Tzu',
        'Siberian Husky',
        'Pomeranian',
      ].where((breed) => breed == 'Any Breed' || names.contains(breed)).toList();
    }

    return [
      'Any Breed',
      'British Shorthair',
      'Persian',
      'Siamese',
      'Maine Coon',
    ].where((breed) => breed == 'Any Breed' || names.contains(breed)).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedBreed = widget.initialFilter.breed;
    final breedBelongsToSpecies = _selectedBreed == 'Any Breed' ||
        _speciesBreeds.any((breed) => breed.name == _selectedBreed);
    if (!breedBelongsToSpecies) {
      _selectedBreed = 'Any Breed';
    }
    _vaccinatedOnly = widget.initialFilter.vaccinatedOnly;
    _vetVerifiedOnly = widget.initialFilter.vetVerifiedOnly;

    if (widget.initialFilter.minAgeMonths != null) {
      _minUnit = 'months old';
      _minAgeController.text = widget.initialFilter.minAgeMonths.toString();
    }
    if (widget.initialFilter.maxAgeMonths != null) {
      _maxUnit = 'months old';
      _maxAgeController.text = widget.initialFilter.maxAgeMonths.toString();
    }
  }

  @override
  void dispose() {
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 170,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7D7D7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter Matches',
                        style: TextStyle(
                          color: Color(0xFF1D1D1F),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          color: Color(0xFF222222),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _FilterLabel('Breed'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._quickBreeds.map(
                      (breed) => _FilterChip(
                        label: breed,
                        selected: _selectedBreed == breed,
                        onTap: () => setState(() => _selectedBreed = breed),
                      ),
                    ),
                    _MoreBreedChip(onTap: _openBreedPicker),
                  ],
                ),
                const SizedBox(height: 34),
                const _FilterLabel('Age Range'),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'Min',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AgeInput(
                        controller: _minAgeController,
                        unit: _minUnit,
                        onUnitChanged: (unit) => setState(() => _minUnit = unit),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Max',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AgeInput(
                        controller: _maxAgeController,
                        unit: _maxUnit,
                        onUnitChanged: (unit) => setState(() => _maxUnit = unit),
                      ),
                    ),
                  ],
                ),
                if (_warning != null) ...[
                  const SizedBox(height: 16),
                  _FilterWarning(message: _warning!),
                ],
                const SizedBox(height: 34),
                const _FilterLabel('Requirements'),
                const SizedBox(height: 12),
                _RequirementToggle(
                  title: 'Vaccinated Only',
                  subtitle: 'Show only pets with vaccination records',
                  value: _vaccinatedOnly,
                  onChanged: (value) => setState(() => _vaccinatedOnly = value),
                ),
                _RequirementToggle(
                  title: 'Vet Verified Only',
                  subtitle: 'Show only vet-verified profiles',
                  value: _vetVerifiedOnly,
                  onChanged: (value) => setState(() => _vetVerifiedOnly = value),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _applyFilter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'APPLY BREEDING FILTER',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBreedPicker() async {
    final breed = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BreedPickerSheet(
        species: widget.species,
        selectedBreed: _selectedBreed,
      ),
    );

    if (breed == null || !mounted) return;
    setState(() => _selectedBreed = breed);
  }

  void _applyFilter() {
    final minAge = _parseAgeInput(_minAgeController.text, _minUnit);
    final maxAge = _parseAgeInput(_maxAgeController.text, _maxUnit);

    final warning = _validateAgeRange(minAge, maxAge);
    if (warning != null) {
      setState(() => _warning = warning);
      return;
    }

    setState(() => _warning = null);
    Navigator.pop(
      context,
      _BreedingFilter(
        breed: _selectedBreed,
        minAgeMonths: minAge,
        maxAgeMonths: maxAge,
        vaccinatedOnly: _vaccinatedOnly,
        vetVerifiedOnly: _vetVerifiedOnly,
      ),
    );
  }

  int? _parseAgeInput(String raw, String unit) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final number = double.tryParse(value);
    if (number == null) {
      setState(() => _warning = 'Please enter a valid number for age.');
      return -1;
    }
    if (number <= 0) {
      setState(() => _warning = 'Please enter a valid age greater than 0.');
      return -1;
    }

    if (unit == 'weeks old') return (number / 4.345).round();
    if (unit == 'years old') return (number * 12).round();
    return number.round();
  }

  String? _validateAgeRange(int? minAge, int? maxAge) {
    if (minAge == -1 || maxAge == -1) return _warning;

    final effectiveMin = minAge;
    final effectiveMax = maxAge;

    final lowerBound = effectiveMin ?? effectiveMax;

    if (lowerBound != null && lowerBound < 12) {
      return 'This age range is too young for breeding. Pets must be at least 12 months old before breeding.';
    }
    if (widget.species == 'Dog' &&
        lowerBound != null &&
        lowerBound < 18) {
      return 'This age range is too young for breeding. Larger breeds should be at least 18 months old.';
    }
    if (effectiveMin != null &&
        effectiveMax != null &&
        effectiveMin > effectiveMax) {
      return 'Minimum breeding age cannot be greater than maximum age.';
    }
    if ((effectiveMax != null && effectiveMax > 96) ||
        (effectiveMin != null && effectiveMin > 96)) {
      return 'This age range may be beyond the recommended breeding age. Breeding older pets may pose health risks.';
    }

    return null;
  }
}

class _BreedPickerSheet extends StatefulWidget {
  final String species;
  final String selectedBreed;

  const _BreedPickerSheet({
    required this.species,
    required this.selectedBreed,
  });

  @override
  State<_BreedPickerSheet> createState() => _BreedPickerSheetState();
}

class _BreedPickerSheetState extends State<_BreedPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  late String _selectedBreed;

  List<_BreedOption> get _filteredBreeds {
    final query = _query.trim().toLowerCase();
    return _BreedOption.all
        .where((breed) => breed.species == widget.species)
        .where((breed) =>
            query.isEmpty || breed.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedBreed = widget.selectedBreed;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        final filtered = _filteredBreeds;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: const Color(0xFFF2AA58), width: 2.5),
          ),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Breed',
                        style: TextStyle(
                          color: Color(0xFFFF8A00),
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _selectedBreed),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          color: Color(0xFFFF8A00),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search breed name...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFFFA640),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF777777)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFA640),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _query.trim().isEmpty
                        ? 'Showing ${widget.species.toLowerCase()} breeds'
                        : 'Showing result for "$_query"',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 18, 32, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} RESULTS FOUND',
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
                  itemCount: filtered.length + 1,
                  separatorBuilder: (_, _) =>
                      const Divider(color: Color(0xFFE6E6E6)),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _BreedPickerRow(
                        name: 'Any Breed',
                        species: widget.species,
                        selected: _selectedBreed == 'Any Breed',
                        onTap: () => setState(
                          () => _selectedBreed = 'Any Breed',
                        ),
                      );
                    }

                    final breed = filtered[index - 1];
                    return _BreedPickerRow(
                      name: breed.name,
                      species: breed.species,
                      selected: _selectedBreed == breed.name,
                      onTap: () =>
                          setState(() => _selectedBreed = breed.name),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BreedPickerRow extends StatelessWidget {
  final String name;
  final String species;
  final bool selected;
  final VoidCallback onTap;

  const _BreedPickerRow({
    required this.name,
    required this.species,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFE2C0),
              ),
              child: Icon(
                species == 'Dog' ? Icons.pets : Icons.cruelty_free,
                color: const Color(0xFFFFA640),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF252525),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    species,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: const Color(0xFFFFA640),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedOption {
  final String name;
  final String species;

  const _BreedOption(this.name, this.species);

  static final all = [
    ...dogBreedOptions.map((breed) => _BreedOption(breed, 'Dog')),
    ...catBreedOptions.map((breed) => _BreedOption(breed, 'Cat')),
  ];
}

class _FilterLabel extends StatelessWidget {
  final String text;

  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF252525),
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFDDE4),
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: const Color(0xFF111111), width: 2)
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1D1D1F),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _MoreBreedChip extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreBreedChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFDDB2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          '+ More',
          style: TextStyle(
            color: Color(0xFF1D1D1F),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _AgeInput extends StatelessWidget {
  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onUnitChanged;

  const _AgeInput({
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF8B8B8B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: unit,
              items: const [
                DropdownMenuItem(
                  value: 'years old',
                  child: Text('years old'),
                ),
                DropdownMenuItem(
                  value: 'months old',
                  child: Text('months old'),
                ),
                DropdownMenuItem(
                  value: 'weeks old',
                  child: Text('weeks old'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onUnitChanged(value);
              },
              style: const TextStyle(
                color: Color(0xFF333333),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _RequirementToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RequirementToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF252525),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFF28A93),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterWarning extends StatelessWidget {
  final String message;

  const _FilterWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF1),
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
