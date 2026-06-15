# Graph Report - C:\Users\User\StudioProjects\dhakker\graphify-out  (2026-06-10)

## Corpus Check
- 102 files · ~160,585 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1678 nodes · 2303 edges · 95 communities (73 shown, 22 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.81)
- Token cost: 38,695 input · 2,000 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Duas Screen & Search|Duas Screen & Search]]
- [[_COMMUNITY_Admin Edit Supplication|Admin: Edit Supplication]]
- [[_COMMUNITY_Admin Add Supplication|Admin: Add Supplication]]
- [[_COMMUNITY_Admin Edit Zone|Admin: Edit Zone]]
- [[_COMMUNITY_Auth & Pilgrim Settings|Auth & Pilgrim Settings]]
- [[_COMMUNITY_Map Screen & Zone Detection|Map Screen & Zone Detection]]
- [[_COMMUNITY_Windows Platform Runner|Windows Platform Runner]]
- [[_COMMUNITY_Admin Supplications List|Admin: Supplications List]]
- [[_COMMUNITY_Admin Supplication Details|Admin: Supplication Details]]
- [[_COMMUNITY_Admin Add Zone|Admin: Add Zone]]
- [[_COMMUNITY_Home Screen & Dua Controller|Home Screen & Dua Controller]]
- [[_COMMUNITY_Home Dua Controller State|Home Dua Controller State]]
- [[_COMMUNITY_Pilgrim Home Layout|Pilgrim Home Layout]]
- [[_COMMUNITY_Localization & Shared Components|Localization & Shared Components]]
- [[_COMMUNITY_Admin Zone Details|Admin: Zone Details]]
- [[_COMMUNITY_Map Location Picker|Map Location Picker]]
- [[_COMMUNITY_Admin Zones List|Admin: Zones List]]
- [[_COMMUNITY_Project Config & Dependencies|Project Config & Dependencies]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 82|Community 82]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]

## God Nodes (most connected - your core abstractions)
1. `dhakker pubspec` - 38 edges
2. `AppCubit` - 19 edges
3. `AppStates` - 15 edges
4. `_` - 12 edges
5. `_` - 12 edges
6. `Create()` - 10 edges
7. `MessageHandler()` - 10 edges
8. `WndProc()` - 9 edges
9. `widget` - 7 edges
10. `HWND` - 7 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  StudioProjects/dhakker/windows/runner/main.cpp → StudioProjects/dhakker/windows/runner/utils.cpp
- `dhakker README` --references--> `dhakker Flutter Application`  [EXTRACTED]
  README.md → pubspec.yaml
- `Dart Analysis Options` --references--> `flutter_lints`  [EXTRACTED]
  analysis_options.yaml → pubspec.yaml
- `Flutter Web Index HTML` --references--> `dhakker Flutter Application`  [EXTRACTED]
  web/index.html → pubspec.yaml
- `_AdminHomeLayoutState` --references--> `AdminCubit`  [EXTRACTED]
  StudioProjects/dhakker/lib/Screens/Admin/layout/admin_home_layout.dart → StudioProjects/dhakker/lib/admin_bloc/admin_cubit.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Firebase Backend Stack** — pubspec_firebase_core, pubspec_firebase_auth, pubspec_cloud_firestore, pubspec_firebase_storage, pubspec_firebase_messaging [INFERRED 0.85]
- **Location and Qibla Direction Stack** — pubspec_geolocator, pubspec_flutter_compass, pubspec_flutter_map, pubspec_latlong2 [INFERRED 0.75]
- **Audio and Voice Interaction Stack** — pubspec_flutter_tts, pubspec_speech_to_text, pubspec_audioplayers [INFERRED 0.75]

## Communities (95 total, 22 thin omitted)

### Community 0 - "Duas Screen & Search"
Cohesion: 0.03
Nodes (63): _allDuas, _allItems, allLabel, _applyFilters, bg, border, _BottomPlaybackBar, build (+55 more)

### Community 1 - "Admin: Edit Supplication"
Cohesion: 0.04
Nodes (56): dart:typed_data, _AppField, _audioMode, _AudioModeSelector, build, card, _CardBox, child (+48 more)

### Community 2 - "Admin: Add Supplication"
Cohesion: 0.04
Nodes (55): _AppField, _audioBytes, _audioFileName, _audioMode, _AudioModeSelector, build, card, _CardBox (+47 more)

### Community 3 - "Admin: Edit Zone"
Cohesion: 0.04
Nodes (54): _addPolygonPoint, _AppField, build, card, _CardBox, _centerLatController, _centerLngController, child (+46 more)

