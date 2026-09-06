// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(email) =>
      "A password reset link has been sent to:\n${email}\nPlease check your email to complete the reset process.";

  static String m1(email) =>
      "A password reset link will be sent to the following email:\n${email}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "adminDashAudioModeLabel":
            MessageLookupByLibrary.simpleMessage("Audio"),
        "adminDashKpiTitle": MessageLookupByLibrary.simpleMessage("Overview"),
        "adminDashLatestSupplications": MessageLookupByLibrary.simpleMessage(
          "Latest Supplications",
        ),
        "adminDashLatestTitle": MessageLookupByLibrary.simpleMessage("Latest"),
        "adminDashLatestZones": MessageLookupByLibrary.simpleMessage(
          "Latest Zones",
        ),
        "adminDashNoData": MessageLookupByLibrary.simpleMessage(
          "No data available",
        ),
        "adminDashTotalSupplications": MessageLookupByLibrary.simpleMessage(
          "Total Supplications",
        ),
        "adminDashTotalZones":
            MessageLookupByLibrary.simpleMessage("Total Zones"),
        "adminDashZoneIdLabel": MessageLookupByLibrary.simpleMessage("Zone"),
        "adminDashZoneLabel": MessageLookupByLibrary.simpleMessage("Zone"),
        "adminHomePlaceholder": MessageLookupByLibrary.simpleMessage(
          "Admin UI will be linked later",
        ),
        "adminHomeTitle": MessageLookupByLibrary.simpleMessage("Admin Panel"),
        "adminNavDashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
        "adminNavSettings": MessageLookupByLibrary.simpleMessage("Settings"),
        "adminNavSupplications": MessageLookupByLibrary.simpleMessage(
          "Supplications",
        ),
        "adminNavZones": MessageLookupByLibrary.simpleMessage("Zones"),
        "adminPanelTitle": MessageLookupByLibrary.simpleMessage("Admin Panel"),
        "adminSettingsLanguage":
            MessageLookupByLibrary.simpleMessage("Language"),
        "adminSettingsLanguageHint": MessageLookupByLibrary.simpleMessage(
          "Change app language",
        ),
        "adminSettingsLogout": MessageLookupByLibrary.simpleMessage("Logout"),
        "adminSettingsTheme": MessageLookupByLibrary.simpleMessage("Theme"),
        "adminSettingsThemeDark": MessageLookupByLibrary.simpleMessage("Dark"),
        "adminSettingsThemeLight":
            MessageLookupByLibrary.simpleMessage("Light"),
        "adminSettingsTitle": MessageLookupByLibrary.simpleMessage(
          "Admin Settings",
        ),
        "adminSupplicationAddAudioTitle": MessageLookupByLibrary.simpleMessage(
          "Audio Settings",
        ),
        "adminSupplicationAddBasicTitle": MessageLookupByLibrary.simpleMessage(
          "Basic Information",
        ),
        "adminSupplicationAddError": MessageLookupByLibrary.simpleMessage(
          "Failed to add the supplication. Please try again.",
        ),
        "adminSupplicationAddSuccess": MessageLookupByLibrary.simpleMessage(
          "Supplication added successfully.",
        ),
        "adminSupplicationAddTagsTitle": MessageLookupByLibrary.simpleMessage(
          "Tags & Status",
        ),
        "adminSupplicationAddTextTitle": MessageLookupByLibrary.simpleMessage(
          "Supplication Text",
        ),
        "adminSupplicationAddTitle": MessageLookupByLibrary.simpleMessage(
          "Add Supplication",
        ),
        "adminSupplicationAudioFile": MessageLookupByLibrary.simpleMessage(
          "Audio File",
        ),
        "adminSupplicationAudioFileDesc": MessageLookupByLibrary.simpleMessage(
          "Upload a saved audio file for this supplication",
        ),
        "adminSupplicationAudioFileRequired":
            MessageLookupByLibrary.simpleMessage(
          "Please select an audio file",
        ),
        "adminSupplicationAudioTts":
            MessageLookupByLibrary.simpleMessage("TTS"),
        "adminSupplicationAudioTtsDesc": MessageLookupByLibrary.simpleMessage(
          "The app will read the supplication using text-to-speech",
        ),
        "adminSupplicationCurrentAudioAvailable":
            MessageLookupByLibrary.simpleMessage(
                "Current audio file is available"),
        "adminSupplicationDetailsArabicTextTitle":
            MessageLookupByLibrary.simpleMessage("Arabic Text"),
        "adminSupplicationDetailsAudioModeLabel":
            MessageLookupByLibrary.simpleMessage("Audio Mode"),
        "adminSupplicationDetailsAudioPlayError":
            MessageLookupByLibrary.simpleMessage(
                "Failed to play the audio file."),
        "adminSupplicationDetailsAudioSectionTitle":
            MessageLookupByLibrary.simpleMessage("Audio"),
        "adminSupplicationDetailsEnglishTextTitle":
            MessageLookupByLibrary.simpleMessage("English Text"),
        "adminSupplicationDetailsFileCardSubtitle":
            MessageLookupByLibrary.simpleMessage(
          "Tap the button to play the uploaded audio file.",
        ),
        "adminSupplicationDetailsFileCardTitle":
            MessageLookupByLibrary.simpleMessage("Audio File Playback"),
        "adminSupplicationDetailsLoadError":
            MessageLookupByLibrary.simpleMessage(
          "Failed to load supplication details.",
        ),
        "adminSupplicationDetailsNoAudioFile":
            MessageLookupByLibrary.simpleMessage(
          "No audio file is available for this supplication.",
        ),
        "adminSupplicationDetailsNoTextToSpeak":
            MessageLookupByLibrary.simpleMessage(
          "There is no text available to convert into speech.",
        ),
        "adminSupplicationDetailsNotFound":
            MessageLookupByLibrary.simpleMessage(
          "Supplication not found.",
        ),
        "adminSupplicationDetailsOverviewTitle":
            MessageLookupByLibrary.simpleMessage("Overview"),
        "adminSupplicationDetailsPlayFileButton":
            MessageLookupByLibrary.simpleMessage("Play Audio File"),
        "adminSupplicationDetailsPlayTtsButton":
            MessageLookupByLibrary.simpleMessage("Play TTS"),
        "adminSupplicationDetailsStatusLabel":
            MessageLookupByLibrary.simpleMessage(
          "Status",
        ),
        "adminSupplicationDetailsStopButton":
            MessageLookupByLibrary.simpleMessage(
          "Stop",
        ),
        "adminSupplicationDetailsTextTitle":
            MessageLookupByLibrary.simpleMessage(
          "Supplication Text",
        ),
        "adminSupplicationDetailsTitle": MessageLookupByLibrary.simpleMessage(
          "Supplication Details",
        ),
        "adminSupplicationDetailsTtsCardSubtitle":
            MessageLookupByLibrary.simpleMessage(
          "Tap the button to convert the supplication text into speech.",
        ),
        "adminSupplicationDetailsTtsCardTitle":
            MessageLookupByLibrary.simpleMessage("Text-to-Speech Playback"),
        "adminSupplicationDetailsTtsError":
            MessageLookupByLibrary.simpleMessage(
          "Failed to play text-to-speech.",
        ),
        "adminSupplicationDetailsZoneInfoTitle":
            MessageLookupByLibrary.simpleMessage("Zone Information"),
        "adminSupplicationDetailsZoneNameLabel":
            MessageLookupByLibrary.simpleMessage("Zone"),
        "adminSupplicationEditError": MessageLookupByLibrary.simpleMessage(
          "Failed to update the supplication. Please try again.",
        ),
        "adminSupplicationEditLoadError": MessageLookupByLibrary.simpleMessage(
          "Failed to load supplication data.",
        ),
        "adminSupplicationEditNotFound": MessageLookupByLibrary.simpleMessage(
          "Supplication not found.",
        ),
        "adminSupplicationEditSave": MessageLookupByLibrary.simpleMessage(
          "Save Changes",
        ),
        "adminSupplicationEditSuccess": MessageLookupByLibrary.simpleMessage(
          "Supplication updated successfully.",
        ),
        "adminSupplicationEditTitle": MessageLookupByLibrary.simpleMessage(
          "Edit Supplication",
        ),
        "adminSupplicationFilePickError": MessageLookupByLibrary.simpleMessage(
          "Failed to pick the audio file",
        ),
        "adminSupplicationNoAudioSelected":
            MessageLookupByLibrary.simpleMessage(
          "No audio file selected",
        ),
        "adminSupplicationPickAudio": MessageLookupByLibrary.simpleMessage(
          "Pick Audio File",
        ),
        "adminSupplicationSave": MessageLookupByLibrary.simpleMessage(
          "Save Supplication",
        ),
        "adminSupplicationSaving": MessageLookupByLibrary.simpleMessage(
          "Saving...",
        ),
        "adminSupplicationStatusActiveText":
            MessageLookupByLibrary.simpleMessage(
          "This supplication is active and can be used in the application.",
        ),
        "adminSupplicationStatusInactiveText":
            MessageLookupByLibrary.simpleMessage(
          "This supplication is inactive and will not be used until enabled.",
        ),
        "adminSupplicationStatusTitle": MessageLookupByLibrary.simpleMessage(
          "Supplication Status",
        ),
        "adminSupplicationTagsAr": MessageLookupByLibrary.simpleMessage(
          "Arabic Tags",
        ),
        "adminSupplicationTagsArHint": MessageLookupByLibrary.simpleMessage(
          "Enter Arabic tags separated by commas",
        ),
        "adminSupplicationTagsEn": MessageLookupByLibrary.simpleMessage(
          "English Tags",
        ),
        "adminSupplicationTagsEnHint": MessageLookupByLibrary.simpleMessage(
          "Enter English tags separated by commas",
        ),
        "adminSupplicationTextAr": MessageLookupByLibrary.simpleMessage(
          "Arabic Text",
        ),
        "adminSupplicationTextArHint": MessageLookupByLibrary.simpleMessage(
          "Enter the supplication text in Arabic",
        ),
        "adminSupplicationTextArRequired": MessageLookupByLibrary.simpleMessage(
          "Arabic text is required",
        ),
        "adminSupplicationTextEn": MessageLookupByLibrary.simpleMessage(
          "English Text",
        ),
        "adminSupplicationTextEnHint": MessageLookupByLibrary.simpleMessage(
          "Enter the supplication text in English",
        ),
        "adminSupplicationTextEnRequired": MessageLookupByLibrary.simpleMessage(
          "English text is required",
        ),
        "adminSupplicationTitleAr": MessageLookupByLibrary.simpleMessage(
          "Arabic Title",
        ),
        "adminSupplicationTitleArHint": MessageLookupByLibrary.simpleMessage(
          "Enter the supplication title in Arabic",
        ),
        "adminSupplicationTitleArRequired":
            MessageLookupByLibrary.simpleMessage(
          "Arabic title is required",
        ),
        "adminSupplicationTitleEn": MessageLookupByLibrary.simpleMessage(
          "English Title",
        ),
        "adminSupplicationTitleEnHint": MessageLookupByLibrary.simpleMessage(
          "Enter the supplication title in English",
        ),
        "adminSupplicationTitleEnRequired":
            MessageLookupByLibrary.simpleMessage(
          "English title is required",
        ),
        "adminSupplicationZoneHint": MessageLookupByLibrary.simpleMessage(
          "Select a zone",
        ),
        "adminSupplicationZoneLabel":
            MessageLookupByLibrary.simpleMessage("Zone"),
        "adminSupplicationZoneRequired": MessageLookupByLibrary.simpleMessage(
          "Please select a zone",
        ),
        "adminSupplicationsAddButton": MessageLookupByLibrary.simpleMessage(
          "Add Supplication",
        ),
        "adminSupplicationsAllAudioModes": MessageLookupByLibrary.simpleMessage(
          "All audio modes",
        ),
        "adminSupplicationsAllStatuses": MessageLookupByLibrary.simpleMessage(
          "All statuses",
        ),
        "adminSupplicationsAllZones": MessageLookupByLibrary.simpleMessage(
          "All zones",
        ),
        "adminSupplicationsAudioFile": MessageLookupByLibrary.simpleMessage(
          "Audio File",
        ),
        "adminSupplicationsAudioModeLabel":
            MessageLookupByLibrary.simpleMessage(
          "Audio Mode",
        ),
        "adminSupplicationsAudioTts":
            MessageLookupByLibrary.simpleMessage("TTS"),
        "adminSupplicationsDeleteError": MessageLookupByLibrary.simpleMessage(
          "Failed to delete the supplication.",
        ),
        "adminSupplicationsDeleteMessage": MessageLookupByLibrary.simpleMessage(
          "Are you sure you want to delete this supplication?",
        ),
        "adminSupplicationsDeleteSuccess": MessageLookupByLibrary.simpleMessage(
          "Supplication deleted successfully.",
        ),
        "adminSupplicationsDeleteTitle": MessageLookupByLibrary.simpleMessage(
          "Delete Supplication",
        ),
        "adminSupplicationsEmptyMessage": MessageLookupByLibrary.simpleMessage(
          "There are no supplications matching the current search or filters.",
        ),
        "adminSupplicationsEmptyTitle": MessageLookupByLibrary.simpleMessage(
          "No supplications found",
        ),
        "adminSupplicationsFilterAudioMode":
            MessageLookupByLibrary.simpleMessage(
          "Audio Mode",
        ),
        "adminSupplicationsFilterStatus": MessageLookupByLibrary.simpleMessage(
          "Status",
        ),
        "adminSupplicationsFilterZone": MessageLookupByLibrary.simpleMessage(
          "Zone",
        ),
        "adminSupplicationsLoadErrorMessage":
            MessageLookupByLibrary.simpleMessage(
          "Something went wrong while loading the supplications list.",
        ),
        "adminSupplicationsLoadErrorTitle":
            MessageLookupByLibrary.simpleMessage(
          "Unable to load supplications",
        ),
        "adminSupplicationsResultsLabel": MessageLookupByLibrary.simpleMessage(
          "results",
        ),
        "adminSupplicationsSearchHint": MessageLookupByLibrary.simpleMessage(
          "Search by Arabic or English title",
        ),
        "adminSupplicationsStatusActive": MessageLookupByLibrary.simpleMessage(
          "Active",
        ),
        "adminSupplicationsStatusInactive":
            MessageLookupByLibrary.simpleMessage(
          "Inactive",
        ),
        "adminSupplicationsTitle": MessageLookupByLibrary.simpleMessage(
          "Supplications Management",
        ),
        "adminSupplicationsZoneLabel":
            MessageLookupByLibrary.simpleMessage("Zone"),
        "adminZoneAddBasicInfoTitle": MessageLookupByLibrary.simpleMessage(
          "Basic Information",
        ),
        "adminZoneAddCenterLat": MessageLookupByLibrary.simpleMessage(
          "Center Latitude",
        ),
        "adminZoneAddCenterLatHint": MessageLookupByLibrary.simpleMessage(
          "Example: 21.4225",
        ),
        "adminZoneAddCenterLatRequired": MessageLookupByLibrary.simpleMessage(
          "Center latitude is required",
        ),
        "adminZoneAddCenterLng": MessageLookupByLibrary.simpleMessage(
          "Center Longitude",
        ),
        "adminZoneAddCenterLngHint": MessageLookupByLibrary.simpleMessage(
          "Example: 39.8262",
        ),
        "adminZoneAddCenterLngRequired": MessageLookupByLibrary.simpleMessage(
          "Center longitude is required",
        ),
        "adminZoneAddCircleCardSubtitle": MessageLookupByLibrary.simpleMessage(
          "Enter the center latitude, center longitude, and radius in meters.",
        ),
        "adminZoneAddCircleCardTitle": MessageLookupByLibrary.simpleMessage(
          "Circle Zone Setup",
        ),
        "adminZoneAddError": MessageLookupByLibrary.simpleMessage(
          "Failed to add the zone. Please try again.",
        ),
        "adminZoneAddLatitudeInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid latitude between -90 and 90",
        ),
        "adminZoneAddLongitudeInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid longitude between -180 and 180",
        ),
        "adminZoneAddNameAr":
            MessageLookupByLibrary.simpleMessage("Arabic Name"),
        "adminZoneAddNameArHint": MessageLookupByLibrary.simpleMessage(
          "Enter the zone name in Arabic",
        ),
        "adminZoneAddNameArRequired": MessageLookupByLibrary.simpleMessage(
          "Arabic name is required",
        ),
        "adminZoneAddNameEn":
            MessageLookupByLibrary.simpleMessage("English Name"),
        "adminZoneAddNameEnHint": MessageLookupByLibrary.simpleMessage(
          "Enter the zone name in English",
        ),
        "adminZoneAddNameEnRequired": MessageLookupByLibrary.simpleMessage(
          "English name is required",
        ),
        "adminZoneAddNoPointsYet": MessageLookupByLibrary.simpleMessage(
          "No points added yet. Start by entering a latitude and longitude, then tap Add Point.",
        ),
        "adminZoneAddPointButton": MessageLookupByLibrary.simpleMessage(
          "Add Point",
        ),
        "adminZoneAddPointLat": MessageLookupByLibrary.simpleMessage(
          "Point Latitude",
        ),
        "adminZoneAddPointLatHint": MessageLookupByLibrary.simpleMessage(
          "Enter latitude",
        ),
        "adminZoneAddPointLng": MessageLookupByLibrary.simpleMessage(
          "Point Longitude",
        ),
        "adminZoneAddPointLngHint": MessageLookupByLibrary.simpleMessage(
          "Enter longitude",
        ),
        "adminZoneAddPointRequired": MessageLookupByLibrary.simpleMessage(
          "Please enter both latitude and longitude for the point",
        ),
        "adminZoneAddPointsCount": MessageLookupByLibrary.simpleMessage(
          "points added",
        ),
        "adminZoneAddPolygonCardSubtitle": MessageLookupByLibrary.simpleMessage(
          "Add each point of the area one by one. At least 3 points are required.",
        ),
        "adminZoneAddPolygonCardTitle": MessageLookupByLibrary.simpleMessage(
          "Polygon Zone Setup",
        ),
        "adminZoneAddPolygonMinPoints": MessageLookupByLibrary.simpleMessage(
          "Polygon zone must contain at least 3 points",
        ),
        "adminZoneAddPriority":
            MessageLookupByLibrary.simpleMessage("Priority"),
        "adminZoneAddPriorityHint": MessageLookupByLibrary.simpleMessage(
          "Enter overlap priority",
        ),
        "adminZoneAddPriorityInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid priority number",
        ),
        "adminZoneAddPriorityRequired": MessageLookupByLibrary.simpleMessage(
          "Priority is required",
        ),
        "adminZoneAddRadius": MessageLookupByLibrary.simpleMessage(
          "Radius (Meters)",
        ),
        "adminZoneAddRadiusHint": MessageLookupByLibrary.simpleMessage(
          "Example: 50",
        ),
        "adminZoneAddRadiusInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid radius greater than zero",
        ),
        "adminZoneAddRadiusRequired": MessageLookupByLibrary.simpleMessage(
          "Radius is required",
        ),
        "adminZoneAddSave": MessageLookupByLibrary.simpleMessage("Save Zone"),
        "adminZoneAddSaving": MessageLookupByLibrary.simpleMessage("Saving..."),
        "adminZoneAddStatusActiveText": MessageLookupByLibrary.simpleMessage(
          "This zone is currently active and can be used in the system.",
        ),
        "adminZoneAddStatusInactiveText": MessageLookupByLibrary.simpleMessage(
          "This zone is inactive and will not be used until enabled.",
        ),
        "adminZoneAddStatusTitle": MessageLookupByLibrary.simpleMessage(
          "Zone Status",
        ),
        "adminZoneAddSuccess": MessageLookupByLibrary.simpleMessage(
          "Zone added successfully.",
        ),
        "adminZoneAddTitle": MessageLookupByLibrary.simpleMessage("Add Zone"),
        "adminZoneAddTypeCircle":
            MessageLookupByLibrary.simpleMessage("Circle"),
        "adminZoneAddTypeCircleDesc": MessageLookupByLibrary.simpleMessage(
          "Use center location and radius",
        ),
        "adminZoneAddTypePolygon":
            MessageLookupByLibrary.simpleMessage("Polygon"),
        "adminZoneAddTypePolygonDesc": MessageLookupByLibrary.simpleMessage(
          "Use multiple points to define the area",
        ),
        "adminZoneAddTypeTitle":
            MessageLookupByLibrary.simpleMessage("Zone Shape"),
        "adminZoneDetailsCenterLatLabel": MessageLookupByLibrary.simpleMessage(
          "Center Latitude",
        ),
        "adminZoneDetailsCenterLngLabel": MessageLookupByLibrary.simpleMessage(
          "Center Longitude",
        ),
        "adminZoneDetailsHint": MessageLookupByLibrary.simpleMessage(
          "You can review the full zone information here, preview its location on the map, and open the related supplications directly.",
        ),
        "adminZoneDetailsInfoTitle": MessageLookupByLibrary.simpleMessage(
          "Zone Information",
        ),
        "adminZoneDetailsLoadError": MessageLookupByLibrary.simpleMessage(
          "Failed to load zone details.",
        ),
        "adminZoneDetailsMapTitle": MessageLookupByLibrary.simpleMessage(
          "Zone Map Preview",
        ),
        "adminZoneDetailsMapUnavailableSubtitle":
            MessageLookupByLibrary.simpleMessage(
          "This zone does not contain enough valid coordinates to draw it on the map.",
        ),
        "adminZoneDetailsMapUnavailableTitle":
            MessageLookupByLibrary.simpleMessage(
          "Map preview is unavailable",
        ),
        "adminZoneDetailsNameAr": MessageLookupByLibrary.simpleMessage(
          "Arabic Name",
        ),
        "adminZoneDetailsNameEn": MessageLookupByLibrary.simpleMessage(
          "English Name",
        ),
        "adminZoneDetailsNoPoints": MessageLookupByLibrary.simpleMessage(
          "No polygon points available.",
        ),
        "adminZoneDetailsNotFound": MessageLookupByLibrary.simpleMessage(
          "Zone not found.",
        ),
        "adminZoneDetailsOverviewTitle": MessageLookupByLibrary.simpleMessage(
          "Overview",
        ),
        "adminZoneDetailsPointsCountLabel":
            MessageLookupByLibrary.simpleMessage(
          "Points Count",
        ),
        "adminZoneDetailsPointsTitle": MessageLookupByLibrary.simpleMessage(
          "Polygon Points",
        ),
        "adminZoneDetailsPriorityLabel": MessageLookupByLibrary.simpleMessage(
          "Priority",
        ),
        "adminZoneDetailsRadiusLabel": MessageLookupByLibrary.simpleMessage(
          "Radius",
        ),
        "adminZoneDetailsRelatedCountLabel":
            MessageLookupByLibrary.simpleMessage(
          "Supplications count",
        ),
        "adminZoneDetailsRelatedSupplicationsButton":
            MessageLookupByLibrary.simpleMessage("View Related Supplications"),
        "adminZoneDetailsRelatedTitle": MessageLookupByLibrary.simpleMessage(
          "Related Supplications",
        ),
        "adminZoneDetailsStatusActive": MessageLookupByLibrary.simpleMessage(
          "Active",
        ),
        "adminZoneDetailsStatusInactive": MessageLookupByLibrary.simpleMessage(
          "Inactive",
        ),
        "adminZoneDetailsStatusLabel": MessageLookupByLibrary.simpleMessage(
          "Status",
        ),
        "adminZoneDetailsTitle": MessageLookupByLibrary.simpleMessage(
          "Zone Details",
        ),
        "adminZoneDetailsTypeCircle": MessageLookupByLibrary.simpleMessage(
          "Circle",
        ),
        "adminZoneDetailsTypeLabel": MessageLookupByLibrary.simpleMessage(
          "Zone Type",
        ),
        "adminZoneDetailsTypePolygon": MessageLookupByLibrary.simpleMessage(
          "Polygon",
        ),
        "adminZoneDetailsZonePreview": MessageLookupByLibrary.simpleMessage(
          "Zone preview",
        ),
        "adminZoneEditBasicInfoTitle": MessageLookupByLibrary.simpleMessage(
          "Basic Information",
        ),
        "adminZoneEditCenterLat": MessageLookupByLibrary.simpleMessage(
          "Center Latitude",
        ),
        "adminZoneEditCenterLatHint": MessageLookupByLibrary.simpleMessage(
          "Example: 21.4225",
        ),
        "adminZoneEditCenterLatRequired": MessageLookupByLibrary.simpleMessage(
          "Center latitude is required",
        ),
        "adminZoneEditCenterLng": MessageLookupByLibrary.simpleMessage(
          "Center Longitude",
        ),
        "adminZoneEditCenterLngHint": MessageLookupByLibrary.simpleMessage(
          "Example: 39.8262",
        ),
        "adminZoneEditCenterLngRequired": MessageLookupByLibrary.simpleMessage(
          "Center longitude is required",
        ),
        "adminZoneEditCircleCardSubtitle": MessageLookupByLibrary.simpleMessage(
          "Update the center latitude, center longitude, and radius in meters.",
        ),
        "adminZoneEditCircleCardTitle": MessageLookupByLibrary.simpleMessage(
          "Circle Zone Setup",
        ),
        "adminZoneEditError": MessageLookupByLibrary.simpleMessage(
          "Failed to update the zone. Please try again.",
        ),
        "adminZoneEditLatitudeInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid latitude between -90 and 90",
        ),
        "adminZoneEditLoadError": MessageLookupByLibrary.simpleMessage(
          "Failed to load zone data.",
        ),
        "adminZoneEditLongitudeInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid longitude between -180 and 180",
        ),
        "adminZoneEditNameAr":
            MessageLookupByLibrary.simpleMessage("Arabic Name"),
        "adminZoneEditNameArHint": MessageLookupByLibrary.simpleMessage(
          "Update the zone name in Arabic",
        ),
        "adminZoneEditNameArRequired": MessageLookupByLibrary.simpleMessage(
          "Arabic name is required",
        ),
        "adminZoneEditNameEn":
            MessageLookupByLibrary.simpleMessage("English Name"),
        "adminZoneEditNameEnHint": MessageLookupByLibrary.simpleMessage(
          "Update the zone name in English",
        ),
        "adminZoneEditNameEnRequired": MessageLookupByLibrary.simpleMessage(
          "English name is required",
        ),
        "adminZoneEditNoPointsYet": MessageLookupByLibrary.simpleMessage(
          "No points added yet. Start by entering a latitude and longitude, then tap Add Point.",
        ),
        "adminZoneEditNotFound": MessageLookupByLibrary.simpleMessage(
          "Zone not found.",
        ),
        "adminZoneEditPointButton": MessageLookupByLibrary.simpleMessage(
          "Add Point",
        ),
        "adminZoneEditPointLat": MessageLookupByLibrary.simpleMessage(
          "Point Latitude",
        ),
        "adminZoneEditPointLatHint": MessageLookupByLibrary.simpleMessage(
          "Enter latitude",
        ),
        "adminZoneEditPointLng": MessageLookupByLibrary.simpleMessage(
          "Point Longitude",
        ),
        "adminZoneEditPointLngHint": MessageLookupByLibrary.simpleMessage(
          "Enter longitude",
        ),
        "adminZoneEditPointRequired": MessageLookupByLibrary.simpleMessage(
          "Please enter both latitude and longitude for the point",
        ),
        "adminZoneEditPointsCount": MessageLookupByLibrary.simpleMessage(
          "points added",
        ),
        "adminZoneEditPolygonCardSubtitle":
            MessageLookupByLibrary.simpleMessage(
          "Add each point of the area one by one. At least 3 points are required.",
        ),
        "adminZoneEditPolygonCardTitle": MessageLookupByLibrary.simpleMessage(
          "Polygon Zone Setup",
        ),
        "adminZoneEditPolygonMinPoints": MessageLookupByLibrary.simpleMessage(
          "Polygon zone must contain at least 3 points",
        ),
        "adminZoneEditPriority":
            MessageLookupByLibrary.simpleMessage("Priority"),
        "adminZoneEditPriorityHint": MessageLookupByLibrary.simpleMessage(
          "Update overlap priority",
        ),
        "adminZoneEditPriorityInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid priority number",
        ),
        "adminZoneEditPriorityRequired": MessageLookupByLibrary.simpleMessage(
          "Priority is required",
        ),
        "adminZoneEditRadius": MessageLookupByLibrary.simpleMessage(
          "Radius (Meters)",
        ),
        "adminZoneEditRadiusHint": MessageLookupByLibrary.simpleMessage(
          "Example: 50",
        ),
        "adminZoneEditRadiusInvalid": MessageLookupByLibrary.simpleMessage(
          "Enter a valid radius greater than zero",
        ),
        "adminZoneEditRadiusRequired": MessageLookupByLibrary.simpleMessage(
          "Radius is required",
        ),
        "adminZoneEditSave":
            MessageLookupByLibrary.simpleMessage("Save Changes"),
        "adminZoneEditSaving":
            MessageLookupByLibrary.simpleMessage("Saving..."),
        "adminZoneEditStatusActiveText": MessageLookupByLibrary.simpleMessage(
          "This zone is currently active and can be used in the system.",
        ),
        "adminZoneEditStatusInactiveText": MessageLookupByLibrary.simpleMessage(
          "This zone is inactive and will not be used until enabled.",
        ),
        "adminZoneEditStatusTitle": MessageLookupByLibrary.simpleMessage(
          "Zone Status",
        ),
        "adminZoneEditSuccess": MessageLookupByLibrary.simpleMessage(
          "Zone updated successfully.",
        ),
        "adminZoneEditTitle": MessageLookupByLibrary.simpleMessage("Edit Zone"),
        "adminZoneEditTypeCircle":
            MessageLookupByLibrary.simpleMessage("Circle"),
        "adminZoneEditTypeCircleDesc": MessageLookupByLibrary.simpleMessage(
          "Use center location and radius",
        ),
        "adminZoneEditTypePolygon":
            MessageLookupByLibrary.simpleMessage("Polygon"),
        "adminZoneEditTypePolygonDesc": MessageLookupByLibrary.simpleMessage(
          "Use multiple points to define the area",
        ),
        "adminZoneEditTypeTitle": MessageLookupByLibrary.simpleMessage(
          "Zone Shape",
        ),
        "adminZonesAddZone": MessageLookupByLibrary.simpleMessage("Add Zone"),
        "adminZonesDeleteError": MessageLookupByLibrary.simpleMessage(
          "Failed to delete the zone.",
        ),
        "adminZonesDeleteMessage": MessageLookupByLibrary.simpleMessage(
          "Are you sure you want to delete this zone?",
        ),
        "adminZonesDeleteSuccess": MessageLookupByLibrary.simpleMessage(
          "Zone deleted successfully.",
        ),
        "adminZonesDeleteTitle": MessageLookupByLibrary.simpleMessage(
          "Delete Zone",
        ),
        "adminZonesDocIdLabel":
            MessageLookupByLibrary.simpleMessage("Document ID"),
        "adminZonesEmptyMessage": MessageLookupByLibrary.simpleMessage(
          "There are no zones matching the current search or filters.",
        ),
        "adminZonesEmptyTitle": MessageLookupByLibrary.simpleMessage(
          "No zones found",
        ),
        "adminZonesFilterAllStatuses": MessageLookupByLibrary.simpleMessage(
          "All statuses",
        ),
        "adminZonesFilterAllTypes": MessageLookupByLibrary.simpleMessage(
          "All types",
        ),
        "adminZonesFilterStatus":
            MessageLookupByLibrary.simpleMessage("Status"),
        "adminZonesFilterType": MessageLookupByLibrary.simpleMessage("Type"),
        "adminZonesLoadErrorMessage": MessageLookupByLibrary.simpleMessage(
          "Something went wrong while loading the zones list.",
        ),
        "adminZonesLoadErrorTitle": MessageLookupByLibrary.simpleMessage(
          "Unable to load zones",
        ),
        "adminZonesPriorityLabel":
            MessageLookupByLibrary.simpleMessage("Priority"),
        "adminZonesResultsLabel":
            MessageLookupByLibrary.simpleMessage("results"),
        "adminZonesSearchHint": MessageLookupByLibrary.simpleMessage(
          "Search by Arabic or English zone name",
        ),
        "adminZonesStatusActive":
            MessageLookupByLibrary.simpleMessage("Active"),
        "adminZonesStatusInactive": MessageLookupByLibrary.simpleMessage(
          "Inactive",
        ),
        "adminZonesTitle":
            MessageLookupByLibrary.simpleMessage("Zones Management"),
        "adminZonesTypeCircle": MessageLookupByLibrary.simpleMessage("Circle"),
        "adminZonesTypePolygon":
            MessageLookupByLibrary.simpleMessage("Polygon"),
        "appTitle": MessageLookupByLibrary.simpleMessage("Dhakker"),
        "authAccountDisabled": MessageLookupByLibrary.simpleMessage(
          "This account is disabled",
        ),
        "authBackToLogin": MessageLookupByLibrary.simpleMessage("Login"),
        "authConfirmPasswordLabel": MessageLookupByLibrary.simpleMessage(
          "Confirm Password",
        ),
        "authConfirmPasswordRequired": MessageLookupByLibrary.simpleMessage(
          "Confirm password is required",
        ),
        "authCreateAccount": MessageLookupByLibrary.simpleMessage("Create one"),
        "authCreatingAccount": MessageLookupByLibrary.simpleMessage(
          "Creating account...",
        ),
        "authEmailAlreadyInUse": MessageLookupByLibrary.simpleMessage(
          "Email already in use",
        ),
        "authEmailHint":
            MessageLookupByLibrary.simpleMessage("example@mail.com"),
        "authEmailLabel": MessageLookupByLibrary.simpleMessage("Email"),
        "authEmailRequired": MessageLookupByLibrary.simpleMessage(
          "Email is required",
        ),
        "authForgotPassword": MessageLookupByLibrary.simpleMessage(
          "Forgot password?",
        ),
        "authForgotPasswordMessage": MessageLookupByLibrary.simpleMessage(
          "Enter your email address, and a password reset link will be sent to help you reset your password.",
        ),
        "authForgotPasswordTitle": MessageLookupByLibrary.simpleMessage(
          "Reset Password",
        ),
        "authFullNameHint":
            MessageLookupByLibrary.simpleMessage("Type your name"),
        "authFullNameLabel": MessageLookupByLibrary.simpleMessage("Full Name"),
        "authFullNameMin": MessageLookupByLibrary.simpleMessage(
          "Name is too short",
        ),
        "authFullNameRequired": MessageLookupByLibrary.simpleMessage(
          "Name is required",
        ),
        "authHaveAccount": MessageLookupByLibrary.simpleMessage(
          "Already have an account?",
        ),
        "authInvalidCredential": MessageLookupByLibrary.simpleMessage(
          "Invalid credentials",
        ),
        "authInvalidEmail": MessageLookupByLibrary.simpleMessage(
          "Invalid email address",
        ),
        "authLoading": MessageLookupByLibrary.simpleMessage("Signing in..."),
        "authLoginButton": MessageLookupByLibrary.simpleMessage("Login"),
        "authLoginSubtitle": MessageLookupByLibrary.simpleMessage(
          "Enter your email and password to access the app",
        ),
        "authLoginSuccess": MessageLookupByLibrary.simpleMessage(
          "Logged in successfully",
        ),
        "authLoginTitle": MessageLookupByLibrary.simpleMessage("Login"),
        "authNetworkError": MessageLookupByLibrary.simpleMessage(
          "Check your internet connection",
        ),
        "authNoAccount": MessageLookupByLibrary.simpleMessage(
          "Don\'t have an account?",
        ),
        "authNoProfileDoc": MessageLookupByLibrary.simpleMessage(
          "No profile data found for this account",
        ),
        "authPasswordHint": MessageLookupByLibrary.simpleMessage("••••••••"),
        "authPasswordLabel": MessageLookupByLibrary.simpleMessage("Password"),
        "authPasswordMin": MessageLookupByLibrary.simpleMessage(
          "Password must be at least 6 characters",
        ),
        "authPasswordRequired": MessageLookupByLibrary.simpleMessage(
          "Password is required",
        ),
        "authPasswordsNotMatch": MessageLookupByLibrary.simpleMessage(
          "Passwords do not match",
        ),
        "authRegisterButton": MessageLookupByLibrary.simpleMessage(
          "Create Account",
        ),
        "authRegisterPlaceholder": MessageLookupByLibrary.simpleMessage(
          "Register screen will be added now",
        ),
        "authRegisterSubtitle": MessageLookupByLibrary.simpleMessage(
          "Enter your details to create a new account",
        ),
        "authRegisterSuccess": MessageLookupByLibrary.simpleMessage(
          "Account created successfully",
        ),
        "authRegisterTitle":
            MessageLookupByLibrary.simpleMessage("Create Account"),
        "authResetPasswordFailed": MessageLookupByLibrary.simpleMessage(
          "Unable to send the password reset link.",
        ),
        "authResetPasswordSuccessMessage": m0,
        "authResetPasswordSuccessTitle": MessageLookupByLibrary.simpleMessage(
          "Link Sent",
        ),
        "authSendResetLink": MessageLookupByLibrary.simpleMessage(
          "Send Reset Link",
        ),
        "authSendingResetLink": MessageLookupByLibrary.simpleMessage(
          "Sending reset link...",
        ),
        "authTooManyRequests": MessageLookupByLibrary.simpleMessage(
          "Too many attempts, try later",
        ),
        "authUnknownError": MessageLookupByLibrary.simpleMessage(
          "Unexpected error occurred",
        ),
        "authUserDisabled": MessageLookupByLibrary.simpleMessage(
          "This account is disabled",
        ),
        "authUserNotFound": MessageLookupByLibrary.simpleMessage(
          "No user found with this email",
        ),
        "authWeakPassword":
            MessageLookupByLibrary.simpleMessage("Weak password"),
        "authWelcomeHint": MessageLookupByLibrary.simpleMessage(
          "Sign in to continue",
        ),
        "authWrongPassword":
            MessageLookupByLibrary.simpleMessage("Wrong password"),
        "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "commonCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "commonDone": MessageLookupByLibrary.simpleMessage("Done"),
        "delete": MessageLookupByLibrary.simpleMessage("Delete"),
        "duasAllZones": MessageLookupByLibrary.simpleMessage("All Zones"),
        "duasComingSoonMessage": MessageLookupByLibrary.simpleMessage(
          "In the next phase, text search, voice request, and bilingual Dua playback will be added here.",
        ),
        "duasComingSoonTitle": MessageLookupByLibrary.simpleMessage(
          "Duas Screen Is Coming Soon",
        ),
        "duasEmptyMessage": MessageLookupByLibrary.simpleMessage(
          "No supplications were found for the current search phrase or selected filter.",
        ),
        "duasEmptyTitle": MessageLookupByLibrary.simpleMessage(
          "No Matching Results",
        ),
        "duasListening": MessageLookupByLibrary.simpleMessage("Listening"),
        "duasMicPermissionMessage": MessageLookupByLibrary.simpleMessage(
          "Please allow microphone access so you can request a Dua using voice commands.",
        ),
        "duasMicPermissionTitle": MessageLookupByLibrary.simpleMessage(
          "Microphone Permission Required",
        ),
        "duasPlayButton": MessageLookupByLibrary.simpleMessage("Play Dua"),
        "duasSearchHint": MessageLookupByLibrary.simpleMessage(
          "Search for a dua or zone",
        ),
        "duasSubtitle": MessageLookupByLibrary.simpleMessage(
          "Search manually for the appropriate Dua, or use voice command for quick access to the requested supplication.",
        ),
        "duasTapToRetry": MessageLookupByLibrary.simpleMessage("Try Again"),
        "duasTitle": MessageLookupByLibrary.simpleMessage("Duas"),
        "duasUnknownZone": MessageLookupByLibrary.simpleMessage("Unknown Zone"),
        "duasVoiceDialogHint": MessageLookupByLibrary.simpleMessage(
          "Say the dua name or the zone name, such as Safa dua or Marwah dua",
        ),
        "duasVoiceDialogTitle": MessageLookupByLibrary.simpleMessage(
          "Listening Now",
        ),
        "edit": MessageLookupByLibrary.simpleMessage("Edit"),
        "gpsDisableAction":
            MessageLookupByLibrary.simpleMessage("Disable Feature"),
        "gpsDisableMessage": MessageLookupByLibrary.simpleMessage(
          "If you disable the location feature, current zone detection will stop, automatic Dua triggering will no longer work, and some smart map features may be affected.",
        ),
        "gpsDisableTitle": MessageLookupByLibrary.simpleMessage(
          "Disable Location Feature",
        ),
        "gpsEnableAction":
            MessageLookupByLibrary.simpleMessage("Enable Location"),
        "gpsEnableMessage": MessageLookupByLibrary.simpleMessage(
          "Location is required to detect the pilgrim’s current zone and automatically show the most suitable Dua inside Al-Masjid Al-Haram.",
        ),
        "gpsEnableTitle":
            MessageLookupByLibrary.simpleMessage("Enable Location"),
        "gpsOpenAppSettings": MessageLookupByLibrary.simpleMessage(
          "Open App Settings",
        ),
        "gpsPermissionAction":
            MessageLookupByLibrary.simpleMessage("Allow Access"),
        "gpsPermissionDeniedForeverMessage":
            MessageLookupByLibrary.simpleMessage(
          "Location permission has been permanently denied. Please open the app settings and grant permission manually to continue using location-based features.",
        ),
        "gpsPermissionDeniedForeverTitle": MessageLookupByLibrary.simpleMessage(
          "Permission Permanently Denied",
        ),
        "gpsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
          "Without location permission, the app will not be able to detect your current zone or trigger the appropriate Dua automatically.",
        ),
        "gpsPermissionDeniedTitle": MessageLookupByLibrary.simpleMessage(
          "Permission Not Granted",
        ),
        "gpsPermissionMessage": MessageLookupByLibrary.simpleMessage(
          "We need location access so the app can detect your current zone and show the most appropriate Dua for your position.",
        ),
        "gpsPermissionTitle": MessageLookupByLibrary.simpleMessage(
          "Allow Location Access",
        ),
        "gpsReadyMessage": MessageLookupByLibrary.simpleMessage(
          "The application can now use your location to detect the current zone and trigger the appropriate Dua automatically.",
        ),
        "gpsReadyTitle":
            MessageLookupByLibrary.simpleMessage("Location Enabled"),
        "homeCurrentLocation": MessageLookupByLibrary.simpleMessage(
          "Current location",
        ),
        "homeDoneReading": MessageLookupByLibrary.simpleMessage("Done reading"),
        "homeGuestUser": MessageLookupByLibrary.simpleMessage("Guest User"),
        "homeLocationTawaf": MessageLookupByLibrary.simpleMessage(
          "Tawaf Courtyard",
        ),
        "homeNoDuaButton":
            MessageLookupByLibrary.simpleMessage("No Dua Available"),
        "homeNoDuaMessage": MessageLookupByLibrary.simpleMessage(
          "There is no available Dua for the current zone, or no zone has been detected yet.",
        ),
        "homeNoZoneDetected": MessageLookupByLibrary.simpleMessage(
          "No active zone detected",
        ),
        "homePlayingNow": MessageLookupByLibrary.simpleMessage(
          "Dua is now playing",
        ),
        "homeReadDua": MessageLookupByLibrary.simpleMessage("Read Dua"),
        "homeRecommendedNow": MessageLookupByLibrary.simpleMessage(
          "Recommended dua now",
        ),
        "homeReplayDua": MessageLookupByLibrary.simpleMessage("Replay Dua"),
        "homeSampleDua": MessageLookupByLibrary.simpleMessage(
          "“Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.”",
        ),
        "homeSignedInAs": MessageLookupByLibrary.simpleMessage("User ID"),
        "homeStatusAutoLocationDisabled": MessageLookupByLibrary.simpleMessage(
          "Automatic location updates are disabled from settings",
        ),
        "homeStatusLoading": MessageLookupByLibrary.simpleMessage(
          "Preparing your live location and Dua",
        ),
        "homeStatusLocationUnavailable": MessageLookupByLibrary.simpleMessage(
          "Location is currently unavailable. Please check the service and permissions",
        ),
        "homeStatusNoZone": MessageLookupByLibrary.simpleMessage(
          "No active holy zone has been detected at the moment",
        ),
        "homeStopPlayback":
            MessageLookupByLibrary.simpleMessage("Stop Playback"),
        "homeVoiceStatusDisabled":
            MessageLookupByLibrary.simpleMessage("Disabled"),
        "homeVoiceStatusEnabled":
            MessageLookupByLibrary.simpleMessage("Enabled"),
        "homeVoiceStatusLabel": MessageLookupByLibrary.simpleMessage(
          "Voice Notifications",
        ),
        "langArabic": MessageLookupByLibrary.simpleMessage("Arabic"),
        "langEnglish": MessageLookupByLibrary.simpleMessage("English"),
        "mapBlackStone": MessageLookupByLibrary.simpleMessage("Black Stone"),
        "mapDetectedZoneDesc": MessageLookupByLibrary.simpleMessage(
          "The map now shows the pilgrim’s real position and highlights the currently detected zone using live coordinates.",
        ),
        "mapDetectedZoneTitle": MessageLookupByLibrary.simpleMessage(
          "Current Zone Detected",
        ),
        "mapInsideRangeDesc": MessageLookupByLibrary.simpleMessage(
          "Your location is updated automatically to show the suitable dua for the place.",
        ),
        "mapInsideRangeTitle": MessageLookupByLibrary.simpleMessage(
          "You are inside the zone",
        ),
        "mapKaaba": MessageLookupByLibrary.simpleMessage("Kaaba"),
        "mapMaqam": MessageLookupByLibrary.simpleMessage("Maqam Ibrahim"),
        "mapMarwah": MessageLookupByLibrary.simpleMessage("Marwah"),
        "mapNoZoneDesc": MessageLookupByLibrary.simpleMessage(
          "The map is tracking the pilgrim’s current location, and once a defined zone is entered it will be highlighted automatically.",
        ),
        "mapNoZoneDetected": MessageLookupByLibrary.simpleMessage(
          "No active zone detected right now",
        ),
        "mapNoZoneTitle": MessageLookupByLibrary.simpleMessage(
          "No Zone Detected Yet",
        ),
        "mapSafa": MessageLookupByLibrary.simpleMessage("Safa"),
        "mapTawaf": MessageLookupByLibrary.simpleMessage("Tawaf"),
        "mapTitle": MessageLookupByLibrary.simpleMessage("Sites Map"),
        "navDuas": MessageLookupByLibrary.simpleMessage("Duas"),
        "navHome": MessageLookupByLibrary.simpleMessage("Home"),
        "navMap": MessageLookupByLibrary.simpleMessage("Map"),
        "navSettings": MessageLookupByLibrary.simpleMessage("Settings"),
        "navTasbih": MessageLookupByLibrary.simpleMessage("Tasbih"),
        "settingsAutoLocation": MessageLookupByLibrary.simpleMessage(
          "Auto location update",
        ),
        "settingsAutoLocationSubtitle": MessageLookupByLibrary.simpleMessage(
          "Control automatic location updates to detect the correct zone and display the right Dua.",
        ),
        "settingsLogout": MessageLookupByLibrary.simpleMessage("Logout"),
        "settingsLogoutButton": MessageLookupByLibrary.simpleMessage("Logout"),
        "settingsLogoutFailed": MessageLookupByLibrary.simpleMessage(
          "Unable to log out right now.",
        ),
        "settingsLogoutMessage": MessageLookupByLibrary.simpleMessage(
          "Are you sure you want to log out from this account now?",
        ),
        "settingsLogoutSubtitle": MessageLookupByLibrary.simpleMessage(
          "Sign out from the current account and return to the login screen.",
        ),
        "settingsLogoutTitle": MessageLookupByLibrary.simpleMessage(
          "Confirm Logout",
        ),
        "settingsNightMode": MessageLookupByLibrary.simpleMessage("Night mode"),
        "settingsNightModeSubtitle": MessageLookupByLibrary.simpleMessage(
          "Switch between dark mode and light mode, and save your preference for the whole app.",
        ),
        "settingsNoEmail": MessageLookupByLibrary.simpleMessage(
          "No email available",
        ),
        "settingsNoEmailAvailable": MessageLookupByLibrary.simpleMessage(
          "There is no email linked to this account.",
        ),
        "settingsResetPassword": MessageLookupByLibrary.simpleMessage(
          "Reset Password",
        ),
        "settingsResetPasswordFailed": MessageLookupByLibrary.simpleMessage(
          "Failed to send the password reset link.",
        ),
        "settingsResetPasswordMessage": m1,
        "settingsResetPasswordSuccess": MessageLookupByLibrary.simpleMessage(
          "A password reset link has been sent to your email.",
        ),
        "settingsResetPasswordTitle": MessageLookupByLibrary.simpleMessage(
          "Reset Password",
        ),
        "settingsSendResetLink":
            MessageLookupByLibrary.simpleMessage("Send Link"),
        "settingsSound": MessageLookupByLibrary.simpleMessage(
          "Sound notifications",
        ),
        "settingsSoundSubtitle": MessageLookupByLibrary.simpleMessage(
          "Enable or disable automatic Dua playback based on the current zone.",
        ),
        "settingsTitle":
            MessageLookupByLibrary.simpleMessage("General Settings"),
        "splashLoading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "splashSubtitle": MessageLookupByLibrary.simpleMessage(
          "Smart supplications and guidance based on your location inside the holy sites.",
        ),
        "tasbihReset": MessageLookupByLibrary.simpleMessage("Reset counter"),
        "tasbihTapHint": MessageLookupByLibrary.simpleMessage("Tap to count"),
        "tasbihTitle":
            MessageLookupByLibrary.simpleMessage("Electronic Tasbih"),
        "userHomePlaceholder": MessageLookupByLibrary.simpleMessage(
          "User UI will be linked later",
        ),
        "userHomeTitle": MessageLookupByLibrary.simpleMessage("Home"),
        "view": MessageLookupByLibrary.simpleMessage("View"),
      };
}
