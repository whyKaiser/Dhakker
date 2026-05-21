import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dhakker/bloc/states.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'package:dhakker/Screens/Piligram/Home/Home_Screen.dart';
import 'package:dhakker/Screens/Piligram/Map/Map_Screen.dart';
import '../Screens/Piligram/Duas/Duas_Screen.dart';
import '../Screens/Piligram/Settings/Settings_Screen.dart';
import '../Screens/Piligram/Tasbih/Tasbih_Screen.dart';

class AppCubit extends Cubit<AppStates> {
  AppCubit() : super(AppInitialState());

  static AppCubit get(BuildContext context) => BlocProvider.of(context);

  int currentScreen = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const MapScreen(),
    const DuasScreen(),
    const TasbihScreen(),
    const SettingsScreen(),
  ];

  void changeScreen(int index) {
    currentScreen = index;
    emit(AppChangeBottomNavState());
  }

  // ==========================================
  // --- منطق عد الأشواط الذكي والقبلة اللحظية ---
  // ==========================================
  int roundCount = 0;
  final double startLat = 21.422487;
  final double startLng = 39.826206;
  bool hasExitedThreshold = true;

  double userHeading = 0.0;
  StreamSubscription? _compassSubscription;

  void initCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      userHeading = event.heading ?? 0.0;
      emit(AppQiblaDirectionUpdateState());
    });
  }

  void updateLocationAndCheckRounds(Position position) {
    double distance = Geolocator.distanceBetween(
      position.latitude, position.longitude, startLat, startLng,
    );

    if (distance < 8 && hasExitedThreshold) {
      incrementRound();
      hasExitedThreshold = false;
    }
    if (distance > 20) {
      hasExitedThreshold = true;
    }
  }

  void incrementRound() {
    if (roundCount < 7) {
      roundCount++;
      emit(AppRoundIncrementState());
    }
  }

  void resetRounds() {
    roundCount = 0;
    hasExitedThreshold = true;
    emit(AppRoundResetState());
  }

  // ==========================================
  // --- منطق مؤشر الازدحام اللحظي للمناطق ---
  // ==========================================
  Map<String, int> zoneUserCount = {};

  void initCrowdZoneListener() {
    FirebaseFirestore.instance.collection('users').snapshots().listen((event) {
      final Map<String, int> tempCount = {};
      for (var doc in event.docs) {
        final data = doc.data();
        if (data.containsKey('currentZone')) {
          final zoneId = data['currentZone'].toString();
          tempCount[zoneId] = (tempCount[zoneId] ?? 0) + 1;
        }
      }
      zoneUserCount = tempCount;
      emit(AppMapCrowdDensityUpdateState());
    });
  }

  Color getZoneColor(String zoneId, Color defaultGold) {
    final count = zoneUserCount[zoneId] ?? 0;
    if (count == 0) return defaultGold.withOpacity(0.20);
    if (count > 50) return Colors.redAccent.withOpacity(0.40);
    if (count > 20) return Colors.orangeAccent.withOpacity(0.30);
    return Colors.greenAccent.withOpacity(0.25);
  }

  // ==========================================
  // --- منطق الـ SOS ---
  // ==========================================
  void sendWhatsAppSOS() async {
    const String phoneNumber = "+966500000000";
    const String message = "نداء استغاثة SOS! موقعي الحالي: https://maps.google.com/?q=21.422,39.826";
    final Uri url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      emit(AppSOSSuccessState());
    } else {
      emit(AppSOSErrorState());
    }
  }

  // ======================================================
  // --- منطق لوحة الإحصائيات (Admin Logic) ---
  // ======================================================
  Map<String, dynamic> adminStats = {
    'totalUsers': 0,
    'sosActive': 0,
    'haramCrowd': 0
  };

  List<Map<String, dynamic>> sosRequests = [];

  void getAdminStats() {
    emit(AppAdminLoadingStatsState());
    FirebaseFirestore.instance.collection('users').snapshots().listen((event) {
      adminStats['totalUsers'] = event.docs.length;
      try {
        adminStats['haramCrowd'] = event.docs.where((doc) {
          final data = doc.data();
          return data.containsKey('currentZone') && data['currentZone'] == 'Al-Haram';
        }).length;
      } catch (e) {
        debugPrint("Error counting crowd: $e");
      }
      emit(AppAdminGetStatsSuccessState());
    }).onError((error) {
      emit(AppAdminGetStatsErrorState(error.toString()));
    });
  }

  void getSOSRequests() {
    FirebaseFirestore.instance
        .collection('sos_requests')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((event) {
      sosRequests = event.docs.map((doc) => doc.data()).toList();
      adminStats['sosActive'] = sosRequests.length;
      emit(AppAdminGetSOSRequestsSuccessState());
    }).onError((error) {
      emit(AppAdminGetSOSRequestsErrorState(error.toString()));
    });
  }

  @override
  Future<void> close() {
    _compassSubscription?.cancel();
    return super.close();
  }
}