import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'breed_options.dart';

class PetListingData {
  final String? ownerId;
  final String? ownerName;
  final String? ownerPhoto;

  final String name;
  final String species;
  final String breed;
  final String primaryBreed;
  final String secondaryBreed;
  final bool isMixedBreed;
  final String breedSize;
  final String age;
  final String gender;
  final String color;
  final String about;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final File? profilePhotoFile;
  final List<File> additionalPhotoFiles;
  final List<File> additionalVideoFiles;

  final String? purpose;
  final String breedingPreferredGender;
  final bool sameBreedOnly;
  final bool vetVerifiedOnly;
  final String adoptionType;
  final double price;
  final bool noOtherPets;
  final bool priceNegotiable;

  final List<PetInterviewQuestion> interviewQuestions;
  final List<PetHealthRecordData> healthRecords;

  const PetListingData({
    this.ownerId,
    this.ownerName,
    this.ownerPhoto,
    this.name = '',
    this.species = 'Dog',
    this.breed = '',
    this.primaryBreed = '',
    this.secondaryBreed = '',
    this.isMixedBreed = false,
    this.breedSize = 'Small',
    this.age = '',
    this.gender = 'Male',
    this.color = '',
    this.about = '',
    this.locationName = '',
    this.latitude,
    this.longitude,
    this.profilePhotoFile,
    this.additionalPhotoFiles = const [],
    this.additionalVideoFiles = const [],
    this.purpose,
    this.breedingPreferredGender = 'Male',
    this.sameBreedOnly = true,
    this.vetVerifiedOnly = true,
    this.adoptionType = 'FREE',
    this.price = 0,
    this.noOtherPets = true,
    this.priceNegotiable = true,
    this.interviewQuestions = const [],
    this.healthRecords = const [],
  });

  bool get isAdoption => purpose?.toLowerCase() == 'adoption';
  bool get isBreeding => purpose?.toLowerCase() == 'breeding';
  bool get hasProfilePhoto => profilePhotoFile != null;
  bool get hasHealthRecords => healthRecords.isNotEmpty;

