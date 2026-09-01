import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/adoption_models.dart';
import 'user_session_service.dart';

class AdoptionServiceException implements Exception {
  final String message;

  const AdoptionServiceException(this.message);

  @override
  String toString() => message;
}

class AdoptionEvidenceFile {
  final String url;
  final String fileName;
  final String fileType;
  final String mimeType;
  final int sizeBytes;

  const AdoptionEvidenceFile({
    required this.url,
    required this.fileName,
    required this.fileType,
    required this.mimeType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'fileName': fileName,
      'fileType': fileType,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }

  bool get isAllowedEvidence {
    return fileType == 'image' || fileType == 'video';
  }
}

class AdoptionService {
  AdoptionService._();

  static final AdoptionService instance = AdoptionService._();
  static const Duration protectionWindowDuration = Duration(days: 7);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String requestId(
    String petId,
    String applicantId, {
    String listingCycleId = '',
  }) {
    return listingCycleId.isEmpty
        ? '${petId}_$applicantId'
        : '${petId}_${listingCycleId}_$applicantId';
  }

  String favoriteId(String petId, String userId) {
    return '${userId}_$petId';
  }

  String viewId(String petId, String userId) {
    return '${petId}_$userId';
  }

  String conversationId(String adoptionRequestId) {
    return 'adoption_$adoptionRequestId';
  }

  Stream<AdoptionListing?> watchListing(String petId) {
    return _firestore
        .collection('pets')
        .doc(petId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? AdoptionListing.fromDocument(snapshot) : null,
        );
  }

  Stream<bool> watchIsFavorite(String petId) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(false);