### Community 4 - "Auth & Pilgrim Settings"
Cohesion: 0.04
Nodes (54): package:dhakker/Screens/auth/Splash_Screen.dart, _autoLocation, _autoLocationKey, bg, border, build, _buttonScale, card (+46 more)

### Community 5 - "Map Screen & Zone Detection"
Cohesion: 0.04
Nodes (51): dart:math, ../home/services/zone_detection_service.dart, active, bg, border, build, _buildUserMarker, card (+43 more)

### Community 6 - "Windows Platform Runner"
Cohesion: 0.06
Nodes (42): DartProject, RegisterPlugins(), PluginRegistry, Point, RECT, MessageHandler(), OnCreate(), Create() (+34 more)

### Community 7 - "Admin: Supplications List"
Cohesion: 0.04
Nodes (49): admin_supplication_add_screen.dart, admin_supplication_details_screen.dart, admin_supplication_edit_screen.dart, _btnScale, color, createState, data, _deleteSupplication (+41 more)

### Community 8 - "Admin: Supplication Details"
Cohesion: 0.04
Nodes (49): audioMode, _audioPlayer, _btnScale, build, buttonLabel, card, children, color (+41 more)

### Community 9 - "Admin: Add Zone"
Cohesion: 0.04
Nodes (49): _addPolygonPoint, _AppField, build, _centerLatController, _centerLngController, color, controller, createState (+41 more)

### Community 10 - "Home Screen & Dua Controller"
Cohesion: 0.04
Nodes (48): ../../../bloc/states.dart, ChangeNotifier, controllers/home_dua_controller.dart, HomeDuaController, build, buttonText, canPlay, card (+40 more)

### Community 11 - "Home Dua Controller State"
Cohesion: 0.04
Nodes (47): auth, autoLocationEnabled, _clearLastHandledState, currentDuasList, currentPosition, currentZone, displayedDuaText, displayedDuaTitle (+39 more)

### Community 12 - "Pilgrim Home Layout"
Cohesion: 0.04
Nodes (47): _autoLocationEnabled, bg, build, card, color1, color2, createState, currentIndex (+39 more)

### Community 13 - "Localization & Shared Components"
Cohesion: 0.04
Nodes (40): load, locale, LocaleController, toggle, build, Testscren, isDark, setTheme (+32 more)

### Community 14 - "Admin: Zone Details"
Cohesion: 0.05
Nodes (44): ../Manage Supplications/AdminSupplicationsList_Screen.dart, accent, AdminZoneDetailsScreen, _AdminZoneDetailsScreenState, build, _buildMapCenter, card, _cardScale (+36 more)

### Community 15 - "Map Location Picker"
Cohesion: 0.05
Nodes (43): LatLng?, accent, _BottomPanel, build, canConfirm, color, _confirm, createState (+35 more)

### Community 16 - "Admin: Zones List"
Cohesion: 0.05
Nodes (41): admin_zone_add_screen.dart, admin_zone_details_screen.dart, admin_zone_edit_screen.dart, AdminZonesListScreen, _AdminZonesListScreenState, _btnScale, build, color (+33 more)

### Community 17 - "Project Config & Dependencies"
Cohesion: 0.05
Nodes (42): Dart Analysis Options, dhakker Flutter Application, dhakker pubspec, animated_text_kit, animations, audioplayers, bloc, carousel_slider (+34 more)

### Community 18 - "Community 18"
Cohesion: 0.06
Nodes (33): _CreateAccountRow, createState, dispose, _email, enabled, _formKey, _inputDecoration, label (+25 more)

### Community 19 - "Community 19"
Cohesion: 0.06
Nodes (32): adminStats, changeScreen, close, _compassSubscription, currentScreen, getAdminStats, getSOSRequests, getZoneColor (+24 more)

### Community 20 - "Community 20"
Cohesion: 0.06
Nodes (31): _BackToLoginRow, build, _confirm, createState, dispose, _email, enabled, _formKey (+23 more)

### Community 21 - "Community 21"
Cohesion: 0.07
Nodes (29): Offset, package:flutter/services.dart, ../../../shared/network/local/cash_helper.dart, bg, border, build, buttonBg, _buttonScale (+21 more)

### Community 22 - "Community 22"
Cohesion: 0.07
Nodes (28): Admin_Dashboard_Screen.dart, ../auth/login_screen.dart, ../../auth/Splash_Screen.dart, package:firebase_auth/firebase_auth.dart, package:flutter_switch/flutter_switch.dart, AdminSettingsScreen, _AdminSettingsScreenState, cardColor (+20 more)

