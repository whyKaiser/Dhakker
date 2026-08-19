// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
            ? locale.languageCode
            : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Dhakker`
  String get appTitle {
    return Intl.message('Dhakker', name: 'appTitle', desc: '', args: []);
  }

  /// `English`
  String get langEnglish {
    return Intl.message('English', name: 'langEnglish', desc: '', args: []);
  }

  /// `Arabic`
  String get langArabic {
    return Intl.message('Arabic', name: 'langArabic', desc: '', args: []);
  }

  /// `Home`
  String get navHome {
    return Intl.message('Home', name: 'navHome', desc: '', args: []);
  }

  /// `Map`
  String get navMap {
    return Intl.message('Map', name: 'navMap', desc: '', args: []);
  }

  /// `Tasbih`
  String get navTasbih {
    return Intl.message('Tasbih', name: 'navTasbih', desc: '', args: []);
  }

  /// `Settings`
  String get navSettings {
    return Intl.message('Settings', name: 'navSettings', desc: '', args: []);
  }

  /// `Current location`
  String get homeCurrentLocation {
    return Intl.message(
      'Current location',
      name: 'homeCurrentLocation',
      desc: '',
      args: [],
    );
  }

  /// `Tawaf Courtyard`
  String get homeLocationTawaf {
    return Intl.message(
      'Tawaf Courtyard',
      name: 'homeLocationTawaf',
      desc: '',
      args: [],
    );
  }

  /// `Recommended dua now`
  String get homeRecommendedNow {
    return Intl.message(
      'Recommended dua now',
      name: 'homeRecommendedNow',
      desc: '',
      args: [],
    );
  }

  /// `Done reading`
  String get homeDoneReading {
    return Intl.message(
      'Done reading',
      name: 'homeDoneReading',
      desc: '',
      args: [],
    );
  }

  /// `“Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.”`
  String get homeSampleDua {
    return Intl.message(
      '“Our Lord, grant us good in this world and good in the Hereafter and protect us from the punishment of the Fire.”',
      name: 'homeSampleDua',
      desc: '',
      args: [],
    );
  }

  /// `Sites Map`
  String get mapTitle {
    return Intl.message('Sites Map', name: 'mapTitle', desc: '', args: []);
  }

  /// `You are inside the zone`
  String get mapInsideRangeTitle {
    return Intl.message(
      'You are inside the zone',
      name: 'mapInsideRangeTitle',
      desc: '',
      args: [],
    );
  }

  /// `Your location is updated automatically to show the suitable dua for the place.`
  String get mapInsideRangeDesc {
    return Intl.message(
      'Your location is updated automatically to show the suitable dua for the place.',
      name: 'mapInsideRangeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Kaaba`
  String get mapKaaba {
    return Intl.message('Kaaba', name: 'mapKaaba', desc: '', args: []);
  }

  /// `Tawaf`
  String get mapTawaf {
    return Intl.message('Tawaf', name: 'mapTawaf', desc: '', args: []);
  }

  /// `Maqam Ibrahim`
  String get mapMaqam {
    return Intl.message('Maqam Ibrahim', name: 'mapMaqam', desc: '', args: []);
  }

  /// `Black Stone`
  String get mapBlackStone {
    return Intl.message(
      'Black Stone',
      name: 'mapBlackStone',
      desc: '',
      args: [],
    );
  }

  /// `Safa`
  String get mapSafa {
    return Intl.message('Safa', name: 'mapSafa', desc: '', args: []);
  }

  /// `Marwah`
  String get mapMarwah {
    return Intl.message('Marwah', name: 'mapMarwah', desc: '', args: []);
  }

  /// `Electronic Tasbih`
  String get tasbihTitle {
    return Intl.message(
      'Electronic Tasbih',
      name: 'tasbihTitle',
      desc: '',
      args: [],
    );
  }

  /// `Tap to count`
  String get tasbihTapHint {
    return Intl.message(
      'Tap to count',
      name: 'tasbihTapHint',
      desc: '',
      args: [],
    );
  }

  /// `Reset counter`
  String get tasbihReset {
    return Intl.message(
      'Reset counter',
      name: 'tasbihReset',
      desc: '',
      args: [],
    );
  }

  /// `General Settings`
  String get settingsTitle {
    return Intl.message(
      'General Settings',
      name: 'settingsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Sound notifications`
  String get settingsSound {
    return Intl.message(
      'Sound notifications',
      name: 'settingsSound',
      desc: '',
      args: [],
    );
  }

  /// `Auto location update`
  String get settingsAutoLocation {
    return Intl.message(
      'Auto location update',
      name: 'settingsAutoLocation',
      desc: '',
      args: [],
    );
  }

  /// `Night mode`
  String get settingsNightMode {
    return Intl.message(
      'Night mode',
      name: 'settingsNightMode',
      desc: '',
      args: [],
    );
  }

  /// `Sign in to continue`
  String get authWelcomeHint {
    return Intl.message(
      'Sign in to continue',
      name: 'authWelcomeHint',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get authLoginTitle {
    return Intl.message('Login', name: 'authLoginTitle', desc: '', args: []);
  }

  /// `Enter your email and password to access the app`
  String get authLoginSubtitle {
    return Intl.message(
      'Enter your email and password to access the app',
      name: 'authLoginSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get authEmailLabel {
    return Intl.message('Email', name: 'authEmailLabel', desc: '', args: []);
  }

  /// `example@mail.com`
  String get authEmailHint {
    return Intl.message(
      'example@mail.com',
      name: 'authEmailHint',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get authPasswordLabel {
    return Intl.message(
      'Password',
      name: 'authPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `••••••••`
  String get authPasswordHint {
    return Intl.message(
      '••••••••',
      name: 'authPasswordHint',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get authLoginButton {
    return Intl.message('Login', name: 'authLoginButton', desc: '', args: []);
  }

  /// `Signing in...`
  String get authLoading {
    return Intl.message(
      'Signing in...',
      name: 'authLoading',
      desc: '',
      args: [],
    );
  }

  /// `Don't have an account?`
  String get authNoAccount {
    return Intl.message(
      'Don\'t have an account?',
      name: 'authNoAccount',
      desc: '',
      args: [],
    );
  }

  /// `Create one`
  String get authCreateAccount {
    return Intl.message(
      'Create one',
      name: 'authCreateAccount',
      desc: '',
      args: [],
    );
  }

  /// `Email is required`
  String get authEmailRequired {
    return Intl.message(
      'Email is required',
      name: 'authEmailRequired',
      desc: '',
      args: [],
    );
  }

  /// `Password is required`
  String get authPasswordRequired {
    return Intl.message(
      'Password is required',
      name: 'authPasswordRequired',
      desc: '',
      args: [],
    );
  }

  /// `Password must be at least 6 characters`
  String get authPasswordMin {
    return Intl.message(
      'Password must be at least 6 characters',
      name: 'authPasswordMin',
      desc: '',
      args: [],
    );
  }

  /// `Invalid email address`
  String get authInvalidEmail {
    return Intl.message(
      'Invalid email address',
      name: 'authInvalidEmail',
      desc: '',
      args: [],
    );
  }

  /// `No user found with this email`
  String get authUserNotFound {
    return Intl.message(
      'No user found with this email',
      name: 'authUserNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Wrong password`
  String get authWrongPassword {
    return Intl.message(
      'Wrong password',
      name: 'authWrongPassword',
      desc: '',
      args: [],
    );
  }

  /// `Invalid credentials`
  String get authInvalidCredential {
    return Intl.message(
      'Invalid credentials',
      name: 'authInvalidCredential',
      desc: '',
      args: [],
    );
  }

  /// `This account is disabled`
  String get authUserDisabled {
    return Intl.message(
      'This account is disabled',
      name: 'authUserDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Too many attempts, try later`
  String get authTooManyRequests {
    return Intl.message(
      'Too many attempts, try later',
      name: 'authTooManyRequests',
      desc: '',
      args: [],
    );
  }

  /// `Check your internet connection`
  String get authNetworkError {
    return Intl.message(
      'Check your internet connection',
      name: 'authNetworkError',
      desc: '',
      args: [],
    );
  }

  /// `Unexpected error occurred`
  String get authUnknownError {
    return Intl.message(
      'Unexpected error occurred',
      name: 'authUnknownError',
      desc: '',
      args: [],
    );
  }

  /// `Logged in successfully`
  String get authLoginSuccess {
    return Intl.message(
      'Logged in successfully',
      name: 'authLoginSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Create Account`
  String get authRegisterTitle {
    return Intl.message(
      'Create Account',
      name: 'authRegisterTitle',
      desc: '',
      args: [],
    );
  }

  /// `Register screen will be added now`
  String get authRegisterPlaceholder {
    return Intl.message(
      'Register screen will be added now',
      name: 'authRegisterPlaceholder',
      desc: '',
      args: [],
    );
  }

  /// `Home`
  String get userHomeTitle {
    return Intl.message('Home', name: 'userHomeTitle', desc: '', args: []);
  }

  /// `User UI will be linked later`
  String get userHomePlaceholder {
    return Intl.message(
      'User UI will be linked later',
      name: 'userHomePlaceholder',
      desc: '',
      args: [],
    );
  }

  /// `Admin Panel`
  String get adminHomeTitle {
    return Intl.message(
      'Admin Panel',
      name: 'adminHomeTitle',
      desc: '',
      args: [],
    );
  }

  /// `Admin UI will be linked later`
  String get adminHomePlaceholder {
    return Intl.message(
      'Admin UI will be linked later',
      name: 'adminHomePlaceholder',
      desc: '',
      args: [],
    );
  }

  /// `No profile data found for this account`
  String get authNoProfileDoc {
    return Intl.message(
      'No profile data found for this account',
      name: 'authNoProfileDoc',
      desc: '',
      args: [],
    );
  }

  /// `This account is disabled`
  String get authAccountDisabled {
    return Intl.message(
      'This account is disabled',
      name: 'authAccountDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Enter your details to create a new account`
  String get authRegisterSubtitle {
    return Intl.message(
      'Enter your details to create a new account',
      name: 'authRegisterSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Create Account`
  String get authRegisterButton {
    return Intl.message(
      'Create Account',
      name: 'authRegisterButton',
      desc: '',
      args: [],
    );
  }

  /// `Creating account...`
  String get authCreatingAccount {
    return Intl.message(
      'Creating account...',
      name: 'authCreatingAccount',
      desc: '',
      args: [],
    );
  }

  /// `Full Name`
  String get authFullNameLabel {
    return Intl.message(
      'Full Name',
      name: 'authFullNameLabel',
      desc: '',
      args: [],
    );
  }

  /// `Type your name`
  String get authFullNameHint {
    return Intl.message(
      'Type your name',
      name: 'authFullNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Name is required`
  String get authFullNameRequired {
    return Intl.message(
      'Name is required',
      name: 'authFullNameRequired',
      desc: '',
      args: [],
    );
  }

  /// `Name is too short`
  String get authFullNameMin {
    return Intl.message(
      'Name is too short',
      name: 'authFullNameMin',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Password`
  String get authConfirmPasswordLabel {
    return Intl.message(
      'Confirm Password',
      name: 'authConfirmPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `Confirm password is required`
  String get authConfirmPasswordRequired {
    return Intl.message(
      'Confirm password is required',
      name: 'authConfirmPasswordRequired',
      desc: '',
      args: [],
    );
  }

  /// `Passwords do not match`
  String get authPasswordsNotMatch {
    return Intl.message(
      'Passwords do not match',
      name: 'authPasswordsNotMatch',
      desc: '',
      args: [],
    );
  }

  /// `Weak password`
  String get authWeakPassword {
    return Intl.message(
      'Weak password',
      name: 'authWeakPassword',
      desc: '',
      args: [],
    );
  }

  /// `Email already in use`
  String get authEmailAlreadyInUse {
    return Intl.message(
      'Email already in use',
      name: 'authEmailAlreadyInUse',
      desc: '',
      args: [],
    );
  }

  /// `Account created successfully`
  String get authRegisterSuccess {
    return Intl.message(
      'Account created successfully',
      name: 'authRegisterSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Already have an account?`
  String get authHaveAccount {
    return Intl.message(
      'Already have an account?',
      name: 'authHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get authBackToLogin {
    return Intl.message('Login', name: 'authBackToLogin', desc: '', args: []);
  }

  /// `Admin Panel`
  String get adminPanelTitle {
    return Intl.message(
      'Admin Panel',
      name: 'adminPanelTitle',
      desc: '',
      args: [],
    );
  }

  /// `Dashboard`
  String get adminNavDashboard {
    return Intl.message(
      'Dashboard',
      name: 'adminNavDashboard',
      desc: '',
      args: [],
    );
  }

  /// `Zones`
  String get adminNavZones {
    return Intl.message('Zones', name: 'adminNavZones', desc: '', args: []);
  }

  /// `Supplications`
  String get adminNavSupplications {
    return Intl.message(
      'Supplications',
      name: 'adminNavSupplications',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get adminNavSettings {
    return Intl.message(
      'Settings',
      name: 'adminNavSettings',
      desc: '',
      args: [],
    );
  }

  /// `Overview`
  String get adminDashKpiTitle {
    return Intl.message(
      'Overview',
      name: 'adminDashKpiTitle',
      desc: '',
      args: [],
    );
  }

  /// `Total Zones`
  String get adminDashTotalZones {
    return Intl.message(
      'Total Zones',
      name: 'adminDashTotalZones',
      desc: '',
      args: [],
    );
  }

  /// `Total Supplications`
  String get adminDashTotalSupplications {
    return Intl.message(
      'Total Supplications',
      name: 'adminDashTotalSupplications',
      desc: '',
      args: [],
    );
  }

  /// `Latest`
  String get adminDashLatestTitle {
    return Intl.message(
      'Latest',
      name: 'adminDashLatestTitle',
      desc: '',
      args: [],
    );
  }

  /// `Latest Zones`
  String get adminDashLatestZones {
    return Intl.message(
      'Latest Zones',
      name: 'adminDashLatestZones',
      desc: '',
      args: [],
    );
  }

  /// `Latest Supplications`
  String get adminDashLatestSupplications {
    return Intl.message(
      'Latest Supplications',
      name: 'adminDashLatestSupplications',
      desc: '',
      args: [],
    );
  }

  /// `No data available`
  String get adminDashNoData {
    return Intl.message(
      'No data available',
      name: 'adminDashNoData',
      desc: '',
      args: [],
    );
  }

  /// `Zone`
  String get adminDashZoneIdLabel {
    return Intl.message(
      'Zone',
      name: 'adminDashZoneIdLabel',
      desc: '',
      args: [],
    );
  }

  /// `Audio`
  String get adminDashAudioModeLabel {
    return Intl.message(
      'Audio',
      name: 'adminDashAudioModeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Zone`
  String get adminDashZoneLabel {
    return Intl.message('Zone', name: 'adminDashZoneLabel', desc: '', args: []);
  }

  /// `Admin Settings`
  String get adminSettingsTitle {
    return Intl.message(
      'Admin Settings',
      name: 'adminSettingsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get adminSettingsLanguage {
    return Intl.message(
      'Language',
      name: 'adminSettingsLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Change app language`
  String get adminSettingsLanguageHint {
    return Intl.message(
      'Change app language',
      name: 'adminSettingsLanguageHint',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get adminSettingsTheme {
    return Intl.message(
      'Theme',
      name: 'adminSettingsTheme',
      desc: '',
      args: [],
    );
  }

  /// `Dark`
  String get adminSettingsThemeDark {
    return Intl.message(
      'Dark',
      name: 'adminSettingsThemeDark',
      desc: '',
      args: [],
    );
  }

  /// `Light`
  String get adminSettingsThemeLight {
    return Intl.message(
      'Light',
      name: 'adminSettingsThemeLight',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get adminSettingsLogout {
    return Intl.message(
      'Logout',
      name: 'adminSettingsLogout',
      desc: '',
      args: [],
    );
  }

  /// `Zones Management`
  String get adminZonesTitle {
    return Intl.message(
      'Zones Management',
      name: 'adminZonesTitle',
      desc: '',
      args: [],
    );
  }

  /// `Search by Arabic or English zone name`
  String get adminZonesSearchHint {
    return Intl.message(
      'Search by Arabic or English zone name',
      name: 'adminZonesSearchHint',
      desc: '',
      args: [],
    );
  }

  /// `Type`
  String get adminZonesFilterType {
    return Intl.message(
      'Type',
      name: 'adminZonesFilterType',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get adminZonesFilterStatus {
    return Intl.message(
      'Status',
      name: 'adminZonesFilterStatus',
      desc: '',
      args: [],
    );
  }

  /// `All types`
  String get adminZonesFilterAllTypes {
    return Intl.message(
      'All types',
      name: 'adminZonesFilterAllTypes',
      desc: '',
      args: [],
    );
  }

  /// `All statuses`
  String get adminZonesFilterAllStatuses {
    return Intl.message(
      'All statuses',
      name: 'adminZonesFilterAllStatuses',
      desc: '',
      args: [],
    );
  }

  /// `Circle`
  String get adminZonesTypeCircle {
    return Intl.message(
      'Circle',
      name: 'adminZonesTypeCircle',
      desc: '',
      args: [],
    );
  }

  /// `Polygon`
  String get adminZonesTypePolygon {
    return Intl.message(
      'Polygon',
      name: 'adminZonesTypePolygon',
      desc: '',
      args: [],
    );
  }

  /// `Active`
  String get adminZonesStatusActive {
    return Intl.message(
      'Active',
      name: 'adminZonesStatusActive',
      desc: '',
      args: [],
    );
  }

  /// `Inactive`
  String get adminZonesStatusInactive {
    return Intl.message(
      'Inactive',
      name: 'adminZonesStatusInactive',
      desc: '',
      args: [],
    );
  }

  /// `Add Zone`
  String get adminZonesAddZone {
    return Intl.message(
      'Add Zone',
      name: 'adminZonesAddZone',
      desc: '',
      args: [],
    );
  }

  /// `results`
  String get adminZonesResultsLabel {
    return Intl.message(
      'results',
      name: 'adminZonesResultsLabel',
      desc: '',
      args: [],
    );
  }

  /// `Priority`
  String get adminZonesPriorityLabel {
    return Intl.message(
      'Priority',
      name: 'adminZonesPriorityLabel',
      desc: '',
      args: [],
    );
  }

  /// `Document ID`
  String get adminZonesDocIdLabel {
    return Intl.message(
      'Document ID',
      name: 'adminZonesDocIdLabel',
      desc: '',
      args: [],
    );
  }

  /// `No zones found`
  String get adminZonesEmptyTitle {
    return Intl.message(
      'No zones found',
      name: 'adminZonesEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `There are no zones matching the current search or filters.`
  String get adminZonesEmptyMessage {
    return Intl.message(
      'There are no zones matching the current search or filters.',
      name: 'adminZonesEmptyMessage',
      desc: '',
      args: [],
    );
  }

  /// `Unable to load zones`
  String get adminZonesLoadErrorTitle {
    return Intl.message(
      'Unable to load zones',
      name: 'adminZonesLoadErrorTitle',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong while loading the zones list.`
  String get adminZonesLoadErrorMessage {
    return Intl.message(
      'Something went wrong while loading the zones list.',
      name: 'adminZonesLoadErrorMessage',
      desc: '',
      args: [],
    );
  }

  /// `Delete Zone`
  String get adminZonesDeleteTitle {
    return Intl.message(
      'Delete Zone',
      name: 'adminZonesDeleteTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this zone?`
  String get adminZonesDeleteMessage {
    return Intl.message(
      'Are you sure you want to delete this zone?',
      name: 'adminZonesDeleteMessage',
      desc: '',
      args: [],
    );
  }

  /// `Zone deleted successfully.`
  String get adminZonesDeleteSuccess {
    return Intl.message(
      'Zone deleted successfully.',
      name: 'adminZonesDeleteSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to delete the zone.`
  String get adminZonesDeleteError {
    return Intl.message(
      'Failed to delete the zone.',
      name: 'adminZonesDeleteError',
      desc: '',
      args: [],
    );
  }

  /// `View`
  String get view {
    return Intl.message('View', name: 'view', desc: '', args: []);
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Add Zone`
  String get adminZoneAddTitle {
    return Intl.message(
      'Add Zone',
      name: 'adminZoneAddTitle',
      desc: '',
      args: [],
    );
  }

  /// `Basic Information`
  String get adminZoneAddBasicInfoTitle {
    return Intl.message(
      'Basic Information',
      name: 'adminZoneAddBasicInfoTitle',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Name`
  String get adminZoneAddNameAr {
    return Intl.message(
      'Arabic Name',
      name: 'adminZoneAddNameAr',
      desc: '',
      args: [],
    );
  }

  /// `Enter the zone name in Arabic`
  String get adminZoneAddNameArHint {
    return Intl.message(
      'Enter the zone name in Arabic',
      name: 'adminZoneAddNameArHint',
      desc: '',
      args: [],
    );
  }

  /// `Arabic name is required`
  String get adminZoneAddNameArRequired {
    return Intl.message(
      'Arabic name is required',
      name: 'adminZoneAddNameArRequired',
      desc: '',
      args: [],
    );
  }

  /// `English Name`
  String get adminZoneAddNameEn {
    return Intl.message(
      'English Name',
      name: 'adminZoneAddNameEn',
      desc: '',
      args: [],
    );
  }

  /// `Enter the zone name in English`
  String get adminZoneAddNameEnHint {
    return Intl.message(
      'Enter the zone name in English',
      name: 'adminZoneAddNameEnHint',
      desc: '',
      args: [],
    );
  }

  /// `English name is required`
  String get adminZoneAddNameEnRequired {
    return Intl.message(
      'English name is required',
      name: 'adminZoneAddNameEnRequired',
      desc: '',
      args: [],
    );
  }

  /// `Priority`
  String get adminZoneAddPriority {
    return Intl.message(
      'Priority',
      name: 'adminZoneAddPriority',
      desc: '',
      args: [],
    );
  }

  /// `Enter overlap priority`
  String get adminZoneAddPriorityHint {
    return Intl.message(
      'Enter overlap priority',
      name: 'adminZoneAddPriorityHint',
      desc: '',
      args: [],
    );
  }

  /// `Priority is required`
  String get adminZoneAddPriorityRequired {
    return Intl.message(
      'Priority is required',
      name: 'adminZoneAddPriorityRequired',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid priority number`
  String get adminZoneAddPriorityInvalid {
    return Intl.message(
      'Enter a valid priority number',
      name: 'adminZoneAddPriorityInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Zone Status`
  String get adminZoneAddStatusTitle {
    return Intl.message(
      'Zone Status',
      name: 'adminZoneAddStatusTitle',
      desc: '',
      args: [],
    );
  }

  /// `This zone is currently active and can be used in the system.`
  String get adminZoneAddStatusActiveText {
    return Intl.message(
      'This zone is currently active and can be used in the system.',
      name: 'adminZoneAddStatusActiveText',
      desc: '',
      args: [],
    );
  }

  /// `This zone is inactive and will not be used until enabled.`
  String get adminZoneAddStatusInactiveText {
    return Intl.message(
      'This zone is inactive and will not be used until enabled.',
      name: 'adminZoneAddStatusInactiveText',
      desc: '',
      args: [],
    );
  }

  /// `Zone Shape`
  String get adminZoneAddTypeTitle {
    return Intl.message(
      'Zone Shape',
      name: 'adminZoneAddTypeTitle',
      desc: '',
      args: [],
    );
  }

  /// `Circle`
  String get adminZoneAddTypeCircle {
    return Intl.message(
      'Circle',
      name: 'adminZoneAddTypeCircle',
      desc: '',
      args: [],
    );
  }

  /// `Use center location and radius`
  String get adminZoneAddTypeCircleDesc {
    return Intl.message(
      'Use center location and radius',
      name: 'adminZoneAddTypeCircleDesc',
      desc: '',
      args: [],
    );
  }

  /// `Polygon`
  String get adminZoneAddTypePolygon {
    return Intl.message(
      'Polygon',
      name: 'adminZoneAddTypePolygon',
      desc: '',
      args: [],
    );
  }

  /// `Use multiple points to define the area`
  String get adminZoneAddTypePolygonDesc {
    return Intl.message(
      'Use multiple points to define the area',
      name: 'adminZoneAddTypePolygonDesc',
      desc: '',
      args: [],
    );
  }

  /// `Circle Zone Setup`
  String get adminZoneAddCircleCardTitle {
    return Intl.message(
      'Circle Zone Setup',
      name: 'adminZoneAddCircleCardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Enter the center latitude, center longitude, and radius in meters.`
  String get adminZoneAddCircleCardSubtitle {
    return Intl.message(
      'Enter the center latitude, center longitude, and radius in meters.',
      name: 'adminZoneAddCircleCardSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Center Latitude`
  String get adminZoneAddCenterLat {
    return Intl.message(
      'Center Latitude',
      name: 'adminZoneAddCenterLat',
      desc: '',
      args: [],
    );
  }

  /// `Example: 21.4225`
  String get adminZoneAddCenterLatHint {
    return Intl.message(
      'Example: 21.4225',
      name: 'adminZoneAddCenterLatHint',
      desc: '',
      args: [],
    );
  }

  /// `Center latitude is required`
  String get adminZoneAddCenterLatRequired {
    return Intl.message(
      'Center latitude is required',
      name: 'adminZoneAddCenterLatRequired',
      desc: '',
      args: [],
    );
  }

  /// `Center Longitude`
  String get adminZoneAddCenterLng {
    return Intl.message(
      'Center Longitude',
      name: 'adminZoneAddCenterLng',
      desc: '',
      args: [],
    );
  }

  /// `Example: 39.8262`
  String get adminZoneAddCenterLngHint {
    return Intl.message(
      'Example: 39.8262',
      name: 'adminZoneAddCenterLngHint',
      desc: '',
      args: [],
    );
  }

  /// `Center longitude is required`
  String get adminZoneAddCenterLngRequired {
    return Intl.message(
      'Center longitude is required',
      name: 'adminZoneAddCenterLngRequired',
      desc: '',
      args: [],
    );
  }

  /// `Radius (Meters)`
  String get adminZoneAddRadius {
    return Intl.message(
      'Radius (Meters)',
      name: 'adminZoneAddRadius',
      desc: '',
      args: [],
    );
  }

  /// `Example: 50`
  String get adminZoneAddRadiusHint {
    return Intl.message(
      'Example: 50',
      name: 'adminZoneAddRadiusHint',
      desc: '',
      args: [],
    );
  }

  /// `Radius is required`
  String get adminZoneAddRadiusRequired {
    return Intl.message(
      'Radius is required',
      name: 'adminZoneAddRadiusRequired',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid radius greater than zero`
  String get adminZoneAddRadiusInvalid {
    return Intl.message(
      'Enter a valid radius greater than zero',
      name: 'adminZoneAddRadiusInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Polygon Zone Setup`
  String get adminZoneAddPolygonCardTitle {
    return Intl.message(
      'Polygon Zone Setup',
      name: 'adminZoneAddPolygonCardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Add each point of the area one by one. At least 3 points are required.`
  String get adminZoneAddPolygonCardSubtitle {
    return Intl.message(
      'Add each point of the area one by one. At least 3 points are required.',
      name: 'adminZoneAddPolygonCardSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Point Latitude`
  String get adminZoneAddPointLat {
    return Intl.message(
      'Point Latitude',
      name: 'adminZoneAddPointLat',
      desc: '',
      args: [],
    );
  }

  /// `Enter latitude`
  String get adminZoneAddPointLatHint {
    return Intl.message(
      'Enter latitude',
      name: 'adminZoneAddPointLatHint',
      desc: '',
      args: [],
    );
  }

  /// `Point Longitude`
  String get adminZoneAddPointLng {
    return Intl.message(
      'Point Longitude',
      name: 'adminZoneAddPointLng',
      desc: '',
      args: [],
    );
  }

  /// `Enter longitude`
  String get adminZoneAddPointLngHint {
    return Intl.message(
      'Enter longitude',
      name: 'adminZoneAddPointLngHint',
      desc: '',
      args: [],
    );
  }

  /// `Add Point`
  String get adminZoneAddPointButton {
    return Intl.message(
      'Add Point',
      name: 'adminZoneAddPointButton',
      desc: '',
      args: [],
    );
  }

  /// `Please enter both latitude and longitude for the point`
  String get adminZoneAddPointRequired {
    return Intl.message(
      'Please enter both latitude and longitude for the point',
      name: 'adminZoneAddPointRequired',
      desc: '',
      args: [],
    );
  }

  /// `Polygon zone must contain at least 3 points`
  String get adminZoneAddPolygonMinPoints {
    return Intl.message(
      'Polygon zone must contain at least 3 points',
      name: 'adminZoneAddPolygonMinPoints',
      desc: '',
      args: [],
    );
  }

  /// `No points added yet. Start by entering a latitude and longitude, then tap Add Point.`
  String get adminZoneAddNoPointsYet {
    return Intl.message(
      'No points added yet. Start by entering a latitude and longitude, then tap Add Point.',
      name: 'adminZoneAddNoPointsYet',
      desc: '',
      args: [],
    );
  }

  /// `points added`
  String get adminZoneAddPointsCount {
    return Intl.message(
      'points added',
      name: 'adminZoneAddPointsCount',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid latitude between -90 and 90`
  String get adminZoneAddLatitudeInvalid {
    return Intl.message(
      'Enter a valid latitude between -90 and 90',
      name: 'adminZoneAddLatitudeInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid longitude between -180 and 180`
  String get adminZoneAddLongitudeInvalid {
    return Intl.message(
      'Enter a valid longitude between -180 and 180',
      name: 'adminZoneAddLongitudeInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Save Zone`
  String get adminZoneAddSave {
    return Intl.message(
      'Save Zone',
      name: 'adminZoneAddSave',
      desc: '',
      args: [],
    );
  }

  /// `Saving...`
  String get adminZoneAddSaving {
    return Intl.message(
      'Saving...',
      name: 'adminZoneAddSaving',
      desc: '',
      args: [],
    );
  }

  /// `Zone added successfully.`
  String get adminZoneAddSuccess {
    return Intl.message(
      'Zone added successfully.',
      name: 'adminZoneAddSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to add the zone. Please try again.`
  String get adminZoneAddError {
    return Intl.message(
      'Failed to add the zone. Please try again.',
      name: 'adminZoneAddError',
      desc: '',
      args: [],
    );
  }

  /// `Edit Zone`
  String get adminZoneEditTitle {
    return Intl.message(
      'Edit Zone',
      name: 'adminZoneEditTitle',
      desc: '',
      args: [],
    );
  }

  /// `Basic Information`
  String get adminZoneEditBasicInfoTitle {
    return Intl.message(
      'Basic Information',
      name: 'adminZoneEditBasicInfoTitle',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Name`
  String get adminZoneEditNameAr {
    return Intl.message(
      'Arabic Name',
      name: 'adminZoneEditNameAr',
      desc: '',
      args: [],
    );
  }

  /// `Update the zone name in Arabic`
  String get adminZoneEditNameArHint {
    return Intl.message(
      'Update the zone name in Arabic',
      name: 'adminZoneEditNameArHint',
      desc: '',
      args: [],
    );
  }

  /// `Arabic name is required`
  String get adminZoneEditNameArRequired {
    return Intl.message(
      'Arabic name is required',
      name: 'adminZoneEditNameArRequired',
      desc: '',
      args: [],
    );
  }

  /// `English Name`
  String get adminZoneEditNameEn {
    return Intl.message(
      'English Name',
      name: 'adminZoneEditNameEn',
      desc: '',
      args: [],
    );
  }

  /// `Update the zone name in English`
  String get adminZoneEditNameEnHint {
    return Intl.message(
      'Update the zone name in English',
      name: 'adminZoneEditNameEnHint',
      desc: '',
      args: [],
    );
  }

  /// `English name is required`
  String get adminZoneEditNameEnRequired {
    return Intl.message(
      'English name is required',
      name: 'adminZoneEditNameEnRequired',
      desc: '',
      args: [],
    );
  }

  /// `Priority`
  String get adminZoneEditPriority {
    return Intl.message(
      'Priority',
      name: 'adminZoneEditPriority',
      desc: '',
      args: [],
    );
  }

  /// `Update overlap priority`
  String get adminZoneEditPriorityHint {
    return Intl.message(
      'Update overlap priority',
      name: 'adminZoneEditPriorityHint',
      desc: '',
      args: [],
    );
  }

  /// `Priority is required`
  String get adminZoneEditPriorityRequired {
    return Intl.message(
      'Priority is required',
      name: 'adminZoneEditPriorityRequired',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid priority number`
  String get adminZoneEditPriorityInvalid {
    return Intl.message(
      'Enter a valid priority number',
      name: 'adminZoneEditPriorityInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Zone Status`
  String get adminZoneEditStatusTitle {
    return Intl.message(
      'Zone Status',
      name: 'adminZoneEditStatusTitle',
      desc: '',
      args: [],
    );
  }

  /// `This zone is currently active and can be used in the system.`
  String get adminZoneEditStatusActiveText {
    return Intl.message(
      'This zone is currently active and can be used in the system.',
      name: 'adminZoneEditStatusActiveText',
      desc: '',
      args: [],
    );
  }

  /// `This zone is inactive and will not be used until enabled.`
  String get adminZoneEditStatusInactiveText {
    return Intl.message(
      'This zone is inactive and will not be used until enabled.',
      name: 'adminZoneEditStatusInactiveText',
      desc: '',
      args: [],
    );
  }

  /// `Zone Shape`
  String get adminZoneEditTypeTitle {
    return Intl.message(
      'Zone Shape',
      name: 'adminZoneEditTypeTitle',
      desc: '',
      args: [],
    );
  }

  /// `Circle`
  String get adminZoneEditTypeCircle {
    return Intl.message(
      'Circle',
      name: 'adminZoneEditTypeCircle',
      desc: '',
      args: [],
    );
  }

  /// `Use center location and radius`
  String get adminZoneEditTypeCircleDesc {
    return Intl.message(
      'Use center location and radius',
      name: 'adminZoneEditTypeCircleDesc',
      desc: '',
      args: [],
    );
  }

  /// `Polygon`
  String get adminZoneEditTypePolygon {
    return Intl.message(
      'Polygon',
      name: 'adminZoneEditTypePolygon',
      desc: '',
      args: [],
    );
  }

  /// `Use multiple points to define the area`
  String get adminZoneEditTypePolygonDesc {
    return Intl.message(
      'Use multiple points to define the area',
      name: 'adminZoneEditTypePolygonDesc',
      desc: '',
      args: [],
    );
  }

  /// `Circle Zone Setup`
  String get adminZoneEditCircleCardTitle {
    return Intl.message(
      'Circle Zone Setup',
      name: 'adminZoneEditCircleCardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Update the center latitude, center longitude, and radius in meters.`
  String get adminZoneEditCircleCardSubtitle {
    return Intl.message(
      'Update the center latitude, center longitude, and radius in meters.',
      name: 'adminZoneEditCircleCardSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Center Latitude`
  String get adminZoneEditCenterLat {
    return Intl.message(
      'Center Latitude',
      name: 'adminZoneEditCenterLat',
      desc: '',
      args: [],
    );
  }

  /// `Example: 21.4225`
  String get adminZoneEditCenterLatHint {
    return Intl.message(
      'Example: 21.4225',
      name: 'adminZoneEditCenterLatHint',
      desc: '',
      args: [],
    );
  }

  /// `Center latitude is required`
  String get adminZoneEditCenterLatRequired {
    return Intl.message(
      'Center latitude is required',
      name: 'adminZoneEditCenterLatRequired',
      desc: '',
      args: [],
    );
  }

  /// `Center Longitude`
  String get adminZoneEditCenterLng {
    return Intl.message(
      'Center Longitude',
      name: 'adminZoneEditCenterLng',
      desc: '',
      args: [],
    );
  }

  /// `Example: 39.8262`
  String get adminZoneEditCenterLngHint {
    return Intl.message(
      'Example: 39.8262',
      name: 'adminZoneEditCenterLngHint',
      desc: '',
      args: [],
    );
  }

  /// `Center longitude is required`
  String get adminZoneEditCenterLngRequired {
    return Intl.message(
      'Center longitude is required',
      name: 'adminZoneEditCenterLngRequired',
      desc: '',
      args: [],
    );
  }

  /// `Radius (Meters)`
  String get adminZoneEditRadius {
    return Intl.message(
      'Radius (Meters)',
      name: 'adminZoneEditRadius',
      desc: '',
      args: [],
    );
  }

  /// `Example: 50`
  String get adminZoneEditRadiusHint {
    return Intl.message(
      'Example: 50',
      name: 'adminZoneEditRadiusHint',
      desc: '',
      args: [],
    );
  }

  /// `Radius is required`
  String get adminZoneEditRadiusRequired {
    return Intl.message(
      'Radius is required',
      name: 'adminZoneEditRadiusRequired',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid radius greater than zero`
  String get adminZoneEditRadiusInvalid {
    return Intl.message(
      'Enter a valid radius greater than zero',
      name: 'adminZoneEditRadiusInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Polygon Zone Setup`
  String get adminZoneEditPolygonCardTitle {
    return Intl.message(
      'Polygon Zone Setup',
      name: 'adminZoneEditPolygonCardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Add each point of the area one by one. At least 3 points are required.`
  String get adminZoneEditPolygonCardSubtitle {
    return Intl.message(
      'Add each point of the area one by one. At least 3 points are required.',
      name: 'adminZoneEditPolygonCardSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Point Latitude`
  String get adminZoneEditPointLat {
    return Intl.message(
      'Point Latitude',
      name: 'adminZoneEditPointLat',
      desc: '',
      args: [],
    );
  }

  /// `Enter latitude`
  String get adminZoneEditPointLatHint {
    return Intl.message(
      'Enter latitude',
      name: 'adminZoneEditPointLatHint',
      desc: '',
      args: [],
    );
  }

  /// `Point Longitude`
  String get adminZoneEditPointLng {
    return Intl.message(
      'Point Longitude',
      name: 'adminZoneEditPointLng',
      desc: '',
      args: [],
    );
  }

  /// `Enter longitude`
  String get adminZoneEditPointLngHint {
    return Intl.message(
      'Enter longitude',
      name: 'adminZoneEditPointLngHint',
      desc: '',
      args: [],
    );
  }

  /// `Add Point`
  String get adminZoneEditPointButton {
    return Intl.message(
      'Add Point',
      name: 'adminZoneEditPointButton',
      desc: '',
      args: [],
    );
  }

  /// `Please enter both latitude and longitude for the point`
  String get adminZoneEditPointRequired {
    return Intl.message(
      'Please enter both latitude and longitude for the point',
      name: 'adminZoneEditPointRequired',
      desc: '',
      args: [],
    );
  }

  /// `Polygon zone must contain at least 3 points`
  String get adminZoneEditPolygonMinPoints {
    return Intl.message(
      'Polygon zone must contain at least 3 points',
      name: 'adminZoneEditPolygonMinPoints',
      desc: '',
      args: [],
    );
  }

  /// `No points added yet. Start by entering a latitude and longitude, then tap Add Point.`
  String get adminZoneEditNoPointsYet {
    return Intl.message(
      'No points added yet. Start by entering a latitude and longitude, then tap Add Point.',
      name: 'adminZoneEditNoPointsYet',
      desc: '',
      args: [],
    );
  }

  /// `points added`
  String get adminZoneEditPointsCount {
    return Intl.message(
      'points added',
      name: 'adminZoneEditPointsCount',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid latitude between -90 and 90`
  String get adminZoneEditLatitudeInvalid {
    return Intl.message(
      'Enter a valid latitude between -90 and 90',
      name: 'adminZoneEditLatitudeInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid longitude between -180 and 180`
  String get adminZoneEditLongitudeInvalid {
    return Intl.message(
      'Enter a valid longitude between -180 and 180',
      name: 'adminZoneEditLongitudeInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Save Changes`
  String get adminZoneEditSave {
    return Intl.message(
      'Save Changes',
      name: 'adminZoneEditSave',
      desc: '',
      args: [],
    );
  }

  /// `Saving...`
  String get adminZoneEditSaving {
    return Intl.message(
      'Saving...',
      name: 'adminZoneEditSaving',
      desc: '',
      args: [],
    );
  }

  /// `Zone updated successfully.`
  String get adminZoneEditSuccess {
    return Intl.message(
      'Zone updated successfully.',
      name: 'adminZoneEditSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to update the zone. Please try again.`
  String get adminZoneEditError {
    return Intl.message(
      'Failed to update the zone. Please try again.',
      name: 'adminZoneEditError',
      desc: '',
      args: [],
    );
  }

  /// `Zone not found.`
  String get adminZoneEditNotFound {
    return Intl.message(
      'Zone not found.',
      name: 'adminZoneEditNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load zone data.`
  String get adminZoneEditLoadError {
    return Intl.message(
      'Failed to load zone data.',
      name: 'adminZoneEditLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Zone Details`
  String get adminZoneDetailsTitle {
    return Intl.message(
      'Zone Details',
      name: 'adminZoneDetailsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone not found.`
  String get adminZoneDetailsNotFound {
    return Intl.message(
      'Zone not found.',
      name: 'adminZoneDetailsNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load zone details.`
  String get adminZoneDetailsLoadError {
    return Intl.message(
      'Failed to load zone details.',
      name: 'adminZoneDetailsLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Overview`
  String get adminZoneDetailsOverviewTitle {
    return Intl.message(
      'Overview',
      name: 'adminZoneDetailsOverviewTitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone Map Preview`
  String get adminZoneDetailsMapTitle {
    return Intl.message(
      'Zone Map Preview',
      name: 'adminZoneDetailsMapTitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone Information`
  String get adminZoneDetailsInfoTitle {
    return Intl.message(
      'Zone Information',
      name: 'adminZoneDetailsInfoTitle',
      desc: '',
      args: [],
    );
  }

  /// `Polygon Points`
  String get adminZoneDetailsPointsTitle {
    return Intl.message(
      'Polygon Points',
      name: 'adminZoneDetailsPointsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Related Supplications`
  String get adminZoneDetailsRelatedTitle {
    return Intl.message(
      'Related Supplications',
      name: 'adminZoneDetailsRelatedTitle',
      desc: '',
      args: [],
    );
  }

  /// `You can review the full zone information here, preview its location on the map, and open the related supplications directly.`
  String get adminZoneDetailsHint {
    return Intl.message(
      'You can review the full zone information here, preview its location on the map, and open the related supplications directly.',
      name: 'adminZoneDetailsHint',
      desc: '',
      args: [],
    );
  }

  /// `Circle`
  String get adminZoneDetailsTypeCircle {
    return Intl.message(
      'Circle',
      name: 'adminZoneDetailsTypeCircle',
      desc: '',
      args: [],
    );
  }

  /// `Polygon`
  String get adminZoneDetailsTypePolygon {
    return Intl.message(
      'Polygon',
      name: 'adminZoneDetailsTypePolygon',
      desc: '',
      args: [],
    );
  }

  /// `Active`
  String get adminZoneDetailsStatusActive {
    return Intl.message(
      'Active',
      name: 'adminZoneDetailsStatusActive',
      desc: '',
      args: [],
    );
  }

  /// `Inactive`
  String get adminZoneDetailsStatusInactive {
    return Intl.message(
      'Inactive',
      name: 'adminZoneDetailsStatusInactive',
      desc: '',
      args: [],
    );
  }

  /// `Priority`
  String get adminZoneDetailsPriorityLabel {
    return Intl.message(
      'Priority',
      name: 'adminZoneDetailsPriorityLabel',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Name`
  String get adminZoneDetailsNameAr {
    return Intl.message(
      'Arabic Name',
      name: 'adminZoneDetailsNameAr',
      desc: '',
      args: [],
    );
  }

  /// `English Name`
  String get adminZoneDetailsNameEn {
    return Intl.message(
      'English Name',
      name: 'adminZoneDetailsNameEn',
      desc: '',
      args: [],
    );
  }

  /// `Zone Type`
  String get adminZoneDetailsTypeLabel {
    return Intl.message(
      'Zone Type',
      name: 'adminZoneDetailsTypeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get adminZoneDetailsStatusLabel {
    return Intl.message(
      'Status',
      name: 'adminZoneDetailsStatusLabel',
      desc: '',
      args: [],
    );
  }

  /// `Center Latitude`
  String get adminZoneDetailsCenterLatLabel {
    return Intl.message(
      'Center Latitude',
      name: 'adminZoneDetailsCenterLatLabel',
      desc: '',
      args: [],
    );
  }

  /// `Center Longitude`
  String get adminZoneDetailsCenterLngLabel {
    return Intl.message(
      'Center Longitude',
      name: 'adminZoneDetailsCenterLngLabel',
      desc: '',
      args: [],
    );
  }

  /// `Radius`
  String get adminZoneDetailsRadiusLabel {
    return Intl.message(
      'Radius',
      name: 'adminZoneDetailsRadiusLabel',
      desc: '',
      args: [],
    );
  }

  /// `Points Count`
  String get adminZoneDetailsPointsCountLabel {
    return Intl.message(
      'Points Count',
      name: 'adminZoneDetailsPointsCountLabel',
      desc: '',
      args: [],
    );
  }

  /// `View Related Supplications`
  String get adminZoneDetailsRelatedSupplicationsButton {
    return Intl.message(
      'View Related Supplications',
      name: 'adminZoneDetailsRelatedSupplicationsButton',
      desc: '',
      args: [],
    );
  }

  /// `Supplications count`
  String get adminZoneDetailsRelatedCountLabel {
    return Intl.message(
      'Supplications count',
      name: 'adminZoneDetailsRelatedCountLabel',
      desc: '',
      args: [],
    );
  }

  /// `Map preview is unavailable`
  String get adminZoneDetailsMapUnavailableTitle {
    return Intl.message(
      'Map preview is unavailable',
      name: 'adminZoneDetailsMapUnavailableTitle',
      desc: '',
      args: [],
    );
  }

  /// `This zone does not contain enough valid coordinates to draw it on the map.`
  String get adminZoneDetailsMapUnavailableSubtitle {
    return Intl.message(
      'This zone does not contain enough valid coordinates to draw it on the map.',
      name: 'adminZoneDetailsMapUnavailableSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone preview`
  String get adminZoneDetailsZonePreview {
    return Intl.message(
      'Zone preview',
      name: 'adminZoneDetailsZonePreview',
      desc: '',
      args: [],
    );
  }

  /// `No polygon points available.`
  String get adminZoneDetailsNoPoints {
    return Intl.message(
      'No polygon points available.',
      name: 'adminZoneDetailsNoPoints',
      desc: '',
      args: [],
    );
  }

  /// `Supplications Management`
  String get adminSupplicationsTitle {
    return Intl.message(
      'Supplications Management',
      name: 'adminSupplicationsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Search by Arabic or English title`
  String get adminSupplicationsSearchHint {
    return Intl.message(
      'Search by Arabic or English title',
      name: 'adminSupplicationsSearchHint',
      desc: '',
      args: [],
    );
  }

  /// `Zone`
  String get adminSupplicationsFilterZone {
    return Intl.message(
      'Zone',
      name: 'adminSupplicationsFilterZone',
      desc: '',
      args: [],
    );
  }

  /// `Audio Mode`
  String get adminSupplicationsFilterAudioMode {
    return Intl.message(
      'Audio Mode',
      name: 'adminSupplicationsFilterAudioMode',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get adminSupplicationsFilterStatus {
    return Intl.message(
      'Status',
      name: 'adminSupplicationsFilterStatus',
      desc: '',
      args: [],
    );
  }

  /// `All zones`
  String get adminSupplicationsAllZones {
    return Intl.message(
      'All zones',
      name: 'adminSupplicationsAllZones',
      desc: '',
      args: [],
    );
  }

  /// `All audio modes`
  String get adminSupplicationsAllAudioModes {
    return Intl.message(
      'All audio modes',
      name: 'adminSupplicationsAllAudioModes',
      desc: '',
      args: [],
    );
  }

  /// `All statuses`
  String get adminSupplicationsAllStatuses {
    return Intl.message(
      'All statuses',
      name: 'adminSupplicationsAllStatuses',
      desc: '',
      args: [],
    );
  }

  /// `TTS`
  String get adminSupplicationsAudioTts {
    return Intl.message(
      'TTS',
      name: 'adminSupplicationsAudioTts',
      desc: '',
      args: [],
    );
  }

  /// `Audio File`
  String get adminSupplicationsAudioFile {
    return Intl.message(
      'Audio File',
      name: 'adminSupplicationsAudioFile',
      desc: '',
      args: [],
    );
  }

  /// `Active`
  String get adminSupplicationsStatusActive {
    return Intl.message(
      'Active',
      name: 'adminSupplicationsStatusActive',
      desc: '',
      args: [],
    );
  }

  /// `Inactive`
  String get adminSupplicationsStatusInactive {
    return Intl.message(
      'Inactive',
      name: 'adminSupplicationsStatusInactive',
      desc: '',
      args: [],
    );
  }

  /// `results`
  String get adminSupplicationsResultsLabel {
    return Intl.message(
      'results',
      name: 'adminSupplicationsResultsLabel',
      desc: '',
      args: [],
    );
  }

  /// `Add Supplication`
  String get adminSupplicationsAddButton {
    return Intl.message(
      'Add Supplication',
      name: 'adminSupplicationsAddButton',
      desc: '',
      args: [],
    );
  }

  /// `Zone`
  String get adminSupplicationsZoneLabel {
    return Intl.message(
      'Zone',
      name: 'adminSupplicationsZoneLabel',
      desc: '',
      args: [],
    );
  }

  /// `Audio Mode`
  String get adminSupplicationsAudioModeLabel {
    return Intl.message(
      'Audio Mode',
      name: 'adminSupplicationsAudioModeLabel',
      desc: '',
      args: [],
    );
  }

  /// `No supplications found`
  String get adminSupplicationsEmptyTitle {
    return Intl.message(
      'No supplications found',
      name: 'adminSupplicationsEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `There are no supplications matching the current search or filters.`
  String get adminSupplicationsEmptyMessage {
    return Intl.message(
      'There are no supplications matching the current search or filters.',
      name: 'adminSupplicationsEmptyMessage',
      desc: '',
      args: [],
    );
  }

  /// `Unable to load supplications`
  String get adminSupplicationsLoadErrorTitle {
    return Intl.message(
      'Unable to load supplications',
      name: 'adminSupplicationsLoadErrorTitle',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong while loading the supplications list.`
  String get adminSupplicationsLoadErrorMessage {
    return Intl.message(
      'Something went wrong while loading the supplications list.',
      name: 'adminSupplicationsLoadErrorMessage',
      desc: '',
      args: [],
    );
  }

  /// `Delete Supplication`
  String get adminSupplicationsDeleteTitle {
    return Intl.message(
      'Delete Supplication',
      name: 'adminSupplicationsDeleteTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this supplication?`
  String get adminSupplicationsDeleteMessage {
    return Intl.message(
      'Are you sure you want to delete this supplication?',
      name: 'adminSupplicationsDeleteMessage',
      desc: '',
      args: [],
    );
  }

  /// `Supplication deleted successfully.`
  String get adminSupplicationsDeleteSuccess {
    return Intl.message(
      'Supplication deleted successfully.',
      name: 'adminSupplicationsDeleteSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to delete the supplication.`
  String get adminSupplicationsDeleteError {
    return Intl.message(
      'Failed to delete the supplication.',
      name: 'adminSupplicationsDeleteError',
      desc: '',
      args: [],
    );
  }

  /// `Add Supplication`
  String get adminSupplicationAddTitle {
    return Intl.message(
      'Add Supplication',
      name: 'adminSupplicationAddTitle',
      desc: '',
      args: [],
    );
  }

  /// `Edit Supplication`
  String get adminSupplicationEditTitle {
    return Intl.message(
      'Edit Supplication',
      name: 'adminSupplicationEditTitle',
      desc: '',
      args: [],
    );
  }

  /// `Basic Information`
  String get adminSupplicationAddBasicTitle {
    return Intl.message(
      'Basic Information',
      name: 'adminSupplicationAddBasicTitle',
      desc: '',
      args: [],
    );
  }

  /// `Supplication Text`
  String get adminSupplicationAddTextTitle {
    return Intl.message(
      'Supplication Text',
      name: 'adminSupplicationAddTextTitle',
      desc: '',
      args: [],
    );
  }

  /// `Audio Settings`
  String get adminSupplicationAddAudioTitle {
    return Intl.message(
      'Audio Settings',
      name: 'adminSupplicationAddAudioTitle',
      desc: '',
      args: [],
    );
  }

  /// `Tags & Status`
  String get adminSupplicationAddTagsTitle {
    return Intl.message(
      'Tags & Status',
      name: 'adminSupplicationAddTagsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone`
  String get adminSupplicationZoneLabel {
    return Intl.message(
      'Zone',
      name: 'adminSupplicationZoneLabel',
      desc: '',
      args: [],
    );
  }

  /// `Select a zone`
  String get adminSupplicationZoneHint {
    return Intl.message(
      'Select a zone',
      name: 'adminSupplicationZoneHint',
      desc: '',
      args: [],
    );
  }

  /// `Please select a zone`
  String get adminSupplicationZoneRequired {
    return Intl.message(
      'Please select a zone',
      name: 'adminSupplicationZoneRequired',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Title`
  String get adminSupplicationTitleAr {
    return Intl.message(
      'Arabic Title',
      name: 'adminSupplicationTitleAr',
      desc: '',
      args: [],
    );
  }

  /// `Enter the supplication title in Arabic`
  String get adminSupplicationTitleArHint {
    return Intl.message(
      'Enter the supplication title in Arabic',
      name: 'adminSupplicationTitleArHint',
      desc: '',
      args: [],
    );
  }

  /// `Arabic title is required`
  String get adminSupplicationTitleArRequired {
    return Intl.message(
      'Arabic title is required',
      name: 'adminSupplicationTitleArRequired',
      desc: '',
      args: [],
    );
  }

  /// `English Title`
  String get adminSupplicationTitleEn {
    return Intl.message(
      'English Title',
      name: 'adminSupplicationTitleEn',
      desc: '',
      args: [],
    );
  }

  /// `Enter the supplication title in English`
  String get adminSupplicationTitleEnHint {
    return Intl.message(
      'Enter the supplication title in English',
      name: 'adminSupplicationTitleEnHint',
      desc: '',
      args: [],
    );
  }

  /// `English title is required`
  String get adminSupplicationTitleEnRequired {
    return Intl.message(
      'English title is required',
      name: 'adminSupplicationTitleEnRequired',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Text`
  String get adminSupplicationTextAr {
    return Intl.message(
      'Arabic Text',
      name: 'adminSupplicationTextAr',
      desc: '',
      args: [],
    );
  }

  /// `Enter the supplication text in Arabic`
  String get adminSupplicationTextArHint {
    return Intl.message(
      'Enter the supplication text in Arabic',
      name: 'adminSupplicationTextArHint',
      desc: '',
      args: [],
    );
  }

  /// `Arabic text is required`
  String get adminSupplicationTextArRequired {
    return Intl.message(
      'Arabic text is required',
      name: 'adminSupplicationTextArRequired',
      desc: '',
      args: [],
    );
  }

  /// `English Text`
  String get adminSupplicationTextEn {
    return Intl.message(
      'English Text',
      name: 'adminSupplicationTextEn',
      desc: '',
      args: [],
    );
  }

  /// `Enter the supplication text in English`
  String get adminSupplicationTextEnHint {
    return Intl.message(
      'Enter the supplication text in English',
      name: 'adminSupplicationTextEnHint',
      desc: '',
      args: [],
    );
  }

  /// `English text is required`
  String get adminSupplicationTextEnRequired {
    return Intl.message(
      'English text is required',
      name: 'adminSupplicationTextEnRequired',
      desc: '',
      args: [],
    );
  }

  /// `TTS`
  String get adminSupplicationAudioTts {
    return Intl.message(
      'TTS',
      name: 'adminSupplicationAudioTts',
      desc: '',
      args: [],
    );
  }

  /// `Audio File`
  String get adminSupplicationAudioFile {
    return Intl.message(
      'Audio File',
      name: 'adminSupplicationAudioFile',
      desc: '',
      args: [],
    );
  }

  /// `The app will read the supplication using text-to-speech`
  String get adminSupplicationAudioTtsDesc {
    return Intl.message(
      'The app will read the supplication using text-to-speech',
      name: 'adminSupplicationAudioTtsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Upload a saved audio file for this supplication`
  String get adminSupplicationAudioFileDesc {
    return Intl.message(
      'Upload a saved audio file for this supplication',
      name: 'adminSupplicationAudioFileDesc',
      desc: '',
      args: [],
    );
  }

  /// `No audio file selected`
  String get adminSupplicationNoAudioSelected {
    return Intl.message(
      'No audio file selected',
      name: 'adminSupplicationNoAudioSelected',
      desc: '',
      args: [],
    );
  }

  /// `Pick Audio File`
  String get adminSupplicationPickAudio {
    return Intl.message(
      'Pick Audio File',
      name: 'adminSupplicationPickAudio',
      desc: '',
      args: [],
    );
  }

  /// `Please select an audio file`
  String get adminSupplicationAudioFileRequired {
    return Intl.message(
      'Please select an audio file',
      name: 'adminSupplicationAudioFileRequired',
      desc: '',
      args: [],
    );
  }

  /// `Failed to pick the audio file`
  String get adminSupplicationFilePickError {
    return Intl.message(
      'Failed to pick the audio file',
      name: 'adminSupplicationFilePickError',
      desc: '',
      args: [],
    );
  }

  /// `Current audio file is available`
  String get adminSupplicationCurrentAudioAvailable {
    return Intl.message(
      'Current audio file is available',
      name: 'adminSupplicationCurrentAudioAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Tags`
  String get adminSupplicationTagsAr {
    return Intl.message(
      'Arabic Tags',
      name: 'adminSupplicationTagsAr',
      desc: '',
      args: [],
    );
  }

  /// `Enter Arabic tags separated by commas`
  String get adminSupplicationTagsArHint {
    return Intl.message(
      'Enter Arabic tags separated by commas',
      name: 'adminSupplicationTagsArHint',
      desc: '',
      args: [],
    );
  }

  /// `English Tags`
  String get adminSupplicationTagsEn {
    return Intl.message(
      'English Tags',
      name: 'adminSupplicationTagsEn',
      desc: '',
      args: [],
    );
  }

  /// `Enter English tags separated by commas`
  String get adminSupplicationTagsEnHint {
    return Intl.message(
      'Enter English tags separated by commas',
      name: 'adminSupplicationTagsEnHint',
      desc: '',
      args: [],
    );
  }

  /// `Supplication Status`
  String get adminSupplicationStatusTitle {
    return Intl.message(
      'Supplication Status',
      name: 'adminSupplicationStatusTitle',
      desc: '',
      args: [],
    );
  }

  /// `This supplication is active and can be used in the application.`
  String get adminSupplicationStatusActiveText {
    return Intl.message(
      'This supplication is active and can be used in the application.',
      name: 'adminSupplicationStatusActiveText',
      desc: '',
      args: [],
    );
  }

  /// `This supplication is inactive and will not be used until enabled.`
  String get adminSupplicationStatusInactiveText {
    return Intl.message(
      'This supplication is inactive and will not be used until enabled.',
      name: 'adminSupplicationStatusInactiveText',
      desc: '',
      args: [],
    );
  }

  /// `Save Supplication`
  String get adminSupplicationSave {
    return Intl.message(
      'Save Supplication',
      name: 'adminSupplicationSave',
      desc: '',
      args: [],
    );
  }

  /// `Save Changes`
  String get adminSupplicationEditSave {
    return Intl.message(
      'Save Changes',
      name: 'adminSupplicationEditSave',
      desc: '',
      args: [],
    );
  }

  /// `Saving...`
  String get adminSupplicationSaving {
    return Intl.message(
      'Saving...',
      name: 'adminSupplicationSaving',
      desc: '',
      args: [],
    );
  }

  /// `Supplication added successfully.`
  String get adminSupplicationAddSuccess {
    return Intl.message(
      'Supplication added successfully.',
      name: 'adminSupplicationAddSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to add the supplication. Please try again.`
  String get adminSupplicationAddError {
    return Intl.message(
      'Failed to add the supplication. Please try again.',
      name: 'adminSupplicationAddError',
      desc: '',
      args: [],
    );
  }

  /// `Supplication updated successfully.`
  String get adminSupplicationEditSuccess {
    return Intl.message(
      'Supplication updated successfully.',
      name: 'adminSupplicationEditSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to update the supplication. Please try again.`
  String get adminSupplicationEditError {
    return Intl.message(
      'Failed to update the supplication. Please try again.',
      name: 'adminSupplicationEditError',
      desc: '',
      args: [],
    );
  }

  /// `Supplication not found.`
  String get adminSupplicationEditNotFound {
    return Intl.message(
      'Supplication not found.',
      name: 'adminSupplicationEditNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load supplication data.`
  String get adminSupplicationEditLoadError {
    return Intl.message(
      'Failed to load supplication data.',
      name: 'adminSupplicationEditLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Supplication Details`
  String get adminSupplicationDetailsTitle {
    return Intl.message(
      'Supplication Details',
      name: 'adminSupplicationDetailsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Supplication not found.`
  String get adminSupplicationDetailsNotFound {
    return Intl.message(
      'Supplication not found.',
      name: 'adminSupplicationDetailsNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load supplication details.`
  String get adminSupplicationDetailsLoadError {
    return Intl.message(
      'Failed to load supplication details.',
      name: 'adminSupplicationDetailsLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Overview`
  String get adminSupplicationDetailsOverviewTitle {
    return Intl.message(
      'Overview',
      name: 'adminSupplicationDetailsOverviewTitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone Information`
  String get adminSupplicationDetailsZoneInfoTitle {
    return Intl.message(
      'Zone Information',
      name: 'adminSupplicationDetailsZoneInfoTitle',
      desc: '',
      args: [],
    );
  }

  /// `Supplication Text`
  String get adminSupplicationDetailsTextTitle {
    return Intl.message(
      'Supplication Text',
      name: 'adminSupplicationDetailsTextTitle',
      desc: '',
      args: [],
    );
  }

  /// `Audio`
  String get adminSupplicationDetailsAudioSectionTitle {
    return Intl.message(
      'Audio',
      name: 'adminSupplicationDetailsAudioSectionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Zone`
  String get adminSupplicationDetailsZoneNameLabel {
    return Intl.message(
      'Zone',
      name: 'adminSupplicationDetailsZoneNameLabel',
      desc: '',
      args: [],
    );
  }

  /// `Audio Mode`
  String get adminSupplicationDetailsAudioModeLabel {
    return Intl.message(
      'Audio Mode',
      name: 'adminSupplicationDetailsAudioModeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get adminSupplicationDetailsStatusLabel {
    return Intl.message(
      'Status',
      name: 'adminSupplicationDetailsStatusLabel',
      desc: '',
      args: [],
    );
  }

  /// `Arabic Text`
  String get adminSupplicationDetailsArabicTextTitle {
    return Intl.message(
      'Arabic Text',
      name: 'adminSupplicationDetailsArabicTextTitle',
      desc: '',
      args: [],
    );
  }

  /// `English Text`
  String get adminSupplicationDetailsEnglishTextTitle {
    return Intl.message(
      'English Text',
      name: 'adminSupplicationDetailsEnglishTextTitle',
      desc: '',
      args: [],
    );
  }

  /// `Text-to-Speech Playback`
  String get adminSupplicationDetailsTtsCardTitle {
    return Intl.message(
      'Text-to-Speech Playback',
      name: 'adminSupplicationDetailsTtsCardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Tap the button to convert the supplication text into speech.`
  String get adminSupplicationDetailsTtsCardSubtitle {
    return Intl.message(
      'Tap the button to convert the supplication text into speech.',
      name: 'adminSupplicationDetailsTtsCardSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Audio File Playback`
  String get adminSupplicationDetailsFileCardTitle {
    return Intl.message(
      'Audio File Playback',
      name: 'adminSupplicationDetailsFileCardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Tap the button to play the uploaded audio file.`
  String get adminSupplicationDetailsFileCardSubtitle {
    return Intl.message(
      'Tap the button to play the uploaded audio file.',
      name: 'adminSupplicationDetailsFileCardSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Play TTS`
  String get adminSupplicationDetailsPlayTtsButton {
    return Intl.message(
      'Play TTS',
      name: 'adminSupplicationDetailsPlayTtsButton',
      desc: '',
      args: [],
    );
  }

  /// `Play Audio File`
  String get adminSupplicationDetailsPlayFileButton {
    return Intl.message(
      'Play Audio File',
      name: 'adminSupplicationDetailsPlayFileButton',
      desc: '',
      args: [],
    );
  }

  /// `Stop`
  String get adminSupplicationDetailsStopButton {
    return Intl.message(
      'Stop',
      name: 'adminSupplicationDetailsStopButton',
      desc: '',
      args: [],
    );
  }

  /// `There is no text available to convert into speech.`
  String get adminSupplicationDetailsNoTextToSpeak {
    return Intl.message(
      'There is no text available to convert into speech.',
      name: 'adminSupplicationDetailsNoTextToSpeak',
      desc: '',
      args: [],
    );
  }

  /// `No audio file is available for this supplication.`
  String get adminSupplicationDetailsNoAudioFile {
    return Intl.message(
      'No audio file is available for this supplication.',
      name: 'adminSupplicationDetailsNoAudioFile',
      desc: '',
      args: [],
    );
  }

  /// `Failed to play text-to-speech.`
  String get adminSupplicationDetailsTtsError {
    return Intl.message(
      'Failed to play text-to-speech.',
      name: 'adminSupplicationDetailsTtsError',
      desc: '',
      args: [],
    );
  }

  /// `Failed to play the audio file.`
  String get adminSupplicationDetailsAudioPlayError {
    return Intl.message(
      'Failed to play the audio file.',
      name: 'adminSupplicationDetailsAudioPlayError',
      desc: '',
      args: [],
    );
  }

  /// `Smart supplications and guidance based on your location inside the holy sites.`
  String get splashSubtitle {
    return Intl.message(
      'Smart supplications and guidance based on your location inside the holy sites.',
      name: 'splashSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get splashLoading {
    return Intl.message(
      'Loading...',
      name: 'splashLoading',
      desc: '',
      args: [],
    );
  }

  /// `Duas`
  String get navDuas {
    return Intl.message('Duas', name: 'navDuas', desc: '', args: []);
  }

  /// `Cancel`
  String get commonCancel {
    return Intl.message('Cancel', name: 'commonCancel', desc: '', args: []);
  }

  /// `Done`
  String get commonDone {
    return Intl.message('Done', name: 'commonDone', desc: '', args: []);
  }

  /// `Enable Location`
  String get gpsEnableTitle {
    return Intl.message(
      'Enable Location',
      name: 'gpsEnableTitle',
      desc: '',
      args: [],
    );
  }

  /// `Location is required to detect the pilgrim’s current zone and automatically show the most suitable Dua inside Al-Masjid Al-Haram.`
  String get gpsEnableMessage {
    return Intl.message(
      'Location is required to detect the pilgrim’s current zone and automatically show the most suitable Dua inside Al-Masjid Al-Haram.',
      name: 'gpsEnableMessage',
      desc: '',
      args: [],
    );
  }

  /// `Enable Location`
  String get gpsEnableAction {
    return Intl.message(
      'Enable Location',
      name: 'gpsEnableAction',
      desc: '',
      args: [],
    );
  }

  /// `Allow Location Access`
  String get gpsPermissionTitle {
    return Intl.message(
      'Allow Location Access',
      name: 'gpsPermissionTitle',
      desc: '',
      args: [],
    );
  }

  /// `We need location access so the app can detect your current zone and show the most appropriate Dua for your position.`
  String get gpsPermissionMessage {
    return Intl.message(
      'We need location access so the app can detect your current zone and show the most appropriate Dua for your position.',
      name: 'gpsPermissionMessage',
      desc: '',
      args: [],
    );
  }

  /// `Allow Access`
  String get gpsPermissionAction {
    return Intl.message(
      'Allow Access',
      name: 'gpsPermissionAction',
      desc: '',
      args: [],
    );
  }

  /// `Permission Not Granted`
  String get gpsPermissionDeniedTitle {
    return Intl.message(
      'Permission Not Granted',
      name: 'gpsPermissionDeniedTitle',
      desc: '',
      args: [],
    );
  }

  /// `Without location permission, the app will not be able to detect your current zone or trigger the appropriate Dua automatically.`
  String get gpsPermissionDeniedMessage {
    return Intl.message(
      'Without location permission, the app will not be able to detect your current zone or trigger the appropriate Dua automatically.',
      name: 'gpsPermissionDeniedMessage',
      desc: '',
      args: [],
    );
  }

  /// `Permission Permanently Denied`
  String get gpsPermissionDeniedForeverTitle {
    return Intl.message(
      'Permission Permanently Denied',
      name: 'gpsPermissionDeniedForeverTitle',
      desc: '',
      args: [],
    );
  }

  /// `Location permission has been permanently denied. Please open the app settings and grant permission manually to continue using location-based features.`
  String get gpsPermissionDeniedForeverMessage {
    return Intl.message(
      'Location permission has been permanently denied. Please open the app settings and grant permission manually to continue using location-based features.',
      name: 'gpsPermissionDeniedForeverMessage',
      desc: '',
      args: [],
    );
  }

  /// `Open App Settings`
  String get gpsOpenAppSettings {
    return Intl.message(
      'Open App Settings',
      name: 'gpsOpenAppSettings',
      desc: '',
      args: [],
    );
  }

  /// `Location Enabled`
  String get gpsReadyTitle {
    return Intl.message(
      'Location Enabled',
      name: 'gpsReadyTitle',
      desc: '',
      args: [],
    );
  }

  /// `The application can now use your location to detect the current zone and trigger the appropriate Dua automatically.`
  String get gpsReadyMessage {
    return Intl.message(
      'The application can now use your location to detect the current zone and trigger the appropriate Dua automatically.',
      name: 'gpsReadyMessage',
      desc: '',
      args: [],
    );
  }

  /// `Disable Location Feature`
  String get gpsDisableTitle {
    return Intl.message(
      'Disable Location Feature',
      name: 'gpsDisableTitle',
      desc: '',
      args: [],
    );
  }

  /// `If you disable the location feature, current zone detection will stop, automatic Dua triggering will no longer work, and some smart map features may be affected.`
  String get gpsDisableMessage {
    return Intl.message(
      'If you disable the location feature, current zone detection will stop, automatic Dua triggering will no longer work, and some smart map features may be affected.',
      name: 'gpsDisableMessage',
      desc: '',
      args: [],
    );
  }

  /// `Disable Feature`
  String get gpsDisableAction {
    return Intl.message(
      'Disable Feature',
      name: 'gpsDisableAction',
      desc: '',
      args: [],
    );
  }

  /// `Duas Screen Is Coming Soon`
  String get duasComingSoonTitle {
    return Intl.message(
      'Duas Screen Is Coming Soon',
      name: 'duasComingSoonTitle',
      desc: '',
      args: [],
    );
  }

  /// `In the next phase, text search, voice request, and bilingual Dua playback will be added here.`
  String get duasComingSoonMessage {
    return Intl.message(
      'In the next phase, text search, voice request, and bilingual Dua playback will be added here.',
      name: 'duasComingSoonMessage',
      desc: '',
      args: [],
    );
  }

  /// `Preparing your live location and Dua`
  String get homeStatusLoading {
    return Intl.message(
      'Preparing your live location and Dua',
      name: 'homeStatusLoading',
      desc: '',
      args: [],
    );
  }

  /// `Automatic location updates are disabled from settings`
  String get homeStatusAutoLocationDisabled {
    return Intl.message(
      'Automatic location updates are disabled from settings',
      name: 'homeStatusAutoLocationDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Location is currently unavailable. Please check the service and permissions`
  String get homeStatusLocationUnavailable {
    return Intl.message(
      'Location is currently unavailable. Please check the service and permissions',
      name: 'homeStatusLocationUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `No active holy zone has been detected at the moment`
  String get homeStatusNoZone {
    return Intl.message(
      'No active holy zone has been detected at the moment',
      name: 'homeStatusNoZone',
      desc: '',
      args: [],
    );
  }

  /// `No active zone detected`
  String get homeNoZoneDetected {
    return Intl.message(
      'No active zone detected',
      name: 'homeNoZoneDetected',
      desc: '',
      args: [],
    );
  }

  /// `There is no available Dua for the current zone, or no zone has been detected yet.`
  String get homeNoDuaMessage {
    return Intl.message(
      'There is no available Dua for the current zone, or no zone has been detected yet.',
      name: 'homeNoDuaMessage',
      desc: '',
      args: [],
    );
  }

  /// `No Dua Available`
  String get homeNoDuaButton {
    return Intl.message(
      'No Dua Available',
      name: 'homeNoDuaButton',
      desc: '',
      args: [],
    );
  }

  /// `Replay Dua`
  String get homeReplayDua {
    return Intl.message(
      'Replay Dua',
      name: 'homeReplayDua',
      desc: '',
      args: [],
    );
  }

  /// `Read Dua`
  String get homeReadDua {
    return Intl.message('Read Dua', name: 'homeReadDua', desc: '', args: []);
  }

  /// `Dua is now playing`
  String get homePlayingNow {
    return Intl.message(
      'Dua is now playing',
      name: 'homePlayingNow',
      desc: '',
      args: [],
    );
  }

  /// `Stop Playback`
  String get homeStopPlayback {
    return Intl.message(
      'Stop Playback',
      name: 'homeStopPlayback',
      desc: '',
      args: [],
    );
  }

  /// `User ID`
  String get homeSignedInAs {
    return Intl.message('User ID', name: 'homeSignedInAs', desc: '', args: []);
  }

  /// `Guest User`
  String get homeGuestUser {
    return Intl.message(
      'Guest User',
      name: 'homeGuestUser',
      desc: '',
      args: [],
    );
  }

  /// `Voice Notifications`
  String get homeVoiceStatusLabel {
    return Intl.message(
      'Voice Notifications',
      name: 'homeVoiceStatusLabel',
      desc: '',
      args: [],
    );
  }

  /// `Enabled`
  String get homeVoiceStatusEnabled {
    return Intl.message(
      'Enabled',
      name: 'homeVoiceStatusEnabled',
      desc: '',
      args: [],
    );
  }

  /// `Disabled`
  String get homeVoiceStatusDisabled {
    return Intl.message(
      'Disabled',
      name: 'homeVoiceStatusDisabled',
      desc: '',
      args: [],
    );
  }

  /// `No active zone detected right now`
  String get mapNoZoneDetected {
    return Intl.message(
      'No active zone detected right now',
      name: 'mapNoZoneDetected',
      desc: '',
      args: [],
    );
  }

  /// `Current Zone Detected`
  String get mapDetectedZoneTitle {
    return Intl.message(
      'Current Zone Detected',
      name: 'mapDetectedZoneTitle',
      desc: '',
      args: [],
    );
  }

  /// `The map now shows the pilgrim’s real position and highlights the currently detected zone using live coordinates.`
  String get mapDetectedZoneDesc {
    return Intl.message(
      'The map now shows the pilgrim’s real position and highlights the currently detected zone using live coordinates.',
      name: 'mapDetectedZoneDesc',
      desc: '',
      args: [],
    );
  }

  /// `No Zone Detected Yet`
  String get mapNoZoneTitle {
    return Intl.message(
      'No Zone Detected Yet',
      name: 'mapNoZoneTitle',
      desc: '',
      args: [],
    );
  }

  /// `The map is tracking the pilgrim’s current location, and once a defined zone is entered it will be highlighted automatically.`
  String get mapNoZoneDesc {
    return Intl.message(
      'The map is tracking the pilgrim’s current location, and once a defined zone is entered it will be highlighted automatically.',
      name: 'mapNoZoneDesc',
      desc: '',
      args: [],
    );
  }

  /// `Duas`
  String get duasTitle {
    return Intl.message('Duas', name: 'duasTitle', desc: '', args: []);
  }

  /// `Search manually for the appropriate Dua, or use voice command for quick access to the requested supplication.`
  String get duasSubtitle {
    return Intl.message(
      'Search manually for the appropriate Dua, or use voice command for quick access to the requested supplication.',
      name: 'duasSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Search for a dua or zone`
  String get duasSearchHint {
    return Intl.message(
      'Search for a dua or zone',
      name: 'duasSearchHint',
      desc: '',
      args: [],
    );
  }

  /// `All Zones`
  String get duasAllZones {
    return Intl.message('All Zones', name: 'duasAllZones', desc: '', args: []);
  }

  /// `Play Dua`
  String get duasPlayButton {
    return Intl.message('Play Dua', name: 'duasPlayButton', desc: '', args: []);
  }

  /// `Unknown Zone`
  String get duasUnknownZone {
    return Intl.message(
      'Unknown Zone',
      name: 'duasUnknownZone',
      desc: '',
      args: [],
    );
  }

  /// `No Matching Results`
  String get duasEmptyTitle {
    return Intl.message(
      'No Matching Results',
      name: 'duasEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `No supplications were found for the current search phrase or selected filter.`
  String get duasEmptyMessage {
    return Intl.message(
      'No supplications were found for the current search phrase or selected filter.',
      name: 'duasEmptyMessage',
      desc: '',
      args: [],
    );
  }

  /// `Microphone Permission Required`
  String get duasMicPermissionTitle {
    return Intl.message(
      'Microphone Permission Required',
      name: 'duasMicPermissionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Please allow microphone access so you can request a Dua using voice commands.`
  String get duasMicPermissionMessage {
    return Intl.message(
      'Please allow microphone access so you can request a Dua using voice commands.',
      name: 'duasMicPermissionMessage',
      desc: '',
      args: [],
    );
  }

  /// `Listening Now`
  String get duasVoiceDialogTitle {
    return Intl.message(
      'Listening Now',
      name: 'duasVoiceDialogTitle',
      desc: '',
      args: [],
    );
  }

  /// `Say the dua name or the zone name, such as Safa dua or Marwah dua`
  String get duasVoiceDialogHint {
    return Intl.message(
      'Say the dua name or the zone name, such as Safa dua or Marwah dua',
      name: 'duasVoiceDialogHint',
      desc: '',
      args: [],
    );
  }

  /// `Listening`
  String get duasListening {
    return Intl.message('Listening', name: 'duasListening', desc: '', args: []);
  }

  /// `Try Again`
  String get duasTapToRetry {
    return Intl.message(
      'Try Again',
      name: 'duasTapToRetry',
      desc: '',
      args: [],
    );
  }

  /// `Enable or disable automatic Dua playback based on the current zone.`
  String get settingsSoundSubtitle {
    return Intl.message(
      'Enable or disable automatic Dua playback based on the current zone.',
      name: 'settingsSoundSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Control automatic location updates to detect the correct zone and display the right Dua.`
  String get settingsAutoLocationSubtitle {
    return Intl.message(
      'Control automatic location updates to detect the correct zone and display the right Dua.',
      name: 'settingsAutoLocationSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Reset Password`
  String get settingsResetPassword {
    return Intl.message(
      'Reset Password',
      name: 'settingsResetPassword',
      desc: '',
      args: [],
    );
  }

  /// `Reset Password`
  String get settingsResetPasswordTitle {
    return Intl.message(
      'Reset Password',
      name: 'settingsResetPasswordTitle',
      desc: '',
      args: [],
    );
  }

  /// `A password reset link will be sent to the following email:\n{email}`
  String settingsResetPasswordMessage(Object email) {
    return Intl.message(
      'A password reset link will be sent to the following email:\n$email',
      name: 'settingsResetPasswordMessage',
      desc: '',
      args: [email],
    );
  }

  /// `Send Link`
  String get settingsSendResetLink {
    return Intl.message(
      'Send Link',
      name: 'settingsSendResetLink',
      desc: '',
      args: [],
    );
  }

  /// `A password reset link has been sent to your email.`
  String get settingsResetPasswordSuccess {
    return Intl.message(
      'A password reset link has been sent to your email.',
      name: 'settingsResetPasswordSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send the password reset link.`
  String get settingsResetPasswordFailed {
    return Intl.message(
      'Failed to send the password reset link.',
      name: 'settingsResetPasswordFailed',
      desc: '',
      args: [],
    );
  }

  /// `No email available`
  String get settingsNoEmail {
    return Intl.message(
      'No email available',
      name: 'settingsNoEmail',
      desc: '',
      args: [],
    );
  }

  /// `There is no email linked to this account.`
  String get settingsNoEmailAvailable {
    return Intl.message(
      'There is no email linked to this account.',
      name: 'settingsNoEmailAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get settingsLogout {
    return Intl.message('Logout', name: 'settingsLogout', desc: '', args: []);
  }

  /// `Sign out from the current account and return to the login screen.`
  String get settingsLogoutSubtitle {
    return Intl.message(
      'Sign out from the current account and return to the login screen.',
      name: 'settingsLogoutSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Logout`
  String get settingsLogoutTitle {
    return Intl.message(
      'Confirm Logout',
      name: 'settingsLogoutTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to log out from this account now?`
  String get settingsLogoutMessage {
    return Intl.message(
      'Are you sure you want to log out from this account now?',
      name: 'settingsLogoutMessage',
      desc: '',
      args: [],
    );
  }

  /// `Logout`
  String get settingsLogoutButton {
    return Intl.message(
      'Logout',
      name: 'settingsLogoutButton',
      desc: '',
      args: [],
    );
  }

  /// `Unable to log out right now.`
  String get settingsLogoutFailed {
    return Intl.message(
      'Unable to log out right now.',
      name: 'settingsLogoutFailed',
      desc: '',
      args: [],
    );
  }

  /// `Switch between dark mode and light mode, and save your preference for the whole app.`
  String get settingsNightModeSubtitle {
    return Intl.message(
      'Switch between dark mode and light mode, and save your preference for the whole app.',
      name: 'settingsNightModeSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Forgot password?`
  String get authForgotPassword {
    return Intl.message(
      'Forgot password?',
      name: 'authForgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Reset Password`
  String get authForgotPasswordTitle {
    return Intl.message(
      'Reset Password',
      name: 'authForgotPasswordTitle',
      desc: '',
      args: [],
    );
  }

  /// `Enter your email address, and a password reset link will be sent to help you reset your password.`
  String get authForgotPasswordMessage {
    return Intl.message(
      'Enter your email address, and a password reset link will be sent to help you reset your password.',
      name: 'authForgotPasswordMessage',
      desc: '',
      args: [],
    );
  }

  /// `Send Reset Link`
  String get authSendResetLink {
    return Intl.message(
      'Send Reset Link',
      name: 'authSendResetLink',
      desc: '',
      args: [],
    );
  }

  /// `Sending reset link...`
  String get authSendingResetLink {
    return Intl.message(
      'Sending reset link...',
      name: 'authSendingResetLink',
      desc: '',
      args: [],
    );
  }

  /// `Link Sent`
  String get authResetPasswordSuccessTitle {
    return Intl.message(
      'Link Sent',
      name: 'authResetPasswordSuccessTitle',
      desc: '',
      args: [],
    );
  }

  /// `A password reset link has been sent to:\n{email}\nPlease check your email to complete the reset process.`
  String authResetPasswordSuccessMessage(Object email) {
    return Intl.message(
      'A password reset link has been sent to:\n$email\nPlease check your email to complete the reset process.',
      name: 'authResetPasswordSuccessMessage',
      desc: '',
      args: [email],
    );
  }

  /// `Unable to send the password reset link.`
  String get authResetPasswordFailed {
    return Intl.message(
      'Unable to send the password reset link.',
      name: 'authResetPasswordFailed',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ar'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
