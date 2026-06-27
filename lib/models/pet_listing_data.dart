import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

class PetListingData {
  final String? ownerId;
  final String? ownerName;
  final String? ownerPhoto;

  final String name;
  final String species;
  final String breed;
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

  PetListingData copyWith({
    String? ownerId,
    String? ownerName,
    String? ownerPhoto,
    String? name,
    String? species,
    String? breed,
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
  }) {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhoto': ownerPhoto,
      'name': name,
      'species': species,
      'breed': breed,
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
      'interviewQuestions':
          interviewQuestions.map((question) => question.toMap()).toList(),
      'healthRecords': healthRecords.map((record) => record.toMap()).toList(),
      'hasProfilePhoto': profilePhotoUrl.isNotEmpty,
      'hasHealthRecords': hasHealthRecords,
      'vetVerified': hasHealthRecords,
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
}

class PetHealthRecordData {
  final String type;
  final String fileName;
  final File? file;
  final String fileUrl;
  final String dateIssued;
  final String veterinarian;
  final String clinic;

  const PetHealthRecordData({
    required this.type,
    required this.fileName,
    this.file,
    this.fileUrl = '',
    this.dateIssued = '',
    this.veterinarian = '',
    this.clinic = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'dateIssued': dateIssued,
      'veterinarian': veterinarian,
      'clinic': clinic,
    };
  }

  PetHealthRecordData copyWith({
    String? type,
    String? fileName,
    File? file,
    String? fileUrl,
    String? dateIssued,
    String? veterinarian,
    String? clinic,
  }) {
    return PetHealthRecordData(
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      file: file ?? this.file,
      fileUrl: fileUrl ?? this.fileUrl,
      dateIssued: dateIssued ?? this.dateIssued,
      veterinarian: veterinarian ?? this.veterinarian,
      clinic: clinic ?? this.clinic,
    );
  }
}
