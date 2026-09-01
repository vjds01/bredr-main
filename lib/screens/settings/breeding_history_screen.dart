import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../chat/chats_screen.dart';

class BreedingHistoryScreen extends StatelessWidget {
  const BreedingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Breeding History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: userId == null
          ? const _HistoryState(
              icon: Icons.lock_outline,
              title: 'Please sign in again',
              body: 'Your completed breeding matches will appear here.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('breedingTransactions')
                  .where('ownerIds', arrayContains: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _HistoryState(
                    icon: Icons.error_outline,
                    title: 'History could not be loaded',
                    body: 'Check your connection and try again.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                final transactions =
                    snapshot.data!.docs
                        .map(
                          (doc) =>
                              _BreedingTransaction.fromDocument(doc, userId),
                        )
                        .toList()
                      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
                if (transactions.isEmpty) {
                  return const _HistoryState(
                    icon: Icons.favorite_border,
                    title: 'No breeding history yet',
                    body:
                        'Matches will appear here after the breeding transaction is completed.',
                  );
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('reviewerId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, reviewSnapshot) {
                    final reviewsByMatch = <String, Map<String, dynamic>>{};
                    for (final document
                        in reviewSnapshot.data?.docs ??
                            const <
                              QueryDocumentSnapshot<Map<String, dynamic>>
                            >[]) {
                      final review = document.data();
                      final matchId = review['matchId']?.toString() ?? '';
                      if (matchId.isNotEmpty) reviewsByMatch[matchId] = review;
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        const Text(
                          'A permanent record of your completed breeding matches.',
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...transactions.map(
                          (transaction) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _HistoryCard(
                              transaction: transaction,
                              reviewData: reviewsByMatch[transaction.matchId],
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

class _HistoryCard extends StatelessWidget {
  final _BreedingTransaction transaction;
  final Map<String, dynamic>? reviewData;

  const _HistoryCard({required this.transaction, required this.reviewData});

  @override
  Widget build(BuildContext context) {
    final reviewed = reviewData != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCDD5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12FE5062),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
            color: const Color(0xFFFFF0F4),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.primary, size: 18),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Breeding completed',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  transaction.formattedDate,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _PetAvatar(photo: transaction.ownPetPhoto, size: 58),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: AppColors.primary,
                            size: 19,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            transaction.completionLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PetAvatar(photo: transaction.otherPetPhoto, size: 58),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.ownPetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Text(
                        transaction.otherPetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Color(0xFFFFE1E8)),
                Row(
                  children: [
                    _PetAvatar(
                      photo: transaction.otherOwnerPhoto,
                      size: 34,
                      person: true,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Matched with',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            transaction.otherOwnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: reviewed
                            ? const Color(0xFFE4F7E8)
                            : const Color(0xFFFFF1D8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        reviewed ? 'Reviewed' : 'Review available',
                        style: TextStyle(
                          color: reviewed
                              ? const Color(0xFF2FA756)
                              : const Color(0xFFC58A23),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatConversationScreen(
                              matchId: transaction.matchId,
                              otherPetName: transaction.otherPetName,
                              otherPetPhoto: transaction.otherPetPhoto,
                              otherOwnerId: transaction.otherOwnerId,
                              otherParticipantLabel: transaction.otherOwnerName,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 17),
                        label: const Text('View Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: reviewed
                            ? () => _showSubmittedReview(context, reviewData)
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BreedingReviewScreen(
                                    matchId: transaction.matchId,
                                  ),
                                ),
                              ),
                        icon: Icon(
                          reviewed
                              ? Icons.visibility_outlined
                              : Icons.rate_review_outlined,
                          size: 17,
                        ),
                        label: Text(reviewed ? 'View Review' : 'Leave Review'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
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
    );
  }
}

void _showSubmittedReview(BuildContext context, Map<String, dynamic>? data) {
  final rating = ((data?['overall'] as num?)?.round() ?? 0).clamp(0, 5);
  final text = data?['reviewText']?.toString().trim() ?? '';
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFFFF7FA),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Review',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFD83D),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text.isEmpty ? 'No written feedback provided.' : text,
              style: const TextStyle(color: Color(0xFF555555), height: 1.45),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BreedingTransaction {
  final String matchId;
  final String ownPetName;
  final String ownPetPhoto;
  final String otherPetName;
  final String otherPetPhoto;
  final String otherOwnerId;
  final String otherOwnerName;
  final String otherOwnerPhoto;
  final String completionType;
  final DateTime completedAt;

  const _BreedingTransaction({
    required this.matchId,
    required this.ownPetName,
    required this.ownPetPhoto,
    required this.otherPetName,
    required this.otherPetPhoto,
    required this.otherOwnerId,
    required this.otherOwnerName,
    required this.otherOwnerPhoto,
    required this.completionType,
    required this.completedAt,
  });

  factory _BreedingTransaction.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String currentUserId,
  ) {
    final data = document.data();
    final owners =
        (data['ownerIds'] as List?)?.map((item) => item.toString()).toList() ??
        const <String>[];
    final pets =
        (data['petIds'] as List?)?.map((item) => item.toString()).toList() ??
        const <String>[];
    final petOwners = Map<String, dynamic>.from(
      data['petOwners'] as Map? ?? const {},
    );
    final petNames = Map<String, dynamic>.from(
      data['petNames'] as Map? ?? const {},
    );
    final petPhotos = Map<String, dynamic>.from(
      data['petPhotos'] as Map? ?? const {},
    );
    final petSnapshots = Map<String, dynamic>.from(
      data['petSnapshots'] as Map? ?? const {},
    );
    final ownerSnapshots = Map<String, dynamic>.from(
      data['ownerSnapshots'] as Map? ?? const {},
    );
    final ownPetId =
        pets.where((id) => petOwners[id] == currentUserId).firstOrNull ??
        (pets.isNotEmpty ? pets.first : '');
    final otherPetId = pets.where((id) => id != ownPetId).firstOrNull ?? '';
    final otherOwnerId =
        owners.where((id) => id != currentUserId).firstOrNull ?? '';
    final ownPet = Map<String, dynamic>.from(
      petSnapshots[ownPetId] as Map? ?? const {},
    );
    final otherPet = Map<String, dynamic>.from(
      petSnapshots[otherPetId] as Map? ?? const {},
    );
    final otherOwner = Map<String, dynamic>.from(
      ownerSnapshots[otherOwnerId] as Map? ?? const {},
    );
    String value(dynamic primary, dynamic fallback, String defaultValue) {
      final first = primary?.toString().trim() ?? '';
      if (first.isNotEmpty) return first;
      final second = fallback?.toString().trim() ?? '';
      return second.isNotEmpty ? second : defaultValue;
    }

    return _BreedingTransaction(
      matchId: data['matchId']?.toString() ?? document.id,
      ownPetName: value(ownPet['name'], petNames[ownPetId], 'Your pet'),
      ownPetPhoto: value(ownPet['petProfilePhoto'], petPhotos[ownPetId], ''),
      otherPetName: value(otherPet['name'], petNames[otherPetId], 'Pet'),
      otherPetPhoto: value(
        otherPet['petProfilePhoto'],
        petPhotos[otherPetId],
        '',
      ),
      otherOwnerId: otherOwnerId,
      otherOwnerName: value(otherOwner['fullName'], null, 'Breedr owner'),
      otherOwnerPhoto: value(otherOwner['profilePhoto'], null, ''),
      completionType: data['completionType']?.toString() ?? 'confirmed',
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get completionLabel => completionType == 'auto_completed'
      ? 'Auto-completed'
      : 'Both owners confirmed';

  String get formattedDate => _formatDate(completedAt);
}

class _PetAvatar extends StatelessWidget {
  final String photo;
  final double size;
  final bool person;

  const _PetAvatar({
    required this.photo,
    required this.size,
    this.person = false,
  });

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Container(
      width: size,
      height: size,
      color: const Color(0xFFFFE1E8),
      child: BreedrNetworkImage(
        imageUrl: photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: Icon(
          person ? Icons.person : Icons.pets,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

class _HistoryState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HistoryState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFCDD5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 38),
            const SizedBox(height: 11),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
