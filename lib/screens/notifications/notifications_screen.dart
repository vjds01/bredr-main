import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/user_session_service.dart';
import '../../services/realtime_notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../adoption/adoption_request_detail_screen.dart';
import '../adoption/owner_adoption_request_detail_screen.dart';
import '../breeding/breeding_likes_screen.dart';
import '../chat/chats_screen.dart';
import '../pet/health_vault_screen.dart';

enum _NotificationFilter { all, breeding, adoption }

class NotificationsScreen extends StatefulWidget {
  final ValueListenable<int>? activationSignal;

  const NotificationsScreen({super.key, this.activationSignal});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;
  bool _openingBreedingLike = false;
  bool _openingLocalNotification = false;

  @override
  void initState() {
    super.initState();
    widget.activationSignal?.addListener(_openPendingLocalNotification);
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationSignal == widget.activationSignal) return;
    oldWidget.activationSignal?.removeListener(_openPendingLocalNotification);
    widget.activationSignal?.addListener(_openPendingLocalNotification);
  }

  @override
  void dispose() {
    widget.activationSignal?.removeListener(_openPendingLocalNotification);
    super.dispose();
  }

  Future<void> _openPendingLocalNotification() async {
    if (!mounted || _openingLocalNotification) return;
    _openingLocalNotification = true;
    // Let Android finish resuming the activity and let Home select the
    // Notifications tab before pushing the destination route.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      _openingLocalNotification = false;
      return;
    }
    final notificationId = RealtimeNotificationService.instance
        .consumeTappedNotificationId();
    if (notificationId == null || notificationId.isEmpty) {
      _openingLocalNotification = false;
      return;
    }
    try {
      final document = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .get();
      if (!mounted || !document.exists) return;
      await _openNotificationTarget(context, document);
      await RealtimeNotificationService.instance.clearPendingTap();
    } catch (error) {
      debugPrint('Unable to open local notification: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this notification.')),
        );
      }
    } finally {
      _openingLocalNotification = false;
    }
  }

  Future<void> _markAsRead(DocumentReference<Map<String, dynamic>> reference) {
    return reference.set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      batch.set(document.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _openNotificationTarget(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await _markAsRead(document.reference);
    if (!context.mounted) return;

    final data = document.data() ?? const <String, dynamic>{};
    final type = data['type'] as String? ?? '';
    if (type.startsWith('health_record_')) {
      final petId = data['petId']?.toString() ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HealthVaultScreen(initialPetId: petId.isEmpty ? null : petId),
        ),
      );
      return;
    }

    if (type == 'breeding_like_received') {
      await _openBreedingLikeNotification(context, data);
      return;
    }

    final requestId = data['requestId'] as String?;
    final opensOwnerRequest = type == 'adoption_request_received';
    if (opensOwnerRequest && requestId != null && requestId.isNotEmpty) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OwnerAdoptionRequestDetailScreen(requestId: requestId),
        ),
      );
      return;
    }

    final opensApplicantRequest =
        type == 'adoption_request_approved' ||
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
    if (!context.mounted) return;
    if (conversationData == null) {
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
          otherPetName:
              (otherPetId == null
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

  Future<void> _openBreedingLikeNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    if (_openingBreedingLike) return;
    _openingBreedingLike = true;
    try {
      final userId = UserSessionService.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        _showUnavailableLike(
          context,
          'Please sign in again to view this like.',
        );
        return;
      }

      final candidateIds = <String>{
        _notificationText(data['petId'], ''),
        _notificationText(data['secondaryPetId'], ''),
        ...(data['petIds'] as List? ?? const []).map(
          (value) => value.toString().trim(),
        ),
      }..removeWhere((id) => id.isEmpty);
      if (candidateIds.length < 2) {
        _showUnavailableLike(context, 'This like is no longer available.');
        return;
      }

      final petDocuments = await Future.wait(
        candidateIds.map(
          (id) => FirebaseFirestore.instance.collection('pets').doc(id).get(),
        ),
      );
      if (!context.mounted) return;

      final currentPet = petDocuments
          .where(
            (document) =>
                document.exists &&
                document.data()?['ownerId']?.toString() == userId,
          )
          .firstOrNull;
      final preferredLikedPetId = _notificationText(data['petId'], '');
      final likedPet =
          petDocuments
              .where(
                (document) =>
                    document.exists &&
                    document.id != currentPet?.id &&
                    document.data()?['ownerId']?.toString() != userId,
              )
              .where(
                (document) =>
                    preferredLikedPetId.isEmpty ||
                    document.id == preferredLikedPetId,
              )
              .firstOrNull ??
          petDocuments
              .where(
                (document) =>
                    document.exists &&
                    document.id != currentPet?.id &&
                    document.data()?['ownerId']?.toString() != userId,
              )
              .firstOrNull;

      if (currentPet == null ||
          likedPet == null ||
          !_isAvailableBreedingPet(likedPet.data())) {
        _showUnavailableLike(context, 'This like is no longer available.');
        return;
      }

      final response = await FirebaseFirestore.instance
          .collection('swipes')
          .doc('${currentPet.id}_${likedPet.id}')
          .get();
      if (!context.mounted) return;
      if (response.exists) {
        _showUnavailableLike(
          context,
          'You have already responded to this like.',
        );
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => BreedingLikeProfileScreen(
            currentPetId: currentPet.id,
            likedPetId: likedPet.id,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _showUnavailableLike(
          context,
          'Unable to open this like. Please try again.',
        );
      }
    } finally {
      _openingBreedingLike = false;
    }
  }

  void _showUnavailableLike(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isAvailableBreedingPet(Map<String, dynamic>? data) {
    if (data == null) return false;
    final purpose = data['purpose']?.toString().trim().toLowerCase() ?? '';
    final status = data['status']?.toString().trim().toLowerCase() ?? '';
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
                return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                  aTime?.millisecondsSinceEpoch ?? 0,
                );
              });

              final visibleNotifications = notifications
                  .where((document) => _matchesFilter(document.data()))
                  .where(
                    (document) =>
                        _matchesPreferences(document.data(), preferences),
                  )
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
                          onTap: () =>
                              setState(() => _filter = _NotificationFilter.all),
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
                            onTap: (document) =>
                                _openNotificationTarget(context, document),
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
    final key = notificationPreferenceKeyForType(data['type'] as String? ?? '');
    if (key == null) return true;
    return preferences[key] as bool? ?? true;
  }
}

