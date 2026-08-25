import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

enum CabuyaoAccessStatus {
  allowed,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  outsideServiceArea,
  locationUnavailable,
}

class CabuyaoAccessResult {
  const CabuyaoAccessResult(this.status, {this.position});

  final CabuyaoAccessStatus status;
  final Position? position;

  bool get isAllowed => status == CabuyaoAccessStatus.allowed;
}

class CabuyaoAccessService {
  CabuyaoAccessService._();

  static final CabuyaoAccessService instance = CabuyaoAccessService._();

  static const double toleranceMeters = 500;

  // Cabuyao's outer city boundary, simplified for an on-device service-area
  // check. The tolerance below keeps edge locations from being rejected by
  // normal GPS drift.
  static const List<_GeoPoint> _cabuyaoBoundary = [
    _GeoPoint(14.2596, 121.0895),
    _GeoPoint(14.2778, 121.0920),
    _GeoPoint(14.2918, 121.1030),
    _GeoPoint(14.2932, 121.1258),
    _GeoPoint(14.2862, 121.1465),
    _GeoPoint(14.2750, 121.1610),
    _GeoPoint(14.2588, 121.1706),
    _GeoPoint(14.2420, 121.1630),
    _GeoPoint(14.2240, 121.1540),
    _GeoPoint(14.2238, 121.1360),
    _GeoPoint(14.2290, 121.1195),
    _GeoPoint(14.2380, 121.1075),
    _GeoPoint(14.2470, 121.0950),
  ];

  Future<CabuyaoAccessResult> checkAccess({
    bool requestPermission = true,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const CabuyaoAccessResult(
          CabuyaoAccessStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const CabuyaoAccessResult(
          CabuyaoAccessStatus.permissionDeniedForever,
        );
      }

      if (permission == LocationPermission.denied) {
        return const CabuyaoAccessResult(
          CabuyaoAccessStatus.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      return CabuyaoAccessResult(
        isWithinCabuyao(position)
            ? CabuyaoAccessStatus.allowed
            : CabuyaoAccessStatus.outsideServiceArea,
        position: position,
      );
    } catch (_) {
      return const CabuyaoAccessResult(
        CabuyaoAccessStatus.locationUnavailable,
      );
    }
  }

  bool isWithinCabuyao(Position position) {
    final point = _GeoPoint(position.latitude, position.longitude);

    if (_isInsidePolygon(point, _cabuyaoBoundary)) return true;

    for (var index = 0; index < _cabuyaoBoundary.length; index++) {
      final start = _cabuyaoBoundary[index];
      final end = _cabuyaoBoundary[(index + 1) % _cabuyaoBoundary.length];
      if (_distanceToSegmentMeters(point, start, end) <= toleranceMeters) {
        return true;
      }
    }

    return false;
  }

  bool _isInsidePolygon(_GeoPoint point, List<_GeoPoint> polygon) {
    var inside = false;

    for (var current = 0, previous = polygon.length - 1;
        current < polygon.length;
        previous = current++) {
      final currentPoint = polygon[current];
      final previousPoint = polygon[previous];
      final intersects = ((currentPoint.latitude > point.latitude) !=
              (previousPoint.latitude > point.latitude)) &&
          (point.longitude <
              (previousPoint.longitude - currentPoint.longitude) *
                      (point.latitude - currentPoint.latitude) /
                      (previousPoint.latitude - currentPoint.latitude) +
                  currentPoint.longitude);
      if (intersects) inside = !inside;
    }

    return inside;
  }

  double _distanceToSegmentMeters(
    _GeoPoint point,
    _GeoPoint start,
    _GeoPoint end,
  ) {
    const metersPerLatitudeDegree = 111320.0;
    final latitudeRadians = point.latitude * math.pi / 180;
    final metersPerLongitudeDegree =
        metersPerLatitudeDegree * math.cos(latitudeRadians);

    final pointX = point.longitude * metersPerLongitudeDegree;
    final pointY = point.latitude * metersPerLatitudeDegree;
    final startX = start.longitude * metersPerLongitudeDegree;
    final startY = start.latitude * metersPerLatitudeDegree;
    final endX = end.longitude * metersPerLongitudeDegree;
    final endY = end.latitude * metersPerLatitudeDegree;
    final segmentX = endX - startX;
    final segmentY = endY - startY;
    final lengthSquared = segmentX * segmentX + segmentY * segmentY;

    if (lengthSquared == 0) {
      return math.sqrt(
        math.pow(pointX - startX, 2) + math.pow(pointY - startY, 2),
      );
    }

    final projection = ((pointX - startX) * segmentX +
            (pointY - startY) * segmentY) /
        lengthSquared;
    final clampedProjection = projection.clamp(0.0, 1.0).toDouble();
    final closestX = startX + clampedProjection * segmentX;
    final closestY = startY + clampedProjection * segmentY;

    return math.sqrt(
      math.pow(pointX - closestX, 2) + math.pow(pointY - closestY, 2),
    );
  }
}

class _GeoPoint {
  const _GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
