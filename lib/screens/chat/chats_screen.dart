import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/adoption_models.dart';
import '../../services/adoption_service.dart';
import '../../services/breeding_match_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/presence_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../adoption/owner_profile_screen.dart';
import '../breeding/breeding_likes_screen.dart';

bool _shouldShowConversation(Map<String, dynamic> data, String currentUserId) {
  final isArchived =
      data['status'] == 'unmatched' || data['isArchived'] == true;
  if (!isArchived) return true;
  if (data['archivedBy'] == currentUserId) return false;

  final archivedAt = data['archivedAt'] as Timestamp?;
  if (archivedAt == null) return true;
  return DateTime.now().difference(archivedAt.toDate()).inDays < 7;
}

bool _isHistoryConversation(Map<String, dynamic> data) {
  final status = data['status'] as String? ?? 'active';
  final purpose = data['purpose'] as String? ?? 'breeding';
  return status == 'unmatched' ||
      (status == 'completed' && purpose != 'adoption');
}

int _unreadCount(Map<String, dynamic> data, String userId) {
  final counts = Map<String, dynamic>.from(
    data['unreadCounts'] as Map? ?? const {},
  );
  return (counts[userId] as num?)?.toInt() ?? 0;
}

bool _conversationContainsPet(Map<String, dynamic> data, String petId) {
  final petIds = (data['petIds'] as List?)?.cast<String>() ?? const <String>[];
  if (petIds.contains(petId)) return true;

  if (data['purpose'] == 'adoption') {
    final requestId = data['requestId'] as String? ?? '';
    final conversationId = data['conversationId'] as String? ?? '';
    return requestId.startsWith('${petId}_') ||
        conversationId.startsWith('adoption_${petId}_');
  }

  return false;
}

bool _isAvailableBreedingLike(Map<String, dynamic> data) {
  final purpose = (data['purpose'] ?? '').toString().trim().toLowerCase();
  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  return purpose == 'breeding' &&
      (data['isActive'] as bool? ?? true) &&
      data['adminHidden'] != true &&
      data['adminRemoved'] != true &&
      !{
        'matched',
        'adopted',
        'removed',
        'inactive',
        'deleted',
      }.contains(status);
}

String _conversationTimeLabel(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate().toLocal();
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inHours < 24 && date.day == now.day) {
    return _clockTime(date);
  }
  if (difference.inDays < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
  return '${date.month}/${date.day}/${date.year}';
}

String _clockTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

String _messageDateLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${local.month}/${local.day}/${local.year}';
}

String _shortDateTime(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate().toLocal();
  return '${date.month}/${date.day}/${date.year} at ${_clockTime(date)}';
}

String _chatFirebaseMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Breedr could not update this adoption process. Please sign in again or check that the latest Firestore rules are deployed.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'The service is temporarily unavailable. Check your connection and try again.';
    default:
      return error.message?.trim().isNotEmpty == true
          ? error.message!
          : 'This adoption process could not be updated. Please try again.';
  }
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view conversations.'));
    }

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pets')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final pets =
              snapshot.data?.docs
                  .map((document) => _ChatPet.fromDocument(document))
                  .where(
                    (pet) =>
                        pet.purpose == 'breeding' || pet.purpose == 'adoption',
                  )
                  .toList() ??
              const <_ChatPet>[];
          final query = _searchQuery.trim().toLowerCase();
          final visiblePets = query.isEmpty
              ? pets
              : pets.where((pet) => pet.matchesSearch(query)).toList();
          final breedingPets = visiblePets
              .where((pet) => pet.purpose == 'breeding')
              .toList();
          final adoptionPets = visiblePets
              .where((pet) => pet.purpose == 'adoption')
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Chat',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.chat_bubble,
                      color: AppColors.primary,
                      size: 23,
                    ),
                    const Spacer(),
                    IconButton.filled(
                      tooltip: _showSearch ? 'Close search' : 'Search pets',
                      onPressed: () => setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      }),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE5EC),
                        foregroundColor: AppColors.primary,
                      ),
                      icon: Icon(_showSearch ? Icons.close : Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Which pet?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  "Select a pet to see its conversation",
                  style: TextStyle(color: Color(0xFF222222), fontSize: 14),
                ),
                if (_showSearch) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search pet, breed, or barangay',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.primary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                _PetPurposeSection(title: 'Breeding', pets: breedingPets),
                if (breedingPets.isNotEmpty && adoptionPets.isNotEmpty)
                  const SizedBox(height: 30),
                _AdoptionPetPurposeSection(
                  ownedPets: adoptionPets,
                  searchQuery: query,
                ),
                if (pets.isEmpty) ...[
                  const SizedBox(height: 80),
                  const _EmptyPets(),
                ] else if (visiblePets.isEmpty) ...[
                  const SizedBox(height: 70),
                  const Center(
                    child: Text(
                      'No pets match your search.',
                      style: TextStyle(color: Color(0xFF777777)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Retained for the detailed chat flow's legacy conversation grouping.
// ignore: unused_element
class _AllConversationsSection extends StatelessWidget {
  final String userId;

  const _AllConversationsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance.watchConversations(userId),
      builder: (context, snapshot) {
        final conversations =
            snapshot.data?.docs
                .where(
                  (document) =>
                      _shouldShowConversation(document.data(), userId),
                )
                .toList() ??
            [];
        conversations.sort((a, b) {
          final aTime = a.data()['updatedAt'] as Timestamp?;
          final bTime = b.data()['updatedAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
            aTime?.millisecondsSinceEpoch ?? 0,
          );
        });

        if (conversations.isEmpty) return const SizedBox.shrink();
        final active = conversations
            .where((document) => !_isHistoryConversation(document.data()))
            .toList();
        final history = conversations
            .where((document) => _isHistoryConversation(document.data()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active.isNotEmpty) ...[
              const Text(
                'Active Messages',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ...active
                  .take(4)
                  .map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ConversationTile(
                        matchId: document.id,
                        data: document.data(),
                        selectedPetId: _currentUserPetId(
                          document.data(),
                          userId,
                        ),
                        searchQuery: '',
                      ),
                    ),
                  ),
            ],
            if (history.isNotEmpty) ...[
              if (active.isNotEmpty) const SizedBox(height: 18),
              const Text(
                'History',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              ...history
                  .take(2)
                  .map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ConversationTile(
                        matchId: document.id,
                        data: document.data(),
                        selectedPetId: _currentUserPetId(
                          document.data(),
                          userId,
                        ),
                        searchQuery: '',
                      ),
                    ),
                  ),
            ],
          ],
        );
      },
    );
  }

  String _currentUserPetId(Map<String, dynamic> data, String userId) {
    final petOwners = Map<String, dynamic>.from(
      data['petOwners'] as Map? ?? const {},
    );
    return petOwners.entries
            .where((entry) => entry.value == userId)
            .map((entry) => entry.key)
            .firstOrNull ??
        '';
  }
}