class _NotificationList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> notifications;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onTap;

  const _NotificationList({required this.notifications, required this.onTap});

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
              key: ValueKey(document.id),
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

class _NotificationCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotificationCard({super.key, required this.data, required this.onTap});

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  late final Future<_ResolvedNotification> _resolution;

  @override
  void initState() {
    super.initState();
    _resolution = _resolveNotification(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedNotification>(
      future: _resolution,
      builder: (context, snapshot) {
        return _buildCard(
          snapshot.data ?? _ResolvedNotification.from(widget.data),
        );
      },
    );
  }

  Widget _buildCard(_ResolvedNotification resolved) {
    final data = widget.data;
    final type = data['type'] as String? ?? '';
    final purpose = _purposeForNotification(data);
    final isRead = data['isRead'] == true;
    final createdAt = data['createdAt'] as Timestamp?;
    final profile = _NotificationProfile.forType(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
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
              _NotificationAvatars(
                profile: profile,
                purpose: purpose,
                resolved: resolved,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolved.title,
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
                      resolved.details,
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
  final _ResolvedNotification resolved;

  const _NotificationAvatars({
    required this.profile,
    required this.purpose,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryIcon = switch (purpose) {
      'adoption' => Icons.home_outlined,
      'health' => Icons.health_and_safety_outlined,
      _ => Icons.favorite,
    };
    final secondaryColor = switch (purpose) {
      'adoption' || 'health' => const Color(0xFF2D8CFF),
      _ => AppColors.primary,
    };
    return SizedBox(
      width: 76,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 5,
            child: _NotificationPhoto(
              url: resolved.actorPhoto,
              fallbackIcon: profile.icon,
              size: 50,
            ),
          ),
          Positioned(
            left: 32,
            top: 5,
            child: _NotificationPhoto(
              url: resolved.petPhoto,
              fallbackIcon: Icons.pets,
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
                color: secondaryColor,
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

class _NotificationPhoto extends StatelessWidget {
  final String url;
  final IconData fallbackIcon;
  final double size;

  const _NotificationPhoto({
    required this.url,
    required this.fallbackIcon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: BreedrNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: Icon(fallbackIcon, color: AppColors.primary, size: size * .5),
      ),
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
        switch (purpose) {
          'adoption' => 'Adoption',
          'health' => 'Health',
          _ => 'Breeding',
        },
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

  const _ActionChip({required this.label, required this.color});

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

final Map<String, Future<Map<String, dynamic>?>> _notificationDocumentCache =
    <String, Future<Map<String, dynamic>?>>{};

Future<Map<String, dynamic>?> _notificationDocument(
  String collection,
  String id,
) {
  if (id.isEmpty) return Future.value(null);
  final key = '$collection/$id';
  return _notificationDocumentCache.putIfAbsent(
    key,
    () async =>
        (await FirebaseFirestore.instance.collection(collection).doc(id).get())
            .data(),
  );
}

class _ResolvedNotification {
  final String title;
  final String details;
  final String actorPhoto;
  final String petPhoto;

  const _ResolvedNotification({
    required this.title,
    required this.details,
    required this.actorPhoto,
    required this.petPhoto,
  });

  factory _ResolvedNotification.from(Map<String, dynamic> data) {
    return _ResolvedNotification(
      title: _notificationText(data['title'], 'Breedr update'),
      details: _notificationText(data['message'], ''),
      actorPhoto: _notificationText(data['actorPhoto'], ''),
      petPhoto: _notificationText(data['petPhoto'], ''),
    );
  }
}

Future<_ResolvedNotification> _resolveNotification(
  Map<String, dynamic> data,
) async {
  final type = _notificationText(data['type'], '');
  final recipientId = _notificationText(data['recipientId'], '');
  var actorId = _notificationText(data['actorId'], '');
  var actorName = _notificationText(data['actorName'], '');
  var actorPhoto = _notificationText(data['actorPhoto'], '');
  var petName = _notificationText(data['petName'], '');
  var petPhoto = _notificationText(data['petPhoto'], '');
  Map<String, dynamic>? petData;

  if (type.startsWith('health_record_')) {
    final petId = _notificationText(data['petId'], '');
    petData = await _notificationDocument('pets', petId);
    petName = petName.isNotEmpty
        ? petName
        : _firstNotificationText(petData, const ['name', 'petName']);
    petPhoto = petPhoto.isNotEmpty
        ? petPhoto
        : _firstNotificationText(petData, const [
            'petProfilePhoto',
            'profilePhoto',
            'photoUrl',
          ]);
  }

  final conversationId = _notificationText(
    data['conversationId'] ?? data['matchId'],
    '',
  );
  final conversation = await _notificationDocument(
    'conversations',
    conversationId,
  );
  if (conversation != null) {
    final participants = (conversation['participantIds'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    if (actorId.isEmpty) {
      actorId = participants.where((id) => id != recipientId).firstOrNull ?? '';
    }
    final owners = Map<String, dynamic>.from(
      conversation['petOwners'] as Map? ?? const {},
    );
    final names = Map<String, dynamic>.from(
      conversation['petNames'] as Map? ?? const {},
    );
    final photos = Map<String, dynamic>.from(
      conversation['petPhotos'] as Map? ?? const {},
    );
    final actorPetId = owners.entries
        .where((entry) => entry.value?.toString() == actorId)
        .map((entry) => entry.key)
        .firstOrNull;
    final relevantPetId = actorPetId ?? owners.keys.firstOrNull;
    if (relevantPetId != null) {
      petName = petName.isNotEmpty
          ? petName
          : _notificationText(names[relevantPetId], '');
      petPhoto = petPhoto.isNotEmpty
          ? petPhoto
          : _notificationText(photos[relevantPetId], '');
      petData = await _notificationDocument('pets', relevantPetId);
    }
  }

  final requestId = _notificationText(data['requestId'], '');
  if (requestId.isNotEmpty && (actorId.isEmpty || petPhoto.isEmpty)) {
    final request = await _notificationDocument('adoptionRequests', requestId);
    if (request != null) {
      final ownerId = _notificationText(request['ownerId'], '');
      final applicantId = _notificationText(request['applicantId'], '');
      actorId = actorId.isNotEmpty
          ? actorId
          : recipientId == ownerId
          ? applicantId
          : ownerId;
      final pet = Map<String, dynamic>.from(
        request['petSnapshot'] as Map? ?? const {},
      );
      final applicant = Map<String, dynamic>.from(
        request['applicantSnapshot'] as Map? ?? const {},
      );
      petData ??= pet;
      petName = petName.isNotEmpty
          ? petName
          : _notificationText(pet['name'], '');
      petPhoto = petPhoto.isNotEmpty
          ? petPhoto
          : _firstNotificationText(pet, const [
              'petProfilePhoto',
              'profilePhoto',
            ]);
      if (actorId == applicantId) {
        actorName = actorName.isNotEmpty
            ? actorName
            : _firstNotificationText(applicant, const ['fullName', 'name']);
        actorPhoto = actorPhoto.isNotEmpty
            ? actorPhoto
            : _firstNotificationText(applicant, const [
                'profilePhoto',
                'photoURL',
              ]);
      }
    }
  }

  final petIds = (data['petIds'] as List? ?? const [])
      .map((value) => value.toString())
      .where((value) => value.isNotEmpty)
      .toList();
  if (petData == null && petIds.isNotEmpty) {
    petData = await _notificationDocument('pets', petIds.first);
    petName = petName.isNotEmpty
        ? petName
        : _firstNotificationText(petData, const ['name', 'petName']);
    petPhoto = petPhoto.isNotEmpty
        ? petPhoto
        : _firstNotificationText(petData, const [
            'petProfilePhoto',
            'profilePhoto',
            'photoUrl',
          ]);
    actorId = actorId.isNotEmpty
        ? actorId
        : _firstNotificationText(petData, const ['ownerId', 'userId']);
  }

  final actor = await _notificationDocument('users', actorId);
  actorName = actorName.isNotEmpty
      ? actorName
      : _firstNotificationText(actor, const [
          'fullName',
          'name',
          'displayName',
          'userName',
          'username',
        ]);
  actorPhoto = actorPhoto.isNotEmpty
      ? actorPhoto
      : _firstNotificationText(actor, const [
          'profilePhoto',
          'photoURL',
          'photoUrl',
        ]);
  petName = petName.isNotEmpty
      ? petName
      : _firstNotificationText(petData, const ['name', 'petName']);
  petPhoto = petPhoto.isNotEmpty
      ? petPhoto
      : _firstNotificationText(petData, const [
          'petProfilePhoto',
          'profilePhoto',
          'photoUrl',
        ]);

  var title = _notificationText(data['title'], 'Breedr update');
  var details = _notificationText(data['message'], '');
  if (type == 'new_message') {
    final message = details.toLowerCase();
    final kind = message.contains('video')
        ? 'a video'
        : message.contains('photo')
        ? 'a photo'
        : 'a message';
    title = actorName.isEmpty
        ? 'New message${petName.isEmpty ? '' : ' about $petName'}'
        : '$actorName sent you $kind${petName.isEmpty ? '' : ' about $petName'}';
    details = [
      _firstNotificationText(petData, const ['breed', 'primaryBreed']),
      _notificationText(petData?['age'], ''),
      _notificationText(petData?['gender'], ''),
      _firstNotificationText(petData, const ['locationName', 'location']),
    ].where((value) => value.isNotEmpty).join(' • ');
    if (details.isEmpty) details = _notificationText(data['message'], '');
  }

  return _ResolvedNotification(
    title: title,
    details: details,
    actorPhoto: actorPhoto,
    petPhoto: petPhoto,
  );
}

String _notificationText(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _firstNotificationText(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return '';
  for (final key in keys) {
    final value = _notificationText(data[key], '');
    if (value.isNotEmpty) return value;
  }
  return '';
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
    if (type.startsWith('health_record_')) {
      return const _NotificationProfile(
        icon: Icons.health_and_safety_outlined,
        actionLabel: 'VIEW RECORD',
        actionColor: Color(0xFF2389E8),
      );
    }
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
  if (type.startsWith('health_record_') || type.startsWith('pet_health')) {
    return 'health';
  }
  return 'breeding';
}

String _purposeForNotification(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';
  if (type.startsWith('adoption')) return 'adoption';
  if (type.startsWith('health_record_') || type.startsWith('pet_health')) {
    return 'health';
  }
  if (type.startsWith('breeding') || type == 'match_ended') {
    return 'breeding';
  }
  final purpose = (data['purpose'] as String?)?.trim().toLowerCase();
  if (purpose == 'adoption' || purpose == 'breeding' || purpose == 'health') {
    return purpose!;
  }
  return _purposeForType(type);
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