### Community 23 - "Community 23"
Cohesion: 0.07
Nodes (28): accent, AdminDashboardScreen, audioMode, build, child, createState, duaId, _HapticScaleWrapper (+20 more)

### Community 24 - "Community 24"
Cohesion: 0.08
Nodes (25): Animation, AnimationController, build, color, createState, dispose, _GlowCircle, initState (+17 more)

### Community 25 - "Community 25"
Cohesion: 0.08
Nodes (24): IconData, package:url_launcher/url_launcher.dart, QuerySnapshot, _ActionBtn, AdminSosMonitorScreen, build, color, data (+16 more)

### Community 26 - "Community 26"
Cohesion: 0.09
Nodes (24): _HomeTopBar, _HomeTopBar, _CountCard, _LatestPanel, _LatestTile2, _OpenContainerTileWrapper, _SectionTitle, _SkeletonBar (+16 more)

### Community 27 - "Community 27"
Cohesion: 0.20
Nodes (21): AdminCubit, AdminChangeScreenState, AdminInitState, AdminState, AppCubit, AppAdminGetSOSRequestsErrorState, AppAdminGetSOSRequestsSuccessState, AppAdminGetStatsErrorState (+13 more)

### Community 28 - "Community 28"
Cohesion: 0.09
Nodes (22): bloc/cubit.dart, firebase_options.dart, build, createState, dispose, main, MyApp, _MyAppState (+14 more)

### Community 29 - "Community 29"
Cohesion: 0.09
Nodes (22): double?, double get, centerLat, centerLng, displayName, fromFirestore, fromMap, isActive (+14 more)

### Community 30 - "Community 30"
Cohesion: 0.11
Nodes (20): FlPluginRegistry, fl_register_plugins(), GApplication, gboolean, gchar, GObject, GtkApplication, main() (+12 more)

### Community 31 - "Community 31"
Cohesion: 0.10
Nodes (21): admin_bloc/admin_cubit.dart, ../../../admin_bloc/admin_states.dart, generated/l10n.dart, _AdminBottomNav, AdminHomeLayout, _AdminHomeLayoutState, _adminPageController, build (+13 more)

### Community 32 - "Community 32"
Cohesion: 0.10
Nodes (21): package:lottie/lottie.dart, ../services/voice_search_service.dart, VoiceSearchService, VoidCallback, _animationScale, build, createState, dispose (+13 more)

### Community 33 - "Community 33"
Cohesion: 0.10
Nodes (20): default, android, ios, macos, web, windows, lib/firebase_options.dart, appId (+12 more)

### Community 34 - "Community 34"
Cohesion: 0.10
Nodes (20): _LangPill, AppHomeLayout, _AppHomeLayoutState, _DialogPrimaryButton, _DialogPrimaryButtonState, _DialogSecondaryButton, _DialogSecondaryButtonState, _LangPill (+12 more)

### Community 35 - "Community 35"
Cohesion: 0.16
Nodes (18): _ActionButton, _AudioFilePickerCard, _HapticButton, _LangPill, _LangPillState, _LangPillState, _AudioFilePickerCardState, _TypeCardState (+10 more)

### Community 36 - "Community 36"
Cohesion: 0.12
Nodes (16): AudioPlayer, _flutterTts, package:audioplayers/audioplayers.dart, package:flutter_tts/flutter_tts.dart, _audioPlayer, _bestArabicVoice, dispose, DuaPlaybackService (+8 more)

### Community 37 - "Community 37"
Cohesion: 0.15
Nodes (15): AppLocalizationDelegate, authResetPasswordSuccessMessage, _current, delegate, isSupported, load, maybeOf, of (+7 more)

### Community 38 - "Community 38"
Cohesion: 0.12
Nodes (15): audioMode, audioUrl, duaId, fromFirestore, isActive, languageCodes, supportsLanguage, text (+7 more)

### Community 39 - "Community 39"
Cohesion: 0.14
Nodes (13): dart:async, actualLocale, availableLocale, _deferredLibraries, _findExact, _findGeneratedMessagesFor, initializeMessages, lib (+5 more)

### Community 40 - "Community 40"
Cohesion: 0.15
Nodes (12): changeScreen, currentScreen, screenAr, screenEn, screens, admin_states.dart, List, package:flutter_bloc/flutter_bloc.dart (+4 more)

### Community 41 - "Community 41"
Cohesion: 0.17
Nodes (11): assets, ddd, fr, h, ip, layers, markers, nm (+3 more)