    return _firestore
        .collection('favorites')
        .doc(favoriteId(petId, userId))
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<List<AdoptionListing>> watchAvailableListings() {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(const []);

    return _firestore
        .collection('pets')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdoptionListing.fromDocument)
              .where((listing) => listing.ownerId != userId)
              .where((listing) => listing.isAvailable)
              .where((listing) => listing.hasValidPrice)
              .toList(),
        );
  }

  Stream<List<AdoptionListing>> watchMyListings() {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(const []);

    return _firestore
        .collection('pets')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where(
                (document) => _normalizedPurpose(document.data()) == 'adoption',
              )
              .map(AdoptionListing.fromDocument)
              .where((listing) => listing.isAvailable)
              .toList(),
        );
  }

  String _normalizedPurpose(Map<String, dynamic> data) {
    return (data['normalizedPurpose'] ?? data['purpose'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  Stream<List<AdoptionRequest>> watchMyRequests() {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(const []);

    return _firestore
        .collection('adoptionRequests')
        .where('applicantId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(AdoptionRequest.fromDocument)
              .toList();
          requests.sort((a, b) {
            final aTime = a.updatedAt ?? a.createdAt;
            final bTime = b.updatedAt ?? b.createdAt;
            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });
          return requests;
        });
  }

  Stream<List<AdoptionRequest>> watchMyAdoptionHistory() {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(const []);

    late StreamController<List<AdoptionRequest>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownerSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? applicantSub;
    var ownerRequests = const <AdoptionRequest>[];
    var applicantRequests = const <AdoptionRequest>[];

    void emit() {
      final byId = <String, AdoptionRequest>{
        for (final request in ownerRequests) request.id: request,
        for (final request in applicantRequests) request.id: request,
      };
      final requests = byId.values
          .where((request) => request.status == AdoptionRequestStatus.completed)
          .toList();
      requests.sort((a, b) {
        final aTime = a.completedAt ?? a.updatedAt ?? a.createdAt;
        final bTime = b.completedAt ?? b.updatedAt ?? b.createdAt;
        return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
          aTime?.millisecondsSinceEpoch ?? 0,
        );
      });
      if (!controller.isClosed) controller.add(requests);
    }

    controller = StreamController<List<AdoptionRequest>>(
      onListen: () {
        ownerSub = _firestore
            .collection('adoptionRequests')
            .where('ownerId', isEqualTo: userId)
            .snapshots()
            .listen((snapshot) {
              ownerRequests = snapshot.docs
                  .map(AdoptionRequest.fromDocument)
                  .toList();
              emit();
            }, onError: controller.addError);
        applicantSub = _firestore
            .collection('adoptionRequests')
            .where('applicantId', isEqualTo: userId)
            .snapshots()
            .listen((snapshot) {
              applicantRequests = snapshot.docs
                  .map(AdoptionRequest.fromDocument)
                  .toList();
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await ownerSub?.cancel();
        await applicantSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<AdoptionRequest?> watchMyRequestForListing(
    String petId, {
    String listingCycleId = '',
  }) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('adoptionRequests')
        .doc(requestId(petId, userId, listingCycleId: listingCycleId))
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? AdoptionRequest.fromDocument(snapshot) : null,
        );
  }

  Stream<AdoptionRequest?> watchRequest(String adoptionRequestId) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('adoptionRequests')
        .doc(adoptionRequestId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final request = AdoptionRequest.fromDocument(snapshot);
          if (request.applicantId != userId && request.ownerId != userId) {
            return null;
          }
          return request;
        });
  }

  Stream<List<AdoptionRequest>> watchRequestsForListing(String petId) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(const []);

    return _firestore
        .collection('adoptionRequests')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .where((document) => document.data()['petId'] == petId)
              .map(AdoptionRequest.fromDocument)
              .toList();
          requests.sort((a, b) {
            final aTime = a.updatedAt ?? a.createdAt;
            final bTime = b.updatedAt ?? b.createdAt;
            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });
          return requests;
        });
  }

  Stream<Set<String>> watchFavoritePetIds({String? purpose}) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(const {});

    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where(
                (document) =>
                    purpose == null || document.data()['purpose'] == purpose,
              )
              .map((document) => document.data()['petId'] as String? ?? '')
              .where((petId) => petId.isNotEmpty)
              .toSet(),
        );
  }

  Stream<int> watchListingViewCount(String petId) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('listingViews')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => document.data()['petId'] == petId)
              .length,
        );
  }

  Stream<int> watchActiveRequestCount(String petId) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    const activeStatuses = {'pending', 'under_review', 'approved'};
    return _firestore
        .collection('adoptionRequests')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where(
                (document) =>
                    document.data()['petId'] == petId &&
                    activeStatuses.contains(document.data()['status']),
              )
              .length,
        );
  }

  Future<AdoptionEligibility> validateListingForRequest(String petId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      return const AdoptionEligibility.denied(
        'Please sign in before requesting to adopt a pet.',
      );
    }

    final petReference = _firestore.collection('pets').doc(petId);
    final petSnapshot = await petReference.get();
    final listing = petSnapshot.exists
        ? AdoptionListing.fromDocument(petSnapshot)
        : null;
    final requestReference = _firestore
        .collection('adoptionRequests')
        .doc(
          requestId(
            petId,
            user.uid,
            listingCycleId: listing?.listingCycleId ?? '',
          ),
        );
    final requestSnapshot = await requestReference.get();

    final reason = _listingValidationReason(
      listing: listing,
      currentUserId: user.uid,
      existingRequest: requestSnapshot,
    );
    return reason == null
        ? AdoptionEligibility.allowed(listing!)
        : AdoptionEligibility.denied(reason);
  }

  Future<bool> toggleFavorite(String petId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException(
        'Please sign in before saving a listing.',
      );
    }

    final favoriteReference = _firestore
        .collection('favorites')
        .doc(favoriteId(petId, user.uid));
    final petReference = _firestore.collection('pets').doc(petId);
    var isFavorite = false;

    await _firestore.runTransaction((transaction) async {
      final favoriteSnapshot = await transaction.get(favoriteReference);
      if (favoriteSnapshot.exists) {
        transaction.delete(favoriteReference);
        isFavorite = false;
        return;
      }

      final petSnapshot = await transaction.get(petReference);
      if (!petSnapshot.exists) {
        throw const AdoptionServiceException(
          'This listing is no longer available.',
        );
      }
      final listing = AdoptionListing.fromDocument(petSnapshot);
      final ownerId = listing.ownerId;
      final purpose = listing.purpose;
      if (ownerId == user.uid) {
        throw const AdoptionServiceException(
          'You cannot save your own listing.',
        );
      }
      if (purpose != 'adoption') {
        throw const AdoptionServiceException(
          'This listing cannot be saved here.',
        );
      }
      if (!listing.isAvailable) {
        throw const AdoptionServiceException(
          'This listing is no longer available.',
        );
      }

      transaction.set(favoriteReference, {
        'favoriteId': favoriteReference.id,
        'userId': user.uid,
        'petId': petId,
        'ownerId': ownerId,
        'purpose': 'adoption',
        'createdAt': FieldValue.serverTimestamp(),
      });
      isFavorite = true;
    });

    return isFavorite;
  }

  Future<void> recordListingView(String petId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final petReference = _firestore.collection('pets').doc(petId);
    final viewReference = _firestore
        .collection('listingViews')
        .doc(viewId(petId, user.uid));

    await _firestore.runTransaction((transaction) async {
      final existingView = await transaction.get(viewReference);
      if (existingView.exists) return;

      final petSnapshot = await transaction.get(petReference);
      if (!petSnapshot.exists) return;
      final listing = AdoptionListing.fromDocument(petSnapshot);
      if (listing.ownerId == user.uid) return;

      transaction.set(viewReference, {
        'viewId': viewReference.id,
        'petId': petId,
        'viewerId': user.uid,
        'ownerId': listing.ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> submitRequest({
    required String petId,
    required List<AdoptionAnswer> answers,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException(
        'Please sign in before submitting an adoption request.',
      );
    }

    final petReference = _firestore.collection('pets').doc(petId);
    final userReference = _firestore.collection('users').doc(user.uid);
    final notificationReference = _firestore.collection('notifications').doc();
    late String resolvedRequestId;

    await _firestore.runTransaction((transaction) async {
      final petSnapshot = await transaction.get(petReference);
      final listing = petSnapshot.exists
          ? AdoptionListing.fromDocument(petSnapshot)
          : null;
      resolvedRequestId = requestId(
        petId,
        user.uid,
        listingCycleId: listing?.listingCycleId ?? '',
      );
      final requestReference = _firestore
          .collection('adoptionRequests')
          .doc(resolvedRequestId);
      final existingRequest = await transaction.get(requestReference);
      final userSnapshot = await transaction.get(userReference);
      final reason = _listingValidationReason(
        listing: listing,
        currentUserId: user.uid,
        existingRequest: existingRequest,
      );
      if (reason != null) throw AdoptionServiceException(reason);

      final normalizedAnswers = _normalizedAnswers(listing!.questions, answers);
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final applicantSnapshot = {
        'userId': user.uid,
        'fullName': userData['fullName'] ?? user.displayName ?? 'Breedr User',
        'profilePhoto': userData['profilePhoto'] ?? user.photoURL ?? '',
        'userName': userData['userName'] ?? '',
        'locationName': userData['locationName'] ?? '',
        'latitude': userData['latitude'],
        'longitude': userData['longitude'],
        'homeType': userData['homeType'] ?? '',
        'childrenAtHome': userData['childrenAtHome'] ?? false,
        'otherPetsAtHome': userData['otherPetsAtHome'] ?? false,
      };

      transaction.set(requestReference, {
        'requestId': resolvedRequestId,
        'petId': petId,
        'ownerId': listing.ownerId,
        'applicantId': user.uid,
        'listingCycleId': listing.listingCycleId,
        'status': 'pending',
        'answers': normalizedAnswers.map((answer) => answer.toMap()).toList(),
        'questionSnapshots': listing.questions
            .map((question) => question.toMap())
            .toList(),
        'petSnapshot': listing.snapshot(),
        'applicantSnapshot': applicantSnapshot,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'notificationId': notificationReference.id,
        'recipientId': listing.ownerId,
        'type': 'adoption_request_received',
        'title': 'New adoption request',
        'message':
            '${applicantSnapshot['fullName']} requested to adopt ${listing.name}.',
        'petId': petId,
        'requestId': resolvedRequestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return resolvedRequestId;
  }

  Future<void> markRequestUnderReview(String adoptionRequestId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final reference = _firestore
        .collection('adoptionRequests')
        .doc(adoptionRequestId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const AdoptionServiceException(
          'This adoption request could not be found.',
        );
      }
      if (data['ownerId'] != user.uid) {
        throw const AdoptionServiceException(
          'Only the listing owner can review this request.',
        );
      }
      if (data['status'] != 'pending') return;

      transaction.update(reference, {
        'status': 'under_review',
        'reviewStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<AdoptionActionEligibility> validateWithdrawal(
    String adoptionRequestId,
  ) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      return const AdoptionActionEligibility.denied(
        'Please sign in before withdrawing this request.',
      );
    }

    final snapshot = await _firestore
        .collection('adoptionRequests')
        .doc(adoptionRequestId)
        .get();
    final data = snapshot.data();
    if (data == null) {
      return const AdoptionActionEligibility.denied(
        'This adoption request could not be found.',
      );
    }
    if (data['applicantId'] != user.uid) {
      return const AdoptionActionEligibility.denied(
        'Only the applicant can withdraw this request.',
      );
    }
    if (data['status'] != 'pending' && data['status'] != 'under_review') {
      return const AdoptionActionEligibility.denied(
        'This request can no longer be withdrawn.',
      );
    }
    return const AdoptionActionEligibility.allowed();
  }

  Future<String> approveRequest(String adoptionRequestId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final requestReference = _firestore
        .collection('adoptionRequests')
        .doc(adoptionRequestId);
    final conversationReference = _firestore
        .collection('conversations')
        .doc(conversationId(adoptionRequestId));
    final notificationReference = _firestore.collection('notifications').doc();
    var resolvedConversationId = '';
    var resolvedPetId = '';
    var resolvedListingName = 'this pet';

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestReference);
      final requestData = requestSnapshot.data();
      if (requestData == null) {
        throw const AdoptionServiceException(
          'This adoption request could not be found.',
        );
      }
      if (requestData['ownerId'] != user.uid) {
        throw const AdoptionServiceException(
          'Only the listing owner can approve this request.',
        );
      }
      if (requestData['status'] != 'pending' &&
          requestData['status'] != 'under_review') {
        throw const AdoptionServiceException(
          'This request can no longer be approved.',
        );
      }

      final petId = requestData['petId'] as String? ?? '';
      final applicantId = requestData['applicantId'] as String? ?? '';
      resolvedPetId = petId;
      final petReference = _firestore.collection('pets').doc(petId);
      final petSnapshot = await transaction.get(petReference);
      if (!petSnapshot.exists) {
        throw const AdoptionServiceException(
          'This adoption listing no longer exists.',
        );
      }
      final listing = AdoptionListing.fromDocument(petSnapshot);
      if (listing.ownerId != user.uid || !listing.isAvailable) {
        throw const AdoptionServiceException(
          'This adoption listing is no longer available for approval.',
        );
      }

      resolvedConversationId = conversationReference.id;
      resolvedListingName = listing.name;
      transaction.update(requestReference, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'conversationId': conversationReference.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(petReference, {
        'status': 'reserved',
        'adoptionStatus': 'reserved',
        'reservedFor': applicantId,
        'approvedRequestId': adoptionRequestId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(conversationReference, {
        'conversationId': conversationReference.id,
        'requestId': adoptionRequestId,
        'purpose': 'adoption',
        'participantIds': [user.uid, applicantId],
        'petIds': [petId],
        'petOwners': {petId: user.uid},
        'petNames': {petId: listing.name},
        'petPhotos': {petId: listing.profilePhoto},
        'status': 'active',
        'isArchived': false,
        'canSendMessages': true,
        'adoptionProcess': {'status': 'not_started', 'currentStep': 0},
        'lastMessage': '',
        'lastMessageAt': null,
        'unreadCounts': {user.uid: 0, applicantId: 0},
        'lastReadAt': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'notificationId': notificationReference.id,
        'recipientId': applicantId,
        'type': 'adoption_request_approved',
        'title': 'Adoption request approved',
        'message':
            'Your request to adopt ${listing.name} was approved. You can now chat with the owner.',
        'petId': petId,
        'requestId': adoptionRequestId,
        'conversationId': conversationReference.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await _declineOtherActiveRequestsAfterApproval(
      petId: resolvedPetId,
      approvedRequestId: adoptionRequestId,
      listingName: resolvedListingName,
    );

    return resolvedConversationId;
  }

  Future<void> _declineOtherActiveRequestsAfterApproval({
    required String petId,
    required String approvedRequestId,
    required String listingName,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null || petId.isEmpty) return;

    final snapshot = await _firestore
        .collection('adoptionRequests')
        .where('ownerId', isEqualTo: user.uid)
        .get();
    final activeRequests = snapshot.docs.where((document) {
      final data = document.data();
      return document.id != approvedRequestId &&
          data['petId'] == petId &&
          (data['status'] == 'pending' || data['status'] == 'under_review');
    }).toList();
    if (activeRequests.isEmpty) return;

    final batch = _firestore.batch();
    for (final request in activeRequests) {
      final data = request.data();
      final applicantId = data['applicantId'] as String? ?? '';
      batch.update(request.reference, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': 'Another applicant was approved.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (applicantId.isNotEmpty) {
        final notification = _firestore.collection('notifications').doc();
        batch.set(notification, {
          'notificationId': notification.id,
          'recipientId': applicantId,
          'type': 'adoption_request_rejected',
          'title': 'Adoption request update',
          'message':
              '$listingName is no longer available because another request was approved.',
          'petId': petId,
          'requestId': request.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> declineRequest(String adoptionRequestId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final requestReference = _firestore
        .collection('adoptionRequests')
        .doc(adoptionRequestId);
    final notificationReference = _firestore.collection('notifications').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestReference);
      final data = snapshot.data();
      if (data == null) {
        throw const AdoptionServiceException(
          'This adoption request could not be found.',
        );
      }
      if (data['ownerId'] != user.uid) {
        throw const AdoptionServiceException(
          'Only the listing owner can decline this request.',
        );
      }
      if (data['status'] != 'pending' && data['status'] != 'under_review') {
        throw const AdoptionServiceException(
          'This request can no longer be declined.',
        );
      }

      final applicantId = data['applicantId'] as String? ?? '';
      final petSnapshot = Map<String, dynamic>.from(
        data['petSnapshot'] as Map? ?? const {},
      );
      transaction.update(requestReference, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'notificationId': notificationReference.id,
        'recipientId': applicantId,
        'type': 'adoption_request_rejected',
        'title': 'Adoption request update',
        'message':
            'The owner declined your request to adopt ${petSnapshot['name'] ?? 'this pet'}.',
        'petId': data['petId'],
        'requestId': adoptionRequestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> withdrawRequest(String adoptionRequestId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final reference = _firestore
        .collection('adoptionRequests')
        .doc(adoptionRequestId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const AdoptionServiceException(
          'This adoption request could not be found.',
        );
      }
      if (data['applicantId'] != user.uid) {
        throw const AdoptionServiceException(
          'Only the applicant can withdraw this request.',
        );
      }
      if (data['status'] != 'pending' && data['status'] != 'under_review') {
        throw const AdoptionServiceException(
          'This request can no longer be withdrawn.',
        );
      }

      transaction.update(reference, {
        'status': 'withdrawn',
        'withdrawnAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> initiateAdoptionProcess(String conversationId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final reference = _firestore
        .collection('conversations')
        .doc(conversationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      if (data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This process is only available for adoption chats.',
        );
      }
      final petOwners = Map<String, dynamic>.from(
        data['petOwners'] as Map? ?? const {},
      );
      if (!petOwners.values.contains(user.uid)) {
        throw const AdoptionServiceException(
          'Only the pet owner can initiate the adoption process.',
        );
      }
      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['initiatedAt'] != null) return;
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';

      transaction.update(reference, {
        'adoptionProcess': {
          'currentStep': 'contract',
          'status': 'contract_pending',
          'initiatedBy': user.uid,
          'initiatedAt': FieldValue.serverTimestamp(),
          'contractSignatures': <String, dynamic>{},
          'handoverConfirmations': <String, dynamic>{},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final participantId in participantIds.where(
        (id) => id != user.uid,
      )) {
        final notification = _firestore.collection('notifications').doc();
        transaction.set(notification, {
          'notificationId': notification.id,
          'recipientId': participantId,
          'type': 'adoption_process_contract_started',
          'title': 'Adoption contract ready',
          'message':
              'The owner started the adoption contract for $petName. Please review and sign it.',
          'matchId': conversationId,
          'conversationId': conversationId,
          'requestId': data['requestId'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> signAdoptionContract(
    String conversationId, {
    required String signatureUrl,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final reference = _firestore
        .collection('conversations')
        .doc(conversationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      if (data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This process is only available for adoption chats.',
        );
      }
      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['initiatedAt'] == null) {
        throw const AdoptionServiceException(
          'The adoption contract has not been initiated yet.',
        );
      }
      final signatures = Map<String, dynamic>.from(
        process['contractSignatures'] as Map? ?? const {},
      );
      if (signatures[user.uid] != null) return;
      signatures[user.uid] = {
        'signedAt': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
      };

      final bothSigned = participantIds.every(
        (participantId) => signatures[participantId] != null,
      );
      process['contractSignatures'] = signatures;
      process['status'] = bothSigned ? 'handover_pending' : 'contract_pending';
      process['currentStep'] = bothSigned ? 'handover' : 'contract';
      if (bothSigned) {
        process['contractCompletedAt'] = FieldValue.serverTimestamp();
      }
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';

      transaction.update(reference, {
        'adoptionProcess': process,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (bothSigned) {
        for (final participantId in participantIds) {
          final notification = _firestore.collection('notifications').doc();
          transaction.set(notification, {
            'notificationId': notification.id,
            'recipientId': participantId,
            'type': 'adoption_process_handover_ready',
            'title': 'Handover is ready',
            'message':
                'Both parties signed the adoption contract for $petName. Confirm handover after the pet is safely handed over.',
            'matchId': conversationId,
            'conversationId': conversationId,
            'requestId': data['requestId'],
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Future<void> confirmAdoptionHandover(String conversationId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final reference = _firestore
        .collection('conversations')
        .doc(conversationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      if (data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This process is only available for adoption chats.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }

      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['status'] != 'handover_pending') {
        throw const AdoptionServiceException(
          'The handover can only be confirmed after both signatures are done.',
        );
      }

      final confirmations = Map<String, dynamic>.from(
        process['handoverConfirmations'] as Map? ?? const {},
      );
      if (confirmations[user.uid] != null) return;

      confirmations[user.uid] = FieldValue.serverTimestamp();
      final bothConfirmed = participantIds.every(
        (participantId) => confirmations[participantId] != null,
      );
      process['handoverConfirmations'] = confirmations;
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';
      if (bothConfirmed) {
        final protectionEndsAt = DateTime.now().toUtc().add(
          protectionWindowDuration,
        );
        process['status'] = 'protection_active';
        process['currentStep'] = 'protection';
        process['handoverCompletedAt'] = FieldValue.serverTimestamp();
        process['protectionStartedAt'] = FieldValue.serverTimestamp();
        process['protectionEndsAt'] = Timestamp.fromDate(protectionEndsAt);
      }

      transaction.update(reference, {
        'adoptionProcess': process,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (bothConfirmed) {
        for (final participantId in participantIds) {
          final notification = _firestore.collection('notifications').doc();
          transaction.set(notification, {
            'notificationId': notification.id,
            'recipientId': participantId,
            'type': 'adoption_process_protection_started',
            'title': 'Protection window started',
            'message':
                'Both parties confirmed handover for $petName. The adoption protection window is now active.',
            'matchId': conversationId,
            'conversationId': conversationId,
            'requestId': data['requestId'],
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        final otherParticipantId = participantIds
            .where((participantId) => participantId != user.uid)
            .firstOrNull;
        if (otherParticipantId != null) {
          final notification = _firestore.collection('notifications').doc();
          transaction.set(notification, {
            'notificationId': notification.id,
            'recipientId': otherParticipantId,
            'type': 'adoption_process_handover_confirmation_needed',
            'title': 'Handover confirmation needed',
            'message':
                'The other party confirmed handover for $petName. Please confirm once the pet is safely handed over.',
            'matchId': conversationId,
            'conversationId': conversationId,
            'requestId': data['requestId'],
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Future<void> processAdoptionProtectionDeadline(String conversationId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final reference = _firestore
        .collection('conversations')
        .doc(conversationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null || data['purpose'] != 'adoption') return;

      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) return;

      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['status'] != 'protection_active') return;
      if (process['returnStatus'] == 'requested') return;

      final protectionEndsAt = process['protectionEndsAt'] as Timestamp?;
      if (protectionEndsAt == null ||
          DateTime.now().toUtc().isBefore(protectionEndsAt.toDate())) {
        return;
      }

      final requestId = data['requestId'] as String? ?? '';
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';

      process['status'] = 'ready_to_complete';
      process['currentStep'] = 'done';
      process['protectionCompletedAt'] = FieldValue.serverTimestamp();

      transaction.update(reference, {
        'adoptionProcess': process,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final participantId in participantIds) {
        final notification = _firestore.collection('notifications').doc();
        transaction.set(notification, {
          'notificationId': notification.id,
          'recipientId': participantId,
          'type': 'adoption_ready_to_complete',
          'title': 'Adoption ready to complete',
          'message':
              'The protection window for $petName has ended. Complete the adoption when ready.',
          'matchId': conversationId,
          'conversationId': conversationId,
          'requestId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> completeAdoptionProcess(String conversationId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final reference = _firestore
        .collection('conversations')
        .doc(conversationId);
    final completionMessageRef = reference.collection('messages').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null || data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }

      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['returnStatus'] == 'requested') {
        throw const AdoptionServiceException(
          'This adoption cannot be completed while a return request is pending.',
        );
      }
      if (process['status'] != 'ready_to_complete' &&
          process['status'] != 'completed') {
        throw const AdoptionServiceException(
          'The protection window must finish before completing this adoption.',
        );
      }
      if (process['status'] == 'completed') return;

      final petIds =
          (data['petIds'] as List?)?.cast<String>() ?? const <String>[];
      final petId = petIds.isEmpty ? '' : petIds.first;
      final requestId = data['requestId'] as String? ?? '';
      final requestRef = requestId.isEmpty
          ? null
          : _firestore.collection('adoptionRequests').doc(requestId);
      final requestData = requestRef == null
          ? null
          : (await transaction.get(requestRef)).data();
      final petSnapshot = Map<String, dynamic>.from(
        requestData?['petSnapshot'] as Map? ?? const {},
      );
      final applicantSnapshot = Map<String, dynamic>.from(
        requestData?['applicantSnapshot'] as Map? ?? const {},
      );
      final petOwners = Map<String, dynamic>.from(
        data['petOwners'] as Map? ?? const {},
      );
      if (!petOwners.values.contains(user.uid)) {
        throw const AdoptionServiceException(
          'Only the original pet owner can mark this adoption as complete.',
        );
      }
      final originalOwnerId =
          (requestData?['ownerId'] as String?) ??
          petOwners.values.firstOrNull?.toString() ??
          '';
      final adopterId =
          (requestData?['applicantId'] as String?) ??
          participantIds.firstWhere(
            (participantId) => participantId != originalOwnerId,
            orElse: () => '',
          );
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';

      process['status'] = 'completed';
      process['currentStep'] = 'done';
      process['completedAt'] = FieldValue.serverTimestamp();
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );
      for (final participantId in participantIds) {
        unreadCounts[participantId] = participantId == user.uid
            ? 0
            : ((unreadCounts[participantId] as num?)?.toInt() ?? 0) + 1;
      }

      transaction.update(reference, {
        'status': 'completed',
        'canSendMessages': true,
        'adoptionProcess': process,
        'lastMessage': 'Adoption completed for $petName',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        'unreadCounts': unreadCounts,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(completionMessageRef, {
        'messageId': completionMessageRef.id,
        'senderId': user.uid,
        'text':
            'Adoption completed for $petName. Both users can now leave a review.',
        'type': 'adoption_process_completed',
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (petId.isNotEmpty) {
        transaction.update(_firestore.collection('pets').doc(petId), {
          if (adopterId.isNotEmpty) 'ownerId': adopterId,
          if ((applicantSnapshot['fullName'] as String?)?.isNotEmpty == true)
            'ownerName': applicantSnapshot['fullName'],
          if ((applicantSnapshot['profilePhoto'] as String?)?.isNotEmpty ==
              true)
            'ownerPhoto': applicantSnapshot['profilePhoto'],
          if (originalOwnerId.isNotEmpty) 'previousOwnerId': originalOwnerId,
          if ((petSnapshot['ownerName'] as String?)?.isNotEmpty == true)
            'previousOwnerName': petSnapshot['ownerName'],
          if ((petSnapshot['ownerPhoto'] as String?)?.isNotEmpty == true)
            'previousOwnerPhoto': petSnapshot['ownerPhoto'],
          if (adopterId.isNotEmpty) 'adoptedBy': adopterId,
          if (requestId.isNotEmpty) 'adoptionRequestId': requestId,
          'adoptionConversationId': conversationId,
          'status': 'adopted',
          'adoptionStatus': 'adopted',
          'isActive': false,
          'adoptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (requestRef != null) {
        transaction.update(requestRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      for (final participantId in participantIds) {
        final notification = _firestore.collection('notifications').doc();
        transaction.set(notification, {
          'notificationId': notification.id,
          'recipientId': participantId,
          'type': 'adoption_process_completed',
          'title': 'Adoption completed',
          'message':
              'The adoption for $petName is complete. You can now leave a review.',
          'matchId': conversationId,
          'conversationId': conversationId,
          'requestId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> requestAdoptionUpdate({
    required String conversationId,
    required String requestType,
    required String requestText,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    final trimmed = requestText.trim();
    if (trimmed.isEmpty) {
      throw const AdoptionServiceException('Please choose an update request.');
    }

    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    final requestRef = conversation.collection('adoptionUpdateRequests').doc();
    final messageRef = conversation.collection('messages').doc();
    final notification = _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversation);
      final data = snapshot.data();
      if (data == null || data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      final petOwners = Map<String, dynamic>.from(
        data['petOwners'] as Map? ?? const {},
      );
      if (!petOwners.values.contains(user.uid)) {
        throw const AdoptionServiceException(
          'Only the original pet owner can request updates.',
        );
      }
      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['status'] != 'protection_active') {
        throw const AdoptionServiceException(
          'Updates can only be requested during the protection window.',
        );
      }
      final recipientId = participantIds.firstWhere(
        (id) => id != user.uid,
        orElse: () => '',
      );
      if (recipientId.isEmpty) return;

      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );
      unreadCounts[recipientId] =
          ((unreadCounts[recipientId] as num?)?.toInt() ?? 0) + 1;
      unreadCounts[user.uid] = 0;

      final payload = {
        'requestId': requestRef.id,
        'conversationId': conversationId,
        'requestedBy': user.uid,
        'recipientId': recipientId,
        'petName': petName,
        'requestType': requestType,
        'requestText': trimmed,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(requestRef, payload);
      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': user.uid,
        'text': trimmed,
        'type': 'adoption_update_request',
        'adoptionUpdateRequestId': requestRef.id,
        'requestType': requestType,
        'requestStatus': 'pending',
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(conversation, {
        'lastMessage': 'Update requested for $petName',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        'unreadCounts': unreadCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'notificationId': notification.id,
        'recipientId': recipientId,
        'type': 'adoption_update_requested',
        'title': 'Update requested',
        'message': 'The original owner requested a photo update for $petName.',
        'purpose': 'adoption',
        'matchId': conversationId,
        'conversationId': conversationId,
        'requestId': data['requestId'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> respondToAdoptionUpdate({
    required String conversationId,
    required String updateRequestId,
    required String photoUrl,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    if (photoUrl.trim().isEmpty) {
      throw const AdoptionServiceException('Please upload a photo first.');
    }

    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    final updateRef = conversation
        .collection('adoptionUpdateRequests')
        .doc(updateRequestId);
    final messageRef = conversation.collection('messages').doc();
    final notification = _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversation);
      final data = conversationSnapshot.data();
      if (data == null || data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      final updateSnapshot = await transaction.get(updateRef);
      final updateData = updateSnapshot.data();
      if (updateData == null) {
        throw const AdoptionServiceException(
          'This update request could not be found.',
        );
      }
      if (updateData['recipientId'] != user.uid) {
        throw const AdoptionServiceException(
          'Only the adopter can respond to this update request.',
        );
      }
      final currentStatus = updateData['status'] as String? ?? 'pending';
      if (currentStatus != 'pending' && currentStatus != 'requested_again') {
        throw const AdoptionServiceException(
          'This update request is not waiting for another photo.',
        );
      }
      final recipientId = updateData['requestedBy'] as String? ?? '';
      if (recipientId.isEmpty) return;
      final petName = updateData['petName'] as String? ?? 'this pet';
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );
      unreadCounts[recipientId] =
          ((unreadCounts[recipientId] as num?)?.toInt() ?? 0) + 1;
      unreadCounts[user.uid] = 0;

      transaction.update(updateRef, {
        'status': 'responded',
        'responseMessageId': messageRef.id,
        'responsePhotoUrl': photoUrl,
        'respondedBy': user.uid,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': user.uid,
        'text': 'Photo update for $petName',
        'type': 'adoption_update_response',
        'adoptionUpdateRequestId': updateRequestId,
        'photoUrl': photoUrl,
        'requestStatus': 'responded',
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(conversation, {
        'lastMessage': 'Photo update sent for $petName',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        'unreadCounts': unreadCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'notificationId': notification.id,
        'recipientId': recipientId,
        'type': 'adoption_update_received',
        'title': 'Photo update received',
        'message': 'The adopter sent a photo update for $petName.',
        'purpose': 'adoption',
        'matchId': conversationId,
        'conversationId': conversationId,
        'requestId': data['requestId'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmAdoptionUpdate({
    required String conversationId,
    required String updateRequestId,
  }) async {
    await _updateAdoptionUpdateStatus(
      conversationId: conversationId,
      updateRequestId: updateRequestId,
      nextStatus: 'confirmed',
      message: 'Photo update confirmed.',
    );
  }

  Future<void> requestAnotherAdoptionUpdate({
    required String conversationId,
    required String updateRequestId,
    required String reason,
  }) async {
    await _updateAdoptionUpdateStatus(
      conversationId: conversationId,
      updateRequestId: updateRequestId,
      nextStatus: 'requested_again',
      message: reason,
      createMessage: true,
    );
  }

  Future<void> _updateAdoptionUpdateStatus({
    required String conversationId,
    required String updateRequestId,
    required String nextStatus,
    required String message,
    bool createMessage = false,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    var lookupUpdateRequestId = updateRequestId;
    final directUpdateSnapshot = await conversation
        .collection('adoptionUpdateRequests')
        .doc(lookupUpdateRequestId)
        .get();
    if (!directUpdateSnapshot.exists) {
      final responseLookup = await conversation
          .collection('adoptionUpdateRequests')
          .where('responseMessageId', isEqualTo: updateRequestId)
          .limit(1)
          .get();
      if (responseLookup.docs.isNotEmpty) {
        lookupUpdateRequestId = responseLookup.docs.first.id;
      }
    }
    final messageRef = conversation.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversation);
      final conversationData = conversationSnapshot.data();
      if (conversationData == null ||
          conversationData['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (conversationData['participantIds'] as List?)?.cast<String>() ??
          const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      var resolvedUpdateRequestId = lookupUpdateRequestId;
      var updateRef = conversation
          .collection('adoptionUpdateRequests')
          .doc(resolvedUpdateRequestId);
      var updateSnapshot = await transaction.get(updateRef);
      if (!updateSnapshot.exists) {
        final responseMessage = await transaction.get(
          conversation.collection('messages').doc(updateRequestId),
        );
        final responseData = responseMessage.data();
        final linkedRequestId =
            responseData?['adoptionUpdateRequestId'] as String? ?? '';
        if (linkedRequestId.isNotEmpty) {
          resolvedUpdateRequestId = linkedRequestId;
          updateRef = conversation
              .collection('adoptionUpdateRequests')
              .doc(resolvedUpdateRequestId);
          updateSnapshot = await transaction.get(updateRef);
        }
      }
      final updateData = updateSnapshot.data();
      if (updateData == null) {
        throw const AdoptionServiceException(
          'This update request could not be found.',
        );
      }
      if (updateData['requestedBy'] != user.uid) {
        throw const AdoptionServiceException(
          'Only the original pet owner can update this request.',
        );
      }
      final currentStatus = updateData['status'] as String? ?? 'pending';
      if (nextStatus == 'confirmed' && currentStatus != 'responded') {
        throw const AdoptionServiceException(
          'This photo update can no longer be confirmed.',
        );
      }
      if (nextStatus == 'requested_again' && currentStatus != 'responded') {
        throw const AdoptionServiceException(
          'Another photo can only be requested before confirming the update.',
        );
      }
      final updatePayload = <String, dynamic>{
        'status': nextStatus,
        'followUpReason': createMessage
            ? message
            : updateData['followUpReason'],
        if (createMessage) 'followUpMessageId': messageRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (nextStatus == 'confirmed') {
        updatePayload['confirmedAt'] = FieldValue.serverTimestamp();
      }
      transaction.update(updateRef, updatePayload);
      if (createMessage) {
        final recipientId = updateData['recipientId'] as String? ?? '';
        final unreadCounts = Map<String, dynamic>.from(
          conversationData['unreadCounts'] as Map? ?? const <String, dynamic>{},
        );
        if (recipientId.isNotEmpty) {
          unreadCounts[recipientId] =
              ((unreadCounts[recipientId] as num?)?.toInt() ?? 0) + 1;
        }
        unreadCounts[user.uid] = 0;
        transaction.set(messageRef, {
          'messageId': messageRef.id,
          'senderId': user.uid,
          'text': message,
          'type': 'adoption_update_follow_up',
          'adoptionUpdateRequestId': resolvedUpdateRequestId,
          'readBy': [user.uid],
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(conversation, {
          'lastMessage': 'Another update requested',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': user.uid,
          'unreadCounts': unreadCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (recipientId.isNotEmpty) {
          final notification = _firestore.collection('notifications').doc();
          final petName = updateData['petName'] as String? ?? 'this pet';
          transaction.set(notification, {
            'notificationId': notification.id,
            'recipientId': recipientId,
            'type': 'adoption_update_requested',
            'title': 'Another update requested',
            'message':
                'The original owner requested another photo update for $petName.',
            'purpose': 'adoption',
            'matchId': conversationId,
            'conversationId': conversationId,
            'requestId': conversationData['requestId'],
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Future<void> validateAdoptionReturnRequestCanBeFiled({
    required String conversationId,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }

    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();
    final data = snapshot.data();
    if (data == null || data['purpose']?.toString() != 'adoption') {
      throw const AdoptionServiceException(
        'This adoption chat could not be found.',
      );
    }

    final participantIds =
        (data['participantIds'] as List?)
            ?.map((id) => id.toString())
            .toList() ??
        const <String>[];
    if (!participantIds.contains(user.uid)) {
      throw const AdoptionServiceException(
        'You are not part of this adoption conversation.',
      );
    }

    final petOwners = Map<String, dynamic>.from(
      data['petOwners'] as Map? ?? const {},
    );
    if (petOwners.values.map((id) => id.toString()).contains(user.uid)) {
      throw const AdoptionServiceException(
        'The adopter files return requests during the protection window.',
      );
    }

    final process = Map<String, dynamic>.from(
      data['adoptionProcess'] as Map? ?? const {},
    );
    if (process['status']?.toString() != 'protection_active') {
      throw const AdoptionServiceException(
        'Return requests can only be filed during the protection window.',
      );
    }
    if (process['returnStatus']?.toString() == 'requested') {
      throw const AdoptionServiceException(
        'A return request has already been filed for this adoption.',
      );
    }
  }

  Future<void> fileAdoptionReturnRequest({
    required String conversationId,
    required String reason,
    required String description,
    required List<AdoptionEvidenceFile> evidenceFiles,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    if (reason.trim().isEmpty) {
      throw const AdoptionServiceException('Please choose a return reason.');
    }
    if (description.trim().length < 50) {
      throw const AdoptionServiceException(
        'Please describe what happened in at least 50 characters.',
      );
    }
    if (evidenceFiles.length > 3) {
      throw const AdoptionServiceException(
        'A return request can include at most three evidence files.',
      );
    }
    if (evidenceFiles.any((file) => !file.isAllowedEvidence)) {
      throw const AdoptionServiceException(
        'Evidence must be an image or video file.',
      );
    }
    if (evidenceFiles.any((file) => file.sizeBytes > 50 * 1024 * 1024)) {
      throw const AdoptionServiceException(
        'Each evidence file must be 50 MB or less.',
      );
    }

    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    final returnRef = conversation.collection('adoptionReturnRequests').doc();
    final adminReturnRef = _firestore
        .collection('adoptionReturnRequests')
        .doc(returnRef.id);
    final messageRef = conversation.collection('messages').doc();
    final notification = _firestore.collection('notifications').doc();
    final evidence = evidenceFiles.map((file) => file.toMap()).toList();
    final evidenceUrls = evidenceFiles.map((file) => file.url).toList();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversation);
      final data = snapshot.data();
      if (data == null || data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This adoption chat could not be found.',
        );
      }
      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      final petOwners = Map<String, dynamic>.from(
        data['petOwners'] as Map? ?? const {},
      );
      if (petOwners.values.contains(user.uid)) {
        throw const AdoptionServiceException(
          'The adopter files return requests during the protection window.',
        );
      }
      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['status'] != 'protection_active') {
        throw const AdoptionServiceException(
          'Return requests can only be filed during the protection window.',
        );
      }
      if (process['returnStatus'] == 'requested') {
        throw const AdoptionServiceException(
          'A return request has already been filed for this adoption.',
        );
      }
      final ownerId = petOwners.values.firstOrNull?.toString() ?? '';
      if (ownerId.isEmpty) return;
      final petIds =
          (data['petIds'] as List?)?.map((id) => id.toString()).toList() ??
          const <String>[];
      final petId = petIds.firstOrNull ?? '';
      final petNames = Map<String, dynamic>.from(
        data['petNames'] as Map? ?? const {},
      );
      final petName = petNames.values.firstOrNull?.toString() ?? 'this pet';
      final requestId = data['requestId'] as String? ?? '';
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const <String, dynamic>{},
      );
      unreadCounts[ownerId] =
          ((unreadCounts[ownerId] as num?)?.toInt() ?? 0) + 1;
      unreadCounts[user.uid] = 0;

      final returnData = {
        'returnRequestId': returnRef.id,
        'conversationId': conversationId,
        'requestId': requestId,
        'petId': petId,
        'petName': petName,
        'participantIds': participantIds,
        'filedBy': user.uid,
        'adopterId': user.uid,
        'ownerId': ownerId,
        'reason': reason,
        'description': description.trim(),
        'evidenceFiles': evidence,
        'evidenceUrls': evidenceUrls,
        'status': 'pendingAdminReview',
        'adminStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.set(returnRef, {...returnData, 'status': 'pending'});
      transaction.set(adminReturnRef, returnData);
      process['returnStatus'] = 'requested';
      process['returnRequestId'] = returnRef.id;
      transaction.update(conversation, {
        'adoptionProcess': process,
        'lastMessage': 'Return request filed for $petName',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        'unreadCounts': unreadCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': user.uid,
        'text': 'Return request filed: $reason',
        'type': 'adoption_return_request',
        'adoptionReturnRequestId': returnRef.id,
        'reason': reason,
        'description': description.trim(),
        'evidenceFiles': evidence,
        'evidenceUrls': evidenceUrls,
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'notificationId': notification.id,
        'recipientId': ownerId,
        'type': 'adoption_return_requested',
        'title': 'Return request filed',
        'message': 'The adopter filed a return request for $petName.',
        'purpose': 'adoption',
        'matchId': conversationId,
        'conversationId': conversationId,
        'requestId': data['requestId'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> processAdoptionReturnDecision({
    required String returnRequestId,
    required bool approved,
    required String adminNote,
  }) async {
    final admin = UserSessionService.instance.currentUser;
    if (admin == null ||
        !await UserSessionService.instance.isCurrentUserAdmin()) {
      throw const AdoptionServiceException(
        'Admin permission is required for this action.',
      );
    }
    if (adminNote.trim().isEmpty) {
      throw const AdoptionServiceException('Please add an admin note first.');
    }

    final topRef = _firestore
        .collection('adoptionReturnRequests')
        .doc(returnRequestId);
    await _firestore.runTransaction((transaction) async {
      final topSnapshot = await transaction.get(topRef);
      final returnData = topSnapshot.data();
      if (returnData == null) {
        throw const AdoptionServiceException(
          'This return request was not found.',
        );
      }
      final existingStatus = (returnData['adminStatus'] ?? returnData['status'])
          ?.toString();
      if (existingStatus != 'pending' &&
          existingStatus != 'pendingAdminReview') {
        throw const AdoptionServiceException(
          'This return request has already been decided.',
        );
      }
      final conversationId = returnData['conversationId']?.toString() ?? '';
      if (conversationId.isEmpty) {
        throw const AdoptionServiceException(
          'The linked adoption conversation was not found.',
        );
      }
      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);
      final nestedRef = conversationRef
          .collection('adoptionReturnRequests')
          .doc(returnRequestId);
      final conversationSnapshot = await transaction.get(conversationRef);
      final nestedSnapshot = await transaction.get(nestedRef);
      final conversationData = conversationSnapshot.data();
      if (conversationData == null ||
          conversationData['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'The linked adoption conversation was not found.',
        );
      }
      final process = Map<String, dynamic>.from(
        conversationData['adoptionProcess'] as Map? ?? const {},
      );
      if (process['returnRequestId']?.toString() != returnRequestId ||
          process['returnStatus'] != 'requested') {
        throw const AdoptionServiceException(
          'The adoption is no longer waiting for this return decision.',
        );
      }

      final decision = approved ? 'approved' : 'denied';
      final petName = returnData['petName']?.toString() ?? 'this pet';
      final participantIds =
          (conversationData['participantIds'] as List? ?? const [])
              .map((id) => id.toString())
              .toList();
      final decisionMessage = approved
          ? 'Breedr approved the return request for $petName. Arrange the physical return in chat, then both parties must confirm the handover.'
          : 'Breedr denied the return request for $petName. The adoption protection window remains active.';

      process['returnStatus'] = decision;
      process['returnResolvedAt'] = FieldValue.serverTimestamp();
      if (approved) {
        process['status'] = 'return_approved';
        process['currentStep'] = 'protection';
        process['returnHandoverConfirmations'] = <String, dynamic>{};
        process['protectionPausedAt'] = FieldValue.serverTimestamp();
      }

      final decisionFields = <String, dynamic>{
        'adminStatus': decision,
        'status': decision,
        'adminDecision': decision,
        'adminNote': adminNote.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': admin.uid,
        'resolvedByEmail': admin.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(topRef, decisionFields);
      transaction.set(nestedRef, {
        ...?nestedSnapshot.data(),
        ...decisionFields,
      });
      transaction.update(conversationRef, {
        'adoptionProcess': process,
        'canSendMessages': true,
        'lastMessage': approved
            ? 'Return approved - arrange handover'
            : 'Return request denied',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': 'system',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final messageRef = conversationRef.collection('messages').doc();
      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': 'system',
        'text': decisionMessage,
        'type': 'adoption_return_decision',
        'isSystemMessage': true,
        'adoptionReturnRequestId': returnRequestId,
        'returnDecision': decision,
        'readBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final participantId in participantIds) {
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'notificationId': notificationRef.id,
          'recipientId': participantId,
          'type': 'adoption_return_decision',
          'title': approved
              ? 'Return request approved'
              : 'Return request denied',
          'message': decisionMessage,
          'purpose': 'adoption',
          'matchId': conversationId,
          'conversationId': conversationId,
          'requestId': returnData['requestId'],
          'adoptionReturnRequestId': returnRequestId,
          'returnDecision': decision,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      final activityRef = _firestore.collection('adminActivity').doc();
      transaction.set(activityRef, {
        'type': 'return',
        'action': approved ? 'Approved Return' : 'Denied Return',
        'status': decision,
        'decision': decision,
        'targetId': returnData['petId'],
        'targetName': petName,
        'returnRequestId': returnRequestId,
        'conversationId': conversationId,
        'reason': returnData['reason'],
        'ownerId': returnData['ownerId'],
        'adopterId': returnData['adopterId'],
        'adminId': admin.uid,
        'adminEmail': admin.email,
        'note': adminNote.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmAdoptionReturnHandover(String conversationId) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);
      final data = conversationSnapshot.data();
      if (data == null || data['purpose'] != 'adoption') {
        throw const AdoptionServiceException(
          'This adoption chat was not found.',
        );
      }
      final participantIds = (data['participantIds'] as List? ?? const [])
          .map((id) => id.toString())
          .toList();
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption chat.',
        );
      }
      final process = Map<String, dynamic>.from(
        data['adoptionProcess'] as Map? ?? const {},
      );
      if (process['status'] != 'return_approved') {
        throw const AdoptionServiceException(
          'The return handover is not awaiting confirmation.',
        );
      }
      final returnRequestId = process['returnRequestId']?.toString() ?? '';
      final requestId = data['requestId']?.toString() ?? '';
      final petIds = (data['petIds'] as List? ?? const [])
          .map((id) => id.toString())
          .toList();
      if (returnRequestId.isEmpty || requestId.isEmpty || petIds.isEmpty) {
        throw const AdoptionServiceException(
          'The linked return records are incomplete.',
        );
      }
      final topRef = _firestore
          .collection('adoptionReturnRequests')
          .doc(returnRequestId);
      final nestedRef = conversationRef
          .collection('adoptionReturnRequests')
          .doc(returnRequestId);
      final adoptionRequestRef = _firestore
          .collection('adoptionRequests')
          .doc(requestId);
      final petRef = _firestore.collection('pets').doc(petIds.first);
      final topSnapshot = await transaction.get(topRef);
      final nestedSnapshot = await transaction.get(nestedRef);
      final adoptionRequestSnapshot = await transaction.get(adoptionRequestRef);
      final petSnapshot = await transaction.get(petRef);
      if (!topSnapshot.exists ||
          !nestedSnapshot.exists ||
          !adoptionRequestSnapshot.exists ||
          !petSnapshot.exists) {
        throw const AdoptionServiceException(
          'The linked return records could not be loaded.',
        );
      }
      final requestData = adoptionRequestSnapshot.data()!;
      final originalOwnerId = requestData['ownerId']?.toString() ?? '';
      final adopterId = requestData['applicantId']?.toString() ?? '';
      if ({originalOwnerId, adopterId}.contains(user.uid) == false) {
        throw const AdoptionServiceException(
          'Only the original owner and adopter can confirm this handover.',
        );
      }
      final confirmations = Map<String, dynamic>.from(
        process['returnHandoverConfirmations'] as Map? ?? const {},
      );
      if (confirmations[user.uid] != null) return;
      confirmations[user.uid] = FieldValue.serverTimestamp();
      final bothConfirmed =
          originalOwnerId.isNotEmpty &&
          adopterId.isNotEmpty &&
          confirmations[originalOwnerId] != null &&
          confirmations[adopterId] != null;
      process['returnHandoverConfirmations'] = confirmations;
      process['returnStatus'] = bothConfirmed
          ? 'completed'
          : 'handover_pending';
      if (bothConfirmed) {
        process['status'] = 'returned';
        process['currentStep'] = 'done';
        process['returnCompletedAt'] = FieldValue.serverTimestamp();
      }
      final petName = topSnapshot.data()?['petName']?.toString() ?? 'this pet';
      final returnFields = <String, dynamic>{
        'handoverConfirmations': confirmations,
        'status': bothConfirmed ? 'completed' : 'handoverPending',
        if (bothConfirmed) 'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(topRef, returnFields);
      transaction.update(nestedRef, returnFields);
      transaction.update(conversationRef, {
        'adoptionProcess': process,
        'status': bothConfirmed ? 'returned' : data['status'],
        'canSendMessages': true,
        'lastMessage': bothConfirmed
            ? 'Pet return completed for $petName'
            : 'Return handover pending',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        if (bothConfirmed) 'returnedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (bothConfirmed) {
        final ownerSnapshot = Map<String, dynamic>.from(
          requestData['petSnapshot'] as Map? ?? const {},
        );
        transaction.update(petRef, {
          'ownerId': originalOwnerId,
          if (ownerSnapshot['ownerName'] != null)
            'ownerName': ownerSnapshot['ownerName'],
          if (ownerSnapshot['ownerPhoto'] != null)
            'ownerPhoto': ownerSnapshot['ownerPhoto'],
          'status': 'unpublished',
          'adoptionStatus': 'returned',
          'isActive': false,
          'purpose': 'pet',
          'returnedAt': FieldValue.serverTimestamp(),
          'returnedFromAdoptionRequestId': requestId,
          'returnedFromConversationId': conversationId,
          'adoptedBy': FieldValue.delete(),
          'adoptedAt': FieldValue.delete(),
          'reservedFor': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(adoptionRequestRef, {
          'status': 'completed',
          'outcome': 'returned',
          'returnRequestId': returnRequestId,
          'returnCompletedAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
          'reviewsEnabled': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final returnedRef = _firestore
            .collection('returnedPets')
            .doc(returnRequestId);
        transaction.set(returnedRef, {
          'returnedPetId': returnRequestId,
          'returnRequestId': returnRequestId,
          'conversationId': conversationId,
          'adoptionRequestId': requestId,
          'petId': petIds.first,
          'petName': petName,
          'ownerId': originalOwnerId,
          'adopterId': adopterId,
          'participantIds': participantIds,
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      final messageRef = conversationRef.collection('messages').doc();
      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': user.uid,
        'text': bothConfirmed
            ? 'Both parties confirmed the physical return of $petName. The return is complete.'
            : 'Return handover pending. Waiting for the other party to confirm.',
        'type': 'adoption_return_handover',
        'returnCompleted': bothConfirmed,
        'readBy': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final participantId in participantIds) {
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'notificationId': notificationRef.id,
          'recipientId': participantId,
          'type': bothConfirmed
              ? 'adoption_return_completed'
              : 'adoption_return_handover_pending',
          'title': bothConfirmed
              ? 'Pet return completed'
              : 'Return handover pending',
          'message': bothConfirmed
              ? '$petName was restored to the original owner\'s pets and remains unpublished.'
              : 'One party confirmed the return of $petName. The other party still needs to confirm.',
          'purpose': 'adoption',
          'matchId': conversationId,
          'conversationId': conversationId,
          'requestId': requestId,
          'adoptionReturnRequestId': returnRequestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> reportPetListing({
    required AdoptionListing listing,
    required String reason,
    required String detail,
    List<AdoptionEvidenceFile> evidenceFiles = const [],
  }) async {
    await reportPetListingSnapshot(
      petId: listing.id,
      petName: listing.name,
      species: listing.species,
      breed: listing.breed,
      purpose: 'adoption',
      profilePhoto: listing.profilePhoto,
      ownerId: listing.ownerId,
      ownerName: listing.ownerName,
      reason: reason,
      detail: detail,
      evidenceFiles: evidenceFiles,
    );
  }

  Future<void> reportPetListingSnapshot({
    required String petId,
    required String petName,
    required String species,
    required String breed,
    required String purpose,
    required String profilePhoto,
    required String ownerId,
    required String ownerName,
    required String reason,
    required String detail,
    List<AdoptionEvidenceFile> evidenceFiles = const [],
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    if (ownerId == user.uid) {
      throw const AdoptionServiceException(
        'You cannot report your own listing.',
      );
    }
    await _createReport(
      type: 'listing',
      targetId: petId,
      reportedUserId: ownerId,
      reason: reason,
      detail: detail,
      evidenceFiles: evidenceFiles,
      targetSnapshot: {
        'petId': petId,
        'petName': petName,
        'species': species,
        'breed': breed,
        'purpose': purpose.trim().toLowerCase(),
        'profilePhoto': profilePhoto,
        'ownerId': ownerId,
        'ownerName': ownerName,
      },
      duplicateMessage:
          'You have already submitted a report for this pet listing.',
    );
  }

  Future<void> reportUser({
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
    required String detail,
    List<AdoptionEvidenceFile> evidenceFiles = const [],
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    if (reportedUserId == user.uid) {
      throw const AdoptionServiceException(
        'You cannot report your own profile.',
      );
    }
    await _createReport(
      type: 'user',
      targetId: reportedUserId,
      reportedUserId: reportedUserId,
      reason: reason,
      detail: detail,
      evidenceFiles: evidenceFiles,
      targetSnapshot: {
        'userId': reportedUserId,
        'displayName': reportedUserName,
      },
      duplicateMessage: 'You have already submitted a report for this user.',
    );
  }

  Future<void> _createReport({
    required String type,
    required String targetId,
    required String reportedUserId,
    required String reason,
    required String detail,
    required List<AdoptionEvidenceFile> evidenceFiles,
    required Map<String, dynamic> targetSnapshot,
    required String duplicateMessage,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    final trimmedReason = reason.trim();
    final trimmedDetail = detail.trim();
    if (trimmedReason.isEmpty) {
      throw const AdoptionServiceException('Please choose a report reason.');
    }
    if (trimmedReason.toLowerCase() == 'other' && trimmedDetail.length < 10) {
      throw const AdoptionServiceException(
        'Please add a short detail for this report.',
      );
    }
    if (evidenceFiles.length > 3) {
      throw const AdoptionServiceException(
        'A report can include at most three evidence files.',
      );
    }
    if (evidenceFiles.any((file) => !file.isAllowedEvidence)) {
      throw const AdoptionServiceException(
        'Evidence must be an image or video file.',
      );
    }
    if (evidenceFiles.any((file) => file.sizeBytes > 50 * 1024 * 1024)) {
      throw const AdoptionServiceException(
        'Each evidence file must be 50 MB or less.',
      );
    }

    final activeReport = await _firestore
        .collection('reports')
        .where('type', isEqualTo: type)
        .where('targetId', isEqualTo: targetId)
        .where('reporterId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (activeReport.docs.isNotEmpty) {
      throw AdoptionServiceException(duplicateMessage);
    }

    final reports = _firestore.collection('reports');
    final reportRef = reports.doc(
      '${type}_${targetId}_${DateTime.now().millisecondsSinceEpoch}_${user.uid}',
    );
    final reportId = reportRef.id;
    final evidence = evidenceFiles.map((file) => file.toMap()).toList();
    final evidenceUrls = evidenceFiles.map((file) => file.url).toList();
    final reporterSnapshot = await _currentReporterSnapshot(user.uid);

    await reportRef.set({
      'reportId': reportId,
      'reportKey': '${type}_${targetId}_${user.uid}',
      'type': type,
      'targetId': targetId,
      'reportedUserId': reportedUserId,
      'reporterId': user.uid,
      'reporterSnapshot': reporterSnapshot,
      'reason': trimmedReason,
      'detail': trimmedDetail,
      'evidenceFiles': evidence,
      'evidenceUrls': evidenceUrls,
      'targetSnapshot': targetSnapshot,
      'status': 'pending',
      'adminAction': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> _currentReporterSnapshot(String userId) async {
    final user = UserSessionService.instance.currentUser;
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      return {
        'userId': userId,
        'fullName': data['fullName'] ?? user?.displayName ?? '',
        'userName': data['userName'] ?? data['username'] ?? '',
        'email': data['email'] ?? user?.email ?? '',
        'profilePhoto': data['profilePhoto'] ?? '',
      };
    } catch (_) {
      return {
        'userId': userId,
        'fullName': user?.displayName ?? '',
        'userName': '',
        'email': user?.email ?? '',
        'profilePhoto': '',
      };
    }
  }

  Future<void> submitAdoptionReview({
    required String conversationId,
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
    if (user == null) {
      throw const AdoptionServiceException('Please sign in again.');
    }
    if (photoUrls.length > 3) {
      throw const AdoptionServiceException(
        'A review can contain at most three photos.',
      );
    }
    final ratings = [
      overall,
      communication,
      careResponsibility,
      transparency,
      reliability,
    ];
    if (ratings.any((rating) => rating < 1 || rating > 5)) {
      throw const AdoptionServiceException(
        'Every rating must be between one and five.',
      );
    }

    final conversationReference = _firestore
        .collection('conversations')
        .doc(conversationId);
    final reviewReference = _firestore
        .collection('reviews')
        .doc('${conversationId}_${user.uid}');

    await _firestore.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationReference);
      final data = conversationSnapshot.data();
      if (data == null ||
          data['purpose'] != 'adoption' ||
          data['status'] != 'completed') {
        throw const AdoptionServiceException(
          'Reviews require a completed adoption.',
        );
      }

      final participantIds =
          (data['participantIds'] as List?)?.cast<String>() ?? const <String>[];
      if (!participantIds.contains(user.uid)) {
        throw const AdoptionServiceException(
          'You are not part of this adoption transaction.',
        );
      }

      final reviewsSubmitted = Map<String, dynamic>.from(
        data['reviewsSubmitted'] as Map? ?? const <String, dynamic>{},
      );
      if (reviewsSubmitted[user.uid] == true) {
        throw const AdoptionServiceException(
          'You already reviewed this adoption.',
        );
      }

      final reviewedUserId = participantIds.firstWhere(
        (participantId) => participantId != user.uid,
      );
      final petOwners = Map<String, dynamic>.from(
        data['petOwners'] as Map? ?? const <String, dynamic>{},
      );
      final petOwnerIds = petOwners.values.whereType<String>().toSet();
      final reviewedUserRole = petOwnerIds.contains(reviewedUserId)
          ? 'petOwner'
          : 'adopter';
      final reviewerRole = petOwnerIds.contains(user.uid)
          ? 'petOwner'
          : 'adopter';
      final otherReviewReference = _firestore
          .collection('reviews')
          .doc('${conversationId}_$reviewedUserId');
      final completedAt =
          (data['completedAt'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc();
      final bothSubmitted = reviewsSubmitted[reviewedUserId] == true;

      transaction.set(reviewReference, {
        'reviewId': reviewReference.id,
        'matchId': conversationId,
        'purpose': 'adoption',
        'reviewerId': user.uid,
        'reviewerRole': reviewerRole,
        'reviewedUserId': reviewedUserId,
        'reviewedUserRole': reviewedUserRole,
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
        'visibleAfter': Timestamp.fromDate(
          completedAt.add(const Duration(days: 7)),
        ),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(conversationReference, {
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

  String? _listingValidationReason({
    required AdoptionListing? listing,
    required String currentUserId,
    required DocumentSnapshot<Map<String, dynamic>> existingRequest,
  }) {
    if (listing == null) {
      return 'This adoption listing could not be found.';
    }
    if (listing.ownerId == currentUserId) {
      return 'You cannot submit an adoption request for your own pet.';
    }
    if (!listing.isAvailable) {
      return 'This pet is no longer available for adoption.';
    }
    if (!listing.hasValidPrice) {
      return 'This paid listing does not currently have a valid price.';
    }
    if (existingRequest.exists) {
      final status = existingRequest.data()?['status'] as String? ?? 'pending';
      switch (status) {
        case 'approved':
          return 'Your adoption request has already been approved.';
        case 'rejected':
          return 'This adoption request was previously declined.';
        case 'withdrawn':
          return 'You previously withdrew your request for this pet.';
        case 'completed':
          return 'This adoption request has already been completed.';
        default:
          return 'You already have an active request for this pet.';
      }
    }
    return null;
  }

  List<AdoptionAnswer> _normalizedAnswers(
    List<AdoptionQuestion> questions,
    List<AdoptionAnswer> answers,
  ) {
    if (answers.map((answer) => answer.questionId).toSet().length !=
        answers.length) {
      throw const AdoptionServiceException(
        'A question cannot contain more than one answer.',
      );
    }
    final answersById = {
      for (final answer in answers) answer.questionId: answer,
    };
    final validQuestionIds = questions.map((question) => question.id).toSet();
    if (answersById.keys.any((id) => !validQuestionIds.contains(id))) {
      throw const AdoptionServiceException(
        'One of the submitted questions is no longer part of this listing.',
      );
    }

    final normalized = <AdoptionAnswer>[];
    for (final question in questions) {
      final answer = answersById[question.id];
      if (question.required && (answer == null || !answer.hasValue)) {
        throw AdoptionServiceException(
          'Please answer the required question: ${question.text}',
        );
      }
      if (answer == null) continue;
      if (answer.type != question.type) {
        throw const AdoptionServiceException(
          'One of the submitted answers no longer matches the listing.',
        );
      }
      if (question.type == 'multipleChoice' &&
          !question.options.contains(answer.value)) {
        throw const AdoptionServiceException(
          'One of the selected answers is no longer available.',
        );
      }
      normalized.add(
        AdoptionAnswer(
          questionId: question.id,
          questionText: question.text,
          type: question.type,
          value: answer.value,
          order: question.order,
        ),
      );
    }
    return normalized;
  }
}
