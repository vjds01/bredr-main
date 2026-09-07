import 'package:cloud_firestore/cloud_firestore.dart';

import 'breed_options.dart';

enum AdoptionListingStatus { active, reserved, adopted, paused, removed }

enum AdoptionRequestStatus {
  pending,
  underReview,
  approved,
  rejected,
  withdrawn,
  completed,
}

enum AdoptionType { free, forSale }

class AdoptionPolicy {
  static const paymentDisclaimer =
      'Breedr does not process or verify payments. Any payment arrangements '
      'are made directly between you and the pet owner. Exercise caution '
      'before transferring money.';
}

DateTime? _dateTimeFromAny(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class AdoptionQuestion {
  final String id;
  final String text;
  final String type;
  final List<String> options;
  final bool required;
  final int order;

  const AdoptionQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
    required this.required,
    required this.order,
  });

  factory AdoptionQuestion.fromMap(
    Map<String, dynamic> data, {
    required int index,
  }) {
    return AdoptionQuestion(
      id: (data['questionId'] as String?)?.trim().isNotEmpty == true
          ? data['questionId'] as String
          : 'question_$index',
      text: (data['text'] as String? ?? data['question'] as String? ?? '')
          .trim(),
      type: (data['type'] as String? ?? 'textAnswer').trim(),
      options: ((data['choices'] as List?) ?? (data['options'] as List?) ?? [])
          .whereType<String>()
          .toList(),
      required: data['required'] as bool? ?? true,
      order: (data['order'] as num?)?.toInt() ?? index,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': id,
      'text': text,
      'type': type,
      'choices': options,
      'required': required,
      'order': order,
    };
  }

  bool get isValid {
    if (id.isEmpty || text.isEmpty) return false;
    if (type == 'multipleChoice' && options.isEmpty) return false;
    return const {
      'multipleChoice',
      'textAnswer',
      'yesNo',
      'rating',
    }.contains(type);
  }
}

class AdoptionAnswer {
  final String questionId;
  final String questionText;
  final String type;
  final dynamic value;
  final int order;

  const AdoptionAnswer({
    required this.questionId,
    required this.questionText,
    required this.type,
    required this.value,
    required this.order,
  });

  factory AdoptionAnswer.fromMap(Map<String, dynamic> data) {
    return AdoptionAnswer(
      questionId: data['questionId'] as String? ?? '',
      questionText:
          data['questionText'] as String? ??
          data['questionSnapshot'] as String? ??
          '',
      type: data['type'] as String? ?? 'textAnswer',
      value: data['answer'],
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionText': questionText,
      'type': type,
      'answer': value,
      'order': order,
    };
  }

  bool get hasValue {
    if (value == null) return false;
    if (value is String) return (value as String).trim().isNotEmpty;
    if (value is num) return value >= 1 && value <= 5;
    if (value is bool) return true;
    return false;
  }
}

class AdoptionListing {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;
  final String purpose;
  final String name;
  final String species;
  final String breed;
  final String primaryBreed;
  final String secondaryBreed;
  final bool isMixedBreed;
  final List<String> breedTags;
  final String breedSize;
  final String age;
  final String gender;
  final String color;
  final String about;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String profilePhoto;
  final List<String> additionalImages;
  final List<String> additionalVideos;
  final List<Map<String, dynamic>> healthRecords;
  final List<AdoptionQuestion> questions;
  final AdoptionType adoptionType;
  final double? price;
  final bool priceNegotiable;
  final bool noOtherPets;
  final bool vetVerified;
  final AdoptionListingStatus status;
  final bool isActive;
  final String adminListingStatus;
  final bool adminHidden;
  final bool adminRemoved;
  final DateTime? adminHiddenUntil;
  final String moderationListingStatus;
  final DateTime? moderationHiddenUntil;
  final String moderationSourceAction;
  final String? reservedFor;
  final String? approvedRequestId;
  final String listingCycleId;

  const AdoptionListing({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
    required this.purpose,
    required this.name,
    required this.species,
    required this.breed,
    required this.primaryBreed,
    required this.secondaryBreed,
    required this.isMixedBreed,
    required this.breedTags,
    required this.breedSize,
    required this.age,
    required this.gender,
    required this.color,
    required this.about,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.profilePhoto,
    required this.additionalImages,
    required this.additionalVideos,
    required this.healthRecords,
    required this.questions,
    required this.adoptionType,
    required this.price,
    required this.priceNegotiable,
    required this.noOtherPets,
    required this.vetVerified,
    required this.status,
    required this.isActive,
    required this.adminListingStatus,
    required this.adminHidden,
    required this.adminRemoved,
    required this.adminHiddenUntil,
    required this.moderationListingStatus,
    required this.moderationHiddenUntil,
    required this.moderationSourceAction,
    required this.reservedFor,
    required this.approvedRequestId,
    required this.listingCycleId,
  });

