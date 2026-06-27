class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  double? latitude;
  double? longitude;
  String? locationName;
}