// Retained for compatibility with the approved-adoption chat flow.
// ignore: unused_element
class _AdoptionApplicantChatsSection extends StatelessWidget {
  const _AdoptionApplicantChatsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdoptionRequest>>(
      stream: AdoptionService.instance.watchMyRequests(),
      builder: (context, snapshot) {
        final approvedRequests = (snapshot.data ?? const <AdoptionRequest>[])
            .where(
              (request) => request.status == AdoptionRequestStatus.approved,
            )
            .toList();
        if (approvedRequests.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Approved Adoption Chats',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ...approvedRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ApprovedAdoptionChatTile(request: request),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovedAdoptionChatTile extends StatelessWidget {
  final AdoptionRequest request;

  const _ApprovedAdoptionChatTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final pet = request.petSnapshot;
    final petName = pet['name'] as String? ?? 'Adoption Chat';
    final petPhoto = pet['petProfilePhoto'] as String? ?? '';
    final conversationId =
        request.conversationId ??
        AdoptionService.instance.conversationId(request.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final unread = data == null
            ? 0
            : _unreadCount(
                data,
                UserSessionService.instance.currentUser?.uid ?? '',
              );
        final lastMessage = data?['lastMessage'] as String? ?? '';
        final updatedAt =
            (data?['lastMessageAt'] as Timestamp?) ??
            (data?['updatedAt'] as Timestamp?);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          leading: _ChatAvatar(
            photoUrl: petPhoto,
            ownerId: request.ownerId,
            showPresence: true,
          ),
          title: Text(
            petName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OwnerIdentity(ownerId: request.ownerId, compact: true),
              Text(
                lastMessage.isEmpty
                    ? 'Your request was approved. Open chat with the owner.'
                    : lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          trailing: SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _conversationTimeLabel(updatedAt),
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 9),
                ),
                const SizedBox(height: 5),
                if (unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(11)),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(
                matchId: conversationId,
                otherPetName: petName,
                otherPetPhoto: petPhoto,
                otherOwnerId: request.ownerId,
                otherParticipantLabel: 'Pet owner',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatPet {
  final String id;
  final String name;
  final String breed;
  final String species;
  final String age;
  final String gender;
  final String location;
  final String purpose;
  final String photoUrl;
  final bool verified;

  const _ChatPet({
    required this.id,
    required this.name,
    required this.breed,
    required this.species,
    required this.age,
    required this.gender,
    required this.location,
    required this.purpose,
    required this.photoUrl,
    required this.verified,
  });

  factory _ChatPet.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    return _ChatPet(
      id: document.id,
      name: data['name'] as String? ?? 'Pet',
      breed: data['breed'] as String? ?? '',
      species: data['species'] as String? ?? '',
      age: data['age'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      location: data['locationName'] as String? ?? '',
      purpose: (data['purpose'] as String? ?? '').toLowerCase(),
      photoUrl:
          (data['petProfilePhoto'] as String?) ??
          (data['profilePhoto'] as String?) ??
          '',
      verified: data['vetVerified'] == true,
    );
  }

  factory _ChatPet.fromAdoptionRequest(AdoptionRequest request) {
    final data = request.petSnapshot;
    return _ChatPet(
      id: request.petId,
      name: data['name'] as String? ?? 'Adoption Pet',
      breed: data['breed'] as String? ?? '',
      species: data['species'] as String? ?? '',
      age: data['age'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      location: data['locationName'] as String? ?? '',
      purpose: 'adoption',
      photoUrl:
          data['petProfilePhoto'] as String? ??
          data['profilePhoto'] as String? ??
          '',
      verified: data['vetVerified'] == true,
    );
  }

  bool matchesSearch(String query) =>
      '$name $breed $species $purpose $location'.toLowerCase().contains(query);
}

class _AdoptionPetPurposeSection extends StatelessWidget {
  final List<_ChatPet> ownedPets;
  final String searchQuery;

  const _AdoptionPetPurposeSection({
    required this.ownedPets,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdoptionRequest>>(
      stream: AdoptionService.instance.watchMyRequests(),
      builder: (context, snapshot) {
        final petsById = {for (final pet in ownedPets) pet.id: pet};
        for (final request in snapshot.data ?? const <AdoptionRequest>[]) {
          if (request.status != AdoptionRequestStatus.approved ||
              request.petId.isEmpty) {
            continue;
          }
          petsById.putIfAbsent(
            request.petId,
            () => _ChatPet.fromAdoptionRequest(request),
          );
        }
        final pets = petsById.values
            .where(
              (pet) => searchQuery.isEmpty || pet.matchesSearch(searchQuery),
            )
            .toList();
        return _PetPurposeSection(title: 'Adoption', pets: pets);
      },
    );
  }
}

class _PetPurposeSection extends StatelessWidget {
  final String title;
  final List<_ChatPet> pets;

  const _PetPurposeSection({required this.title, required this.pets});

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE3EA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                title == 'Breeding' ? Icons.pets : Icons.home_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDDE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pets.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: pets
              .map(
                (pet) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ChatPetCard(pet: pet),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ChatPetCard extends StatelessWidget {
  final _ChatPet pet;

  const _ChatPetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance.watchConversationsForPet(pet.id),
      builder: (context, snapshot) {
        final userId = UserSessionService.instance.currentUser?.uid ?? '';
        final unreadCount =
            snapshot.data?.docs
                .where(
                  (document) =>
                      _conversationContainsPet(document.data(), pet.id) &&
                      _shouldShowConversation(document.data(), userId),
                )
                .fold<int>(
                  0,
                  (total, document) =>
                      total + _unreadCount(document.data(), userId),
                ) ??
            0;
        if (pet.purpose != 'breeding') {
          return _ChatPetCardBody(
            pet: pet,
            unreadCount: unreadCount,
            incomingLikeCount: 0,
          );
        }
        return StreamBuilder<List<BreedingIncomingLike>>(
          stream: BreedingMatchService.instance.watchUnansweredIncomingLikes(
            pet.id,
          ),
          builder: (context, likeSnapshot) {
            final likedPetIds = (likeSnapshot.data ?? const [])
                .map((like) => like.likingPetId)
                .toSet();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('pets').snapshots(),
              builder: (context, petSnapshot) {
                final likeCount =
                    petSnapshot.data?.docs
                        .where(
                          (document) =>
                              likedPetIds.contains(document.id) &&
                              _isAvailableBreedingLike(document.data()),
                        )
                        .length ??
                    0;
                return _ChatPetCardBody(
                  pet: pet,
                  unreadCount: unreadCount,
                  incomingLikeCount: likeCount,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChatPetCardBody extends StatelessWidget {
  final _ChatPet pet;
  final int unreadCount;
  final int incomingLikeCount;

  const _ChatPetCardBody({
    required this.pet,
    required this.unreadCount,
    required this.incomingLikeCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasFooter = unreadCount > 0 || incomingLikeCount > 0;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PetConversationsScreen(pet: pet)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _PetSelectorAvatar(pet: pet),
                      if (pet.verified)
                        const Positioned(
                          right: -2,
                          bottom: 1,
                          child: Icon(
                            Icons.verified,
                            color: Color(0xFF19A8E8),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pet.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              _CountBadge(
                                count: unreadCount,
                                color: const Color(0xFF20A7E8),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            pet.breed.isEmpty ? pet.species : pet.breed,
                            pet.age,
                            pet.gender,
                          ].where((value) => value.isNotEmpty).join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (pet.location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: Color(0xFF777777),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  pet.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE3EA),
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            pet.purpose == 'breeding' ? 'Breeding' : 'Adoption',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE3EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFooter)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: const Color(0xFFFFECF1),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 5,
                  children: [
                    if (unreadCount > 0)
                      _FooterCount(
                        icon: Icons.chat_bubble_outline,
                        text:
                            '$unreadCount new ${unreadCount == 1 ? 'message' : 'messages'}',
                      ),
                    if (incomingLikeCount > 0)
                      _FooterCount(
                        icon: Icons.favorite_border,
                        text:
                            '$incomingLikeCount new ${incomingLikeCount == 1 ? 'like' : 'likes'}',
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

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22),
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _FooterCount extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FooterCount({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.primary, size: 14),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _PetSelectorAvatar extends StatelessWidget {
  final _ChatPet pet;

  const _PetSelectorAvatar({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFDDE6),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ClipOval(
        child: BreedrNetworkImage(
          imageUrl: pet.photoUrl,
          width: 68,
          height: 68,
          fallback: _PetSpeciesPlaceholder(species: pet.species),
        ),
      ),
    );
  }
}

class _PetSpeciesPlaceholder extends StatelessWidget {
  final String species;

  const _PetSpeciesPlaceholder({required this.species});

  @override
  Widget build(BuildContext context) {
    return Icon(
      species.toLowerCase() == 'cat' ? Icons.cruelty_free : Icons.pets,
      color: AppColors.primary,
      size: 38,
    );
  }
}

class _PetConversationsScreen extends StatefulWidget {
  final _ChatPet pet;

  const _PetConversationsScreen({required this.pet});

  @override
  State<_PetConversationsScreen> createState() =>
      _PetConversationsScreenState();
}

class _PetConversationsScreenState extends State<_PetConversationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _ConversationView _view = _ConversationView.active;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _otherPetName(Map<String, dynamic> data) {
    if (data['purpose'] == 'adoption') {
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      return petNames.values.firstOrNull?.toString() ?? 'Adoption Chat';
    }
    final petOwners = Map<String, dynamic>.from(
      data['petOwners'] as Map? ?? const {},
    );
    final petNames = Map<String, dynamic>.from(
      data['petNames'] as Map? ?? const {},
    );
    final otherPetId = petOwners.keys
        .where((petId) => petId != widget.pet.id)
        .firstOrNull;
    return otherPetId == null
        ? 'Pet'
        : (petNames[otherPetId] ?? 'Pet').toString();
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final petName = _otherPetName(data).toLowerCase();
    final lastMessage = (data['lastMessage'] as String? ?? '').toLowerCase();
    return petName.contains(query) || lastMessage.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "${widget.pet.name}'s Chat",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDDE5),
                border: Border.all(color: const Color(0xFF555555)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                widget.pet.purpose == 'breeding' ? 'Breeding' : 'Adoption',
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search messages or pet name',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF999999)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF999999)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (widget.pet.purpose == 'breeding')
            BreedingLikesPreview(
              petId: widget.pet.id,
              petName: widget.pet.name,
              searchQuery: _searchQuery,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ConversationView>(
                segments: const [
                  ButtonSegment(
                    value: _ConversationView.active,
                    icon: Icon(Icons.chat_bubble_outline),
                    label: Text('Active'),
                  ),
                  ButtonSegment(
                    value: _ConversationView.history,
                    icon: Icon(Icons.history),
                    label: Text('History'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.first);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Text(
              _view == _ConversationView.active
                  ? 'Active Messages'
                  : 'Completed & Ended',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: BreedingMatchService.instance.watchConversationsForPet(
                widget.pet.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final allConversations =
                    snapshot.data?.docs
                        .where(
                          (document) =>
                              _conversationContainsPet(
                                document.data(),
                                widget.pet.id,
                              ) &&
                              _shouldShowConversation(
                                document.data(),
                                UserSessionService.instance.currentUser?.uid ??
                                    '',
                              ),
                        )
                        .toList() ??
                    [];
                allConversations.sort((a, b) {
                  final aTime = a.data()['updatedAt'] as Timestamp?;
                  final bTime = b.data()['updatedAt'] as Timestamp?;
                  return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                    aTime?.millisecondsSinceEpoch ?? 0,
                  );
                });

                if (allConversations.isEmpty) {
                  return const _EmptyChats();
                }

                final conversations = allConversations
                    .where(
                      (document) =>
                          _isHistoryConversation(document.data()) ==
                              (_view == _ConversationView.history) &&
                          _matchesSearch(document.data()),
                    )
                    .toList();

                if (conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No message previews found for "$_searchQuery".'
                            : _view == _ConversationView.active
                            ? 'No active conversations for this pet.'
                            : 'Completed and ended conversations will appear here.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF777777)),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: Color(0xFFFFCDD5)),
                  itemBuilder: (context, index) {
                    final document = conversations[index];
                    return _ConversationTile(
                      matchId: document.id,
                      data: document.data(),
                      selectedPetId: widget.pet.id,
                      searchQuery: _searchQuery,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _ConversationView { active, history }

class _ConversationTile extends StatelessWidget {
  final String matchId;
  final Map<String, dynamic> data;
  final String selectedPetId;
  final String searchQuery;

  const _ConversationTile({
    required this.matchId,
    required this.data,
    required this.selectedPetId,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final userId = UserSessionService.instance.currentUser?.uid ?? '';
    final purpose = data['purpose'] as String? ?? 'breeding';
    final participantIds =
        (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
    final petOwners = Map<String, dynamic>.from(
      data['petOwners'] as Map? ?? const {},
    );
    final petNames = Map<String, dynamic>.from(
      data['petNames'] as Map? ?? const {},
    );
    final petPhotos = Map<String, dynamic>.from(
      data['petPhotos'] as Map? ?? const {},
    );
    final adoptionPetId = purpose == 'adoption'
        ? petNames.keys.firstOrNull?.toString()
        : null;
    final otherPetId = purpose == 'adoption'
        ? adoptionPetId
        : petOwners.keys.where((petId) => petId != selectedPetId).firstOrNull;
    final otherPetName = otherPetId == null
        ? 'Breeding Match'
        : petNames[otherPetId]?.toString() ?? 'Pet';
    final otherPetPhoto = otherPetId == null
        ? ''
        : (petPhotos[otherPetId] as String? ?? '');
    final listedOwnerId = otherPetId == null
        ? ''
        : (petOwners[otherPetId] ?? '').toString();
    final otherOwnerId = purpose == 'adoption'
        ? participantIds.firstWhere(
            (participantId) => participantId != userId,
            orElse: () => listedOwnerId,
          )
        : listedOwnerId;
    final lastMessage = data['lastMessage'] as String? ?? '';
    final isUnmatched = data['status'] == 'unmatched';
    final isCompleted = data['status'] == 'completed';
    final unread = _unreadCount(data, userId);
    final updatedAt =
        (data['lastMessageAt'] as Timestamp?) ??
        (data['updatedAt'] as Timestamp?);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      leading: _ChatAvatar(
        photoUrl: otherPetPhoto,
        ownerId: otherOwnerId,
        showPresence: !isUnmatched,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HighlightedSearchText(
            text: otherPetName.toString(),
            query: searchQuery,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          _OwnerIdentity(
            ownerId: otherOwnerId,
            compact: true,
            label: purpose == 'adoption' && userId == listedOwnerId
                ? 'Adopter'
                : 'Pet owner',
          ),
          const SizedBox(height: 3),
          _HighlightedSearchText(
            text: isUnmatched
                ? 'This match has ended.'
                : lastMessage.isEmpty
                ? 'You matched. Say hello!'
                : lastMessage,
            query: searchQuery,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      trailing: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _conversationTimeLabel(updatedAt),
              style: TextStyle(
                color: unread > 0 ? AppColors.primary : const Color(0xFF888888),
                fontSize: 9,
                fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            if (unread > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(11)),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else if (isUnmatched || isCompleted)
              Text(
                isUnmatched ? 'Unmatched' : 'Completed',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            matchId: matchId,
            otherPetName: otherPetName.toString(),
            otherPetPhoto: otherPetPhoto,
            otherOwnerId: otherOwnerId,
            initiallyUnmatched: isUnmatched,
            otherParticipantLabel:
                purpose == 'adoption' && userId == listedOwnerId
                ? 'Adopter'
                : 'Pet owner',
          ),
        ),
      ),
    );
  }
}

class _HighlightedSearchText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  const _HighlightedSearchText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedText = text.toLowerCase();
    if (normalizedQuery.isEmpty || !normalizedText.contains(normalizedQuery)) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final matchIndex = normalizedText.indexOf(normalizedQuery, start);
      if (matchIndex < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (matchIndex > start) {
        spans.add(TextSpan(text: text.substring(start, matchIndex)));
      }
      final matchEnd = matchIndex + normalizedQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchEnd),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFD56A),
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      start = matchEnd;
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _OwnerIdentity extends StatelessWidget {
  final String ownerId;
  final bool compact;
  final String label;
  final VoidCallback? onTap;

  const _OwnerIdentity({
    required this.ownerId,
    required this.compact,
    this.label = 'Pet owner',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (ownerId.isEmpty) {
      return Text(
        '$label: Breedr user',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF555555),
          fontSize: compact ? 10 : 12,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final ownerName = data?['fullName'] as String? ?? 'Breedr user';
        final ownerPhoto = data?['profilePhoto'] as String? ?? '';
        final avatarSize = compact ? 18.0 : 24.0;

        final identity = Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              '$label:',
              style: TextStyle(
                color: const Color(0xFF444444),
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            _OwnerAvatar(photoUrl: ownerPhoto, size: avatarSize),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF222222),
                  fontSize: compact ? 10 : 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
        if (onTap == null) return identity;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: identity,
            ),
          ),
        );
      },
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  final String photoUrl;
  final double size;

  const _OwnerAvatar({required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFDDE6),
      ),
      clipBehavior: Clip.antiAlias,
      child: BreedrNetworkImage(
        imageUrl: photoUrl,
        width: size,
        height: size,
        fallback: const Icon(Icons.person, color: AppColors.primary),
      ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final String matchId;
  final String otherPetName;
  final String otherPetPhoto;
  final String otherOwnerId;
  final bool initiallyUnmatched;
  final String otherParticipantLabel;

  const ChatConversationScreen({
    super.key,
    required this.matchId,
    required this.otherPetName,
    required this.otherPetPhoto,
    required this.otherOwnerId,
    this.initiallyUnmatched = false,
    this.otherParticipantLabel = 'Pet owner',
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  static const int _maxVideoBytes = 50 * 1024 * 1024;
  final _messageController = TextEditingController();
  final _messagesScrollController = ScrollController();
  bool _sending = false;
  bool _unmatching = false;
  bool _markingRead = false;
  bool _hasScrolledToLatest = false;
  File? _pendingMedia;
  String? _pendingMediaType;
  String? _pendingMediaName;
  int? _pendingMediaBytes;
  Timer? _readOnlyTimer;
  DateTime? _scheduledReadOnlyAt;

  Future<void> _openOtherOwnerProfile() async {
    if (widget.otherOwnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This pet owner profile is unavailable.')),
      );
      return;
    }

    var ratingPurpose = 'breeding';
    try {
      final match = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();
      if (match.data()?['purpose'] == 'adoption') ratingPurpose = 'adoption';
    } catch (_) {
      // Profile navigation and reporting remain available if this lookup fails.
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerProfileScreen(
          ownerId: widget.otherOwnerId,
          ratingPurpose: ratingPurpose,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _readOnlyTimer?.cancel();
    _messageController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest({bool animated = false}) {
    if (!_messagesScrollController.hasClients) return;

    final offset = _messagesScrollController.position.maxScrollExtent;
    if (animated) {
      _messagesScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    _messagesScrollController.jumpTo(offset);
  }

  void _scheduleInitialScrollToLatest() {
    if (_hasScrolledToLatest) return;

    _hasScrolledToLatest = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;

      _scrollToLatest();

      // Image messages can increase the list height after their first layout.
      // Re-check briefly so opening a chat consistently reaches its true end.
      for (final delay in <int>[80, 250, 600]) {
        Future<void>.delayed(Duration(milliseconds: delay), () {
          if (mounted) _scrollToLatest();
        });
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final pendingMedia = _pendingMedia;
    final pendingType = _pendingMediaType;
    if ((text.isEmpty && pendingMedia == null) || _sending) return;

    setState(() => _sending = true);
    try {
      String? mediaUrl;
      if (pendingMedia != null && pendingType != null) {
        final cloudinary = CloudinaryService();
        mediaUrl = pendingType == 'video'
            ? await cloudinary.uploadVideoOrThrow(pendingMedia)
            : await cloudinary.uploadImageOrThrow(pendingMedia);
      }
      await BreedingMatchService.instance.sendMessage(
        matchId: widget.matchId,
        text: text,
        mediaType: pendingType,
        mediaUrl: mediaUrl,
        mediaFileName: _pendingMediaName,
        mediaSizeBytes: _pendingMediaBytes,
      );
      _messageController.clear();
      _clearPendingMedia();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToLatest(animated: true),
      );
    } on CloudinaryUploadException catch (error) {
      if (mounted) _showSnack(error.message);
    } catch (error) {
      if (!mounted) return;
      final message =
          error is StateError && error.message.contains('both parties sign')
          ? 'Chat unlocks once both parties sign the adoption contract.'
          : error is StateError && error.message.contains('read-only')
          ? 'This completed breeding conversation is now read-only.'
          : 'This message could not be sent. Please check your connection.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _clearPendingMedia() {
    if (!mounted) return;
    setState(() {
      _pendingMedia = null;
      _pendingMediaType = null;
      _pendingMediaName = null;
      _pendingMediaBytes = null;
    });
  }

  Future<void> _showAttachmentMenu() async {
    final action = await showModalBottomSheet<_ChatAttachmentAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add an attachment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _AttachmentOption(
                icon: Icons.photo_camera_outlined,
                title: 'Take Photo',
                subtitle: 'Use your camera',
                action: _ChatAttachmentAction.camera,
              ),
              _AttachmentOption(
                icon: Icons.photo_library_outlined,
                title: 'Choose Photo',
                subtitle: 'Select an image from your library',
                action: _ChatAttachmentAction.photo,
              ),
              _AttachmentOption(
                icon: Icons.video_library_outlined,
                title: 'Choose Video',
                subtitle: 'Select an MP4 video up to 50 MB',
                action: _ChatAttachmentAction.video,
              ),
              _AttachmentOption(
                icon: Icons.folder_open_outlined,
                title: 'Browse Device',
                subtitle: 'Choose a JPG, PNG, or MP4 file',
                action: _ChatAttachmentAction.browse,
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _pickAttachment(action);
  }

  Future<void> _pickAttachment(_ChatAttachmentAction action) async {
    String? path;
    String? name;
    String? mediaType;
    if (action == _ChatAttachmentAction.camera ||
        action == _ChatAttachmentAction.photo) {
      final picked = await ImagePicker().pickImage(
        source: action == _ChatAttachmentAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 82,
      );
      path = picked?.path;
      name = picked?.name;
      mediaType = 'image';
    } else if (action == _ChatAttachmentAction.video) {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      path = picked?.path;
      name = picked?.name;
      mediaType = 'video';
    } else {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4'],
      );
      path = picked?.files.single.path;
      name = picked?.files.single.name;
      mediaType = name?.toLowerCase().endsWith('.mp4') == true
          ? 'video'
          : 'image';
    }
    if (path == null || !mounted) return;
    final file = File(path);
    final bytes = await file.length();
    if (!mounted) return;
    if (mediaType == 'video') {
      if (!path.toLowerCase().endsWith('.mp4')) {
        _showSnack('Please choose an MP4 video.');
        return;
      }
      if (bytes > _maxVideoBytes) {
        _showSnack('This video is larger than 50 MB. Choose a smaller video.');
        return;
      }
    }
    setState(() {
      _pendingMedia = file;
      _pendingMediaType = mediaType;
      _pendingMediaName = name ?? file.uri.pathSegments.last;
      _pendingMediaBytes = bytes;
    });
  }

  Future<void> _respondToAdoptionUpdate(String updateRequestId) async {
    final source = await _choosePhotoSource(
      title: 'Reply with photo',
      cameraLabel: 'Take Photo',
      galleryLabel: 'Choose from Gallery',
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final url = await CloudinaryService().uploadImageOrThrow(
        File(picked.path),
      );
      await AdoptionService.instance.respondToAdoptionUpdate(
        conversationId: widget.matchId,
        updateRequestId: updateRequestId,
        photoUrl: url,
      );
    } on AdoptionServiceException catch (error) {
      if (mounted) _showSnack(error.message);
    } catch (_) {
      if (mounted) _showSnack('Unable to send the photo update.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<ImageSource?> _choosePhotoSource({
    required String title,
    required String cameraLabel,
    required String galleryLabel,
  }) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE4EB),
                  child: Icon(Icons.photo_camera, color: AppColors.primary),
                ),
                title: Text(
                  cameraLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Open the camera and take a fresh photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE4EB),
                  child: Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: Text(
                  galleryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Pick an existing photo from your device'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAdoptionUpdate(String updateRequestId) async {
    try {
      await AdoptionService.instance.confirmAdoptionUpdate(
        conversationId: widget.matchId,
        updateRequestId: updateRequestId,
      );
      if (mounted) _showSnack('Photo update confirmed.');
    } on AdoptionServiceException catch (error) {
      if (mounted) _showSnack(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showSnack(_chatFirebaseMessage(error));
    } catch (_) {
      if (mounted) _showSnack('Unable to confirm this update.');
    }
  }

  Future<void> _requestAnotherAdoptionUpdate(String updateRequestId) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _RequestAnotherPhotoSheet(),
    );
    if (reason == null || !mounted) return;

    try {
      await AdoptionService.instance.requestAnotherAdoptionUpdate(
        conversationId: widget.matchId,
        updateRequestId: updateRequestId,
        reason: reason,
      );
    } on AdoptionServiceException catch (error) {
      if (mounted) _showSnack(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showSnack(_chatFirebaseMessage(error));
    } catch (_) {
      if (mounted) _showSnack('Unable to request another update.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markRead() async {
    if (_markingRead) return;
    _markingRead = true;
    try {
      await BreedingMatchService.instance.markConversationRead(widget.matchId);
    } catch (error) {
      debugPrint('Unable to mark conversation ${widget.matchId} read: $error');
    } finally {
      _markingRead = false;
    }
  }

  void _scheduleReadOnlyRefresh(DateTime? readOnlyAt) {
    if (readOnlyAt == null ||
        _scheduledReadOnlyAt == readOnlyAt ||
        !DateTime.now().toUtc().isBefore(readOnlyAt)) {
      return;
    }
    _scheduledReadOnlyAt = readOnlyAt;
    _readOnlyTimer?.cancel();
    _readOnlyTimer = Timer(readOnlyAt.difference(DateTime.now().toUtc()), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _showUnmatchConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Unmatch this pet?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'You and ${widget.otherPetName} will no longer be matched. '
          'The conversation will no longer be available, and these pets '
          'cannot match again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _unmatching = true);
    try {
      await BreedingMatchService.instance.unmatch(widget.matchId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('You and ${widget.otherPetName} have been unmatched.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to unmatch right now. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _unmatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = UserSessionService.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        toolbarHeight: 88,
        title: Row(
          children: [
            _ChatAvatar(
              photoUrl: widget.otherPetPhoto,
              ownerId: widget.otherOwnerId,
              size: 58,
              showPresence: !widget.initiallyUnmatched,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherPetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _OwnerIdentity(
                    ownerId: widget.otherOwnerId,
                    compact: false,
                    label: widget.otherParticipantLabel,
                    onTap: _openOtherOwnerProfile,
                  ),
                  if (!widget.initiallyUnmatched)
                    _ActivityLabel(ownerId: widget.otherOwnerId),
                ],
              ),
            ),
          ],
        ),
        actions: widget.initiallyUnmatched
            ? null
            : [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: BreedingMatchService.instance.watchMatch(
                    widget.matchId,
                  ),
                  builder: (context, snapshot) {
                    final status = snapshot.data?.data()?['status'] as String?;
                    if (status == null ||
                        status == 'completed' ||
                        status == 'unmatched') {
                      return const SizedBox.shrink();
                    }
                    return PopupMenuButton<String>(
                      tooltip: 'Conversation options',
                      enabled: !_unmatching,
                      onSelected: (value) {
                        if (value == 'unmatch') {
                          _showUnmatchConfirmation();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'unmatch',
                          child: Row(
                            children: [
                              Icon(
                                Icons.heart_broken_outlined,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10),
                              Text('Unmatch'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 6),
              ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BreedingMatchService.instance.watchMatch(widget.matchId),
        builder: (context, matchSnapshot) {
          final match = matchSnapshot.data?.data();
          if (match?['status'] == 'unmatched') {
            return _UnmatchedConversationView(petName: widget.otherPetName);
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: BreedingMatchService.instance.watchConversation(
              widget.matchId,
            ),
            builder: (context, conversationSnapshot) {
              final conversation =
                  conversationSnapshot.data?.data() ?? <String, dynamic>{};
              final unread = _unreadCount(conversation, userId);
              final purpose = conversation['purpose'] as String? ?? 'breeding';
              if (unread > 0) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _markRead(),
                );
              }

              final reviewReleaseAt = match?['reviewReleaseAt'] as Timestamp?;
              final completedAt = match?['completedAt'] as Timestamp?;
              final readOnlyAt =
                  reviewReleaseAt?.toDate() ??
                  completedAt?.toDate().add(const Duration(days: 7));
              _scheduleReadOnlyRefresh(readOnlyAt);
              final isReadOnly =
                  purpose != 'adoption' &&
                  match?['status'] == 'completed' &&
                  readOnlyAt != null &&
                  !DateTime.now().toUtc().isBefore(readOnlyAt);
              final adoptionProcess = Map<String, dynamic>.from(
                conversation['adoptionProcess'] as Map? ?? const {},
              );
              final petOwners = Map<String, dynamic>.from(
                conversation['petOwners'] as Map? ?? const {},
              );
              final adoptionInitiated = adoptionProcess['initiatedAt'] != null;
              final currentUserIsAdoptionOwner = petOwners.values.contains(
                userId,
              );
              final showAdoptionProcessPanel =
                  purpose == 'adoption' && adoptionInitiated;
              final showAdoptionInitiatePanel =
                  purpose == 'adoption' &&
                  !adoptionInitiated &&
                  currentUserIsAdoptionOwner;
              final isAdoptionReadOnly =
                  purpose == 'adoption' &&
                  adoptionProcess['status'] == 'contract_pending';
              final lastReadAt = Map<String, dynamic>.from(
                conversation['lastReadAt'] as Map? ?? const {},
              );
              final otherReadAt = lastReadAt[widget.otherOwnerId] as Timestamp?;

              return Column(
                children: [
                  if (match != null)
                    _CompletionPanel(
                      matchId: widget.matchId,
                      data: match,
                      currentUserId: userId,
                    ),
                  if (showAdoptionProcessPanel)
                    _AdoptionProcessPanel(
                      conversationId: widget.matchId,
                      data: conversation,
                      currentUserId: userId,
                    ),
                  if (showAdoptionInitiatePanel)
                    _AdoptionProcessPanel(
                      conversationId: widget.matchId,
                      data: conversation,
                      currentUserId: userId,
                      compactBeforeInitiated: true,
                    ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: BreedingMatchService.instance.watchMessages(
                        widget.matchId,
                      ),
                      builder: (context, snapshot) {
                        final messages = snapshot.data?.docs ?? [];
                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'Start the conversation.',
                              style: TextStyle(color: Color(0xFF777777)),
                            ),
                          );
                        }

                        _scheduleInitialScrollToLatest();

                        var lastOwnIndex = -1;
                        for (
                          var index = messages.length - 1;
                          index >= 0;
                          index--
                        ) {
                          if (messages[index].data()['senderId'] == userId) {
                            lastOwnIndex = index;
                            break;
                          }
                        }

                        return ListView.builder(
                          controller: _messagesScrollController,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final data = messages[index].data();
                            final createdAt = data['createdAt'] as Timestamp?;
                            final previousCreatedAt = index == 0
                                ? null
                                : messages[index - 1].data()['createdAt']
                                      as Timestamp?;
                            final showDate =
                                createdAt != null &&
                                (previousCreatedAt == null ||
                                    _messageDateLabel(createdAt.toDate()) !=
                                        _messageDateLabel(
                                          previousCreatedAt.toDate(),
                                        ));
                            final mine = data['senderId'] == userId;
                            final isRead =
                                mine &&
                                createdAt != null &&
                                otherReadAt != null &&
                                !otherReadAt.toDate().isBefore(
                                  createdAt.toDate(),
                                );

                            return Column(
                              children: [
                                if (showDate)
                                  _MessageDateDivider(
                                    label: _messageDateLabel(
                                      createdAt.toDate(),
                                    ),
                                  ),
                                _MessageBubble(
                                  messageId: messages[index].id,
                                  conversationId: widget.matchId,
                                  data: data,
                                  mine: mine,
                                  createdAt: createdAt,
                                  showReceipt:
                                      mine &&
                                      index == lastOwnIndex &&
                                      createdAt != null,
                                  isRead: isRead,
                                  onRespondToUpdate: _respondToAdoptionUpdate,
                                  onConfirmUpdate: _confirmAdoptionUpdate,
                                  onRequestAnotherUpdate:
                                      _requestAnotherAdoptionUpdate,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (isReadOnly || isAdoptionReadOnly)
                    _ReadOnlyConversationNotice(
                      message: isAdoptionReadOnly
                          ? 'Chat unlocks once both parties sign the adoption contract.'
                          : 'This completed breeding conversation is now read-only.',
                    )
                  else
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_pendingMedia != null) ...[
                              _PendingChatAttachment(
                                file: _pendingMedia!,
                                mediaType: _pendingMediaType ?? 'image',
                                fileName: _pendingMediaName ?? 'Attachment',
                                sizeBytes: _pendingMediaBytes ?? 0,
                                onRemove: _sending ? null : _clearPendingMedia,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    enabled: !_unmatching && !_sending,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    minLines: 1,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: _pendingMedia == null
                                          ? 'Type a message...'
                                          : 'Add a caption...',
                                      prefixIcon: IconButton(
                                        tooltip: 'Add attachment',
                                        onPressed: _sending || _unmatching
                                            ? null
                                            : _showAttachmentMenu,
                                        icon: const Icon(
                                          Icons.attach_file,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFFFF0F5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton.filled(
                                  onPressed: _sending || _unmatching
                                      ? null
                                      : _send,
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ],
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

enum _ChatAttachmentAction { camera, photo, video, browse }

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _ChatAttachmentAction action;

  const _AttachmentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFE8EE),
        foregroundColor: AppColors.primary,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, action),
    );
  }
}

class _PendingChatAttachment extends StatelessWidget {
  final File file;
  final String mediaType;
  final String fileName;
  final int sizeBytes;
  final VoidCallback? onRemove;

  const _PendingChatAttachment({
    required this.file,
    required this.mediaType,
    required this.fileName,
    required this.sizeBytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: mediaType == 'image'
                ? Image.file(file, width: 58, height: 58, fit: BoxFit.cover)
                : Container(
                    width: 58,
                    height: 58,
                    color: const Color(0xFF333333),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${mediaType == 'video' ? 'MP4 video' : 'Photo'} • ${_formatFileSize(sizeBytes)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

class _UnmatchedConversationView extends StatelessWidget {
  final String petName;

  const _UnmatchedConversationView({required this.petName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.heart_broken_outlined,
              size: 58,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unmatched',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your match with $petName has ended. This conversation is no '
              'longer available, and these pets cannot match again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to messages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptionProcessPanel extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> data;
  final String currentUserId;
  final bool compactBeforeInitiated;

  const _AdoptionProcessPanel({
    required this.conversationId,
    required this.data,
    required this.currentUserId,
    this.compactBeforeInitiated = false,
  });

  @override
  State<_AdoptionProcessPanel> createState() => _AdoptionProcessPanelState();
}

class _AdoptionProcessPanelState extends State<_AdoptionProcessPanel> {
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc();
  bool _busy = false;
  bool _processingDeadline = false;

  @override
  void initState() {
    super.initState();
    _processProtectionDeadline();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now().toUtc());
      _processProtectionDeadline();
    });
  }

  @override
  void didUpdateWidget(covariant _AdoptionProcessPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data['adoptionProcess'] != widget.data['adoptionProcess']) {
      _processProtectionDeadline();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final process = Map<String, dynamic>.from(
      widget.data['adoptionProcess'] as Map? ?? const {},
    );
    final petOwners = Map<String, dynamic>.from(
      widget.data['petOwners'] as Map? ?? const {},
    );
    final petNames = Map<String, dynamic>.from(
      widget.data['petNames'] as Map? ?? const {},
    );
    final participantIds =
        (widget.data['participantIds'] as List?)?.cast<String>() ??
        const <String>[];
    final isOwner = petOwners.values.contains(widget.currentUserId);
    final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';
    final signatures = Map<String, dynamic>.from(
      process['contractSignatures'] as Map? ?? const {},
    );
    final initiated = process['initiatedAt'] != null;
    final signedByMe = signatures[widget.currentUserId] != null;
    final bothSigned =
        participantIds.isNotEmpty &&
        participantIds.every((id) => signatures[id] != null);
    final handoverConfirmations = Map<String, dynamic>.from(
      process['handoverConfirmations'] as Map? ?? const {},
    );
    final status =
        process['status'] as String? ??
        (bothSigned ? 'handover_pending' : 'not_started');
    final returnHandoverConfirmations = Map<String, dynamic>.from(
      process['returnHandoverConfirmations'] as Map? ?? const {},
    );
    final handoverConfirmedByMe = status == 'return_approved'
        ? returnHandoverConfirmations[widget.currentUserId] != null
        : handoverConfirmations[widget.currentUserId] != null;
    final step = _adoptionProcessStep(status, bothSigned: bothSigned);
    final returnFlow = status == 'return_approved' || status == 'returned';
    final reviewsSubmitted = Map<String, dynamic>.from(
      widget.data['reviewsSubmitted'] as Map? ?? const {},
    );
    final ownReviewSubmitted = reviewsSubmitted[widget.currentUserId] == true;
    final title = _panelTitle(
      isOwner: isOwner,
      initiated: initiated,
      signedByMe: signedByMe,
      bothSigned: bothSigned,
      handoverConfirmedByMe: handoverConfirmedByMe,
      status: status,
    );
    final message = _panelMessage(
      petName: petName,
      isOwner: isOwner,
      initiated: initiated,
      signedByMe: signedByMe,
      bothSigned: bothSigned,
      handoverConfirmedByMe: handoverConfirmedByMe,
      status: status,
      protectionEndsAt: process['protectionEndsAt'] as Timestamp?,
    );

    if (widget.compactBeforeInitiated && !initiated && isOwner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF0F5),
          border: Border(bottom: BorderSide(color: Color(0xFFFFC8D4))),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFB6C4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ProcessActionButton(
                busy: _busy,
                label: 'Initiate',
                onPressed: _actionFor(
                  context,
                  isOwner: isOwner,
                  initiated: initiated,
                  signedByMe: signedByMe,
                  bothSigned: bothSigned,
                  handoverConfirmedByMe: handoverConfirmedByMe,
                  status: status,
                  ownReviewSubmitted: ownReviewSubmitted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFFEAF0),
        border: Border(bottom: BorderSide(color: Color(0xFFFFC8D4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adoption Process',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Step ${returnFlow ? 3 : step} of ${returnFlow ? 3 : 4}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AdoptionStepTracker(
            step: returnFlow ? 3 : step,
            returnFlow: returnFlow,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB6C4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ProcessActionButton(
                  busy: _busy,
                  label: _buttonLabel(
                    isOwner: isOwner,
                    initiated: initiated,
                    signedByMe: signedByMe,
                    bothSigned: bothSigned,
                    handoverConfirmedByMe: handoverConfirmedByMe,
                    status: status,
                    ownReviewSubmitted: ownReviewSubmitted,
                  ),
                  onPressed: _actionFor(
                    context,
                    isOwner: isOwner,
                    initiated: initiated,
                    signedByMe: signedByMe,
                    bothSigned: bothSigned,
                    handoverConfirmedByMe: handoverConfirmedByMe,
                    status: status,
                    ownReviewSubmitted: ownReviewSubmitted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _panelTitle({
    required bool isOwner,
    required bool initiated,
    required bool signedByMe,
    required bool bothSigned,
    required bool handoverConfirmedByMe,
    required String status,
  }) {
    if (status == 'returned') return 'Return completed';
    if (status == 'return_approved') {
      return handoverConfirmedByMe
          ? 'Return handover pending'
          : 'Return approved - arrange handover';
    }
    if (status == 'completed') return 'Adoption completed';
    if (status == 'ready_to_complete') return 'Adoption ready to complete';
    if (status == 'protection_active') return _adoptionProtectionTitle();
    if (status == 'handover_pending') {
      return handoverConfirmedByMe
          ? 'Waiting for handover'
          : 'Confirm Handover';
    }
    if (bothSigned) return 'Contract signed';
    if (!initiated) {
      return isOwner ? 'Initiate a Contract' : 'Waiting for contract';
    }
    if (signedByMe) return 'Waiting for signature';
    return 'Sign the Adoption Contract';
  }

  String _panelMessage({
    required String petName,
    required bool isOwner,
    required bool initiated,
    required bool signedByMe,
    required bool bothSigned,
    required bool handoverConfirmedByMe,
    required String status,
    required Timestamp? protectionEndsAt,
  }) {
    if (status == 'returned') {
      return '$petName was returned to the original owner and remains unpublished.';
    }
    if (status == 'return_approved') {
      return handoverConfirmedByMe
          ? 'Your return confirmation is recorded. Waiting for the other party.'
          : 'Coordinate the physical return in chat, then confirm after the handover happens.';
    }
    if (status == 'completed') {
      return 'This adoption is recorded as completed. You can now leave a review.';
    }
    if (status == 'ready_to_complete') {
      return 'The protection window has ended. Complete the adoption to make it official.';
    }
    if (status == 'protection_active') {
      final remaining = protectionEndsAt?.toDate().difference(_now);
      return 'The protection window is active. Test mode remaining: ${_durationLabel(remaining)}.';
    }
    if (status == 'handover_pending') {
      return handoverConfirmedByMe
          ? 'Your handover confirmation is recorded. Waiting for the other party.'
          : 'Confirm once the pet has been handed over safely.';
    }
    if (bothSigned) {
      return 'Both parties signed. Handover will be handled in the adoption process screen.';
    }
    if (!initiated) {
      return isOwner
          ? 'Start the official adoption process for $petName.'
          : 'The owner has not started the adoption process yet.';
    }
    if (signedByMe) {
      return 'Your signature is recorded. Waiting for the other party.';
    }
    return 'Read the agreement clauses and sign to continue.';
  }

  String _buttonLabel({
    required bool isOwner,
    required bool initiated,
    required bool signedByMe,
    required bool bothSigned,
    required bool handoverConfirmedByMe,
    required String status,
    required bool ownReviewSubmitted,
  }) {
    if (status == 'returned') return 'Return Completed';
    if (status == 'return_approved') {
      return handoverConfirmedByMe ? 'Pending' : 'Confirm Return';
    }
    if (status == 'completed') {
      return ownReviewSubmitted ? 'Reviewed' : 'Leave Review';
    }
    if (status == 'ready_to_complete') {
      return isOwner ? 'Mark Adopted' : 'Waiting';
    }
    if (status == 'protection_active') return 'View Process';
    if (status == 'handover_pending') {
      return handoverConfirmedByMe ? 'View Process' : 'Confirm';
    }
    if (bothSigned) return 'View Process';
    if (!initiated) return isOwner ? 'Initiate' : 'Waiting';
    if (signedByMe) return 'View Process';
    return 'Sign Now';
  }

  VoidCallback? _actionFor(
    BuildContext context, {
    required bool isOwner,
    required bool initiated,
    required bool signedByMe,
    required bool bothSigned,
    required bool handoverConfirmedByMe,
    required String status,
    required bool ownReviewSubmitted,
  }) {
    if (_busy) return null;
    if (status == 'returned') return _openProcess;
    if (status == 'return_approved') {
      return handoverConfirmedByMe ? _openProcess : _confirmReturnHandover;
    }
    if (status == 'completed') {
      return ownReviewSubmitted ? _openProcess : _openReview;
    }
    if (status == 'ready_to_complete') {
      return isOwner ? _completeAdoption : null;
    }
    if (status == 'protection_active') return _openProcess;
    if (status == 'handover_pending') {
      return handoverConfirmedByMe ? _openProcess : _confirmHandover;
    }
    if (!initiated && !isOwner) return null;
    if (!initiated && isOwner) return _initiate;
    if (!signedByMe) return _sign;
    return _openProcess;
  }

  Future<void> _processProtectionDeadline() async {
    if (_processingDeadline) return;
    final process = Map<String, dynamic>.from(
      widget.data['adoptionProcess'] as Map? ?? const {},
    );
    if (process['status'] != 'protection_active') return;
    final protectionEndsAt = process['protectionEndsAt'] as Timestamp?;
    if (protectionEndsAt == null || _now.isBefore(protectionEndsAt.toDate())) {
      return;
    }

    _processingDeadline = true;
    try {
      await AdoptionService.instance.processAdoptionProtectionDeadline(
        widget.conversationId,
      );
    } catch (error) {
      debugPrint('Unable to complete adoption deadline: $error');
    } finally {
      _processingDeadline = false;
    }
  }

  Future<void> _confirmReturnHandover() async {
    final confirmed = await _showConfirmReturnHandoverDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.confirmAdoptionReturnHandover(
        widget.conversationId,
      );
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _initiate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Start Adoption Contract?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Chat will be disabled until both parties sign. Both of you must '
          'review and sign the adoption agreement before handover can begin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Start Contract'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.initiateAdoptionProcess(
        widget.conversationId,
      );
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _AdoptionContractScreen(
              conversationId: widget.conversationId,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      }
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sign() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdoptionContractScreen(
          conversationId: widget.conversationId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  Future<void> _confirmHandover() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdoptionHandoverScreen(
          conversationId: widget.conversationId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  Future<void> _completeAdoption() async {
    final petName = _adoptionPetName(widget.data);
    final confirmed = await _showCompleteAdoptionDialog(context, petName);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.completeAdoptionProcess(
        widget.conversationId,
      );
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _AdoptionCompletedScreen(
              conversationId: widget.conversationId,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      }
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openProcess() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdoptionProcessScreen(
          conversationId: widget.conversationId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreedingReviewScreen(
          matchId: widget.conversationId,
          purpose: 'adoption',
        ),
      ),
    );
  }

  // Retained for the legacy adoption-process panel.
  // ignore: unused_element
  void _showProcessGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adoption Process Guide',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              const _ProcessGuideRow(
                title: '1. Contract',
                message: 'Both parties sign the adoption agreement.',
              ),
              const _ProcessGuideRow(
                title: '2. Handover',
                message: 'Meetup details are arranged in chat and confirmed.',
              ),
              _ProcessGuideRow(
                title: '3. Protection',
                message: _adoptionProtectionGuideMessage(),
              ),
              const _ProcessGuideRow(
                title: '4. Done',
                message: 'The adoption is completed and reviews can be left.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

int _adoptionProcessStep(String status, {required bool bothSigned}) {
  if (status == 'completed' ||
      status == 'ready_to_complete' ||
      status == 'returned') {
    return 4;
  }
  if (status == 'protection_active' || status == 'return_approved') return 3;
  if (status == 'handover_pending' || bothSigned) return 2;
  return 1;
}

String _durationLabel(Duration? duration) {
  if (duration == null || duration.isNegative) return 'ending now';
  if (duration.inDays > 0) {
    final hours = duration.inHours.remainder(24);
    if (hours > 0) return '${duration.inDays}d ${hours}h';
    return duration.inDays == 1 ? '1 day' : '${duration.inDays} days';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}

bool get _adoptionProtectionIsTestMode =>
    AdoptionService.protectionWindowDuration != const Duration(days: 30);

String _adoptionProtectionTitle() {
  return _adoptionProtectionIsTestMode
      ? '${_durationLabel(AdoptionService.protectionWindowDuration)} Protection Window (Test Mode)'
      : '30-Day Protection Window';
}

String _adoptionProtectionGuideMessage() {
  return _adoptionProtectionIsTestMode
      ? 'For testing, the protection window is shortened to ${_durationLabel(AdoptionService.protectionWindowDuration)}.'
      : 'The protection window starts after handover.';
}

class _AdoptionStepTracker extends StatelessWidget {
  final int step;
  final bool returnFlow;

  const _AdoptionStepTracker({required this.step, this.returnFlow = false});

  @override
  Widget build(BuildContext context) {
    final labels = returnFlow
        ? const ['Contract', 'Handover', 'Return']
        : [
            'Contract',
            'Handover',
            _adoptionProtectionIsTestMode ? 'Protect' : '30 Days',
            'Done',
          ];
    return SizedBox(
      height: 54,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const iconSize = 24.0;
          const labelWidth = 58.0;
          final completedSegments = (step - 1).clamp(0, labels.length - 1);
          final spacing =
              (constraints.maxWidth - iconSize) / (labels.length - 1);
          return Column(
            children: [
              SizedBox(
                height: 26,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: List.generate(labels.length - 1, (index) {
                        final active = index < completedSegments;
                        return Expanded(
                          child: Container(
                            height: 2,
                            color: active
                                ? AppColors.primary
                                : const Color(0xFFFFB6C4),
                          ),
                        );
                      }),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(labels.length, (index) {
                        final active = index < step;
                        return Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? AppColors.primary : Colors.white,
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Icon(
                            Icons.pets,
                            size: 14,
                            color: active ? Colors.white : AppColors.primary,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(labels.length, (index) {
                    final active = index < step;
                    final iconCenter = (index * spacing) + (iconSize / 2);
                    final left = (iconCenter - (labelWidth / 2)).clamp(
                      0.0,
                      constraints.maxWidth - labelWidth,
                    );
                    return Positioned(
                      left: left,
                      width: labelWidth,
                      child: Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? AppColors.primary
                              : const Color(0xFF888888),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdoptionProcessScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;

  const _AdoptionProcessScreen({
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  State<_AdoptionProcessScreen> createState() => _AdoptionProcessScreenState();
}

class _AdoptionProcessScreenState extends State<_AdoptionProcessScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc();
  bool _busy = false;
  bool _processingDeadline = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        title: const Text(
          'Adoption Process',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BreedingMatchService.instance.watchConversation(
          widget.conversationId,
        ),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final process = Map<String, dynamic>.from(
            data['adoptionProcess'] as Map? ?? const {},
          );
          _processProtectionDeadline(process);

          final petNames = Map<String, dynamic>.from(
            data['petNames'] as Map? ?? const {},
          );
          final participantIds =
              (data['participantIds'] as List?)?.cast<String>() ??
              const <String>[];
          final petOwners = Map<String, dynamic>.from(
            data['petOwners'] as Map? ?? const {},
          );
          final isOwner = petOwners.values.contains(widget.currentUserId);
          final petName = petNames.values.firstOrNull?.toString() ?? 'Pet';
          final signatures = Map<String, dynamic>.from(
            process['contractSignatures'] as Map? ?? const {},
          );
          final handoverConfirmations = Map<String, dynamic>.from(
            process['handoverConfirmations'] as Map? ?? const {},
          );
          final status = process['status'] as String? ?? 'not_started';
          final returnFlow =
              status == 'return_approved' || status == 'returned';
          final returnHandoverConfirmations = Map<String, dynamic>.from(
            process['returnHandoverConfirmations'] as Map? ?? const {},
          );
          final bothSigned =
              participantIds.isNotEmpty &&
              participantIds.every((id) => signatures[id] != null);
          final step = _adoptionProcessStep(status, bothSigned: bothSigned);
          final signedByMe = signatures[widget.currentUserId] != null;
          final handoverConfirmedByMe = status == 'return_approved'
              ? returnHandoverConfirmations[widget.currentUserId] != null
              : handoverConfirmations[widget.currentUserId] != null;
          final reviewsSubmitted = Map<String, dynamic>.from(
            data['reviewsSubmitted'] as Map? ?? const {},
          );
          final ownReviewSubmitted =
              reviewsSubmitted[widget.currentUserId] == true;

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  petName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  status == 'returned'
                                      ? 'Adoption ended - pet returned'
                                      : status == 'return_approved'
                                      ? 'Return handover in progress'
                                      : 'Adoption - In progress',
                                  style: const TextStyle(
                                    color: Color(0xFF777777),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Step ${returnFlow ? 3 : step} of ${returnFlow ? 3 : 4}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _AdoptionStepTracker(
                        step: returnFlow ? 3 : step,
                        returnFlow: returnFlow,
                      ),
                      const SizedBox(height: 20),
                      _AdoptionProcessStepCard(
                        title: 'Sign Adoption Contract',
                        subtitle: 'Step 1 of ${returnFlow ? 3 : 4}',
                        message: bothSigned
                            ? 'Adoption Agreement signed by both parties.'
                            : signedByMe
                            ? 'Your signature is recorded. Waiting for the other party.'
                            : 'Read all clauses and sign before handover.',
                        state: bothSigned
                            ? _ProcessCardState.done
                            : status == 'contract_pending'
                            ? _ProcessCardState.inProgress
                            : _ProcessCardState.locked,
                        dateLabel: _shortDateTime(
                          process['contractCompletedAt'] as Timestamp?,
                        ),
                        onTap: status == 'contract_pending' || bothSigned
                            ? _signContract
                            : null,
                      ),
                      _AdoptionProcessStepCard(
                        title: 'Handover',
                        subtitle: 'Step 2 of ${returnFlow ? 3 : 4}',
                        message: status == 'handover_pending'
                            ? handoverConfirmedByMe
                                  ? 'Your confirmation is recorded. Waiting for the other party.'
                                  : 'Meetup details are arranged in chat. Confirm once the handover is done.'
                            : status == 'protection_active' ||
                                  status == 'ready_to_complete' ||
                                  status == 'completed' ||
                                  returnFlow
                            ? 'Handover confirmed by both parties.'
                            : 'Complete previous steps first.',
                        state:
                            status == 'protection_active' ||
                                status == 'ready_to_complete' ||
                                status == 'completed' ||
                                returnFlow
                            ? _ProcessCardState.done
                            : status == 'handover_pending'
                            ? _ProcessCardState.inProgress
                            : _ProcessCardState.locked,
                        dateLabel: _shortDateTime(
                          process['handoverCompletedAt'] as Timestamp?,
                        ),
                        onTap:
                            status == 'handover_pending' ||
                                status == 'protection_active' ||
                                status == 'ready_to_complete' ||
                                status == 'completed'
                            ? _confirmHandover
                            : null,
                      ),
                      _AdoptionProcessStepCard(
                        title: status == 'return_approved'
                            ? 'Return approved - arrange handover'
                            : status == 'returned'
                            ? 'Return completed'
                            : _adoptionProtectionTitle(),
                        subtitle: 'Step 3 of ${returnFlow ? 3 : 4}',
                        message: status == 'return_approved'
                            ? handoverConfirmedByMe
                                  ? 'Return handover pending. Waiting for the other party to confirm.'
                                  : 'Coordinate in chat and confirm after the physical pet return happens.'
                            : status == 'returned'
                            ? 'Both parties confirmed the return handover.'
                            : status == 'protection_active'
                            ? 'Test mode remaining: ${_durationLabel((process['protectionEndsAt'] as Timestamp?)?.toDate().difference(_now))}.'
                            : status == 'ready_to_complete' ||
                                  status == 'completed'
                            ? 'Completed the protection window.'
                            : _adoptionProtectionGuideMessage(),
                        state: status == 'returned'
                            ? _ProcessCardState.done
                            : status == 'return_approved'
                            ? _ProcessCardState.inProgress
                            : status == 'ready_to_complete' ||
                                  status == 'completed'
                            ? _ProcessCardState.done
                            : status == 'protection_active'
                            ? _ProcessCardState.inProgress
                            : _ProcessCardState.locked,
                        dateLabel: _shortDateTime(
                          (process['protectionCompletedAt'] as Timestamp?) ??
                              (status == 'completed'
                                  ? process['protectionEndsAt'] as Timestamp?
                                  : null),
                        ),
                        onTap:
                            status == 'return_approved' &&
                                !handoverConfirmedByMe
                            ? _confirmReturnHandover
                            : status == 'protection_active' ||
                                  status == 'ready_to_complete' ||
                                  status == 'completed'
                            ? () =>
                                  _openProtectionDetails(data, process, petName)
                            : null,
                      ),
                      if (!returnFlow)
                        _AdoptionProcessStepCard(
                          title: 'Adoption Complete',
                          subtitle: 'Step 4 of 4',
                          message: status == 'completed'
                              ? 'This adoption is complete and recorded permanently.'
                              : status == 'ready_to_complete'
                              ? 'The protection window has ended. Complete the adoption to make it official.'
                              : 'Reviews become available after completion.',
                          state: status == 'completed'
                              ? _ProcessCardState.done
                              : status == 'ready_to_complete'
                              ? _ProcessCardState.inProgress
                              : _ProcessCardState.locked,
                          dateLabel: _shortDateTime(
                            process['completedAt'] as Timestamp?,
                          ),
                          onTap: status == 'completed' && !ownReviewSubmitted
                              ? _openReview
                              : null,
                        ),
                      const SizedBox(height: 10),
                      if (status == 'protection_active') ...[
                        _ProtectionActionPanel(
                          isOwner: isOwner,
                          petName: petName,
                          protectionEndsAt:
                              process['protectionEndsAt'] as Timestamp?,
                          onViewDetails: () =>
                              _openProtectionDetails(data, process, petName),
                          onRequestUpdate: isOwner
                              ? () => _requestUpdate(petName)
                              : null,
                          onFileReturn: isOwner
                              ? null
                              : () => _fileReturnRequest(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const _AdoptionContractNotice(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : _primaryAction(
                                    status: status,
                                    isOwner: isOwner,
                                    signedByMe: signedByMe,
                                    handoverConfirmedByMe:
                                        handoverConfirmedByMe,
                                    ownReviewSubmitted: ownReviewSubmitted,
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _primaryLabel(
                                      status: status,
                                      isOwner: isOwner,
                                      signedByMe: signedByMe,
                                      handoverConfirmedByMe:
                                          handoverConfirmedByMe,
                                      ownReviewSubmitted: ownReviewSubmitted,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _showProcessGuide,
                            child: const Text('View Process Guide'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  VoidCallback? _primaryAction({
    required String status,
    required bool isOwner,
    required bool signedByMe,
    required bool handoverConfirmedByMe,
    required bool ownReviewSubmitted,
  }) {
    if (status == 'return_approved' && !handoverConfirmedByMe) {
      return _confirmReturnHandover;
    }
    if (status == 'contract_pending' && !signedByMe) return _signContract;
    if (status == 'handover_pending' && !handoverConfirmedByMe) {
      return _confirmHandover;
    }
    if (status == 'ready_to_complete') {
      return isOwner ? _completeAdoption : null;
    }
    if (status == 'completed' && !ownReviewSubmitted) return _openReview;
    return null;
  }

  String _primaryLabel({
    required String status,
    required bool isOwner,
    required bool signedByMe,
    required bool handoverConfirmedByMe,
    required bool ownReviewSubmitted,
  }) {
    if (status == 'returned') return 'Return Completed';
    if (status == 'return_approved') {
      return handoverConfirmedByMe
          ? 'Return Handover Pending'
          : 'Confirm Return Handover';
    }
    if (status == 'contract_pending') {
      return signedByMe ? 'Waiting for Signature' : 'Sign & Proceed';
    }
    if (status == 'handover_pending') {
      return handoverConfirmedByMe
          ? 'Waiting for Handover'
          : 'Confirm Handover';
    }
    if (status == 'protection_active') return 'Protection Window Active';
    if (status == 'ready_to_complete') {
      return isOwner ? 'Mark as Adopted' : 'Waiting for Owner';
    }
    if (status == 'completed') {
      return ownReviewSubmitted ? 'Review Submitted' : 'Leave a Review';
    }
    return 'Waiting for Process';
  }

  Future<void> _signContract() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdoptionContractScreen(
          conversationId: widget.conversationId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  Future<void> _confirmHandover() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdoptionHandoverScreen(
          conversationId: widget.conversationId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  Future<void> _confirmReturnHandover() async {
    final confirmed = await _showConfirmReturnHandoverDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.confirmAdoptionReturnHandover(
        widget.conversationId,
      );
    } on AdoptionServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_chatFirebaseMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeAdoption() async {
    final conversationSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get();
    final petName = _adoptionPetName(
      conversationSnapshot.data() ?? const <String, dynamic>{},
    );
    if (!mounted) return;
    final confirmed = await _showCompleteAdoptionDialog(context, petName);
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.completeAdoptionProcess(
        widget.conversationId,
      );
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _AdoptionCompletedScreen(
              conversationId: widget.conversationId,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      }
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestUpdate(String petName) async {
    final result = await showModalBottomSheet<_UpdateRequestChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RequestUpdateSheet(petName: petName),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.requestAdoptionUpdate(
        conversationId: widget.conversationId,
        requestType: result.type,
        requestText: result.text,
      );
      if (mounted) _showSnack('Update request sent.');
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fileReturnRequest() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.validateAdoptionReturnRequestCanBeFiled(
        conversationId: widget.conversationId,
      );
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
      return;
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    final request = await Navigator.push<_ReturnRequestDraft>(
      context,
      MaterialPageRoute(builder: (_) => const _ReturnRequestScreen()),
    );
    if (request == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await AdoptionService.instance.fileAdoptionReturnRequest(
        conversationId: widget.conversationId,
        reason: request.reason,
        description: request.description,
        evidenceFiles: request.evidenceFiles,
      );
      if (mounted) _showSnack('Return request submitted.');
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openProtectionDetails(
    Map<String, dynamic> conversation,
    Map<String, dynamic> process,
    String petName,
  ) {
    final petOwners = Map<String, dynamic>.from(
      conversation['petOwners'] as Map? ?? const {},
    );
    final isOwner = petOwners.values.contains(widget.currentUserId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProtectionWindowScreen(
          petName: petName,
          isOwner: isOwner,
          returnRequested: process['returnStatus'] == 'requested',
          protectionStartedAt: process['protectionStartedAt'] as Timestamp?,
          protectionEndsAt: process['protectionEndsAt'] as Timestamp?,
          onRequestUpdate: isOwner ? () => _requestUpdate(petName) : null,
          onFileReturn: isOwner ? null : () => _fileReturnRequest(),
        ),
      ),
    );
  }

  Future<void> _processProtectionDeadline(Map<String, dynamic> process) async {
    if (_processingDeadline || process['status'] != 'protection_active') return;
    final protectionEndsAt = process['protectionEndsAt'] as Timestamp?;
    if (protectionEndsAt == null || _now.isBefore(protectionEndsAt.toDate())) {
      return;
    }

    _processingDeadline = true;
    try {
      await AdoptionService.instance.processAdoptionProtectionDeadline(
        widget.conversationId,
      );
    } catch (error) {
      debugPrint('Unable to complete adoption deadline: $error');
    } finally {
      _processingDeadline = false;
    }
  }

  void _openReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreedingReviewScreen(
          matchId: widget.conversationId,
          purpose: 'adoption',
        ),
      ),
    );
  }

  void _showProcessGuide() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adoption Process Guide',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              const _ProcessGuideRow(
                title: '1. Contract',
                message: 'Both parties sign the adoption agreement.',
              ),
              const _ProcessGuideRow(
                title: '2. Handover',
                message: 'Meetup details are arranged in chat and confirmed.',
              ),
              _ProcessGuideRow(
                title: '3. Protection',
                message: _adoptionProtectionGuideMessage(),
              ),
              const _ProcessGuideRow(
                title: '4. Done',
                message: 'The adoption is completed and reviews can be left.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<bool?> _showCompleteAdoptionDialog(
  BuildContext context,
  String petName,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Complete Adoption?',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action will mark $petName as permanently adopted. This cannot be undone.',
          ),
          const SizedBox(height: 14),
          const _CompletionDialogPoint(text: 'Ownership becomes permanent'),
          const _CompletionDialogPoint(text: 'Protection window closes'),
          const _CompletionDialogPoint(text: 'Both users can leave a review'),
          const _CompletionDialogPoint(
            text: 'Adoption is moved to Adoption History',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Complete Adoption'),
        ),
      ],
    ),
  );
}

Future<bool?> _showConfirmReturnHandoverDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Confirm Pet Return Handover?',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Only confirm after the physical pet return has actually happened.',
          ),
          SizedBox(height: 14),
          _CompletionDialogPoint(
            text: 'Your confirmation cannot be casually undone',
          ),
          _CompletionDialogPoint(
            text: 'The other party must confirm independently',
          ),
          _CompletionDialogPoint(
            text: 'The return completes only after both confirmations',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Confirm Handover'),
        ),
      ],
    ),
  );
}

class _CompletionDialogPoint extends StatelessWidget {
  final String text;

  const _CompletionDialogPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionCompletedScreen extends StatelessWidget {
  final String conversationId;
  final String currentUserId;

  const _AdoptionCompletedScreen({
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Adoption Complete',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BreedingMatchService.instance.watchConversation(conversationId),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final process = Map<String, dynamic>.from(
            data['adoptionProcess'] as Map? ?? const {},
          );
          final petName = _adoptionPetName(data);
          final completedAt = process['completedAt'] as Timestamp?;
          final reviewsSubmitted = Map<String, dynamic>.from(
            data['reviewsSubmitted'] as Map? ?? const {},
          );
          final ownReviewSubmitted = reviewsSubmitted[currentUserId] == true;

          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F6DC),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC8D4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "It's Official!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF2F8E3C),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$petName\'s adoption is complete and recorded permanently in both profiles.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _CompletionSummaryCard(completedAt: completedAt),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFC5D1)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.volunteer_activism,
                        color: AppColors.primary,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Thank you for giving $petName a forever home.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: ownReviewSubmitted
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BreedingReviewScreen(
                                matchId: conversationId,
                                purpose: 'adoption',
                              ),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    ownReviewSubmitted ? 'Review Submitted' : 'Leave a Review',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open Chat'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompletionSummaryCard extends StatelessWidget {
  final Timestamp? completedAt;

  const _CompletionSummaryCard({required this.completedAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Process Summary',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const _SummaryLine(text: 'Interview approved'),
          const _SummaryLine(text: 'Contract signed by both parties'),
          const _SummaryLine(text: 'Handover meetup completed'),
          const _SummaryLine(text: 'Protection window ended'),
          _SummaryLine(
            text: completedAt == null
                ? 'Adoption completed'
                : 'Adoption completed on ${_shortDate(completedAt!.toDate())}',
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String text;

  const _SummaryLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          const Icon(Icons.check_box, color: Color(0xFF2F8E3C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionActionPanel extends StatelessWidget {
  final bool isOwner;
  final String petName;
  final Timestamp? protectionEndsAt;
  final VoidCallback onViewDetails;
  final VoidCallback? onRequestUpdate;
  final VoidCallback? onFileReturn;

  const _ProtectionActionPanel({
    required this.isOwner,
    required this.petName,
    required this.protectionEndsAt,
    required this.onViewDetails,
    required this.onRequestUpdate,
    required this.onFileReturn,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = protectionEndsAt?.toDate().difference(
      DateTime.now().toUtc(),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOwner ? "It's time for a check-in" : _adoptionProtectionTitle(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text(
            isOwner
                ? 'Request a fresh photo update of $petName during the protection window.'
                : 'You can file a valid return request while the protection window is active.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 5),
            Text(
              '${_durationLabel(remaining)} remaining',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isOwner ? onRequestUpdate : onFileReturn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(isOwner ? 'Request Update' : 'File Return'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestUpdateSheet extends StatefulWidget {
  final String petName;

  const _RequestUpdateSheet({required this.petName});

  @override
  State<_RequestUpdateSheet> createState() => _RequestUpdateSheetState();
}

class _RequestUpdateSheetState extends State<_RequestUpdateSheet> {
  final _customController = TextEditingController();
  _UpdateRequestChoice? _selected;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      _UpdateRequestChoice(
        type: 'responding_to_name',
        title: '${widget.petName} responding to their name',
        text:
            'Can you send a photo update of ${widget.petName} responding to their name?',
        icon: Icons.record_voice_over_outlined,
      ),
      _UpdateRequestChoice(
        type: 'today_date',
        title: "${widget.petName} with today's date",
        text:
            'Can you send a photo of ${widget.petName} with today\'s date visible?',
        icon: Icons.calendar_month_outlined,
      ),
      _UpdateRequestChoice(
        type: 'playing_or_walk',
        title: '${widget.petName} playing or on a walk',
        text:
            'Can you send a recent photo of ${widget.petName} playing or on a walk?',
        icon: Icons.directions_walk,
      ),
      _UpdateRequestChoice(
        type: 'general',
        title: 'General update',
        text:
            'Can you send a photo or video update of ${widget.petName} whenever you get a chance?',
        icon: Icons.photo_camera_outlined,
      ),
      const _UpdateRequestChoice(
        type: 'custom',
        title: 'Write your own request',
        text: '',
        icon: Icons.edit_outlined,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Request Photo Update',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Ask the adopter for a fresh update during the protection window.',
              style: TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    if (option.type == 'custom') {
                      setState(() => _selected = option);
                    } else {
                      Navigator.pop(context, option);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selected?.type == option.type
                          ? const Color(0xFFFFE8EE)
                          : Colors.white,
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(option.icon, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selected?.type == 'custom' &&
                            option.type == 'custom') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customController,
                            minLines: 3,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Type your request...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_selected?.type == 'custom') ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  final text = _customController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please type your update request.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    _UpdateRequestChoice(
                      type: 'custom',
                      title: 'Custom request',
                      text: text,
                      icon: Icons.edit_outlined,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Submit Request'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateRequestChoice {
  final String type;
  final String title;
  final String text;
  final IconData icon;

  const _UpdateRequestChoice({
    required this.type,
    required this.title,
    required this.text,
    required this.icon,
  });
}

class _ProtectionWindowScreen extends StatelessWidget {
  final String petName;
  final bool isOwner;
  final bool returnRequested;
  final Timestamp? protectionStartedAt;
  final Timestamp? protectionEndsAt;
  final VoidCallback? onRequestUpdate;
  final VoidCallback? onFileReturn;

  const _ProtectionWindowScreen({
    required this.petName,
    required this.isOwner,
    required this.returnRequested,
    required this.protectionStartedAt,
    required this.protectionEndsAt,
    required this.onRequestUpdate,
    required this.onFileReturn,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = protectionEndsAt?.toDate().difference(
      DateTime.now().toUtc(),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          _adoptionProtectionIsTestMode
              ? '${_durationLabel(AdoptionService.protectionWindowDuration)} Window'
              : '30-Day Window',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDDE6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _adoptionProtectionTitle(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: protectionEndsAt == null
                        ? 0.0
                        : 1 -
                              ((remaining?.inSeconds ?? 0) /
                                      AdoptionService
                                          .protectionWindowDuration
                                          .inSeconds)
                                  .clamp(0.0, 1.0),
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          protectionStartedAt == null
                              ? 'Started: pending'
                              : 'Started: ${_shortDate(protectionStartedAt!.toDate())}',
                          style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          protectionEndsAt == null
                              ? 'Ends: pending'
                              : 'Ends: ${_shortDate(protectionEndsAt!.toDate())}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$petName is now in the adopter\'s care. The adopter may file a valid return request during this window if an issue is discovered.',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProtectionInfoCard(
              color: AppColors.primary,
              title: remaining == null
                  ? 'Protection window active'
                  : '${_durationLabel(remaining)} remaining',
              message:
                  'After this window, the adoption can be completed and recorded permanently.',
            ),
            const SizedBox(height: 16),
            const _ProtectionInfoCard(
              color: Color(0xFFFFF3C4),
              title: 'Return may be valid for:',
              message:
                  'Undisclosed illness, violent behavior not disclosed, severe incompatibility, or inaccurate listing details.',
            ),
            const SizedBox(height: 16),
            const _ProtectionInfoCard(
              color: Color(0xFFE8F6FF),
              title: 'Photo updates happen in chat',
              message:
                  'The original owner can request updates. The adopter can respond with a recent photo.',
            ),
            const SizedBox(height: 18),
            if (returnRequested)
              const _ProtectionInfoCard(
                color: Color(0xFFFFF3C4),
                title: 'Return request filed',
                message:
                    'Completion is paused while the return request is waiting for admin review.',
              ),
            if (!returnRequested) ...[
              if (isOwner)
                FilledButton.icon(
                  onPressed: onRequestUpdate == null
                      ? null
                      : () {
                          final callback = onRequestUpdate!;
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => callback(),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Request Update'),
                )
              else
                FilledButton.icon(
                  onPressed: onFileReturn == null
                      ? null
                      : () {
                          final callback = onFileReturn!;
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => callback(),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('File a Request Return'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProtectionInfoCard extends StatelessWidget {
  final Color color;
  final String title;
  final String message;

  const _ProtectionInfoCard({
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _ReturnRequestScreen extends StatefulWidget {
  const _ReturnRequestScreen();

  @override
  State<_ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<_ReturnRequestScreen> {
  final _descriptionController = TextEditingController();
  final _evidenceFiles = <_SelectedEvidenceFile>[];
  String _reason = 'Violent or aggressive behavior';
  bool _uploading = false;

  static const _reasons = [
    ('Violent or aggressive behavior', 'Not disclosed before adoption'),
    ('Undisclosed illness or condition', 'Pet is sick with unknown condition'),
    ('Severe incompatibility', 'Allergies, other pets, household conflicts'),
    ('Listing was misrepresented', 'Breed, age, or details were inaccurate'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final remainingSlots = 3 - _evidenceFiles.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 3 evidence files.')),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'm4v'],
    );
    if (picked == null || !mounted) return;

    final selected = <_SelectedEvidenceFile>[];
    final existingPaths = _evidenceFiles
        .map((evidence) => evidence.file.path)
        .toSet();
    final existingFingerprints = _evidenceFiles
        .map(
          (evidence) =>
              '${evidence.fileName.toLowerCase()}::${evidence.sizeBytes}',
        )
        .toSet();
    var skippedDuplicate = false;
    var skippedOversized = false;
    var skippedUnsupported = false;
    var reachedFileLimit = false;
    for (final file in picked.files) {
      if (selected.length >= remainingSlots) {
        reachedFileLimit = true;
        break;
      }
      final path = file.path;
      final fingerprint = '${file.name.toLowerCase()}::${file.size}';
      if (path == null) {
        skippedUnsupported = true;
        continue;
      }
      if (existingPaths.contains(path) ||
          existingFingerprints.contains(fingerprint)) {
        skippedDuplicate = true;
        continue;
      }
      final evidence = _SelectedEvidenceFile.fromPath(
        path,
        fileName: file.name,
        sizeBytes: file.size,
      );
      if (evidence == null) {
        skippedUnsupported = true;
        continue;
      }
      if (evidence.sizeBytes > 50 * 1024 * 1024) {
        skippedOversized = true;
        continue;
      }
      selected.add(evidence);
      existingPaths.add(path);
      existingFingerprints.add(fingerprint);
    }

    setState(() {
      _evidenceFiles.addAll(selected);
    });

    final warnings = <String>[
      if (skippedDuplicate)
        'That file is already selected. Duplicate evidence files are not allowed.',
      if (reachedFileLimit) 'You can attach up to 3 evidence files only.',
      if (skippedOversized) 'Each evidence file must be 50 MB or smaller.',
      if (skippedUnsupported)
        'Only JPG, PNG, WEBP, MP4, MOV, and M4V files are accepted.',
    ];
    if (warnings.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(warnings.join(' '))));
    }
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please describe what happened in at least 50 characters.',
          ),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
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
      if (!mounted) return;
      Navigator.pop(
        context,
        _ReturnRequestDraft(
          reason: _reason,
          description: description,
          evidenceFiles: evidence,
        ),
      );
    } on CloudinaryUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload evidence right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Return Request',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE1E8),
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Only valid reasons within the protection window are accepted. The owner will be notified.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Reason for Return *',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ..._reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _reason = reason.$1),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _reason == reason.$1
                        ? const Color(0xFFFFE1E8)
                        : Colors.white,
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason.$1,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(reason.$2, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              border: Border.all(color: const Color(0xFFD0D0D0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, color: Color(0xFF999999), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'I just changed my mind',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Not eligible as a return reason',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Describe what happened *',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Describe the issue in detail (min 50 characters)',
              filled: true,
              fillColor: const Color(0xFFFFE8EE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickEvidence,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _evidenceFiles.isEmpty
                  ? 'Upload Evidence - Optional'
                  : '${_evidenceFiles.length} file(s) selected',
            ),
          ),
          if (_evidenceFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._evidenceFiles.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(file.icon, size: 18, color: AppColors.primary),
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
                      tooltip: 'Remove file',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _uploading
                          ? null
                          : () => setState(() => _evidenceFiles.remove(file)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'JPG, PNG, WEBP, MP4, MOV, or M4V. Max 3 files, 50 MB each.',
            style: TextStyle(color: Color(0xFF777777), fontSize: 11),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _uploading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(_uploading ? 'Uploading...' : 'Submit Return Request'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _uploading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SelectedEvidenceFile {
  final File file;
  final String fileName;
  final String fileType;
  final String mimeType;
  final int sizeBytes;

  const _SelectedEvidenceFile({
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.mimeType,
    required this.sizeBytes,
  });

  static _SelectedEvidenceFile? fromPath(
    String path, {
    required String fileName,
    required int sizeBytes,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    final fileType = switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => 'image',
      'mp4' || 'mov' || 'm4v' => 'video',
      _ => '',
    };
    if (fileType.isEmpty) return null;
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      _ => 'application/octet-stream',
    };
    return _SelectedEvidenceFile(
      file: File(path),
      fileName: fileName,
      fileType: fileType,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  IconData get icon {
    return switch (fileType) {
      'image' => Icons.image_outlined,
      'video' => Icons.videocam_outlined,
      _ => Icons.attach_file,
    };
  }
}

class _ReturnRequestDraft {
  final String reason;
  final String description;
  final List<AdoptionEvidenceFile> evidenceFiles;

  const _ReturnRequestDraft({
    required this.reason,
    required this.description,
    required this.evidenceFiles,
  });
}

class _AdoptionContractScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;

  const _AdoptionContractScreen({
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  State<_AdoptionContractScreen> createState() =>
      _AdoptionContractScreenState();
}

class _AdoptionContractScreenState extends State<_AdoptionContractScreen> {
  final GlobalKey _signatureKey = GlobalKey();
  final List<Offset?> _signaturePoints = [];
  bool _accepted = false;
  bool _signing = false;
  bool _isDrawingSignature = false;

  bool get _hasSignature => _signaturePoints.any((point) => point != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Adoption Process',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BreedingMatchService.instance.watchConversation(
          widget.conversationId,
        ),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final process = Map<String, dynamic>.from(
            data['adoptionProcess'] as Map? ?? const {},
          );
          final participantIds =
              (data['participantIds'] as List?)?.cast<String>() ??
              const <String>[];
          final ownerId = _adoptionOwnerId(data);
          final adopterId = participantIds.firstWhere(
            (id) => id != ownerId,
            orElse: () => '',
          );
          final signatures = Map<String, dynamic>.from(
            process['contractSignatures'] as Map? ?? const {},
          );
          final signedByMe = signatures[widget.currentUserId] != null;
          final petName = _adoptionPetName(data);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  physics: _isDrawingSignature
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD8E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Breedr Adoption Agreement',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ContractPartiesLine(
                            petName: petName,
                            ownerId: ownerId,
                            adopterId: adopterId,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'This contract protects both parties. Read all clauses before signing.',
                            style: TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _ContractClauseCard(
                      number: 1,
                      title: 'Breedr Adoption Agreement',
                      message:
                          'The owner confirms all known health conditions of the pet have been disclosed. Any undisclosed illness within 14 days of handover entitles the adopter to a full refund.',
                    ),
                    const _ContractClauseCard(
                      number: 2,
                      title: 'No Resale Clause',
                      message:
                          'The adopter agrees not to resell, transfer, or abandon the pet without first offering to return it to the original owner. Violation may lead to account suspension.',
                    ),
                    const _ContractClauseCard(
                      number: 3,
                      title: 'Protection Return Window',
                      message:
                          'Within the protection window after handover, the adopter may return the pet if it shows undisclosed illness, violent behavior, or severe incompatibility. The owner must accept valid returns.',
                    ),
                    const _ContractClauseCard(
                      number: 4,
                      title: 'Veterinary Care',
                      message:
                          'The adopter agrees to maintain the pet vaccination schedule and provide necessary veterinary care. Neglect is grounds for contract violation.',
                    ),
                    const _ContractClauseCard(
                      number: 5,
                      title: 'Monthly Photo Updates',
                      message:
                          'The adopter agrees to send at least one photo update per month for the first 6 months after adoption.',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD8E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Digital Signature',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _SignatureStatusCard(
                                  label: 'Owner',
                                  userId: ownerId,
                                  signedAt: _signatureSignedAt(
                                    signatures[ownerId],
                                  ),
                                  signatureUrl: _signatureUrl(
                                    signatures[ownerId],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SignatureStatusCard(
                                  label: 'Adopter',
                                  userId: adopterId,
                                  signedAt: _signatureSignedAt(
                                    signatures[adopterId],
                                  ),
                                  signatureUrl: _signatureUrl(
                                    signatures[adopterId],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!signedByMe) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFB6C4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Draw Your Signature',
                                    style: TextStyle(
                                      color: Color(0xFF222222),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _signaturePoints.isEmpty
                                      ? null
                                      : () => setState(
                                          () => _signaturePoints.clear(),
                                        ),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            RepaintBoundary(
                              key: _signatureKey,
                              child: _SignaturePad(
                                points: _signaturePoints,
                                onDrawStart: () {
                                  if (!_isDrawingSignature) {
                                    setState(() => _isDrawingSignature = true);
                                  }
                                },
                                onDrawEnd: () {
                                  if (_isDrawingSignature) {
                                    setState(() => _isDrawingSignature = false);
                                  }
                                },
                                onChanged: (points) {
                                  setState(() {
                                    _signaturePoints
                                      ..clear()
                                      ..addAll(points);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use your finger to sign. Your signature will be saved with this adoption contract.',
                              style: TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: signedByMe
                          ? null
                          : () => setState(() => _accepted = !_accepted),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFB6C4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: signedByMe || _accepted,
                              onChanged: signedByMe
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _accepted = value ?? false,
                                      );
                                    },
                              activeColor: AppColors.primary,
                            ),
                            const Expanded(
                              child: Text(
                                'I have read, understood, and agree to all 5 clauses. I am signing this Adoption Agreement voluntarily and in good faith.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
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
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed:
                              signedByMe ||
                                  !_accepted ||
                                  _signing ||
                                  !_hasSignature
                              ? null
                              : _sign,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: _signing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  signedByMe ? 'Signed' : 'Sign & Proceed',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => _showAdoptionProcessGuide(context),
                          child: const Text('View Process Guide'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sign() async {
    setState(() => _signing = true);
    File? signatureFile;
    try {
      signatureFile = await _exportSignatureFile();
      final signatureUrl = await CloudinaryService().uploadImageOrThrow(
        signatureFile,
      );
      await AdoptionService.instance.signAdoptionContract(
        widget.conversationId,
        signatureUrl: signatureUrl,
      );
      if (mounted) Navigator.pop(context);
    } on CloudinaryUploadException catch (error) {
      if (mounted) _showError(error.message);
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      try {
        if (signatureFile != null && await signatureFile.exists()) {
          await signatureFile.delete();
        }
      } catch (_) {
        // Temporary signature cleanup should not block the user.
      }
      if (mounted) setState(() => _signing = false);
    }
  }

  Future<File> _exportSignatureFile() async {
    final boundary =
        _signatureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || !_hasSignature) {
      throw const CloudinaryUploadException(
        'Please draw your signature before continuing.',
      );
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      throw const CloudinaryUploadException(
        'Your signature could not be prepared. Please try again.',
      );
    }

    final file = File(
      '${Directory.systemTemp.path}/breedr_signature_${widget.currentUserId}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdoptionHandoverScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;

  const _AdoptionHandoverScreen({
    required this.conversationId,
    required this.currentUserId,
  });

  @override
  State<_AdoptionHandoverScreen> createState() =>
      _AdoptionHandoverScreenState();
}

class _AdoptionHandoverScreenState extends State<_AdoptionHandoverScreen> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 1,
        shadowColor: Colors.black26,
        title: const Text(
          'Adoption Process',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: BreedingMatchService.instance.watchConversation(
          widget.conversationId,
        ),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final process = Map<String, dynamic>.from(
            data['adoptionProcess'] as Map? ?? const {},
          );
          final confirmations = Map<String, dynamic>.from(
            process['handoverConfirmations'] as Map? ?? const {},
          );
          final petOwners = Map<String, dynamic>.from(
            data['petOwners'] as Map? ?? const {},
          );
          final participantIds =
              (data['participantIds'] as List?)?.cast<String>() ??
              const <String>[];
          final ownerId = _adoptionOwnerId(data);
          final adopterId = participantIds.firstWhere(
            (id) => id != ownerId,
            orElse: () => '',
          );
          final isOwner = petOwners.values.contains(widget.currentUserId);
          final petName = _adoptionPetName(data);
          final confirmedByMe = confirmations[widget.currentUserId] != null;
          final ownerConfirmed = confirmations[ownerId] != null;
          final adopterConfirmed = confirmations[adopterId] != null;
          final status = process['status'] as String? ?? '';
          final canConfirm = status == 'handover_pending' && !confirmedByMe;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                  children: [
                    Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD8E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.handshake_rounded,
                          color: AppColors.primary,
                          size: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      confirmedByMe ? 'Handover Recorded' : 'Confirm Handover',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOwner
                          ? 'Confirm only after you have safely handed over $petName to the adopter in person.'
                          : 'Confirm only after you have safely received $petName from the owner in person.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _HandoverWarningCard(
                      message:
                          'Please confirm only when the handover is complete. This action cannot be undone.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC5D1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _adoptionProtectionTitle(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'After you both confirm, the adopter has ${_adoptionProtectionIsTestMode ? _durationLabel(AdoptionService.protectionWindowDuration) : '30 days'} to report valid issues. You can still chat during this period.',
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HandoverStatusCard(
                      ownerId: ownerId,
                      adopterId: adopterId,
                      currentUserId: widget.currentUserId,
                      ownerConfirmed: ownerConfirmed,
                      adopterConfirmed: adopterConfirmed,
                    ),
                    const SizedBox(height: 12),
                    _HandoverChecklist(isOwner: isOwner, petName: petName),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: canConfirm && !_confirming ? _confirm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              confirmedByMe
                                  ? 'Handover Confirmed'
                                  : 'Confirm Handover',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Before Confirm Handover',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Only continue if the pet has been handed over in person and both sides agree the handover is complete. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm Handover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _confirming = true);
    try {
      await AdoptionService.instance.confirmAdoptionHandover(
        widget.conversationId,
      );
      if (mounted) Navigator.pop(context);
    } on AdoptionServiceException catch (error) {
      if (mounted) _showError(error.message);
    } on FirebaseException catch (error) {
      if (mounted) _showError(_chatFirebaseMessage(error));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HandoverWarningCard extends StatelessWidget {
  final String message;

  const _HandoverWarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD783)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF5A640)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoverStatusCard extends StatelessWidget {
  final String ownerId;
  final String adopterId;
  final String currentUserId;
  final bool ownerConfirmed;
  final bool adopterConfirmed;

  const _HandoverStatusCard({
    required this.ownerId,
    required this.adopterId,
    required this.currentUserId,
    required this.ownerConfirmed,
    required this.adopterConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Handover Status',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HandoverPartyStatus(
                  userId: ownerId,
                  label: 'Pet Owner',
                  isCurrentUser: currentUserId == ownerId,
                  confirmed: ownerConfirmed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HandoverPartyStatus(
                  userId: adopterId,
                  label: 'Adopter',
                  isCurrentUser: currentUserId == adopterId,
                  confirmed: adopterConfirmed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Both parties must confirm before the protection window starts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF777777), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _HandoverPartyStatus extends StatelessWidget {
  final String userId;
  final String label;
  final bool isCurrentUser;
  final bool confirmed;

  const _HandoverPartyStatus({
    required this.userId,
    required this.label,
    required this.isCurrentUser,
    required this.confirmed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userId.isEmpty
          ? null
          : FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        return Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFFFD8E2),
              backgroundImage: _userPhoto(data).isEmpty
                  ? null
                  : NetworkImage(_userPhoto(data)),
              child: _userPhoto(data).isEmpty
                  ? const Icon(Icons.person, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              isCurrentUser ? 'You' : _userName(data),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 10),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: confirmed
                    ? const Color(0xFFD8F5D4)
                    : const Color(0xFFFFF4D7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                confirmed ? 'Confirmed' : 'Not yet',
                style: TextStyle(
                  color: confirmed
                      ? const Color(0xFF2F8E3C)
                      : const Color(0xFFF5A640),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HandoverChecklist extends StatelessWidget {
  final bool isOwner;
  final String petName;

  const _HandoverChecklist({required this.isOwner, required this.petName});

  @override
  Widget build(BuildContext context) {
    final items = isOwner
        ? [
            'You have met the adopter in person',
            'You handed over $petName',
            'Any available health documents were provided',
            'The adopter agreed the handover is complete',
          ]
        : [
            'You have met the owner in person',
            'You received $petName safely',
            'Any available health documents were received',
            'You agree the handover is complete',
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please confirm that:',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 12, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProcessCardState { locked, inProgress, done }

class _AdoptionProcessStepCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String message;
  final _ProcessCardState state;
  final String dateLabel;
  final VoidCallback? onTap;

  const _AdoptionProcessStepCard({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.state,
    this.dateLabel = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = state == _ProcessCardState.done;
    final isActive = state == _ProcessCardState.inProgress;
    final color = isDone
        ? const Color(0xFFD8F5D4)
        : isActive
        ? const Color(0xFFFFE3EA)
        : Colors.white;
    final borderColor = isDone
        ? const Color(0xFF62BA5D)
        : isActive
        ? AppColors.primary
        : const Color(0xFFBBBBBB);

    final content = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 13,
                        color: isDone
                            ? const Color(0xFF2F8E3C)
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: TextStyle(
                            color: isDone
                                ? const Color(0xFF2F8E3C)
                                : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProcessStatusPill(state: state),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF777777),
                  size: 18,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}

class _ProcessStatusPill extends StatelessWidget {
  final _ProcessCardState state;

  const _ProcessStatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDone = state == _ProcessCardState.done;
    final isActive = state == _ProcessCardState.inProgress;
    final label = isDone
        ? 'Done'
        : isActive
        ? 'In progress'
        : 'Locked';
    final color = isDone
        ? const Color(0xFF3FA34D)
        : isActive
        ? AppColors.primary
        : const Color(0xFF555555);
    final icon = isDone
        ? Icons.check
        : isActive
        ? Icons.circle
        : Icons.lock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionContractNotice extends StatelessWidget {
  const _AdoptionContractNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Breedr records adoption progress for both parties. It does not process payments, verify payments, or replace legal advice.',
        style: TextStyle(color: Color(0xFF555555), fontSize: 12, height: 1.35),
      ),
    );
  }
}

class _ContractClauseCard extends StatelessWidget {
  final int number;
  final String title;
  final String message;

  const _ContractClauseCard({
    required this.number,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureStatusCard extends StatelessWidget {
  final String label;
  final String userId;
  final Timestamp? signedAt;
  final String? signatureUrl;

  const _SignatureStatusCard({
    required this.label,
    required this.userId,
    required this.signedAt,
    required this.signatureUrl,
  });

  @override
  Widget build(BuildContext context) {
    final signed = signedAt != null;
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: signed ? const Color(0xFFE8FFE8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userId.isEmpty
            ? null
            : FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final name = _userName(data);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 10),
              ),
              const SizedBox(height: 4),
              if (signatureUrl != null && signatureUrl!.isNotEmpty) ...[
                Container(
                  height: 36,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: BreedrNetworkImage(
                    imageUrl: signatureUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    signed ? Icons.check : Icons.hourglass_bottom,
                    color: signed ? const Color(0xFF3FA34D) : AppColors.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    signed ? 'Signed' : 'Awaiting',
                    style: TextStyle(
                      color: signed
                          ? const Color(0xFF3FA34D)
                          : AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (signedAt != null)
                Text(
                  _shortDate(signedAt!.toDate()),
                  style: const TextStyle(color: Color(0xFF777777), fontSize: 9),
                ),
            ],
          );
        },
      ),
    );
  }
}

Timestamp? _signatureSignedAt(dynamic value) {
  if (value is Timestamp) return value;
  if (value is Map) return value['signedAt'] as Timestamp?;
  return null;
}

String? _signatureUrl(dynamic value) {
  if (value is Map) return value['signatureUrl'] as String?;
  return null;
}

class SignaturePadTestScreen extends StatefulWidget {
  const SignaturePadTestScreen({super.key});

  @override
  State<SignaturePadTestScreen> createState() => _SignaturePadTestScreenState();
}

class _SignaturePadTestScreenState extends State<SignaturePadTestScreen> {
  final List<Offset?> _points = [];
  bool _isDrawing = false;

  bool get _hasSignature => _points.any((point) => point != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Signature Pad Test',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        physics: _isDrawing
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFB6C4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Draw Your Signature',
                        style: TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _points.isEmpty
                          ? null
                          : () {
                              setState(() => _points.clear());
                            },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SignaturePad(
                  points: _points,
                  onDrawStart: () {
                    if (!_isDrawing) setState(() => _isDrawing = true);
                  },
                  onDrawEnd: () {
                    if (_isDrawing) setState(() => _isDrawing = false);
                  },
                  onChanged: (points) {
                    setState(() {
                      _points
                        ..clear()
                        ..addAll(points);
                    });
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Temporary dev screen only. Use this to test finger/mouse drawing without creating a new adoption transaction.',
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _hasSignature
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Signature pad input looks good.'),
                        ),
                      );
                    }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text(
                'Confirm Test Signature',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePad extends StatefulWidget {
  final List<Offset?> points;
  final ValueChanged<List<Offset?>> onChanged;
  final VoidCallback? onDrawStart;
  final VoidCallback? onDrawEnd;

  const _SignaturePad({
    required this.points,
    required this.onChanged,
    this.onDrawStart,
    this.onDrawEnd,
  });

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  late List<Offset?> _points;
  final ValueNotifier<int> _repaintTick = ValueNotifier<int>(0);
  bool _pointerDown = false;

  @override
  void initState() {
    super.initState();
    _points = List<Offset?>.from(widget.points);
  }

  @override
  void didUpdateWidget(covariant _SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.length != _points.length) {
      _points = List<Offset?>.from(widget.points);
      _repaintTick.value++;
    }
  }

  @override
  void dispose() {
    _repaintTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointerDown = true;
        widget.onDrawStart?.call();
        _addPoint(
          context,
          _localPosition(context, event.position),
          notifyParent: true,
        );
      },
      onPointerMove: (event) {
        if (!_pointerDown) return;
        _addPoint(context, _localPosition(context, event.position));
      },
      onPointerUp: (_) => _finishStroke(),
      onPointerCancel: (_) => _finishStroke(),
      child: Container(
        height: 230,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFD9D9D9),
            style: BorderStyle.solid,
          ),
        ),
        child: CustomPaint(
          isComplex: true,
          willChange: true,
          painter: _SignaturePainter(_points, repaint: _repaintTick),
          child: _points.any((point) => point != null)
              ? null
              : const Center(
                  child: Text(
                    'Sign here',
                    style: TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Offset _localPosition(BuildContext context, Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.globalToLocal(globalPosition);
  }

  void _addPoint(
    BuildContext context,
    Offset position, {
    bool notifyParent = false,
  }) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final clamped = Offset(
      position.dx.clamp(0.0, size.width),
      position.dy.clamp(0.0, size.height),
    );
    final hadSignature = _points.any((point) => point != null);
    _points.add(clamped);
    _repaintTick.value++;
    if (!hadSignature) {
      setState(() {});
    }
    if (notifyParent) {
      widget.onChanged(List<Offset?>.from(_points));
    }
  }

  void _finishStroke() {
    if (!_pointerDown) return;
    _pointerDown = false;
    if (_points.isNotEmpty && _points.last != null) {
      _points.add(null);
      _repaintTick.value++;
    }
    widget.onChanged(List<Offset?>.from(_points));
    widget.onDrawEnd?.call();
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points, {required Listenable repaint})
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      } else if (current != null && next == null) {
        canvas.drawCircle(current, paint.strokeWidth / 2, paint);
      }
    }
    if (points.length == 1 && points.first != null) {
      canvas.drawCircle(points.first!, paint.strokeWidth / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
  }
}

class _ContractPartiesLine extends StatelessWidget {
  final String petName;
  final String ownerId;
  final String adopterId;

  const _ContractPartiesLine({
    required this.petName,
    required this.ownerId,
    required this.adopterId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        if (ownerId.isNotEmpty)
          FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
        if (adopterId.isNotEmpty)
          FirebaseFirestore.instance.collection('users').doc(adopterId).get(),
      ]),
      builder: (context, snapshot) {
        final docs =
            snapshot.data ?? const <DocumentSnapshot<Map<String, dynamic>>>[];
        final ownerName = docs.isNotEmpty ? _userName(docs[0].data()) : 'Owner';
        final adopterName = docs.length > 1
            ? _userName(docs[1].data())
            : 'Adopter';
        return Text(
          '$petName - $ownerName to $adopterName',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        );
      },
    );
  }
}

String _adoptionPetName(Map<String, dynamic> data) {
  final petNames = Map<String, dynamic>.from(data['petNames'] as Map? ?? {});
  return petNames.values.firstOrNull?.toString() ?? 'this pet';
}

String _adoptionOwnerId(Map<String, dynamic> data) {
  final petOwners = Map<String, dynamic>.from(data['petOwners'] as Map? ?? {});
  return petOwners.values.firstOrNull?.toString() ?? '';
}

String _userName(Map<String, dynamic>? data) {
  if (data == null) return 'Pet Owner';
  return data['fullName'] as String? ??
      data['name'] as String? ??
      data['displayName'] as String? ??
      data['username'] as String? ??
      'Pet Owner';
}

String _userPhoto(Map<String, dynamic>? data) {
  if (data == null) return '';
  return data['profilePhoto'] as String? ??
      data['photoUrl'] as String? ??
      data['avatarUrl'] as String? ??
      '';
}

String _shortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

void _showAdoptionProcessGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFFFF7FA),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adoption Process Guide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            const _ProcessGuideRow(
              title: '1. Contract',
              message: 'Both parties sign the adoption agreement.',
            ),
            const _ProcessGuideRow(
              title: '2. Handover',
              message: 'Meetup details are arranged in chat and confirmed.',
            ),
            _ProcessGuideRow(
              title: '3. Protection',
              message: _adoptionProtectionGuideMessage(),
            ),
            const _ProcessGuideRow(
              title: '4. Done',
              message: 'The adoption is completed and reviews can be left.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProcessActionButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  const _ProcessActionButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
      ),
    );
  }
}

class _ProcessGuideRow extends StatelessWidget {
  final String title;
  final String message;

  const _ProcessGuideRow({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionPanel extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> data;
  final String currentUserId;

  const _CompletionPanel({
    required this.matchId,
    required this.data,
    required this.currentUserId,
  });

  @override
  State<_CompletionPanel> createState() => _CompletionPanelState();
}

class _CompletionPanelState extends State<_CompletionPanel> {
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _processDeadline();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now().toUtc());
      _processDeadline();
    });
  }

  @override
  void didUpdateWidget(covariant _CompletionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data['status'] != widget.data['status']) {
      _processDeadline();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _processDeadline() async {
    if (_processing || widget.data['status'] != 'completion_pending') return;
    final autoCompleteAt = widget.data['autoCompleteAt'] as Timestamp?;
    if (autoCompleteAt == null || _now.isBefore(autoCompleteAt.toDate())) {
      return;
    }

    _processing = true;
    try {
      await BreedingMatchService.instance.processCompletionDeadline(
        widget.matchId,
      );
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final purpose = data['purpose'] as String? ?? 'breeding';
    if (purpose != 'breeding') return const SizedBox.shrink();

    final status = data['status'] as String? ?? 'active';
    final confirmations = Map<String, dynamic>.from(
      data['completionConfirmations'] as Map? ?? const {},
    );
    final decisions = Map<String, dynamic>.from(
      data['removalDecisions'] as Map? ?? const {},
    );
    final ownerIds =
        (data['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
    final ownConfirmed = confirmations[widget.currentUserId] == true;
    final otherConfirmed = ownerIds
        .where((id) => id != widget.currentUserId)
        .any((id) => confirmations[id] == true);
    final requesterId = data['completionRequestedBy'] as String?;
    final ownReviewSubmitted =
        Map<String, dynamic>.from(
          data['reviewsSubmitted'] as Map? ?? const {},
        )[widget.currentUserId] ==
        true;

    if (status == 'completed') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        color: const Color(0xFFFFE8EE),
        child: Column(
          children: [
            Icon(
              data['completionType'] == 'auto_completed'
                  ? Icons.schedule_send
                  : Icons.check_circle,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(height: 5),
            Text(
              data['completionType'] == 'auto_completed'
                  ? 'Breeding auto-completed'
                  : 'Breeding completed',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (!decisions.containsKey(widget.currentUserId)) ...[
              const Text(
                'Would you like to set your pet offline from breeding listings?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decideRemoval(context, false),
                      child: const Text('Keep Available'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _decideRemoval(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Set Offline'),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                decisions[widget.currentUserId] == true
                    ? 'Your pet is offline. You can make it available again from My Pets.'
                    : 'Your pet remains available for breeding.',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ownReviewSubmitted
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BreedingReviewScreen(matchId: widget.matchId),
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  ownReviewSubmitted ? Icons.check : Icons.rate_review_outlined,
                ),
                label: Text(
                  ownReviewSubmitted ? 'Review Submitted' : 'Leave a Review',
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'completion_pending') {
      final deadline = data['confirmationDeadline'] as Timestamp?;
      final autoCompleteAt = data['autoCompleteAt'] as Timestamp?;
      final firstPeriodRemaining = deadline?.toDate().difference(_now);
      final totalRemaining = autoCompleteAt?.toDate().difference(_now);
      final afterReminderWindow =
          deadline != null && !_now.isBefore(deadline.toDate());
      final isRequester = requesterId == widget.currentUserId;
      final canRemind =
          isRequester && afterReminderWindow && data['reminderSentAt'] == null;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        color: const Color(0xFFFFF2DE),
        child: Column(
          children: [
            const Icon(Icons.schedule, color: Color(0xFFF2A13A), size: 28),
            const SizedBox(height: 4),
            Text(
              isRequester
                  ? 'Waiting for Other Owner'
                  : 'Waiting for Your Confirmation',
              style: const TextStyle(
                color: Color(0xFFE6952F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isRequester
                  ? 'You marked this breeding as completed.'
                  : 'The other owner marked this breeding as completed.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
            _CompletionProgress(
              remaining: afterReminderWindow
                  ? totalRemaining
                  : firstPeriodRemaining,
              total: const Duration(hours: 24),
              label: afterReminderWindow
                  ? 'Auto-completion remaining'
                  : 'Confirmation time remaining',
            ),
            const SizedBox(height: 9),
            if (!ownConfirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmCompletion(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A640),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Completion'),
                ),
              )
            else if (canRemind)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sendReminder,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send One Reminder'),
                ),
              )
            else
              Text(
                data['reminderSentAt'] != null
                    ? 'Reminder sent. Waiting for confirmation.'
                    : 'You will be able to send one reminder after 24 hours.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF777777), fontSize: 10),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Has the breeding been completed?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => _confirmCompletion(context, otherConfirmed),
            child: Text(otherConfirmed ? 'Confirm' : 'Mark Completed'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCompletion(
    BuildContext context,
    bool otherConfirmed,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          otherConfirmed
              ? 'Confirm breeding completion?'
              : 'Mark breeding as completed?',
        ),
        content: const Text(
          'Both owners must confirm before the breeding is recorded as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await BreedingMatchService.instance.confirmBreedingCompleted(
        widget.matchId,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to confirm completion. Please try again.'),
        ),
      );
    }
  }

  Future<void> _sendReminder() async {
    try {
      await BreedingMatchService.instance.sendCompletionReminder(
        widget.matchId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send the reminder.')),
      );
    }
  }

  Future<void> _decideRemoval(BuildContext context, bool remove) async {
    try {
      await BreedingMatchService.instance.decideOwnPetRemoval(
        matchId: widget.matchId,
        removeFromListings: remove,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update your pet listing. Please try again.'),
        ),
      );
    }
  }
}

class _CompletionProgress extends StatelessWidget {
  final Duration? remaining;
  final Duration total;
  final String label;

  const _CompletionProgress({
    required this.remaining,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final safeRemaining = remaining == null || remaining!.isNegative
        ? Duration.zero
        : remaining!;
    final progress = (safeRemaining.inSeconds / total.inSeconds).clamp(
      0.0,
      1.0,
    );
    final hours = safeRemaining.inHours;
    final minutes = safeRemaining.inMinutes.remainder(60);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${hours}h ${minutes}m',
              style: const TextStyle(color: Color(0xFF777777), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E5E5),
              color: const Color(0xFFF5A640),
            ),
          ),
        ),
      ],
    );
  }
}

class BreedingReviewScreen extends StatefulWidget {
  final String matchId;
  final String purpose;

  const BreedingReviewScreen({
    super.key,
    required this.matchId,
    this.purpose = 'breeding',
  });

  @override
  State<BreedingReviewScreen> createState() => _BreedingReviewScreenState();
}

class _BreedingReviewScreenState extends State<BreedingReviewScreen> {
  final _reviewController = TextEditingController();
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();
  final List<File> _photos = [];

  int _overall = 0;
  int _communication = 0;
  int _careResponsibility = 0;
  int _transparency = 0;
  int _reliability = 0;
  String _recommendation = 'Yes';
  bool _submitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 3) return;
    final selected = await _picker.pickMultiImage(imageQuality: 75);
    if (!mounted || selected.isEmpty) return;

    setState(() {
      final remaining = 3 - _photos.length;
      _photos.addAll(selected.take(remaining).map((image) => File(image.path)));
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if ([
      _overall,
      _communication,
      _careResponsibility,
      _transparency,
      _reliability,
    ].any((rating) => rating == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete every star rating.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final photoUrls = <String>[];
      for (var index = 0; index < _photos.length; index++) {
        final url = await _cloudinary.uploadImageOrThrow(_photos[index]);
        photoUrls.add(url);
      }

      if (widget.purpose == 'adoption') {
        await AdoptionService.instance.submitAdoptionReview(
          conversationId: widget.matchId,
          overall: _overall,
          communication: _communication,
          careResponsibility: _careResponsibility,
          transparency: _transparency,
          reliability: _reliability,
          recommendation: _recommendation,
          reviewText: _reviewController.text,
          photoUrls: photoUrls,
        );
      } else {
        await BreedingMatchService.instance.submitReview(
          matchId: widget.matchId,
          overall: _overall,
          communication: _communication,
          careResponsibility: _careResponsibility,
          transparency: _transparency,
          reliability: _reliability,
          recommendation: _recommendation,
          reviewText: _reviewController.text,
          photoUrls: photoUrls,
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Thank you!',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text('Your review has been submitted successfully.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error, stackTrace) {
      debugPrint(
        'Review submission failed for match ${widget.matchId}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_reviewErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _reviewErrorMessage(Object error) {
    if (error is CloudinaryUploadException) {
      if (error.statusCode == 400) {
        return 'One of the selected photos could not be uploaded. '
            'Please choose a JPG or PNG image and try again.';
      }
      return error.message;
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Your account is not permitted to submit this review yet. '
              'Reopen the completed transaction and try again.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Firebase is temporarily unavailable. Check your connection '
              'and try submitting again.';
        case 'already-exists':
          return 'You have already submitted a review for this transaction.';
      }
      return 'The review could not be saved (${error.code}). Please try again.';
    }
    if (error is StateError) {
      final message = error.message;
      if (message.isNotEmpty) return message;
    }
    if (error is AdoptionServiceException) {
      return error.message;
    }
    if (error is SocketException || error is TimeoutException) {
      return 'No internet connection was available. Please reconnect and '
          'submit the review again.';
    }
    return 'Something unexpected prevented the review from being submitted. '
        'Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Leave a Review',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          children: [
            const Text(
              'HOW WAS YOUR OVERALL EXPERIENCE?',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _StarRating(
                value: _overall,
                size: 42,
                onChanged: (value) => setState(() => _overall = value),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'RATE THEM ON THESE ASPECTS',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _AspectRating(
              label: 'Communication',
              value: _communication,
              onChanged: (value) => setState(() => _communication = value),
            ),
            _AspectRating(
              label: 'Care & Responsibility',
              value: _careResponsibility,
              onChanged: (value) => setState(() => _careResponsibility = value),
            ),
            _AspectRating(
              label: 'Transparency',
              value: _transparency,
              onChanged: (value) => setState(() => _transparency = value),
            ),
            _AspectRating(
              label: 'On-time & Reliability',
              value: _reliability,
              onChanged: (value) => setState(() => _reliability = value),
            ),
            const SizedBox(height: 22),
            const Text(
              'WOULD YOU RECOMMEND?',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Yes', label: Text('Yes')),
                ButtonSegment(value: 'Maybe', label: Text('Maybe')),
                ButtonSegment(value: 'No', label: Text('No')),
              ],
              selected: {_recommendation},
              onSelectionChanged: (selection) {
                setState(() => _recommendation = selection.first);
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'WRITE A REVIEW',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              minLines: 5,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Share details about your experience...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ADD PHOTOS (OPTIONAL)',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_photos.length}/3',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_photos.length < 3)
                    InkWell(
                      onTap: _pickPhotos,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFBBBBBB)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, size: 34),
                        ),
                      ),
                    ),
                  ...List.generate(_photos.length, (index) {
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 92,
                            height: 92,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: ColoredBox(
                                color: const Color(0xFFF0F0F0),
                                child: Image.file(
                                  _photos[index],
                                  width: 92,
                                  height: 92,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 3,
                          right: 13,
                          child: IconButton.filled(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                            onPressed: () =>
                                setState(() => _photos.removeAt(index)),
                            icon: const Icon(Icons.close, size: 15),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your review becomes public when both owners submit, or after seven days.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AspectRating extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _AspectRating({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          _StarRating(value: value, size: 25, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int value;
  final double size;
  final ValueChanged<int> onChanged;

  const _StarRating({
    required this.value,
    required this.size,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final rating = index + 1;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: size, height: size),
          onPressed: () => onChanged(rating),
          icon: Icon(
            rating <= value ? Icons.star : Icons.star_border,
            color: const Color(0xFFFFD83D),
            size: size * 0.82,
          ),
        );
      }),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String conversationId;
  final Map<String, dynamic> data;
  final bool mine;
  final Timestamp? createdAt;
  final bool showReceipt;
  final bool isRead;
  final ValueChanged<String> onRespondToUpdate;
  final ValueChanged<String> onConfirmUpdate;
  final ValueChanged<String> onRequestAnotherUpdate;

  const _MessageBubble({
    required this.messageId,
    required this.conversationId,
    required this.data,
    required this.mine,
    required this.createdAt,
    required this.showReceipt,
    required this.isRead,
    required this.onRespondToUpdate,
    required this.onConfirmUpdate,
    required this.onRequestAnotherUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'text';
    final text = data['text'] as String? ?? '';
    final card = switch (type) {
      'media' => _ChatMediaBubble(data: data, mine: mine),
      'adoption_update_request' => _AdoptionUpdateRequestBubble(
        conversationId: conversationId,
        data: data,
        mine: mine,
        onRespond: onRespondToUpdate,
      ),
      'adoption_update_response' => _AdoptionUpdateResponseBubble(
        conversationId: conversationId,
        data: data,
        mine: mine,
        onConfirm: onConfirmUpdate,
        onRequestAnother: onRequestAnotherUpdate,
        fallbackMessageId: messageId,
      ),
      'adoption_update_follow_up' => _AdoptionUpdateFollowUpBubble(
        messageId: messageId,
        conversationId: conversationId,
        data: data,
        mine: mine,
        onRespond: onRespondToUpdate,
      ),
      'adoption_return_request' => _AdoptionReturnRequestBubble(
        data: data,
        mine: mine,
      ),
      'adoption_return_decision' => _AdoptionReturnDecisionBubble(data: data),
      'adoption_return_handover' => _AdoptionInfoBubble(
        title: data['returnCompleted'] == true
            ? 'Pet return completed'
            : 'Return handover pending',
        message: text,
        mine: mine,
      ),
      _ => null,
    };

    final isSystemMessage = type == 'adoption_return_decision';

    return Align(
      alignment: isSystemMessage
          ? Alignment.center
          : mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isSystemMessage
            ? CrossAxisAlignment.center
            : mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          card ??
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: mine ? Colors.white : const Color(0xFF222222),
                  ),
                ),
              ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                createdAt == null
                    ? 'Sending...'
                    : _clockTime(createdAt!.toDate().toLocal()),
                style: const TextStyle(color: Color(0xFF888888), fontSize: 9),
              ),
              if (showReceipt) ...[
                const SizedBox(width: 5),
                Icon(
                  isRead ? Icons.done_all : Icons.done,
                  size: 13,
                  color: isRead
                      ? const Color(0xFF2398E8)
                      : const Color(0xFF999999),
                ),
                const SizedBox(width: 2),
                Text(
                  isRead ? 'Read' : 'Sent',
                  style: TextStyle(
                    color: isRead
                        ? const Color(0xFF2398E8)
                        : const Color(0xFF888888),
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChatMediaBubble extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool mine;

  const _ChatMediaBubble({required this.data, required this.mine});

  @override
  State<_ChatMediaBubble> createState() => _ChatMediaBubbleState();
}

class _ChatMediaBubbleState extends State<_ChatMediaBubble> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideo;

  @override
  void initState() {
    super.initState();
    final type = widget.data['mediaType'] as String?;
    final url = widget.data['mediaUrl'] as String? ?? '';
    if (type == 'video' && url.isNotEmpty) {
      final playbackUrl = CloudinaryService.compatibleVideoUrl(url);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(playbackUrl),
      );
      _videoController = controller;
      _initializeVideo = controller.initialize().then((_) {
        controller.addListener(_handleVideoChanged);
      });
    }
  }

  void _handleVideoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.removeListener(_handleVideoChanged);
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaType = widget.data['mediaType'] as String? ?? 'image';
    final url = widget.data['mediaUrl'] as String? ?? '';
    final caption = widget.data['text'] as String? ?? '';
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: widget.mine ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: mediaType == 'video'
                ? _buildVideo(url)
                : _buildImage(context, url),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                caption,
                style: TextStyle(
                  color: widget.mine ? Colors.white : const Color(0xFF222222),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () => showDialog<void>(
              context: context,
              barrierColor: Colors.black87,
              builder: (context) => Dialog.fullscreen(
                backgroundColor: Colors.black,
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        child: BreedrNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          fallback: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      child: BreedrNetworkImage(
        imageUrl: url,
        width: 245,
        height: 210,
        fit: BoxFit.cover,
        fallback: Container(
          width: 245,
          height: 160,
          color: const Color(0xFFFFE9EF),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _buildVideo(String url) {
    final controller = _videoController;
    final initialization = _initializeVideo;
    if (url.isEmpty || controller == null || initialization == null) {
      return _mediaError('Video unavailable');
    }
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _videoError(
            url,
            controller.value.errorDescription ?? 'Unable to load video',
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 245,
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final ratio = controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio;
        return SizedBox(
          width: 245,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(controller),
                Center(
                  child: IconButton.filled(
                    onPressed: () {
                      if (controller.value.position >=
                          controller.value.duration) {
                        controller.seekTo(Duration.zero);
                      }
                      controller.value.isPlaying
                          ? controller.pause()
                          : controller.play();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_rounded
                          : controller.value.position >=
                                controller.value.duration
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: Colors.white54,
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

  Widget _mediaError(String message) {
    return Container(
      width: 245,
      height: 150,
      color: const Color(0xFF333333),
      alignment: Alignment.center,
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _videoError(String originalUrl, String message) {
    return Container(
      width: 245,
      height: 170,
      color: const Color(0xFF333333),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 30),
          const SizedBox(height: 7),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(CloudinaryService.compatibleVideoUrl(originalUrl)),
              mode: LaunchMode.externalApplication,
            ),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Video'),
          ),
        ],
      ),
    );
  }
}

class _AdoptionUpdateRequestBubble extends StatelessWidget {
  final String conversationId;
  final Map<String, dynamic> data;
  final bool mine;
  final ValueChanged<String> onRespond;

  const _AdoptionUpdateRequestBubble({
    required this.conversationId,
    required this.data,
    required this.mine,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final updateRequestId = data['adoptionUpdateRequestId'] as String? ?? '';
    final text = data['text'] as String? ?? 'Please send a photo update.';
    if (updateRequestId.isEmpty) {
      return _buildContent(text: text, canRespond: false);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('adoptionUpdateRequests')
          .doc(updateRequestId)
          .snapshots(),
      builder: (context, snapshot) => _buildContent(
        text: text,
        canRespond: snapshot.data?.data()?['status'] == 'pending',
        updateRequestId: updateRequestId,
      ),
    );
  }

  Widget _buildContent({
    required String text,
    required bool canRespond,
    String updateRequestId = '',
  }) {
    return _AdoptionMessageCard(
      mine: mine,
      title: mine ? 'You requested an update' : 'Update requested',
      icon: Icons.photo_camera_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
          if (!mine && canRespond) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onRespond(updateRequestId),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Send Photo'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdoptionUpdateFollowUpBubble extends StatelessWidget {
  final String messageId;
  final String conversationId;
  final Map<String, dynamic> data;
  final bool mine;
  final ValueChanged<String> onRespond;

  const _AdoptionUpdateFollowUpBubble({
    required this.messageId,
    required this.conversationId,
    required this.data,
    required this.mine,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final updateRequestId = data['adoptionUpdateRequestId'] as String? ?? '';
    final message = data['text'] as String? ?? 'Please send another photo.';
    if (updateRequestId.isEmpty) {
      return _AdoptionInfoBubble(
        title: 'Another update requested',
        message: message,
        mine: mine,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('adoptionUpdateRequests')
          .doc(updateRequestId)
          .snapshots(),
      builder: (context, snapshot) {
        final updateData = snapshot.data?.data();
        final canRespond =
            updateData?['status'] == 'requested_again' &&
            updateData?['followUpMessageId'] == messageId;
        return _AdoptionMessageCard(
          mine: mine,
          title: 'Another update requested',
          icon: Icons.refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 12, height: 1.35)),
              if (!mine && canRespond) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => onRespond(updateRequestId),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Send Photo'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AdoptionUpdateResponseBubble extends StatelessWidget {
  final String conversationId;
  final Map<String, dynamic> data;
  final bool mine;
  final ValueChanged<String> onConfirm;
  final ValueChanged<String> onRequestAnother;
  final String fallbackMessageId;

  const _AdoptionUpdateResponseBubble({
    required this.conversationId,
    required this.data,
    required this.mine,
    required this.onConfirm,
    required this.onRequestAnother,
    required this.fallbackMessageId,
  });

  @override
  Widget build(BuildContext context) {
    final updateRequestId =
        data['adoptionUpdateRequestId'] as String? ?? fallbackMessageId;
    final photoUrl = data['photoUrl'] as String? ?? '';
    if (updateRequestId.isEmpty) {
      return _AdoptionUpdateResponseContent(
        photoUrl: photoUrl,
        mine: mine,
        requestStatus: data['requestStatus'] as String? ?? 'responded',
        onConfirm: null,
        onRequestAnother: null,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('adoptionUpdateRequests')
          .doc(updateRequestId)
          .snapshots(),
      builder: (context, snapshot) {
        final updateData = snapshot.data?.data();
        final storedStatus = updateData?['status'] as String? ?? 'loading';
        final currentResponseMessageId =
            updateData?['responseMessageId'] as String?;
        final isCurrentResponse =
            currentResponseMessageId == null ||
            currentResponseMessageId == fallbackMessageId;
        final requestStatus = isCurrentResponse ? storedStatus : 'superseded';
        return _AdoptionUpdateResponseContent(
          photoUrl: photoUrl,
          mine: mine,
          requestStatus: requestStatus,
          onConfirm: () => onConfirm(updateRequestId),
          onRequestAnother: () => onRequestAnother(updateRequestId),
        );
      },
    );
  }
}

class _AdoptionUpdateResponseContent extends StatelessWidget {
  final String photoUrl;
  final bool mine;
  final String requestStatus;
  final VoidCallback? onConfirm;
  final VoidCallback? onRequestAnother;

  const _AdoptionUpdateResponseContent({
    required this.photoUrl,
    required this.mine,
    required this.requestStatus,
    required this.onConfirm,
    required this.onRequestAnother,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirmed = requestStatus == 'confirmed';
    final isRequestedAgain = requestStatus == 'requested_again';
    final isSuperseded = requestStatus == 'superseded';
    final isLoading = requestStatus == 'loading';
    return _AdoptionMessageCard(
      mine: mine,
      title: mine ? 'Photo update sent' : 'Photo update received',
      icon: Icons.image_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BreedrNetworkImage(
                imageUrl: photoUrl,
                width: 170,
                height: 190,
                fit: BoxFit.cover,
                fallback: Container(
                  width: 170,
                  height: 140,
                  color: const Color(0xFFFFEEF3),
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          if (!mine && onConfirm != null && onRequestAnother != null) ...[
            const SizedBox(height: 10),
            if (isConfirmed)
              const _UpdateStatusNotice(
                icon: Icons.verified_rounded,
                text: 'Photo update confirmed.',
                color: Color(0xFF3FA34D),
              )
            else if (isRequestedAgain)
              const _UpdateStatusNotice(
                icon: Icons.refresh,
                text: 'Another photo has been requested.',
                color: AppColors.primary,
              )
            else if (isSuperseded)
              const _UpdateStatusNotice(
                icon: Icons.history,
                text: 'A newer photo update was received.',
                color: Color(0xFF777777),
              )
            else if (isLoading)
              const _UpdateStatusNotice(
                icon: Icons.sync,
                text: 'Checking photo update status...',
                color: Color(0xFF777777),
              )
            else ...[
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text("Confirm It's Them"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onRequestAnother,
                child: const Text('Request Another Photo'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UpdateStatusNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _UpdateStatusNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionReturnRequestBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool mine;

  const _AdoptionReturnRequestBubble({required this.data, required this.mine});

  @override
  Widget build(BuildContext context) {
    final reason = data['reason'] as String? ?? 'Return request';
    final description = data['description'] as String? ?? '';
    return _AdoptionMessageCard(
      mine: mine,
      title: mine ? 'You filed a return request' : 'Return request filed',
      icon: Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _AdoptionReturnDecisionBubble extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AdoptionReturnDecisionBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    final approved = data['returnDecision'] == 'approved';
    final rawMessage = data['text']?.toString().trim() ?? '';
    final message = rawMessage.isNotEmpty
        ? rawMessage
        : approved
        ? "Breedr approved this return request. Please coordinate the pet's safe return with the other party."
        : 'Breedr reviewed this return request. The adoption remains active.';
    final accent = approved ? const Color(0xFF269E61) : AppColors.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: approved ? const Color(0xFFE8F7EC) : const Color(0xFFFFECEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  approved
                      ? 'Return request approved'
                      : 'Return request denied',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF3D3D3D),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionInfoBubble extends StatelessWidget {
  final String title;
  final String message;
  final bool mine;

  const _AdoptionInfoBubble({
    required this.title,
    required this.message,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    return _AdoptionMessageCard(
      mine: mine,
      title: title,
      icon: Icons.info_outline,
      child: Text(message, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AdoptionMessageCard extends StatelessWidget {
  final bool mine;
  final String title;
  final IconData icon;
  final Widget child;

  const _AdoptionMessageCard({
    required this.mine,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFFFE1E8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RequestAnotherPhotoSheet extends StatelessWidget {
  const _RequestAnotherPhotoSheet();

  @override
  Widget build(BuildContext context) {
    const options = [
      ('Too blurry', "Can't see the pet clearly"),
      ('Too dark / hard to see', 'Lighting made it unclear'),
      ("Doesn't look like the pet", 'Just want to double check'),
      ('Just want another photo', 'No particular reason'),
      ('Please send another update when you can.', 'Custom general request'),
    ];
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Request Another Photo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                "This isn't a report. Let them know what wasn't quite right.",
                style: TextStyle(color: Color(0xFF666666)),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () =>
                        Navigator.pop(context, '${option.$1}: ${option.$2}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.$1,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            option.$2,
                            style: const TextStyle(color: Color(0xFF666666)),
                          ),
                        ],
                      ),
                    ),
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

class _MessageDateDivider extends StatelessWidget {
  final String label;

  const _MessageDateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFFFCDD5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFFFCDD5))),
        ],
      ),
    );
  }
}

class _ReadOnlyConversationNotice extends StatelessWidget {
  final String message;

  const _ReadOnlyConversationNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
        color: const Color(0xFFFFE8EE),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final String photoUrl;
  final String ownerId;
  final double size;
  final bool showPresence;

  const _ChatAvatar({
    required this.photoUrl,
    this.ownerId = '',
    this.size = 52,
    this.showPresence = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFDDE6),
              ),
              child: ClipOval(
                child: BreedrNetworkImage(
                  imageUrl: photoUrl,
                  fallback: const Icon(Icons.pets, color: AppColors.primary),
                ),
              ),
            ),
          ),
          if (showPresence && ownerId.isNotEmpty)
            Positioned(top: 0, right: 0, child: _PresenceDot(ownerId: ownerId)),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  final String ownerId;

  const _PresenceDot({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return _PresenceBuilder(
      ownerId: ownerId,
      builder: (context, presence) {
        if (!presence.isOnline) return const SizedBox.shrink();
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF28C840),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }
}

class _ActivityLabel extends StatelessWidget {
  final String ownerId;

  const _ActivityLabel({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return _PresenceBuilder(
      ownerId: ownerId,
      builder: (context, presence) {
        final label = presence.isOnline
            ? 'Active now'
            : presence.isRecent
            ? 'Active recently'
            : '';
        if (label.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              color: presence.isOnline
                  ? const Color(0xFF28A83C)
                  : const Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }
}

class _PresenceBuilder extends StatelessWidget {
  final String ownerId;
  final Widget Function(BuildContext context, _PresenceState presence) builder;

  const _PresenceBuilder({required this.ownerId, required this.builder});

  @override
  Widget build(BuildContext context) {
    final currentUserId = UserSessionService.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty || ownerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .snapshots(),
      builder: (context, viewerSnapshot) {
        final viewerAllowsActivity =
            viewerSnapshot.data?.data()?['showActivityStatus'] as bool? ?? true;
        if (!viewerAllowsActivity) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(ownerId)
              .snapshots(),
          builder: (context, ownerSnapshot) {
            final ownerAllowsActivity =
                ownerSnapshot.data?.data()?['showActivityStatus'] as bool? ??
                true;
            if (!ownerAllowsActivity) return const SizedBox.shrink();

            return StreamBuilder<DatabaseEvent>(
              stream: PresenceService.instance.watchPresence(ownerId),
              builder: (context, presenceSnapshot) {
                final rawValue = presenceSnapshot.data?.snapshot.value;
                if (rawValue is! Map) {
                  return builder(context, const _PresenceState());
                }

                final state = rawValue['state']?.toString() ?? 'offline';
                final visible = rawValue['visible'] != false;
                final timestamp = rawValue['lastChanged'];
                final lastChanged = timestamp is num
                    ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
                    : null;
                return builder(
                  context,
                  _PresenceState(
                    isOnline: visible && state == 'online',
                    isVisible: visible,
                    lastChanged: lastChanged,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PresenceState {
  final bool isOnline;
  final bool isVisible;
  final DateTime? lastChanged;

  const _PresenceState({
    this.isOnline = false,
    this.isVisible = true,
    this.lastChanged,
  });

  bool get isRecent {
    final changed = lastChanged;
    if (!isVisible || isOnline || changed == null) return false;
    return DateTime.now().difference(changed) < const Duration(hours: 1);
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, color: AppColors.primary, size: 56),
          SizedBox(height: 14),
          Text(
            'No listed pets yet.',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your breeding and adoption pets will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 56),
            SizedBox(height: 14),
            Text(
              'No matches yet.',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'A conversation will appear here after both pets like each other.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
