import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_session_service.dart';

class BreedingMatchService {
  BreedingMatchService._();

  static final BreedingMatchService instance = BreedingMatchService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String swipeId(String swiperPetId, String targetPetId) {
    return '${swiperPetId}_$targetPetId';
  }

  String matchId(String petAId, String petBId) {
    final ids = [petAId, petBId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<Set<String>> watchSwipedPetIds(String swiperPetId) {
    return _firestore
        .collection('swipes')
        .where('swiperPetId', isEqualTo: swiperPetId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => document.data()['targetPetId'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }

  Future<SwipeResult> recordSwipe({
    required String swiperPetId,
    required String swiperPetName,
    required String swiperPetPhoto,
    required String swiperOwnerId,
    required String targetPetId,
    required String targetPetName,
    required String targetPetPhoto,
    required String targetOwnerId,
    required bool liked,
  }) async {
    final swipeReference =
        _firestore.collection('swipes').doc(swipeId(swiperPetId, targetPetId));
    final reverseReference =
        _firestore.collection('swipes').doc(swipeId(targetPetId, swiperPetId));
    final resolvedMatchId = matchId(swiperPetId, targetPetId);
    final matchReference =
        _firestore.collection('matches').doc(resolvedMatchId);
    final conversationReference =
        _firestore.collection('conversations').doc(resolvedMatchId);
    final likeNotificationReference =
        _firestore.collection('notifications').doc();
    final swiperMatchNotificationReference =
        _firestore.collection('notifications').doc();
    final targetMatchNotificationReference =
        _firestore.collection('notifications').doc();

    var matched = false;

    await _firestore.runTransaction((transaction) async {
      final existingMatch = await transaction.get(matchReference);
      if (existingMatch.data()?['status'] == 'unmatched') {
        throw StateError('These pets were permanently unmatched.');
      }

      final reverseSwipe = liked
          ? await transaction.get(reverseReference)
          : null;
      final reverseData = reverseSwipe?.data();
      final reverseLiked = reverseData?['action'] == 'like';

      transaction.set(
        swipeReference,
        {
          'swiperPetId': swiperPetId,
          'swiperPetName': swiperPetName,
          'swiperOwnerId': swiperOwnerId,
          'targetPetId': targetPetId,
          'targetPetName': targetPetName,
          'targetOwnerId': targetOwnerId,
          'purpose': 'breeding',
          'action': liked ? 'like' : 'dislike',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!liked) return;

      if (!reverseLiked) {
        transaction.set(likeNotificationReference, {
          'notificationId': likeNotificationReference.id,
          'recipientId': targetOwnerId,
          'type': 'breeding_like_received',
          'title': '$swiperPetName liked $targetPetName',
          'message':
              '$swiperPetName liked $targetPetName. Like them back to start a breeding chat.',
          'matchId': resolvedMatchId,
          'petIds': [swiperPetId, targetPetId],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      matched = true;
      final petIds = [swiperPetId, targetPetId]..sort();
      final ownerIds = [swiperOwnerId, targetOwnerId];

      transaction.set(
        matchReference,
        {
          'matchId': resolvedMatchId,
          'purpose': 'breeding',
          'petIds': petIds,
          'ownerIds': ownerIds,
          'petOwners': {
            swiperPetId: swiperOwnerId,
            targetPetId: targetOwnerId,
          },
          'petNames': {
            swiperPetId: swiperPetName,
            targetPetId: targetPetName,
          },
          'petPhotos': {
            swiperPetId: swiperPetPhoto,
            targetPetId: targetPetPhoto,
          },
          'status': 'active',
          'completionConfirmations': <String, bool>{},
          'removalDecisions': <String, bool>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        conversationReference,
        {
          'conversationId': resolvedMatchId,
          'matchId': resolvedMatchId,
          'purpose': 'breeding',
          'participantIds': ownerIds,
          'petIds': petIds,
          'petOwners': {
            swiperPetId: swiperOwnerId,
            targetPetId: targetOwnerId,
          },
          'petNames': {
            swiperPetId: swiperPetName,
            targetPetId: targetPetName,
          },
          'petPhotos': {
            swiperPetId: swiperPetPhoto,
            targetPetId: targetPetPhoto,
          },
          'status': 'active',
          'isArchived': false,
          'canSendMessages': true,
          'lastMessage': '',
          'lastMessageAt': null,
          'unreadCounts': {
            swiperOwnerId: 0,
            targetOwnerId: 0,
          },
          'lastReadAt': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(swiperMatchNotificationReference, {
        'notificationId': swiperMatchNotificationReference.id,
        'recipientId': swiperOwnerId,
        'type': 'breeding_match_created',
        'title': "It's a match!",
        'message':
            '$targetPetName also likes $swiperPetName. Chat is now open.',
        'matchId': resolvedMatchId,
        'petIds': petIds,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(targetMatchNotificationReference, {
        'notificationId': targetMatchNotificationReference.id,
        'recipientId': targetOwnerId,
        'type': 'breeding_match_created',
        'title': "It's a match!",
        'message':
            '$swiperPetName also likes $targetPetName. Chat is now open.',
        'matchId': resolvedMatchId,
        'petIds': petIds,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return SwipeResult(
      matched: matched,
      matchId: matched ? resolvedMatchId : null,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversationsForPet(
    String petId,
  ) {
    final user = UserSessionService.instance.currentUser;
    if (user == null || petId.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: user.uid)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConversation(
    String matchId,
  ) {
    return _firestore.collection('conversations').doc(matchId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String matchId) {
    return _firestore
        .collection('conversations')
        .doc(matchId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> sendMessage({
    required String matchId,
    required String text,
  }) async {
    final user = UserSessionService.instance.currentUser;
    final trimmed = text.trim();
    if (user == null || trimmed.isEmpty) return;

    final conversation =
        _firestore.collection('conversations').doc(matchId);
    final match = _firestore.collection('matches').doc(matchId);
    final message = conversation.collection('messages').doc();
    final notification = _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversation);
      final matchSnapshot = await transaction.get(match);
      final data = snapshot.data();
      if (data == null) throw StateError('Conversation not found.');

      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw StateError('You are not part of this conversation.');
      }
      if (data['status'] == 'unmatched' ||
          data['isArchived'] == true ||
          data['canSendMessages'] == false) {
        throw StateError('This conversation is no longer available.');
      }
      final matchData = matchSnapshot.data();
      final reviewReleaseAt = matchData?['reviewReleaseAt'] as Timestamp?;
      if (matchData?['status'] == 'completed' &&
          reviewReleaseAt != null &&
          !DateTime.now().toUtc().isBefore(reviewReleaseAt.toDate())) {
        throw StateError(
          'This completed conversation is now read-only.',
        );
      }

      final recipientId =
          participantIds.firstWhere((participantId) => participantId != user.uid);
      final purpose = data['purpose'] as String? ?? 'breeding';
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );
      unreadCounts[recipientId] =
          ((unreadCounts[recipientId] as num?)?.toInt() ?? 0) + 1;
      unreadCounts[user.uid] = 0;
      final lastReadAt = Map<String, dynamic>.from(
        data['lastReadAt'] as Map? ?? const <String, dynamic>{},
      );
      lastReadAt[user.uid] = FieldValue.serverTimestamp();

      transaction.set(message, {
        'messageId': message.id,
        'senderId': user.uid,
        'text': trimmed,
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'notificationId': notification.id,
        'recipientId': recipientId,
        'type': 'new_message',
        'title': 'New message',
        'message': trimmed,
        'purpose': purpose,
        'matchId': matchId,
        'conversationId': matchId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(
        conversation,
        <String, dynamic>{
          'lastMessage': trimmed,
          'lastMessageSenderId': user.uid,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts': unreadCounts,
          'lastReadAt': lastReadAt,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> markConversationRead(String matchId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final conversation =
        _firestore.collection('conversations').doc(matchId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversation);
      final data = snapshot.data();
      if (data == null) return;

      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw StateError('You are not part of this conversation.');
      }
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );
      unreadCounts[user.uid] = 0;
      final lastReadAt = Map<String, dynamic>.from(
        data['lastReadAt'] as Map? ?? const <String, dynamic>{},
      );
      lastReadAt[user.uid] = FieldValue.serverTimestamp();

      transaction.update(
        conversation,
        <String, dynamic>{
          'unreadCounts': unreadCounts,
          'lastReadAt': lastReadAt,
        },
      );
    });
  }

  Future<void> unmatch(String matchId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    final matchReference = _firestore.collection('matches').doc(matchId);
    final conversationReference =
        _firestore.collection('conversations').doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchReference);
      final conversationSnapshot =
          await transaction.get(conversationReference);
      final matchData = matchSnapshot.data();
      final conversationData = conversationSnapshot.data();

      if (matchData == null || conversationData == null) {
        throw StateError('Match not found.');
      }

      final ownerIds =
          (matchData['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!ownerIds.contains(user.uid)) {
        throw StateError('You are not part of this match.');
      }
      if (matchData['status'] == 'unmatched') return;
      if (matchData['status'] == 'completed') {
        throw StateError(
          'A completed breeding transaction cannot be unmatched.',
        );
      }

      final petIds =
          (matchData['petIds'] as List?)?.cast<String>() ?? const <String>[];
      if (petIds.length != 2) {
        throw StateError('Matched pets were not found.');
      }
      final petOwners = Map<String, dynamic>.from(
        matchData['petOwners'] as Map? ?? const {},
      );
      final otherOwnerId = ownerIds.firstWhere((id) => id != user.uid);
      final petNames = Map<String, dynamic>.from(
        matchData['petNames'] as Map? ?? const {},
      );
      final firstPetName = (petNames[petIds[0]] ?? 'Pet').toString();
      final secondPetName = (petNames[petIds[1]] ?? 'Pet').toString();
      final notificationReference =
          _firestore.collection('notifications').doc();

      transaction.update(matchReference, {
        'status': 'unmatched',
        'unmatchedBy': user.uid,
        'unmatchedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(conversationReference, {
        'status': 'unmatched',
        'isArchived': true,
        'canSendMessages': false,
        'archivedBy': user.uid,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'notificationId': notificationReference.id,
        'recipientId': otherOwnerId,
        'type': 'match_ended',
        'title': 'Match ended',
        'message':
            'Your match between $firstPetName and $secondPetName has ended.',
        'matchId': matchId,
        'petIds': petIds,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (var index = 0; index < petIds.length; index++) {
        final swiperPetId = petIds[index];
        final targetPetId = petIds[index == 0 ? 1 : 0];
        transaction.set(
          _firestore
              .collection('swipes')
              .doc(swipeId(swiperPetId, targetPetId)),
          {
            'swiperPetId': swiperPetId,
            'swiperOwnerId': petOwners[swiperPetId] ?? '',
            'targetPetId': targetPetId,
            'targetOwnerId': petOwners[targetPetId] ?? '',
            'purpose': 'breeding',
            'action': 'unmatched',
            'permanentlyExcluded': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  Future<void> confirmBreedingCompleted(String matchId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    final reference = _firestore.collection('matches').doc(matchId);
    final conversationReference =
        _firestore.collection('conversations').doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) throw StateError('Match not found.');
      if (data['status'] == 'unmatched') {
        throw StateError('This match has already been permanently unmatched.');
      }
      if (data['status'] == 'completed') {
        throw StateError('This breeding transaction is already completed.');
      }

      final ownerIds =
          (data['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!ownerIds.contains(user.uid)) {
        throw StateError('You are not part of this match.');
      }

      final confirmations = Map<String, dynamic>.from(
        data['completionConfirmations'] as Map? ?? const {},
      );
      if (confirmations[user.uid] == true) {
        throw StateError('You already confirmed this completion.');
      }
      confirmations[user.uid] = true;
      final completed = ownerIds.every((id) => confirmations[id] == true);
      final now = DateTime.now().toUtc();
      final requestedAt =
          data['completionRequestedAt'] as Timestamp? ?? Timestamp.fromDate(now);
      final completionSnapshots = completed
          ? await _buildCompletionSnapshots(transaction, data)
          : const <String, dynamic>{};

      transaction.update(reference, {
        'completionConfirmations': confirmations,
        'status': completed ? 'completed' : 'completion_pending',
        'completionRequestedBy':
            data['completionRequestedBy'] ?? user.uid,
        'completionRequestedAt': requestedAt,
        'confirmationDeadline': data['confirmationDeadline'] ??
            Timestamp.fromDate(now.add(const Duration(hours: 24))),
        'autoCompleteAt': data['autoCompleteAt'] ??
            Timestamp.fromDate(now.add(const Duration(hours: 48))),
        if (completed) ...{
          'completedAt': Timestamp.fromDate(now),
          'completionType': 'confirmed',
          'reviewReleaseAt':
              Timestamp.fromDate(now.add(const Duration(days: 7))),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (completed) {
        transaction.set(
          conversationReference,
          {
            'status': 'completed',
            'reviewReleaseAt':
                Timestamp.fromDate(now.add(const Duration(days: 7))),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          _firestore.collection('breedingTransactions').doc(matchId),
          _transactionSnapshot(
            matchId: matchId,
            matchData: data,
            confirmations: confirmations,
            completedAt: now,
            completionType: 'confirmed',
            completionSnapshots: completionSnapshots,
          ),
        );
        for (final ownerId in ownerIds) {
          final notification = _firestore.collection('notifications').doc();
          transaction.set(notification, {
            'notificationId': notification.id,
            'recipientId': ownerId,
            'type': 'breeding_completed',
            'title': 'Breeding completed',
            'message':
                'Both owners confirmed completion. You can now leave a review.',
            'matchId': matchId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        final otherOwnerId = ownerIds.firstWhere((id) => id != user.uid);
        final notification = _firestore.collection('notifications').doc();
        transaction.set(notification, {
          'notificationId': notification.id,
          'recipientId': otherOwnerId,
          'type': 'breeding_completion_requested',
          'title': 'Completion confirmation needed',
          'message':
              'Please confirm whether this breeding transaction was completed.',
          'matchId': matchId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> processCompletionDeadline(String matchId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final matchReference = _firestore.collection('matches').doc(matchId);
    final conversationReference =
        _firestore.collection('conversations').doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(matchReference);
      final data = snapshot.data();
      if (data == null || data['status'] != 'completion_pending') return;

      final ownerIds =
          (data['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!ownerIds.contains(user.uid)) return;

      final autoCompleteAt = data['autoCompleteAt'] as Timestamp?;
      final now = DateTime.now().toUtc();
      if (autoCompleteAt == null || now.isBefore(autoCompleteAt.toDate())) {
        return;
      }

      final confirmations = Map<String, dynamic>.from(
        data['completionConfirmations'] as Map? ?? const {},
      );
      final completionSnapshots =
          await _buildCompletionSnapshots(transaction, data);
      transaction.update(matchReference, {
        'status': 'completed',
        'completedAt': Timestamp.fromDate(now),
        'completionType': 'auto_completed',
        'reviewReleaseAt':
            Timestamp.fromDate(now.add(const Duration(days: 7))),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _firestore.collection('breedingTransactions').doc(matchId),
        _transactionSnapshot(
          matchId: matchId,
          matchData: data,
          confirmations: confirmations,
          completedAt: now,
          completionType: 'auto_completed',
          completionSnapshots: completionSnapshots,
        ),
      );
      transaction.set(
        conversationReference,
        {
          'status': 'completed',
          'reviewReleaseAt':
              Timestamp.fromDate(now.add(const Duration(days: 7))),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (final ownerId in ownerIds) {
        final notification = _firestore.collection('notifications').doc();
        transaction.set(notification, {
          'notificationId': notification.id,
          'recipientId': ownerId,
          'type': 'breeding_auto_completed',
          'title': 'Breeding auto-completed',
          'message':
              'The 48-hour confirmation period ended. You can now leave a review.',
          'matchId': matchId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> processPendingCompletionsForCurrentUser() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('matches')
        .where('ownerIds', arrayContains: user.uid)
        .get();
    for (final document in snapshot.docs) {
      if (document.data()['status'] == 'completion_pending') {
        await processCompletionDeadline(document.id);
      }
    }
  }

  Future<void> sendCompletionReminder(String matchId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    final reference = _firestore.collection('matches').doc(matchId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null || data['status'] != 'completion_pending') {
        throw StateError('Completion is not pending.');
      }
      if (data['completionRequestedBy'] != user.uid) {
        throw StateError('Only the requester can send the reminder.');
      }
      if (data['reminderSentAt'] != null) {
        throw StateError('A reminder has already been sent.');
      }

      final deadline = data['confirmationDeadline'] as Timestamp?;
      if (deadline == null || DateTime.now().toUtc().isBefore(deadline.toDate())) {
        throw StateError('The reminder becomes available after 24 hours.');
      }

      final ownerIds =
          (data['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
      final recipientId = ownerIds.firstWhere((id) => id != user.uid);
      final notification = _firestore.collection('notifications').doc();
      transaction.update(reference, {
        'reminderSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'notificationId': notification.id,
        'recipientId': recipientId,
        'type': 'breeding_completion_reminder',
        'title': 'Completion reminder',
        'message':
            'A breeding completion is still waiting for your confirmation.',
        'matchId': matchId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitReview({
    required String matchId,
    required int overall,
    required int communication,
    required int careResponsibility,
    required int transparency,
    required int reliability,
    required String recommendation,
    required String reviewText,
    required List<String> photoUrls,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');
    if (photoUrls.length > 3) {
      throw StateError('A review can contain at most three photos.');
    }
    final ratings = [
      overall,
      communication,
      careResponsibility,
      transparency,
      reliability,
    ];
    if (ratings.any((rating) => rating < 1 || rating > 5)) {
      throw StateError('Every rating must be between one and five.');
    }

    final matchReference = _firestore.collection('matches').doc(matchId);
    final reviewReference =
        _firestore.collection('reviews').doc('${matchId}_${user.uid}');

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchReference);
      final data = matchSnapshot.data();
      if (data == null ||
          (data['status'] != 'completed' &&
              data['status'] != 'auto_completed')) {
        throw StateError('Reviews require a completed breeding.');
      }

      final ownerIds =
          (data['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!ownerIds.contains(user.uid)) {
        throw StateError('You are not part of this transaction.');
      }
      final reviewsSubmitted = Map<String, dynamic>.from(
        data['reviewsSubmitted'] as Map? ?? const <String, dynamic>{},
      );
      if (reviewsSubmitted[user.uid] == true) {
        throw StateError('You already reviewed this transaction.');
      }

      final reviewedUserId = ownerIds.firstWhere((id) => id != user.uid);
      final otherReviewReference =
          _firestore.collection('reviews').doc('${matchId}_$reviewedUserId');
      final completedAt =
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now().toUtc();
      final bothSubmitted = reviewsSubmitted[reviewedUserId] == true;

      transaction.set(reviewReference, {
        'reviewId': reviewReference.id,
        'matchId': matchId,
        'purpose': 'breeding',
        'reviewerId': user.uid,
        'reviewedUserId': reviewedUserId,
        'overall': overall,
        'communication': communication,
        'careResponsibility': careResponsibility,
        'transparency': transparency,
        'reliability': reliability,
        'recommendation': recommendation,
        'reviewText': reviewText.trim(),
        'photoUrls': photoUrls,
        'isPublished': bothSubmitted,
        'completedAt': Timestamp.fromDate(completedAt),
        'visibleAfter':
            Timestamp.fromDate(completedAt.add(const Duration(days: 7))),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(matchReference, {
        'reviewsSubmitted.${user.uid}': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (bothSubmitted) {
        transaction.update(otherReviewReference, {
          'isPublished': true,
          'publishedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> processReviewReleasesForCurrentUser() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final reviewed = await _firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: user.uid)
        .get();
    final authored = await _firestore
        .collection('reviews')
        .where('reviewerId', isEqualTo: user.uid)
        .get();
    final documents = {
      for (final document in [...reviewed.docs, ...authored.docs])
        document.id: document,
    };
    final now = DateTime.now().toUtc();

    for (final document in documents.values) {
      final data = document.data();
      final visibleAfter = data['visibleAfter'] as Timestamp?;
      if (data['isPublished'] == true ||
          visibleAfter == null ||
          now.isBefore(visibleAfter.toDate())) {
        continue;
      }
      await document.reference.update({
        'isPublished': true,
        'publishedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublishedReviewsForUser(
    String userId,
  ) {
    return _firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: userId)
        .where('isPublished', isEqualTo: true)
        .snapshots();
  }

  Map<String, dynamic> _transactionSnapshot({
    required String matchId,
    required Map<String, dynamic> matchData,
    required Map<String, dynamic> confirmations,
    required DateTime completedAt,
    required String completionType,
    required Map<String, dynamic> completionSnapshots,
  }) {
    return {
      'transactionId': matchId,
      'matchId': matchId,
      'purpose': 'breeding',
      'ownerIds': matchData['ownerIds'] ?? const <String>[],
      'petIds': matchData['petIds'] ?? const <String>[],
      'petOwners': matchData['petOwners'] ?? const <String, dynamic>{},
      'petNames': matchData['petNames'] ?? const <String, dynamic>{},
      'petPhotos': matchData['petPhotos'] ?? const <String, dynamic>{},
      'ownerSnapshots':
          completionSnapshots['ownerSnapshots'] ?? const <String, dynamic>{},
      'petSnapshots':
          completionSnapshots['petSnapshots'] ?? const <String, dynamic>{},
      'completionConfirmations': confirmations,
      'completionRequestedBy': matchData['completionRequestedBy'],
      'completionRequestedAt': matchData['completionRequestedAt'],
      'completedAt': Timestamp.fromDate(completedAt),
      'completionType': completionType,
      'reviewReleaseAt':
          Timestamp.fromDate(completedAt.add(const Duration(days: 7))),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<Map<String, dynamic>> _buildCompletionSnapshots(
    Transaction transaction,
    Map<String, dynamic> matchData,
  ) async {
    final ownerIds =
        (matchData['ownerIds'] as List?)?.cast<String>() ?? const <String>[];
    final petIds =
        (matchData['petIds'] as List?)?.cast<String>() ?? const <String>[];
    final ownerSnapshots = <String, dynamic>{};
    final petSnapshots = <String, dynamic>{};

    for (final ownerId in ownerIds) {
      final snapshot = await transaction.get(
        _firestore.collection('users').doc(ownerId),
      );
      final data = snapshot.data() ?? const <String, dynamic>{};
      ownerSnapshots[ownerId] = {
        'fullName': data['fullName'] ?? 'Breedr User',
        'profilePhoto': data['profilePhoto'] ?? '',
        'locationName': data['locationName'] ?? '',
      };
    }

    for (final petId in petIds) {
      final snapshot = await transaction.get(
        _firestore.collection('pets').doc(petId),
      );
      final data = snapshot.data() ?? const <String, dynamic>{};
      petSnapshots[petId] = {
        'name': data['name'] ?? data['petName'] ?? 'Pet',
        'petProfilePhoto': data['petProfilePhoto'] ?? '',
        'species': data['species'] ?? '',
        'breed': data['breed'] ?? '',
        'gender': data['gender'] ?? '',
        'birthDate': data['birthDate'],
        'age': data['age'],
        'color': data['color'] ?? '',
        'size': data['size'] ?? '',
      };
    }

    return {
      'ownerSnapshots': ownerSnapshots,
      'petSnapshots': petSnapshots,
    };
  }

  Future<void> decideOwnPetRemoval({
    required String matchId,
    required bool removeFromListings,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    final matchReference = _firestore.collection('matches').doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchReference);
      final data = matchSnapshot.data();
      if (data == null) throw StateError('Match not found.');
      if (data['status'] != 'completed') {
        throw StateError('Both owners must confirm completion first.');
      }

      final petOwners = Map<String, dynamic>.from(
        data['petOwners'] as Map? ?? const {},
      );
      String? ownPetId;
      for (final entry in petOwners.entries) {
        if (entry.value == user.uid) {
          ownPetId = entry.key;
          break;
        }
      }
      if (ownPetId == null) {
        throw StateError('Your pet was not found in this match.');
      }

      final decisions = Map<String, dynamic>.from(
        data['removalDecisions'] as Map? ?? const {},
      );
      decisions[user.uid] = removeFromListings;

      transaction.update(matchReference, {
        'removalDecisions': decisions,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (removeFromListings) {
        transaction.update(
          _firestore.collection('pets').doc(ownPetId),
          {
            'status': 'matched',
            'isActive': false,
            'matchId': matchId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    });
  }
}

class SwipeResult {
  final bool matched;
  final String? matchId;

  const SwipeResult({
    required this.matched,
    this.matchId,
  });
}