  factory AdoptionListing.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final details = Map<String, dynamic>.from(
      data['adoptionDetails'] as Map? ?? const <String, dynamic>{},
    );
    final rawQuestions = data['interviewQuestions'] as List? ?? const [];
    final questions = <AdoptionQuestion>[
      for (var index = 0; index < rawQuestions.length; index++)
        if (rawQuestions[index] is Map)
          AdoptionQuestion.fromMap(
            Map<String, dynamic>.from(rawQuestions[index] as Map),
            index: index,
          ),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final rawType = (details['adoptionType'] as String? ?? 'FREE')
        .toUpperCase();
    final rawStatus =
        (data['adoptionStatus'] as String? ??
                data['status'] as String? ??
                'active')
            .toLowerCase();

    final primaryBreed = data['primaryBreed'] as String? ?? '';
    final secondaryBreed = data['secondaryBreed'] as String? ?? '';
    final isMixedBreed = data['isMixedBreed'] as bool? ?? false;
    final breed = data['breed'] as String? ?? '';
    final storedBreedTags =
        (data['breedTags'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final derivedBreedTags = storedBreedTags.isNotEmpty
        ? storedBreedTags
        : _deriveBreedTags(
            breed: breed,
            primaryBreed: primaryBreed,
            secondaryBreed: secondaryBreed,
            isMixedBreed: isMixedBreed,
          );

    return AdoptionListing(
      id: document.id,
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Pet Owner',
      ownerPhoto: data['ownerPhoto'] as String? ?? '',
      purpose: (data['normalizedPurpose'] ?? data['purpose'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      name: data['name'] as String? ?? 'Pet',
      species: data['species'] as String? ?? '',
      breed: breed,
      primaryBreed: primaryBreed,
      secondaryBreed: secondaryBreed,
      isMixedBreed: isMixedBreed,
      breedTags: derivedBreedTags,
      breedSize: data['breedSize'] as String? ?? '',
      age: data['age'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      color: data['color'] as String? ?? '',
      about: data['about'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      profilePhoto:
          data['petProfilePhoto'] as String? ??
          data['profilePhoto'] as String? ??
          '',
      additionalImages: _stringListFromAny(
        data['additionalImages'] ??
            data['additionalPhotos'] ??
            data['additionalPhotoUrls'] ??
            data['morePhotos'],
      ),
      additionalVideos: _stringListFromAny(
        data['additionalVideos'] ?? data['additionalVideoUrls'],
      ),
      healthRecords:
          (data['healthRecords'] as List?)
              ?.whereType<Map>()
              .map((record) => Map<String, dynamic>.from(record))
              .toList() ??
          const [],
      questions: questions.where((question) => question.isValid).toList(),
      adoptionType:
          rawType == 'FOR SALE' || rawType == 'FOR_SALE' || rawType == 'FORSALE'
          ? AdoptionType.forSale
          : AdoptionType.free,
      price: rawType == 'FREE' ? null : (details['price'] as num?)?.toDouble(),
      priceNegotiable: details['priceNegotiable'] as bool? ?? false,
      noOtherPets: details['noOtherPets'] as bool? ?? false,
      vetVerified: data['vetVerified'] == true,
      status: _listingStatus(rawStatus),
      isActive: data['isActive'] as bool? ?? true,
      adminListingStatus: (data['adminListingStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      adminHidden: data['adminHidden'] as bool? ?? false,
      adminRemoved: data['adminRemoved'] as bool? ?? false,
      adminHiddenUntil: _dateTimeFromAny(data['adminHiddenUntil']),
      moderationListingStatus: (data['moderationListingStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      moderationHiddenUntil: _dateTimeFromAny(data['moderationHiddenUntil']),
      moderationSourceAction: (data['moderationSourceAction'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      reservedFor: data['reservedFor'] as String?,
      approvedRequestId: data['approvedRequestId'] as String?,
      listingCycleId:
          (data['listingCycleId'] ?? data['returnedFromAdoptionRequestId'])
              ?.toString() ??
          '',
    );
  }

  static List<String> _deriveBreedTags({
    required String breed,
    required String primaryBreed,
    required String secondaryBreed,
    required bool isMixedBreed,
  }) {
    final tags = breedTagsFor(
      isMixedBreed: isMixedBreed,
      primaryBreed: primaryBreed.isNotEmpty ? primaryBreed : breed,
      secondaryBreed: secondaryBreed,
    );
    if (tags.isNotEmpty) return tags;
    final fallback = breed.trim();
    return fallback.isEmpty ? const [] : [fallback];
  }

  static AdoptionListingStatus _listingStatus(String value) {
    switch (value) {
      case 'reserved':
        return AdoptionListingStatus.reserved;
      case 'adopted':
        return AdoptionListingStatus.adopted;
      case 'paused':
        return AdoptionListingStatus.paused;
      case 'removed':
        return AdoptionListingStatus.removed;
      case 'published':
      case 'active':
      default:
        return AdoptionListingStatus.active;
    }
  }

  bool get isForSale => adoptionType == AdoptionType.forSale;
  bool get isHiddenByAdmin {
    if (moderationListingStatus == 'removed') return true;
    if (moderationListingStatus == 'hidden') {
      // Older admin warnings incorrectly hid every listing indefinitely.
      // A warning is notice-only, so those legacy records remain visible.
      if (moderationSourceAction == 'warned') return false;
      final until = moderationHiddenUntil;
      return until == null || until.isAfter(DateTime.now());
    }
    if (adminRemoved || adminListingStatus == 'removed') return true;
    if (status == AdoptionListingStatus.removed) return true;
    if (adminListingStatus == 'hidden') {
      final until = adminHiddenUntil;
      return until == null || until.isAfter(DateTime.now());
    }
    return adminHidden;
  }

  bool get isAvailable =>
      purpose == 'adoption' &&
      isActive &&
      !isHiddenByAdmin &&
      status == AdoptionListingStatus.active;
  bool get hasValidPrice => !isForSale || (price != null && price! > 0);

  Map<String, dynamic> snapshot() {
    return {
      'petId': id,
      'name': name,
      'species': species,
      'breed': breed,
      'primaryBreed': primaryBreed,
      'secondaryBreed': secondaryBreed,
      'isMixedBreed': isMixedBreed,
      'breedTags': breedTags,
      'breedSize': breedSize,
      'age': age,
      'gender': gender,
      'color': color,
      'locationName': locationName,
      'petProfilePhoto': profilePhoto,
      'adoptionType': isForSale ? 'forSale' : 'free',
      'price': price,
      'ownerName': ownerName,
      'ownerPhoto': ownerPhoto,
      'vetVerified': vetVerified,
      'listingCycleId': listingCycleId,
    };
  }
}

List<String> _stringListFromAny(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

class AdoptionRequest {
  final String id;
  final String petId;
  final String ownerId;
  final String applicantId;
  final AdoptionRequestStatus status;
  final List<AdoptionAnswer> answers;
  final Map<String, dynamic> petSnapshot;
  final Map<String, dynamic> applicantSnapshot;
  final String? conversationId;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? completedAt;
  final String outcome;

  const AdoptionRequest({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.applicantId,
    required this.status,
    required this.answers,
    required this.petSnapshot,
    required this.applicantSnapshot,
    required this.conversationId,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.outcome,
  });

  factory AdoptionRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawAnswers = data['answers'] as List? ?? const [];
    return AdoptionRequest(
      id: document.id,
      petId: data['petId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      applicantId: data['applicantId'] as String? ?? '',
      status: _requestStatus(data['status'] as String? ?? 'pending'),
      answers:
          rawAnswers
              .whereType<Map>()
              .map(
                (answer) =>
                    AdoptionAnswer.fromMap(Map<String, dynamic>.from(answer)),
              )
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order)),
      petSnapshot: Map<String, dynamic>.from(
        data['petSnapshot'] as Map? ?? const <String, dynamic>{},
      ),
      applicantSnapshot: Map<String, dynamic>.from(
        data['applicantSnapshot'] as Map? ?? const <String, dynamic>{},
      ),
      conversationId: data['conversationId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      completedAt: data['completedAt'] as Timestamp?,
      outcome: data['outcome']?.toString() ?? 'adopted',
    );
  }

  static AdoptionRequestStatus _requestStatus(String value) {
    switch (value) {
      case 'under_review':
        return AdoptionRequestStatus.underReview;
      case 'approved':
        return AdoptionRequestStatus.approved;
      case 'rejected':
        return AdoptionRequestStatus.rejected;
      case 'withdrawn':
        return AdoptionRequestStatus.withdrawn;
      case 'completed':
        return AdoptionRequestStatus.completed;
      default:
        return AdoptionRequestStatus.pending;
    }
  }
}

class AdoptionEligibility {
  final bool allowed;
  final String? reason;
  final AdoptionListing? listing;

  const AdoptionEligibility._({
    required this.allowed,
    this.reason,
    this.listing,
  });

  const AdoptionEligibility.allowed(AdoptionListing listing)
    : this._(allowed: true, listing: listing);

  const AdoptionEligibility.denied(String reason)
    : this._(allowed: false, reason: reason);
}

class AdoptionActionEligibility {
  final bool allowed;
  final String? reason;

  const AdoptionActionEligibility.allowed() : allowed = true, reason = null;

  const AdoptionActionEligibility.denied(this.reason) : allowed = false;
}