### Community 42 - "Community 42"
Cohesion: 0.17
Nodes (8): Any, FlutterAppDelegate, NSApplication, Bool, AppDelegate, Bool, AppDelegate, UIApplication

### Community 43 - "Community 43"
Cohesion: 0.17
Nodes (11): Color, baseGold, build, buildCircleZones, buildPolygonZones, buildZoneLabelMarker, highlightColor, isActive (+3 more)

### Community 44 - "Community 44"
Cohesion: 0.23
Nodes (9): _In_, _In_opt_, wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), string, wchar_t (+1 more)

### Community 45 - "Community 45"
Cohesion: 0.18
Nodes (10): bool get, package:speech_to_text/speech_to_text.dart, cancelListening, initialize, isListening, _speech, startListening, stopListening (+2 more)

### Community 46 - "Community 46"
Cohesion: 0.18
Nodes (10): ../../home/models/supplication_model.dart, ../../home/models/zone_model.dart, SupplicationModel, ZoneModel, dua, DuaSearchItem, DuaSearchService, normalize (+2 more)

### Community 47 - "Community 47"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 48 - "Community 48"
Cohesion: 0.20
Nodes (9): FirebaseFirestore, Map, ../models/supplication_model.dart, package:cloud_firestore/cloud_firestore.dart, firestore, getSupplicationsByZone, pickBestSupplication, SupplicationService (+1 more)

### Community 49 - "Community 49"
Cohesion: 0.25
Nodes (9): _, email, localeName, m0, m1, messages, _notInlinedMessages, package:intl/message_lookup_by_library.dart (+1 more)

### Community 50 - "Community 50"
Cohesion: 0.22
Nodes (8): android, DefaultFirebaseOptions, ios, macos, web, windows, package:firebase_core/firebase_core.dart, static const FirebaseOptions

### Community 51 - "Community 51"
Cohesion: 0.22
Nodes (8): MapController, package:flutter_map/flutter_map.dart, package:latlong2/latlong.dart, focusOnPoint, mapController, MapControllerService, zoomIn, zoomOut

### Community 52 - "Community 52"
Cohesion: 0.29
Nodes (8): _, email, localeName, m0, m1, messages, _notInlinedMessages, package:intl/intl.dart

### Community 53 - "Community 53"
Cohesion: 0.25
Nodes (7): ../models/zone_model.dart, package:flutter/foundation.dart, package:geolocator/geolocator.dart, detectBestZone, isInsideCircle, isInsidePolygon, ZoneDetectionService

### Community 54 - "Community 54"
Cohesion: 0.29
Nodes (6): client, configuration_version, project_info, project_id, project_number, storage_bucket

### Community 55 - "Community 55"
Cohesion: 0.29
Nodes (4): RegisterGeneratedPlugins(), FlutterPluginRegistry, NSWindow, MainFlutterWindow

### Community 56 - "Community 56"
Cohesion: 0.29
Nodes (3): RunnerTests, RunnerTests, XCTestCase

### Community 57 - "Community 57"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 58 - "Community 58"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 59 - "Community 59"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 60 - "Community 60"
Cohesion: 0.50
Nodes (4): build, build, MaterialPageRoute, build

### Community 63 - "Community 63"
Cohesion: 0.67
Nodes (3): DuasScreen, _DuasScreenState, SingleTickerProviderStateMixin

### Community 64 - "Community 64"
Cohesion: 0.67
Nodes (3): MessageLookup, MessageLookup, MessageLookupByLibrary

## Knowledge Gaps
- **1083 isolated node(s):** `project_number`, `project_id`, `storage_bucket`, `client`, `configuration_version` (+1078 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppCubit` connect `Community 27` to `Community 34`, `Home Screen & Dua Controller`, `Community 80`, `Community 19`, `Community 84`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `widget` connect `Community 28` to `Admin: Edit Supplication`, `Admin: Add Supplication`, `Admin: Edit Zone`, `Map Screen & Zone Detection`, `Community 22`, `Community 23`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `_` connect `Community 52` to `Community 64`, `Community 49`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `project_number`, `project_id`, `storage_bucket` to the rest of the system?**
  _1083 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Duas Screen & Search` be split into smaller, more focused modules?**
  _Cohesion score 0.03125 - nodes in this community are weakly interconnected._
- **Should `Admin: Edit Supplication` be split into smaller, more focused modules?**
  _Cohesion score 0.03508771929824561 - nodes in this community are weakly interconnected._
- **Should `Admin: Add Supplication` be split into smaller, more focused modules?**
  _Cohesion score 0.03571428571428571 - nodes in this community are weakly interconnected._