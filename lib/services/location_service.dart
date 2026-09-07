class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  double? latitude;
  double? longitude;
  double? accuracyMeters;
  String? locationName;

  bool get hasVerifiedLocation =>
      latitude != null &&
      longitude != null &&
      (locationName?.trim().isNotEmpty ?? false);
}
