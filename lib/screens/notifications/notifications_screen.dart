import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../adoption/adoption_request_detail_screen.dart';
import '../adoption/owner_adoption_request_detail_screen.dart';
import '../chat/chats_screen.dart';

enum _NotificationFilter { all, breeding, adoption }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;

  Future<void> _markAsRead(
    DocumentReference<Map<String, dynamic>> reference,
  ) {
    return reference.set(
      {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _markAllAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> notifications,
  ) async {
    final unread = notifications
        .where((document) => document.data()['isRead'] != true)
        .toList();
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final document in unread) {
      batch.set(
        document.reference,
        {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> _openNotificationTarget(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await _markAsRead(document.reference);

    final data = document.data();
    final type = data['type'] as String? ?? '';
    if (type == 'breeding_like_received') return;

    final requestId = data['requestId'] as String?;
    final opensOwnerRequest = type == 'adoption_request_received';
    if (opensOwnerRequest && requestId != null && requestId.isNotEmpty) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerAdoptionRequestDetailScreen(
            requestId: requestId,
          ),
        ),
      );
      return;
    }

    final opensApplicantRequest = type == 'adoption_request_approved' ||
        type == 'adoption_request_rejected';
    if (opensApplicantRequest && requestId != null && requestId.isNotEmpty) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdoptionRequestDetailScreen(requestId: requestId),
        ),
      );
      return;
    }

    final matchId =
        data['matchId'] as String? ?? data['conversationId'] as String?;
    if (matchId == null || matchId.isEmpty) return;

    final conversation = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(matchId)
        .get();
    final conversationData = conversation.data();
    if (conversationData == null || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This conversation is no longer available.'),
        ),
      );
      return;
    }

    final userId = UserSessionService.instance.currentUser?.uid ?? '';
    final petOwners = Map<String, dynamic>.from(
      conversationData['petOwners'] as Map? ?? const {},
    );
    final petNames = Map<String, dynamic>.from(
      conversationData['petNames'] as Map? ?? const {},
    );
    final petPhotos = Map<String, dynamic>.from(
      conversationData['petPhotos'] as Map? ?? const {},
    );
    final participantIds =
        (conversationData['participantIds'] as List?)?.cast<String>() ??
            const <String>[];
    final purpose = conversationData['purpose'] as String? ?? 'breeding';
    final ownPetId = petOwners.entries
        .where((entry) => entry.value == userId)
        .map((entry) => entry.key)
        .firstOrNull;
    final otherPetId = purpose == 'adoption'
        ? petOwners.keys.firstOrNull
        : petOwners.keys.where((petId) => petId != ownPetId).firstOrNull;
    final otherOwnerId = purpose == 'adoption'
        ? participantIds.where((id) => id != userId).firstOrNull ?? ''
        : otherPetId == null
            ? ''
            : (petOwners[otherPetId] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          matchId: matchId,
          otherPetName: (otherPetId == null
                  ? petNames.values.firstOrNull
                  : petNames[otherPetId])
              ?.toString() ??
              (purpose == 'adoption' ? 'Adoption Chat' : 'Breeding Match'),
          otherPetPhoto: otherPetId == null
              ? ''
              : (petPhotos[otherPetId] as String? ?? ''),
          otherOwnerId: otherOwnerId,
          initiallyUnmatched: conversationData['status'] == 'unmatched',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) {
      return const SafeArea(
        child: Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          final preferences = Map<String, dynamic>.from(
            userSnapshot.data?.data()?['notificationPreferences'] as Map? ??
                const <String, dynamic>{},
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final notifications = snapshot.data?.docs.toList() ?? [];
          notifications.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });

          final visibleNotifications = notifications
              .where((document) => _matchesFilter(document.data()))
              .where((document) => _matchesPreferences(
                    document.data(),
                    preferences,
                  ))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'NOTIFICATIONS',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: visibleNotifications.isEmpty
                          ? null
                          : () => _markAllAsRead(visibleNotifications),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'MARK AS ALL READ',
                        style: TextStyle(
                          color: Color(0xFF444444),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All',
                      selected: _filter == _NotificationFilter.all,
                      onTap: () => setState(
                        () => _filter = _NotificationFilter.all,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _FilterPill(
                      label: 'Breeding',
                      selected: _filter == _NotificationFilter.breeding,
                      onTap: () => setState(
                        () => _filter = _NotificationFilter.breeding,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _FilterPill(
                      label: 'Adoption',
                      selected: _filter == _NotificationFilter.adoption,
                      onTap: () => setState(
                        () => _filter = _NotificationFilter.adoption,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFFFCDD5)),
              Expanded(
                child: visibleNotifications.isEmpty
                    ? _EmptyNotifications(filter: _filter)
                    : _NotificationList(
                        notifications: visibleNotifications,
                        onTap: (document) => _openNotificationTarget(
                          context,
                          document,
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

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_filter == _NotificationFilter.all) return true;
    final purpose = _purposeForNotification(data);
    return _filter == _NotificationFilter.breeding
        ? purpose == 'breeding'
        : purpose == 'adoption';
  }

  bool _matchesPreferences(
    Map<String, dynamic> data,
    Map<String, dynamic> preferences,
  ) {
    final key = _preferenceKeyForType(data['type'] as String? ?? '');
    if (key == null) return true;
    return preferences[key] as bool? ?? true;
  }
}

class _NotificationList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> notifications;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onTap;

  const _NotificationList({
    required this.notifications,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var lastGroup = '';
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 28),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final document = notifications[index];
        final data = document.data();
        final group = _groupLabel(data['createdAt'] as Timestamp?);
        final showGroup = group != lastGroup;
        lastGroup = group;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showGroup) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  top: index == 0 ? 0 : 18,
                  bottom: 10,
                ),
                child: Text(
                  group,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            _NotificationCard(
              data: data,
              onTap: () => onTap(document),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  String _groupLabel(Timestamp? timestamp) {
    if (timestamp == null) return 'Today';
    final date = timestamp.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return day == today ? 'Today' : 'Earlier Today';
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final purpose = _purposeForNotification(data);
    final isRead = data['isRead'] == true;
    final createdAt = data['createdAt'] as Timestamp?;
    final profile = _NotificationProfile.forType(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 9),
          decoration: BoxDecoration(
            color: isRead ? const Color(0xFFFFE4EA) : const Color(0xFFFFD9E2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF98AA), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NotificationAvatars(profile: profile, purpose: purpose),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] as String? ?? 'Breedr update',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 13,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data['message'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 9,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _PurposeChip(purpose: purpose),
                        const SizedBox(width: 7),
                        if (profile.actionLabel.isNotEmpty)
                          Flexible(
                            child: _ActionChip(
                              label: profile.actionLabel,
                              color: profile.actionColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isRead)
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: AppColors.primary,
                    ),
                  const SizedBox(height: 30),
                  Text(
                    _relativeTime(createdAt?.toDate()),
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 8,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationAvatars extends StatelessWidget {
  final _NotificationProfile profile;
  final String purpose;

  const _NotificationAvatars({
    required this.profile,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryIcon =
        purpose == 'adoption' ? Icons.home_outlined : Icons.favorite;
    return SizedBox(
      width: 76,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 5,
            child: _IconAvatar(
              icon: profile.icon,
              background: Colors.white,
              iconColor: AppColors.primary,
              size: 50,
            ),
          ),
          Positioned(
            left: 32,
            top: 5,
            child: _IconAvatar(
              icon: purpose == 'adoption' ? Icons.pets : Icons.pets,
              background: const Color(0xFFE5F7E5),
              iconColor: const Color(0xFF37A344),
              size: 50,
            ),
          ),
          Positioned(
            left: 48,
            top: 31,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: purpose == 'adoption'
                    ? const Color(0xFF2D8CFF)
                    : AppColors.primary,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(secondaryIcon, color: Colors.white, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAvatar extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final double size;

  const _IconAvatar({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}

class _PurposeChip extends StatelessWidget {
  final String purpose;

  const _PurposeChip({required this.purpose});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAF0),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF222222), width: 0.8),
      ),
      child: Text(
        purpose == 'adoption' ? 'Adoption' : 'Breeding',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ActionChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE2E9) : const Color(0xFFFFDDE6),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: const Color(0xFF111111), width: 2)
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final _NotificationFilter filter;

  const _EmptyNotifications({required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _NotificationFilter.breeding => 'breeding',
      _NotificationFilter.adoption => 'adoption',
      _ => '',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none,
              color: AppColors.primary,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              label.isEmpty
                  ? 'No notifications yet.'
                  : 'No $label notifications yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Updates about your pets, requests, and matches will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationProfile {
  final IconData icon;
  final String actionLabel;
  final Color actionColor;

  const _NotificationProfile({
    required this.icon,
    required this.actionLabel,
    required this.actionColor,
  });

  static _NotificationProfile forType(String type) {
    if (type == 'adoption_request_received') {
      return const _NotificationProfile(
        icon: Icons.question_answer_outlined,
        actionLabel: 'REVIEW NOW',
        actionColor: Color(0xFF2389E8),
      );
    }
    if (type == 'adoption_request_approved') {
      return const _NotificationProfile(
        icon: Icons.person_outline,
        actionLabel: 'OPEN CHAT',
        actionColor: AppColors.primary,
      );
    }
    if (type.startsWith('adoption_process')) {
      return const _NotificationProfile(
        icon: Icons.description_outlined,
        actionLabel: 'VIEW PROCESS',
        actionColor: Color(0xFF2389E8),
      );
    }
    if (type == 'adoption_ready_to_complete') {
      return const _NotificationProfile(
        icon: Icons.check_circle_outline,
        actionLabel: 'COMPLETE',
        actionColor: AppColors.primary,
      );
    }
    if (type.startsWith('adoption_update')) {
      return const _NotificationProfile(
        icon: Icons.photo_camera_outlined,
        actionLabel: 'OPEN CHAT',
        actionColor: AppColors.primary,
      );
    }
    if (type == 'adoption_return_requested') {
      return const _NotificationProfile(
        icon: Icons.warning_amber_rounded,
        actionLabel: 'OPEN CHAT',
        actionColor: AppColors.primary,
      );
    }
    if (type == 'adoption_return_decision') {
      return const _NotificationProfile(
        icon: Icons.gavel_outlined,
        actionLabel: 'OPEN CHAT',
        actionColor: AppColors.primary,
      );
    }
    if (type.contains('completion') || type.contains('completed')) {
      return const _NotificationProfile(
        icon: Icons.check_circle_outline,
        actionLabel: 'CONFIRM',
        actionColor: AppColors.primary,
      );
    }
    if (type == 'match_ended') {
      return const _NotificationProfile(
        icon: Icons.heart_broken_outlined,
        actionLabel: '',
        actionColor: AppColors.primary,
      );
    }
    if (type == 'breeding_like_received') {
      return const _NotificationProfile(
        icon: Icons.favorite_outline,
        actionLabel: '',
        actionColor: AppColors.primary,
      );
    }
    return const _NotificationProfile(
      icon: Icons.pets,
      actionLabel: 'OPEN CHAT',
      actionColor: AppColors.primary,
    );
  }
}

String _purposeForType(String type) {
  if (type.startsWith('adoption')) return 'adoption';
  return 'breeding';
}

String _purposeForNotification(Map<String, dynamic> data) {
  final purpose = (data['purpose'] as String?)?.trim().toLowerCase();
  if (purpose == 'adoption' || purpose == 'breeding') return purpose!;
  return _purposeForType(data['type'] as String? ?? '');
}

String? _preferenceKeyForType(String type) {
  if (type == 'breeding_like_received' ||
      type == 'breeding_match_created' ||
      type.startsWith('breeding_completion') ||
      type == 'breeding_completed' ||
      type == 'breeding_auto_completed' ||
      type == 'match_ended') {
    return 'breedingLikes';
  }
  if (type.startsWith('adoption_request')) {
    return 'adoptionRequests';
  }
  if (type == 'adoption_process_contract_started') {
    return 'contractUpdates';
  }
  if (type.startsWith('adoption_process') ||
      type == 'adoption_ready_to_complete' ||
      type.startsWith('adoption_update') ||
      type == 'adoption_return_requested' ||
      type == 'adoption_return_decision') {
    return 'adoptionUpdates';
  }
  if (type == 'new_message') {
    return 'newMessages';
  }
  if (type.startsWith('pet_health')) {
    return 'petHealth';
  }
  if (type.startsWith('review')) {
    return 'reviewsReceived';
  }
  return null;
}

String _relativeTime(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inMinutes < 1) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes} mins';
  if (difference.inDays < 1) return '${difference.inHours} hours ago';
  return '${difference.inDays} days ago';
}
