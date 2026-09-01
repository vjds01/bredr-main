import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

class CabuyaoBarangayService {
  CabuyaoBarangayService._();

  static const _boundaryAsset = 'assets/data/cabuyao_barangays.geojson';
  static Future<Map<String, dynamic>>? _boundaryData;

  static const barangays = <String>[
    'Baclaran',
    'Banaybanay',
    'Banlic',
    'Butong',
    'Bigaa',
    'Casile',
    'Gulod',
    'Mamatid',
    'Marinig',
    'Niugan',
    'Pittland',
    'Pulo',
    'Sala',
    'San Isidro',
    'Diezmo',
    'Barangay Uno (Poblacion)',
    'Barangay Dos (Poblacion)',
    'Barangay Tres (Poblacion)',
  ];

  static const _aliases = <String, List<String>>{
    'Baclaran': ['baclaran'],
    'Banaybanay': ['banaybanay', 'banay banay'],
    'Banlic': ['banlic'],
    'Butong': ['butong'],
    'Bigaa': ['bigaa'],
    'Casile': ['casile'],
    'Gulod': ['gulod'],
    'Mamatid': ['mamatid'],
    'Marinig': ['marinig'],
    'Niugan': ['niugan'],
    'Pittland': ['pittland'],
    'Pulo': ['pulo'],
    'Sala': ['sala'],
    'San Isidro': ['san isidro'],
    'Diezmo': ['diezmo'],
    'Barangay Uno (Poblacion)': [
      'barangay uno',
      'brgy uno',
      'poblacion uno',
      'poblacion 1',
      'barangay 1',
    ],
    'Barangay Dos (Poblacion)': [
      'barangay dos',
      'brgy dos',
      'poblacion dos',
      'poblacion 2',
      'barangay 2',
    ],
    'Barangay Tres (Poblacion)': [
      'barangay tres',
      'brgy tres',
      'poblacion tres',
      'poblacion 3',
      'barangay 3',
    ],
  };

  static String? fromPlacemark(Placemark? place) {
    if (place == null) return null;

    final candidates = <String?>[
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.street,
      place.name,
      place.thoroughfare,
    ];

    for (final candidate in candidates) {
      final barangay = canonicalName(candidate);
      if (barangay != null) return format(barangay);
    }
    return null;
  }

  static Future<String?> fromCoordinates(
    double latitude,
    double longitude, {
    AssetBundle? bundle,
  }) async {
    try {
      final data = await (_boundaryData ??= _loadBoundaries(bundle));
      return fromGeoJson(data, latitude, longitude);
    } catch (_) {
      // Boundary lookup is an enhancement. Callers can still use the manual
      // picker when the bundled data cannot be loaded for any reason.
      return null;
    }
  }

  static Future<(double latitude, double longitude)?>
  representativeCoordinatesFor(String locationName) async {
    try {
      final canonical = canonicalName(locationName);
      if (canonical == null) return null;
      final data = await (_boundaryData ??= _loadBoundaries(null));
      final features = data['features'];
      if (features is! List) return null;

      for (final feature in features.whereType<Map>()) {
        final properties = feature['properties'];
        final geometry = feature['geometry'];
        if (properties is! Map || geometry is! Map) continue;
        if (canonicalName(properties['name']?.toString()) != canonical) {
          continue;
        }

        dynamic ring;
        if (geometry['type'] == 'Polygon') {
          final polygons = geometry['coordinates'];
          if (polygons is List && polygons.isNotEmpty) ring = polygons.first;
        } else if (geometry['type'] == 'MultiPolygon') {
          final polygons = geometry['coordinates'];
          if (polygons is List &&
              polygons.isNotEmpty &&
              polygons.first is List &&
              (polygons.first as List).isNotEmpty) {
            ring = (polygons.first as List).first;
          }
        }
        if (ring is! List || ring.isEmpty) return null;

        var latitudeTotal = 0.0;
        var longitudeTotal = 0.0;
        var count = 0;
        for (final point in ring.whereType<List>()) {
          if (point.length < 2) continue;
          longitudeTotal += (point[0] as num).toDouble();
          latitudeTotal += (point[1] as num).toDouble();
          count++;
        }
        return count == 0
            ? null
            : (latitudeTotal / count, longitudeTotal / count);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? fromGeoJson(
    Map<String, dynamic> geoJson,
    double latitude,
    double longitude,
  ) {
    final features = geoJson['features'];
    if (features is! List) return null;

    for (final feature in features.whereType<Map>()) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry is! Map || properties is! Map) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      final containsPoint = switch (type) {
        'Polygon' => _polygonContains(coordinates, latitude, longitude),
        'MultiPolygon' =>
          coordinates is List &&
              coordinates.any(
                (polygon) => _polygonContains(polygon, latitude, longitude),
              ),
        _ => false,
      };

      if (containsPoint) {
        final canonical = canonicalName(properties['name']?.toString());
        return canonical == null ? null : format(canonical);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _loadBoundaries(
    AssetBundle? bundle,
  ) async {
    final json = await (bundle ?? rootBundle).loadString(_boundaryAsset);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static bool _polygonContains(
    dynamic coordinates,
    double latitude,
    double longitude,
  ) {
    if (coordinates is! List || coordinates.isEmpty) return false;
    if (!_ringContains(coordinates.first, latitude, longitude)) return false;

    // GeoJSON rings after the first one are holes.
    return !coordinates
        .skip(1)
        .any((hole) => _ringContains(hole, latitude, longitude));
  }

  static bool _ringContains(dynamic ring, double latitude, double longitude) {
    if (ring is! List || ring.length < 3) return false;
    var inside = false;

    for (
      var index = 0, previous = ring.length - 1;
      index < ring.length;
      previous = index++
    ) {
      final currentPoint = ring[index];
      final previousPoint = ring[previous];
      if (currentPoint is! List ||
          previousPoint is! List ||
          currentPoint.length < 2 ||
          previousPoint.length < 2) {
        continue;
      }

      final currentLongitude = (currentPoint[0] as num).toDouble();
      final currentLatitude = (currentPoint[1] as num).toDouble();
      final previousLongitude = (previousPoint[0] as num).toDouble();
      final previousLatitude = (previousPoint[1] as num).toDouble();

      final crossesLatitude =
          (currentLatitude > latitude) != (previousLatitude > latitude);
      final intersectionLongitude =
          (previousLongitude - currentLongitude) *
              (latitude - currentLatitude) /
              (previousLatitude - currentLatitude) +
          currentLongitude;
      if (crossesLatitude && longitude < intersectionLongitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  static String? canonicalName(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = _normalize(value);

    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        final normalizedAlias = _normalize(alias);
        if (normalized == normalizedAlias ||
            normalized.startsWith('$normalizedAlias ') ||
            normalized.endsWith(' $normalizedAlias') ||
            normalized.contains(' $normalizedAlias ')) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static String format(String barangay) => 'Brgy. $barangay, Cabuyao, Laguna';

  static bool isCanonicalLocation(String? value) =>
      canonicalName(value) != null &&
      value?.contains('Cabuyao, Laguna') == true;

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
