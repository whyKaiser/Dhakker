/// The base map layers, shared by every screen that draws a map.
///
/// ── Why this file exists ──────────────────────────────────────────────────
///
/// The dark theme used to pull tiles from `basemaps.cartocdn.com`, which now
/// requires an API key and stamps "API KEY REQUIRED" across every tile it
/// serves without one. A pilgrim standing in Mina saw that watermark over the
/// map they were trying to navigate by. There was no key, and adding one would
/// have meant a paid dependency and a secret to manage for what is only a
/// backdrop.
///
/// So both themes now draw the same OpenStreetMap tiles, and the dark variant
/// is produced locally by a colour filter rather than fetched from a second
/// provider. One source, no key, nothing to expire.
///
/// ── The usage policy this rests on ────────────────────────────────────────
///
/// OpenStreetMap's public tile servers are run on donated capacity, and their
/// tile usage policy asks that heavy applications not depend on them. This is
/// fine for the app as it stands and for testing; if Dhakker is deployed to a
/// real pilgrimage at scale, the honest answer is a dedicated tile source
/// (self-hosted, or a paid provider), NOT more requests to a volunteer server.
/// That is a deliberate decision for later, recorded here so it is not
/// discovered the hard way during Hajj.
///
/// Attribution is not optional. OSM's licence requires crediting it wherever
/// its tiles are shown, and none of the three map screens did.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tiles are the same in both themes; only this filter differs.
///
/// Inverts luminance to turn the light basemap dark, keeping roads legible as
/// light lines on a dark ground. Colour is dropped rather than inverted —
/// inverted hues read as a photographic negative, which is worse to navigate
/// by than a clean greyscale.
const ColorFilter _darkBasemapFilter = ColorFilter.matrix(<double>[
  -0.2126, -0.7152, -0.0722, 0, 255, //
  -0.2126, -0.7152, -0.0722, 0, 255, //
  -0.2126, -0.7152, -0.0722, 0, 255, //
  0, 0, 0, 1, 0, //
]);

const String _osmUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// The tile layer, darkened in place when [isDark].
///
/// No `subdomains`: the a/b/c hostnames are deprecated for OSM and the single
/// `tile.openstreetmap.org` host is the documented endpoint.
Widget basemapTileLayer({required bool isDark}) {
  final layer = TileLayer(
    urlTemplate: _osmUrlTemplate,
    userAgentPackageName: 'dhakker',
    maxNativeZoom: 19,
  );
  if (!isDark) return layer;
  return ColorFiltered(colorFilter: _darkBasemapFilter, child: layer);
}

/// The credit OSM's licence requires. Belongs last in a map's children so it
/// draws above the tiles.
/// Deliberately the always-visible widget rather than the collapsible one:
/// a credit hidden behind a tap is not a credit.
Widget basemapAttribution() {
  return SimpleAttributionWidget(
    source: const Text('OpenStreetMap contributors'),
    onTap: () => launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
      mode: LaunchMode.externalApplication,
    ),
  );
}
