import 'dart:io';

class OnboardingData {

  // STEP 1
  final String fullName;
  final String userName;
  final String email;
  final String password;

  // STEP 2
  final String? bio;
  final String? homeType;
  final bool childrenAtHome;
  final bool otherPetsAtHome;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  // NEW FIELDS
  final bool isActive;
  final String? profilePhoto;
  final List<String> additionalImages;
  final File? profilePhotoFile;
  final List<File> additionalPhotoFiles;

  //authprovider
  final String authProvider;

  const OnboardingData({
    required this.fullName,
    required this.userName,
    required this.email,
    required this.password,
    required this.authProvider,

    // STEP 2
    this.bio,
    this.homeType,
    this.childrenAtHome = false,
    this.otherPetsAtHome = false,
    this.locationName,
    this.latitude,
    this.longitude,

    // NEW FIELDS
    this.isActive = true,
    this.profilePhoto,
    this.additionalImages = const [],
    this.profilePhotoFile,
    this.additionalPhotoFiles = const [],
  });

  bool get profileCompleted =>
      fullName.trim().isNotEmpty &&
      userName.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      (bio?.trim().isNotEmpty ?? false) &&
      (homeType?.isNotEmpty ?? false) &&
      (locationName?.isNotEmpty ?? false) &&
      (profilePhoto?.isNotEmpty ?? false);

  OnboardingData copyWith({
    String? fullName,
    String? userName,
    String? email,
    String? password,
    String? authProvider,

    // STEP 2
    String? bio,
    String? homeType,
    bool? childrenAtHome,
    bool? otherPetsAtHome,
    String? locationName,
    double? latitude,
    double? longitude,

    // NEW FIELDS
    bool? isActive,
    String? profilePhoto,
    List<String>? additionalImages,
    File? profilePhotoFile,
    List<File>? additionalPhotoFiles,
  }) {

    return OnboardingData(
      fullName: fullName ?? this.fullName,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      password: password ?? this.password,
      authProvider: authProvider ?? this.authProvider,

      // STEP 2
      bio: bio ?? this.bio,
      homeType: homeType ?? this.homeType,
      childrenAtHome:
          childrenAtHome ?? this.childrenAtHome,
      otherPetsAtHome:
          otherPetsAtHome ?? this.otherPetsAtHome,
      locationName: locationName ?? this.locationName,
      latitude:
          latitude ?? this.latitude,
      longitude:
          longitude ?? this.longitude,

      // NEW FIELDS
      isActive:
          isActive ?? this.isActive,
      profilePhoto:
          profilePhoto ?? this.profilePhoto,
      additionalImages:
          additionalImages ?? this.additionalImages,

      profilePhotoFile:
          profilePhotoFile ?? this.profilePhotoFile,
      additionalPhotoFiles:
          additionalPhotoFiles ?? this.additionalPhotoFiles,   
    );
  }
}