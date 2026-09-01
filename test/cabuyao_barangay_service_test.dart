import 'dart:convert';
import 'dart:io';

import 'package:breedr/services/cabuyao_barangay_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CabuyaoBarangayService', () {
    test('contains the complete canonical barangay list', () {
      expect(CabuyaoBarangayService.barangays, hasLength(18));
      expect(
        CabuyaoBarangayService.barangays,
        containsAll(<String>[
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
        ]),
      );
    });

    test('normalizes common barangay spellings', () {
      expect(
        CabuyaoBarangayService.canonicalName('Barangay Banay Banay'),
        'Banaybanay',
      );
      expect(CabuyaoBarangayService.canonicalName('Brgy. Niugan'), 'Niugan');
      expect(
        CabuyaoBarangayService.canonicalName('Poblacion 2'),
        'Barangay Dos (Poblacion)',
      );
    });

    test('formats a community-friendly location', () {
      expect(
        CabuyaoBarangayService.format('Niugan'),
        'Brgy. Niugan, Cabuyao, Laguna',
      );
      expect(
        CabuyaoBarangayService.isCanonicalLocation(
          'Brgy. Niugan, Cabuyao, Laguna',
        ),
        isTrue,
      );
      expect(
        CabuyaoBarangayService.isCanonicalLocation('Cabuyao, Calabarzon'),
        isFalse,
      );
    });

    test('detects Niugan from the bundled boundary data', () {
      final geoJson = jsonDecode(
        File('assets/data/cabuyao_barangays.geojson').readAsStringSync(),
      ) as Map<String, dynamic>;

      expect(
        CabuyaoBarangayService.fromGeoJson(geoJson, 14.2685, 121.1332),
        'Brgy. Niugan, Cabuyao, Laguna',
      );
    });

    test('returns null when coordinates are outside every polygon', () {
      final geoJson = <String, dynamic>{
        'features': <Map<String, dynamic>>[
          <String, dynamic>{
            'properties': <String, dynamic>{'name': 'Niugan'},
            'geometry': <String, dynamic>{
              'type': 'Polygon',
              'coordinates': <dynamic>[
                <dynamic>[
                  <double>[121.0, 14.0],
                  <double>[122.0, 14.0],
                  <double>[122.0, 15.0],
                  <double>[121.0, 15.0],
                  <double>[121.0, 14.0],
                ],
              ],
            },
          },
        ],
      };

      expect(
        CabuyaoBarangayService.fromGeoJson(geoJson, 16.0, 123.0),
        isNull,
      );
    });
  });
}
