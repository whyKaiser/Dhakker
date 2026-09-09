// The base map is what a pilgrim navigates by. These guard the two things
// that actually broke: tiles from a provider that stamps a watermark over
// them, and OSM's tiles shown with no credit.

import 'dart:io';

import 'package:dhakker/shared/map/basemap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every file that draws a map, so a fourth one cannot quietly reintroduce a
/// keyed provider. A path that stops existing fails the test rather than
/// silently checking nothing.
const _mapSources = <String>[
  'lib/shared/map/basemap.dart',
  'lib/Screens/Piligram/Map/map_screen.dart',
  'lib/Screens/Admin/Manage Zones/admin_zone_details_screen.dart',
  'lib/Screens/Admin/Manage Zones/map_location_picker_screen.dart',
];

void main() {
  test('the light basemap is the OSM tile layer', () {
    final layer = basemapTileLayer(isDark: false);
    expect(layer, isA<TileLayer>());
    expect(
      (layer as TileLayer).urlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
  });

  test('the dark basemap is the same tiles, filtered — not another provider',
      () {
    // The bug was a SECOND provider for dark mode. Darkening has to happen
    // locally, or the watermark comes back the next time that provider
    // changes its terms.
    final widget = basemapTileLayer(isDark: true);
    expect(widget, isA<ColorFiltered>());
    final inner = (widget as ColorFiltered).child;
    expect(inner, isA<TileLayer>());
    expect(
      (inner as TileLayer).urlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
  });

  test('the comment stripper the scan below relies on works', () {
    // basemap.dart's own doc comment names cartocdn.com to explain why it is
    // gone. A naive grep would match that prose and pass — or fail — for the
    // wrong reason forever.
    const sample = '''
// cartocdn.com in a line comment
/// cartocdn.com in a doc comment
const url = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
''';
    final stripped = _withoutComments(sample);
    expect(stripped.contains('cartocdn.com'), isFalse);
    expect(stripped.contains('openstreetmap.org'), isTrue);
  });

  test('no map screen references a tile provider that requires a key', () {
    for (final path in _mapSources) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');
      final source = _withoutComments(file.readAsStringSync());
      for (final host in const [
        'cartocdn.com',
        'basemaps.carto',
        'api.mapbox.com',
        'maptiler.com',
        'stadiamaps.com',
        'thunderforest.com',
      ]) {
        expect(
          source.contains(host),
          isFalse,
          reason: '$path reaches for $host, which needs an API key',
        );
      }
    }
  });

  test('no map screen builds its own TileLayer', () {
    // One definition, or the next change fixes two screens out of three.
    for (final path in _mapSources.skip(1)) {
      final source = _withoutComments(File(path).readAsStringSync());
      // A bare `TileLayer(` — the lookbehind keeps `basemapTileLayer(` from
      // matching its own name.
      expect(
        RegExp(r'(?<![A-Za-z])TileLayer\(').hasMatch(source),
        isFalse,
        reason:
            '$path constructs a TileLayer instead of using basemapTileLayer',
      );
      expect(source.contains('basemapTileLayer('), isTrue,
          reason: '$path does not use the shared basemap');
    }
  });

  testWidgets('the basemap carries its OpenStreetMap attribution',
      (tester) async {
    // Not decoration: OSM's licence requires the credit wherever its tiles
    // are shown, and all three screens showed them without it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 400,
            child: FlutterMap(
              options: const MapOptions(),
              children: [basemapAttribution()],
            ),
          ),
        ),
      ),
    );
    expect(find.text('OpenStreetMap contributors'), findsOneWidget);
  });
}

/// Removes `//` line comments so a scan tests the code, not its prose.
String _withoutComments(String source) =>
    source.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
