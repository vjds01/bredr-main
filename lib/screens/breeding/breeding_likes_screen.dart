import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/breeding_match_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../adoption/owner_profile_screen.dart';
import '../adoption/pet_adoption_profile_screen.dart';
import '../chat/chats_screen.dart';
import 'match_screen.dart';

class BreedingLikesPreview extends StatelessWidget {
  final String petId;
  final String petName;
  final String searchQuery;

  const BreedingLikesPreview({
    super.key,
    required this.petId,
    required this.petName,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BreedingIncomingLike>>(
      stream: BreedingMatchService.instance.watchUnansweredIncomingLikes(petId),
      builder: (context, likeSnapshot) {
        if (likeSnapshot.hasError) return const SizedBox.shrink();
        final likes = likeSnapshot.data ?? const <BreedingIncomingLike>[];
        if (likes.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('pets').snapshots(),
          builder: (context, petSnapshot) {
            final pets = _availableLikedPets(
              likes,
              petSnapshot.data?.docs ?? [],
            );
            final query = searchQuery.trim().toLowerCase();
            final visible = query.isEmpty
                ? pets
                : pets.where((pet) => pet.matchesSearch(query)).toList();
            if (visible.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'New Likes for $petName',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BreedingLikesScreen(
                              petId: petId,
                              petName: petName,
                            ),
                          ),
                        ),
                        child: const Text('View More'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  Text(
                    '${pets.length} unanswered ${pets.length == 1 ? 'like' : 'likes'}',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visible.take(5).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _LikePreviewCard(
                        pet: visible[index],
                        currentPetId: petId,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class BreedingLikesScreen extends StatefulWidget {
  final String petId;
  final String petName;

  const BreedingLikesScreen({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<BreedingLikesScreen> createState() => _BreedingLikesScreenState();
}

class _BreedingLikesScreenState extends State<BreedingLikesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
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
        title: Text(
          "${widget.petName}'s Likes",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<List<BreedingIncomingLike>>(
        stream: BreedingMatchService.instance.watchUnansweredIncomingLikes(
          widget.petId,
        ),
        builder: (context, likeSnapshot) {
          if (likeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (likeSnapshot.hasError) {
            return const _LikesMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Likes unavailable',
              message: 'Check your connection and try again.',
            );
          }
          final likes = likeSnapshot.data ?? const <BreedingIncomingLike>[];
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('pets').snapshots(),
            builder: (context, petSnapshot) {
              final pets = _availableLikedPets(
                likes,
                petSnapshot.data?.docs ?? [],
              );
              final visible = _query.isEmpty
                  ? pets
                  : pets.where((pet) => pet.matchesSearch(_query)).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                children: [
                  Text(
                    '${pets.length} New ${pets.length == 1 ? 'Like' : 'Likes'}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Pets that liked your pet. View a profile and respond when interested.',
                    style: TextStyle(color: Color(0xFF777777), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('breeding-likes-search'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) =>
                        setState(() => _query = _normalizeSearch(value)),
                    decoration: InputDecoration(
                      hintText: 'Search likes',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (pets.isEmpty)
                    const _LikesMessage(
                      icon: Icons.favorite_border,
                      title: 'No new likes yet',
                      message: 'New breeding likes will appear here.',
                    )
                  else if (visible.isEmpty)
                    const _LikesMessage(
                      icon: Icons.search_off,
                      title: 'No likes found',
                      message: 'Try a different search term.',
                    )
                  else
                    ...visible.map(
                      (pet) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _LikeListCard(
                          pet: pet,
                          currentPetId: widget.petId,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class BreedingLikeProfileScreen extends StatefulWidget {
  final String currentPetId;
  final String likedPetId;

  const BreedingLikeProfileScreen({
    super.key,
    required this.currentPetId,
    required this.likedPetId,
  });

  @override
  State<BreedingLikeProfileScreen> createState() =>
      _BreedingLikeProfileScreenState();
}

class _BreedingLikeProfileScreenState extends State<BreedingLikeProfileScreen> {
  bool _responding = false;

  Future<void> _respond(_LikedPet current, _LikedPet target, bool liked) async {
    if (_responding) return;
    setState(() => _responding = true);
    try {
      final result = await BreedingMatchService.instance.recordSwipe(
        swiperPetId: current.id,
        swiperPetName: current.name,
        swiperPetPhoto: current.photoUrl,
        swiperOwnerId: current.ownerId,
        targetPetId: target.id,
        targetPetName: target.name,
        targetPetPhoto: target.photoUrl,
        targetOwnerId: target.ownerId,
        liked: liked,
      );
      if (!mounted) return;
      if (!liked) {
        Navigator.pop(context);
        return;
      }
      if (!result.matched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Like saved. Waiting for a mutual match.'),
          ),
        );
        Navigator.pop(context);
        return;
      }
      final action = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (matchContext) => MatchScreen(
            matchedPetName: target.name,
            currentPetPhoto: current.photoUrl,
            currentPetSpecies: current.species,
            matchedPetPhoto: target.photoUrl,
            matchedPetSpecies: target.species,
            onKeepSwiping: () => Navigator.pop(matchContext, 'keep_swiping'),
            onSayHello: () => Navigator.pop(matchContext, 'say_hello'),
          ),
        ),
      );
      if (!mounted) return;

      if (action == 'say_hello') {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              matchId: result.matchId!,
              otherPetName: target.name,
              otherPetPhoto: target.photoUrl,
              otherOwnerId: target.ownerId,
            ),
          ),
        );
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to respond to this like: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection('pets')
            .doc(widget.currentPetId)
            .get(),
        FirebaseFirestore.instance
            .collection('pets')
            .doc(widget.likedPetId)
            .get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final current = _LikedPet.fromDocument(snapshot.data![0]);
        final target = _LikedPet.fromDocument(snapshot.data![1]);
        return Scaffold(
          backgroundColor: const Color(0xFFFFF7FA),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFF7FA),
            foregroundColor: AppColors.primary,
            actions: [
              if (UserSessionService.instance.currentUser?.uid !=
                  target.ownerId)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'report') _showReport(context, target);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Color(0xFFE93535)),
                          SizedBox(width: 8),
                          Text('Report this Listing'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: .82,
                  child: BreedrNetworkImage(
                    imageUrl: target.photoUrl,
                    fit: BoxFit.cover,
                    fallback: const ColoredBox(
                      color: Color(0xFFFFDDE6),
                      child: Icon(
                        Icons.pets,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                target.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('${target.age} • ${target.gender} • ${target.breed}'),
              Text(
                target.location,
                style: const TextStyle(color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              _ProfileSection(
                title: 'ABOUT ${target.name.toUpperCase()}',
                child: Text(
                  target.about.isEmpty ? 'No description added.' : target.about,
                ),
              ),
              const SizedBox(height: 16),
              _ProfileSection(
                title: '${target.name.toUpperCase()} PET HEALTH RECORD',
                child: Text(
                  target.healthRecordCount == 0
                      ? 'No health records added.'
                      : '${target.healthRecordCount} health record(s) available.',
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerProfileScreen(
                      ownerId: target.ownerId,
                      fallbackName: target.ownerName,
                      fallbackPhoto: target.ownerPhoto,
                      ratingPurpose: 'breeding',
                    ),
                  ),
                ),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: target.ownerPhoto.isEmpty
                          ? null
                          : NetworkImage(target.ownerPhoto),
                    ),
                    title: Text(target.ownerName),
                    subtitle: const Text('View breeder profile'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _responding
                          ? null
                          : () => _respond(current, target, false),
                      child: const Text('Pass'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _responding
                          ? null
                          : () => _respond(current, target, true),
                      child: Text(_responding ? 'Please wait...' : 'Like Back'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReport(BuildContext context, _LikedPet pet) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetListingReportSheet(
        target: PetListingReportTarget(
          petId: pet.id,
          petName: pet.name,
          species: pet.species,
          breed: pet.breed,
          purpose: 'breeding',
          profilePhoto: pet.photoUrl,
          ownerId: pet.ownerId,
          ownerName: pet.ownerName,
        ),
      ),
    );
  }
}

class _LikePreviewCard extends StatelessWidget {
  final _LikedPet pet;
  final String currentPetId;
  const _LikePreviewCard({required this.pet, required this.currentPetId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openLikedPet(context, currentPetId, pet.id),
      child: SizedBox(
        width: 125,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BreedrNetworkImage(
                imageUrl: pet.photoUrl,
                width: 125,
                height: 135,
                fit: BoxFit.cover,
                fallback: const ColoredBox(
                  color: Color(0xFFFFDDE6),
                  child: Icon(Icons.pets),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              '${pet.gender} • ${pet.age}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeListCard extends StatelessWidget {
  final _LikedPet pet;
  final String currentPetId;
  const _LikeListCard({required this.pet, required this.currentPetId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BreedrNetworkImage(
                imageUrl: pet.photoUrl,
                width: 92,
                height: 118,
                fit: BoxFit.cover,
                fallback: const ColoredBox(
                  color: Color(0xFFFFDDE6),
                  child: Icon(Icons.pets),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${pet.gender} • ${pet.age} • ${pet.breed}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    pet.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Owner: ${pet.ownerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          _openLikedPet(context, currentPetId, pet.id),
                      child: const Text('View Profile'),
                    ),
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

void _openLikedPet(
  BuildContext context,
  String currentPetId,
  String likedPetId,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BreedingLikeProfileScreen(
        currentPetId: currentPetId,
        likedPetId: likedPetId,
      ),
    ),
  );
}

List<_LikedPet> _availableLikedPets(
  List<BreedingIncomingLike> likes,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
  final likedIds = likes.map((like) => like.likingPetId).toSet();
  return documents
      .where((document) => likedIds.contains(document.id))
      .map(_LikedPet.fromDocument)
      .where((pet) => pet.isAvailable)
      .toList();
}

class _LikedPet {
  final String id, name, species, breed, age, gender, location, about;
  final String photoUrl, ownerId, ownerName, ownerPhoto;
  final int healthRecordCount;
  final bool isAvailable;

  const _LikedPet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.gender,
    required this.location,
    required this.about,
    required this.photoUrl,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
    required this.healthRecordCount,
    required this.isAvailable,
  });

  factory _LikedPet.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final status = (data['status'] ?? '').toString().toLowerCase();
    final purpose = (data['purpose'] ?? '').toString().toLowerCase();
    return _LikedPet(
      id: document.id,
      name: data['name'] as String? ?? 'Pet',
      species: data['species'] as String? ?? '',
      breed: data['breed'] as String? ?? '',
      age: data['age'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      location: data['locationName'] as String? ?? '',
      about: data['about'] as String? ?? '',
      photoUrl:
          data['petProfilePhoto'] as String? ??
          data['profilePhoto'] as String? ??
          '',
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Pet Owner',
      ownerPhoto: data['ownerPhoto'] as String? ?? '',
      healthRecordCount: (data['healthRecords'] as List?)?.length ?? 0,
      isAvailable:
          purpose == 'breeding' &&
          (data['isActive'] as bool? ?? true) &&
          data['adminHidden'] != true &&
          data['adminRemoved'] != true &&
          !{
            'matched',
            'adopted',
            'removed',
            'inactive',
            'deleted',
          }.contains(status),
    );
  }

  bool matchesSearch(String query) {
    final searchable = _normalizeSearch(
      '$name $breed $species $gender $age $ownerName $location',
    );
    return searchable.contains(_normalizeSearch(query));
  }
}

String _normalizeSearch(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class _ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _ProfileSection({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _LikesMessage extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const _LikesMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(icon, size: 48, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF777777)),
        ),
      ],
    ),
  );
}