  Map<String, dynamic> toDraftJson() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhoto': ownerPhoto,
      'name': name,
      'species': species,
      'breed': breed,
      'primaryBreed': primaryBreed,
      'secondaryBreed': secondaryBreed,
      'isMixedBreed': isMixedBreed,
      'breedSize': breedSize,
      'age': age,
      'gender': gender,
      'color': color,
      'about': about,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'profilePhotoPath': profilePhotoFile?.path,
      'additionalPhotoPaths': additionalPhotoFiles
          .map((file) => file.path)
          .toList(),
      'additionalVideoPaths': additionalVideoFiles
          .map((file) => file.path)
          .toList(),
      'purpose': purpose,
      'breedingPreferredGender': breedingPreferredGender,
      'sameBreedOnly': sameBreedOnly,
      'vetVerifiedOnly': vetVerifiedOnly,
      'adoptionType': adoptionType,
      'price': price,
      'noOtherPets': noOtherPets,
      'priceNegotiable': priceNegotiable,
      'interviewQuestions': interviewQuestions
          .map((question) => question.toDraftJson())
          .toList(),
      'healthRecords': healthRecords
          .map((record) => record.toDraftJson())
          .toList(),
    };
  }

  factory PetListingData.fromDraftJson(Map<String, dynamic> json) {
    final profilePhotoPath = json['profilePhotoPath'] as String?;
    final additionalPhotoPaths =
        (json['additionalPhotoPaths'] as List<dynamic>? ?? [])
            .whereType<String>();
    final additionalVideoPaths =
        (json['additionalVideoPaths'] as List<dynamic>? ?? [])
            .whereType<String>();

    return PetListingData(
      ownerId: json['ownerId'] as String?,
      ownerName: json['ownerName'] as String?,
      ownerPhoto: json['ownerPhoto'] as String?,
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? 'Dog',
      breed: json['breed'] as String? ?? '',
      primaryBreed: json['primaryBreed'] as String? ?? '',
      secondaryBreed: json['secondaryBreed'] as String? ?? '',
      isMixedBreed: json['isMixedBreed'] as bool? ?? false,
      breedSize: json['breedSize'] as String? ?? 'Small',
      age: json['age'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Male',
      color: json['color'] as String? ?? '',
      about: json['about'] as String? ?? '',
      locationName: json['locationName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      profilePhotoFile: _fileFromPath(profilePhotoPath),
      additionalPhotoFiles: additionalPhotoPaths
          .map(_fileFromPath)
          .whereType<File>()
          .toList(),
      additionalVideoFiles: additionalVideoPaths
          .map(_fileFromPath)
          .whereType<File>()
          .toList(),
      purpose: json['purpose'] as String?,
      breedingPreferredGender:
          json['breedingPreferredGender'] as String? ?? 'Male',
      sameBreedOnly: json['sameBreedOnly'] as bool? ?? true,
      vetVerifiedOnly: json['vetVerifiedOnly'] as bool? ?? true,
      adoptionType: json['adoptionType'] as String? ?? 'FREE',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      noOtherPets: json['noOtherPets'] as bool? ?? true,
      priceNegotiable: json['priceNegotiable'] as bool? ?? true,
      interviewQuestions: (json['interviewQuestions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PetInterviewQuestion.fromDraftJson)
          .toList(),
      healthRecords: (json['healthRecords'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PetHealthRecordData.fromDraftJson)
          .where((record) => record.file != null || record.fileUrl.isNotEmpty)
          .toList(),
    );
  }

  static File? _fileFromPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  PetListingData copyWith({
    String? ownerId,
    String? ownerName,
    String? ownerPhoto,
    String? name,
    String? species,
    String? breed,
    String? primaryBreed,
    String? secondaryBreed,
    bool? isMixedBreed,
    String? breedSize,
    String? age,
    String? gender,
    String? color,
    String? about,
    String? locationName,
    double? latitude,
    double? longitude,
    File? profilePhotoFile,
    List<File>? additionalPhotoFiles,
    List<File>? additionalVideoFiles,
    String? purpose,
    String? breedingPreferredGender,
    bool? sameBreedOnly,
    bool? vetVerifiedOnly,
    String? adoptionType,
    double? price,
    bool? noOtherPets,
    bool? priceNegotiable,
    List<PetInterviewQuestion>? interviewQuestions,
    List<PetHealthRecordData>? healthRecords,
  }) {
    return PetListingData(
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhoto: ownerPhoto ?? this.ownerPhoto,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      primaryBreed: primaryBreed ?? this.primaryBreed,
      secondaryBreed: secondaryBreed ?? this.secondaryBreed,
      isMixedBreed: isMixedBreed ?? this.isMixedBreed,
      breedSize: breedSize ?? this.breedSize,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      color: color ?? this.color,
      about: about ?? this.about,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profilePhotoFile: profilePhotoFile ?? this.profilePhotoFile,
      additionalPhotoFiles: additionalPhotoFiles ?? this.additionalPhotoFiles,
      additionalVideoFiles: additionalVideoFiles ?? this.additionalVideoFiles,
      purpose: purpose ?? this.purpose,
      breedingPreferredGender:
          breedingPreferredGender ?? this.breedingPreferredGender,
      sameBreedOnly: sameBreedOnly ?? this.sameBreedOnly,
      vetVerifiedOnly: vetVerifiedOnly ?? this.vetVerifiedOnly,
      adoptionType: adoptionType ?? this.adoptionType,
      price: price ?? this.price,
      noOtherPets: noOtherPets ?? this.noOtherPets,
      priceNegotiable: priceNegotiable ?? this.priceNegotiable,
      interviewQuestions: interviewQuestions ?? this.interviewQuestions,
      healthRecords: healthRecords ?? this.healthRecords,
    );
  }

  Map<String, dynamic> toFirestore({
    String profilePhotoUrl = '',
    List<String> additionalImageUrls = const [],
    List<String> additionalVideoUrls = const [],
  }) {
    final displayBreed = mixedBreedDisplayName(
      isMixedBreed: isMixedBreed,
      primaryBreed: primaryBreed.isNotEmpty ? primaryBreed : breed,
      secondaryBreed: secondaryBreed,
    );
    final tags = breedTagsFor(
      isMixedBreed: isMixedBreed,
      primaryBreed: primaryBreed.isNotEmpty ? primaryBreed : breed,
      secondaryBreed: secondaryBreed,
    );

    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhoto': ownerPhoto,
      'name': name,
      'species': species,
      'breed': displayBreed,
      'primaryBreed': primaryBreed.isNotEmpty ? primaryBreed : breed,
      'secondaryBreed': isMixedBreed ? secondaryBreed : '',
      'isMixedBreed': isMixedBreed,
      'breedTags': tags,
      'breedSize': breedSize,
      'age': age,
      'gender': gender,
      'color': color,
      'about': about,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'petProfilePhoto': profilePhotoUrl,
      'additionalImages': additionalImageUrls,
      'additionalVideos': additionalVideoUrls,
      'purpose': purpose?.toLowerCase(),
      'breedingPreferences': isBreeding
          ? {
              'preferredGender': breedingPreferredGender,
              'sameBreedOnly': sameBreedOnly,
              'vetVerifiedOnly': vetVerifiedOnly,
            }
          : null,
      'adoptionDetails': isAdoption
          ? {
              'adoptionType': adoptionType,
              'price': price,
              'noOtherPets': noOtherPets,
              'priceNegotiable': priceNegotiable,
            }
          : null,
      'adoptionStatus': isAdoption ? 'active' : null,
      'reservedFor': null,
      'approvedRequestId': null,
      'interviewQuestions': interviewQuestions
          .map((question) => question.toMap())
          .toList(),
      'healthRecords': healthRecords.map((record) => record.toMap()).toList(),
      'hasProfilePhoto': profilePhotoUrl.isNotEmpty,
      'hasHealthRecords': hasHealthRecords,
      'vetVerified': false,
      'verifiedHealthRecordCount': 0,
      'status': 'published',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class PetInterviewQuestion {
  final String questionId;
  final String type;
  final String text;
  final List<String> choices;
  final bool required;
  final int order;

  const PetInterviewQuestion({
    this.questionId = '',
    required this.type,
    required this.text,
    this.choices = const [],
    this.required = true,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'type': type,
      'text': text,
      'choices': choices,
      'required': required,
      'order': order,
    };
  }

  Map<String, dynamic> toDraftJson() => toMap();

  factory PetInterviewQuestion.fromDraftJson(Map<String, dynamic> json) {
    return PetInterviewQuestion(
      questionId: json['questionId'] as String? ?? '',
      type: json['type'] as String? ?? 'textAnswer',
      text: json['text'] as String? ?? '',
      choices: (json['choices'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      required: json['required'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
    );
  }
}

class PetHealthRecordData {
  final String recordId;
  final String type;
  final String otherType;
  final String verificationStatus;
  final String fileName;
  final File? file;
  final String fileUrl;
  final String dateIssued;
  final String nextUpdate;
  final String veterinarian;
  final String clinic;

  const PetHealthRecordData({
    this.recordId = '',
    required this.type,
    this.otherType = '',
    this.verificationStatus = 'pending',
    required this.fileName,
    this.file,
    this.fileUrl = '',
    this.dateIssued = '',
    this.nextUpdate = '',
    this.veterinarian = '',
    this.clinic = '',
  });

  String get displayType =>
      type == 'Other' && otherType.trim().isNotEmpty ? otherType.trim() : type;

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'type': type,
      'otherType': otherType,
      'verificationStatus': verificationStatus,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'dateIssued': dateIssued,
      'nextUpdate': nextUpdate,
      'veterinarian': veterinarian,
      'clinic': clinic,
    };
  }

  Map<String, dynamic> toDraftJson() {
    return {...toMap(), 'filePath': file?.path};
  }

  factory PetHealthRecordData.fromDraftJson(Map<String, dynamic> json) {
    final filePath = json['filePath'] as String?;
    final file = PetListingData._fileFromPath(filePath);

    return PetHealthRecordData(
      recordId: json['recordId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      otherType: json['otherType'] as String? ?? '',
      verificationStatus: json['verificationStatus'] as String? ?? 'pending',
      fileName: json['fileName'] as String? ?? '',
      file: file,
      fileUrl: json['fileUrl'] as String? ?? '',
      dateIssued: json['dateIssued'] as String? ?? '',
      nextUpdate:
          json['nextUpdate'] as String? ?? json['nextDue'] as String? ?? '',
      veterinarian: json['veterinarian'] as String? ?? '',
      clinic: json['clinic'] as String? ?? '',
    );
  }

  PetHealthRecordData copyWith({
    String? recordId,
    String? type,
    String? otherType,
    String? verificationStatus,
    String? fileName,
    File? file,
    String? fileUrl,
    String? dateIssued,
    String? nextUpdate,
    String? veterinarian,
    String? clinic,
  }) {
    return PetHealthRecordData(
      recordId: recordId ?? this.recordId,
      type: type ?? this.type,
      otherType: otherType ?? this.otherType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      fileName: fileName ?? this.fileName,
      file: file ?? this.file,
      fileUrl: fileUrl ?? this.fileUrl,
      dateIssued: dateIssued ?? this.dateIssued,
      nextUpdate: nextUpdate ?? this.nextUpdate,
      veterinarian: veterinarian ?? this.veterinarian,
      clinic: clinic ?? this.clinic,
    );
  }
}
