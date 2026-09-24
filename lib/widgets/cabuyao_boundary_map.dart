import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cabuyao_barangay_service.dart';

/// An offline map made from the barangay polygons bundled with Breedr.
class CabuyaoBoundaryMap extends StatefulWidget {
  const CabuyaoBoundaryMap({
    super.key,
    required this.locationName,
    this.latitude,
    this.longitude,
    this.locationSource,
    this.compact = false,
  });

  final String locationName;
  final double? latitude;
  final double? longitude;
  final String? locationSource;
  final bool compact;

  @override
  State<CabuyaoBoundaryMap> createState() => _CabuyaoBoundaryMapState();
}

class _CabuyaoBoundaryMapState extends State<CabuyaoBoundaryMap> {
  late final Future<_BoundaryData> _data = _BoundaryData.load();
  final TransformationController _transform = TransformationController();
  String? _selectedBarangay;
  bool _viewInitialized = false;
  Size? _viewport;
  double? _side;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _focus(_BoundaryData data, String? barangay) {
    final viewport = _viewport;
    final side = _side;
    if (viewport == null || side == null) return;
    if (barangay == null || !data.polygons.containsKey(barangay)) {
      final origin = Offset(
        (viewport.width - side) / 2,
        (viewport.height - side) / 2,
      );
      _transform.value = Matrix4.identity()
        ..translateByDouble(origin.dx, origin.dy, 0, 1);
      return;
    }
    final points = data.polygons[barangay]!
        .expand((ring) => ring)
        .map((point) => data.toPixel(point.dy, point.dx, Size(side, side)))
        .toList();
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final scale = math
        .min(
          viewport.width / math.max(90, (maxX - minX) * 1.6),
          viewport.height / math.max(90, (maxY - minY) * 1.6),
        )
        .clamp(1.5, 6.0)
        .toDouble();
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - center.dx * scale,
        viewport.height / 2 - center.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoom(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final sceneCenter = _transform.toScene(center);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor)
        .clamp(1.0, 8.0)
        .toDouble();
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - sceneCenter.dx * scale,
        center.dy - sceneCenter.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _search(_BoundaryData data) async {
    var query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) {
          final matches = CabuyaoBarangayService.barangays
              .where((name) => name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: SizedBox(
                height: math.max(
                  160,
                  math.min(
                    MediaQuery.sizeOf(sheetContext).height * .55,
                    MediaQuery.sizeOf(sheetContext).height -
                        MediaQuery.viewInsetsOf(sheetContext).bottom -
                        80,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Find a barangay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (value) => update(() => query = value.trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search Cabuyao barangays',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(matches[index]),
                          onTap: () =>
                              Navigator.pop(sheetContext, matches[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedBarangay = selected);
    _focus(data, selected);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BoundaryData>(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xFFF5F9FF),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snapshot.data!;
        final highlighted =
            _selectedBarangay ??
            CabuyaoBarangayService.canonicalName(widget.locationName);

        if (widget.compact) {
          return LayoutBuilder(
            builder: (context, constraints) => CustomPaint(
              painter: _BoundaryPainter(
                data: data,
                highlighted: highlighted,
                latitude: widget.latitude,
                longitude: widget.longitude,
                showBarangayLabel: false,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _search(data),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Find barangay'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Zoom in',
                  onPressed: () => _zoom(1.5),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: 'Zoom out',
                  onPressed: () => _zoom(1 / 1.5),
                  icon: const Icon(Icons.remove),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: const Color(0xFFF5F9FF),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.max(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final viewport = constraints.biggest;
                      _viewport = viewport;
                      _side = side;
                      if (!_viewInitialized) {
                        _viewInitialized = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _focus(data, highlighted);
                        });
                      }
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: InteractiveViewer(
                              transformationController: _transform,
                              constrained: false,
                              minScale: 1,
                              maxScale: 8,
                              boundaryMargin: const EdgeInsets.all(500),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final point = data.toCoordinates(
                                    details.localPosition,
                                    Size(side, side),
                                  );
                                  final name =
                                      CabuyaoBarangayService.fromGeoJson(
                                        data.raw,
                                        point.$1,
                                        point.$2,
                                      );
                                  if (name != null) {
                                    setState(
                                      () => _selectedBarangay =
                                          CabuyaoBarangayService.canonicalName(
                                            name,
                                          ),
                                    );
                                  }
                                },
                                child: SizedBox.square(
                                  dimension: side,
                                  child: CustomPaint(
                                    painter: _BoundaryPainter(
                                      data: data,
                                      highlighted: highlighted,
                                      latitude: widget.latitude,
                                      longitude: widget.longitude,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _focus(data, null),
                              icon: const Icon(Icons.zoom_out_map, size: 17),
                              label: const Text('Show all Cabuyao'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              highlighted == null
                  ? 'Tap a barangay to explore'
                  : CabuyaoBarangayService.format(highlighted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                const _MapLegendDot(
                  color: Color(0xFFFF718B),
                  label: 'Selected',
                ),
                const _MapLegendDot(
                  color: Color(0xFFBBDCE7),
                  label: 'Other barangays',
                ),
                _MapLegendDot(
                  color: const Color(0xFFE23D61),
                  label: switch (widget.locationSource) {
                    'gps' => 'Saved GPS point',
                    'barangay' => 'Approximate barangay point',
                    _ => 'Saved point (precision unknown)',
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BoundaryData {
  _BoundaryData(
    this.raw,
    this.polygons,
    this.minLat,
    this.maxLat,
    this.minLon,
    this.maxLon,
  );

  final Map<String, dynamic> raw;
  final Map<String, List<List<Offset>>> polygons;
  final double minLat, maxLat, minLon, maxLon;

  static Future<_BoundaryData> load() async {
    final raw =
        jsonDecode(
              await rootBundle.loadString(
                'assets/data/cabuyao_barangays.geojson',
              ),
            )
            as Map<String, dynamic>;
    final polygons = <String, List<List<Offset>>>{};
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLon = double.infinity;
    var maxLon = double.negativeInfinity;

    for (final feature in (raw['features'] as List).whereType<Map>()) {
      final name = CabuyaoBarangayService.canonicalName(
        (feature['properties'] as Map)['name']?.toString(),
      );
      if (name == null) continue;
      final geometry = feature['geometry'] as Map;
      final coordinateGroups = geometry['type'] == 'MultiPolygon'
          ? geometry['coordinates'] as List
          : [geometry['coordinates']];
      final rings = <List<Offset>>[];
      for (final group in coordinateGroups) {
        for (final ring in (group as List).whereType<List>()) {
          final points = <Offset>[];
          for (final pair in ring.whereType<List>()) {
            if (pair.length < 2) continue;
            final lon = (pair[0] as num).toDouble();
            final lat = (pair[1] as num).toDouble();
            minLat = math.min(minLat, lat);
            maxLat = math.max(maxLat, lat);
            minLon = math.min(minLon, lon);
            maxLon = math.max(maxLon, lon);
            points.add(Offset(lon, lat));
          }
          if (points.length >= 3) rings.add(points);
        }
      }
      polygons[name] = rings;
    }
    return _BoundaryData(raw, polygons, minLat, maxLat, minLon, maxLon);
  }

  Rect plotRect(Size size) {
    const padding = 18.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;
    final geoWidth = maxLon - minLon;
    final geoHeight = maxLat - minLat;
    final scale = math.min(
      availableWidth / geoWidth,
      availableHeight / geoHeight,
    );
    final width = geoWidth * scale;
    final height = geoHeight * scale;
    return Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
  }

  Offset toPixel(double lat, double lon, Size size) {
    final rect = plotRect(size);
    return Offset(
      rect.left + (lon - minLon) / (maxLon - minLon) * rect.width,
      rect.bottom - (lat - minLat) / (maxLat - minLat) * rect.height,
    );
  }

  (double, double) toCoordinates(Offset pixel, Size size) {
    final rect = plotRect(size);
    return (
      minLat + (rect.bottom - pixel.dy) / rect.height * (maxLat - minLat),
      minLon + (pixel.dx - rect.left) / rect.width * (maxLon - minLon),
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  const _MapLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
}

class _BoundaryPainter extends CustomPainter {
  const _BoundaryPainter({
    required this.data,
    required this.highlighted,
    this.latitude,
    this.longitude,
    this.showBarangayLabel = true,
  });

  final _BoundaryData data;
  final String? highlighted;
  final double? latitude, longitude;
  final bool showBarangayLabel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5F9FF),
    );
    for (final entry in data.polygons.entries) {
      final selected = entry.key == highlighted;
      for (final ring in entry.value) {
        final path = Path();
        for (var i = 0; i < ring.length; i++) {
          final pixel = data.toPixel(ring[i].dy, ring[i].dx, size);
          if (i == 0) {
            path.moveTo(pixel.dx, pixel.dy);
          } else {
            path.lineTo(pixel.dx, pixel.dy);
          }
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = selected
                ? const Color(0xFFFF718B)
                : const Color(0xFFBBDCE7),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2.4 : 1.2,
        );
      }
    }

    if (showBarangayLabel &&
        highlighted != null &&
        data.polygons.containsKey(highlighted)) {
      final points = data.polygons[highlighted]!
          .expand((ring) => ring)
          .map((p) => data.toPixel(p.dy, p.dx, size))
          .toList();
      final center = Offset(
        (points.map((p) => p.dx).reduce(math.min) +
                points.map((p) => p.dx).reduce(math.max)) /
            2,
        (points.map((p) => p.dy).reduce(math.min) +
                points.map((p) => p.dy).reduce(math.max)) /
            2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: highlighted,
          style: const TextStyle(
            color: Color(0xFF6D2640),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: math.max(80, size.width - 24));
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: label.width + 14,
          height: label.height + 8,
        ),
        const Radius.circular(7),
      );
      canvas.drawRRect(labelRect, Paint()..color = Colors.white);
      label.paint(
        canvas,
        Offset(center.dx - label.width / 2, center.dy - label.height / 2),
      );
    }

    if (latitude != null &&
        longitude != null &&
        latitude! >= data.minLat &&
        latitude! <= data.maxLat &&
        longitude! >= data.minLon &&
        longitude! <= data.maxLon) {
      final point = data.toPixel(latitude!, longitude!, size);
      canvas.drawCircle(point, 11, Paint()..color = Colors.white);
      canvas.drawCircle(point, 7, Paint()..color = const Color(0xFFE23D61));
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _BoundaryPainter oldDelegate) =>
      oldDelegate.highlighted != highlighted ||
      oldDelegate.latitude != latitude ||
      oldDelegate.longitude != longitude;
}
