import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Screens/Admin/Dashboard/AdminDashboard_Screen.dart';
import '../Screens/Admin/Manage Supplications/AdminSupplicationsList_Screen.dart';
import '../Screens/Admin/Manage Zones/ZoneList_Screen.dart';
import '../Screens/Admin/Settings/AdminSettings_Screen.dart';
import 'admin_states.dart';



class AdminCubit extends Cubit<AdminState> {
  AdminCubit() : super(AdminInitState());

  static AdminCubit get(BuildContext context) => BlocProvider.of(context);

  int currentScreen = 0;

  final List<Widget> screens = const [
    AdminDashboardScreen(),
    AdminZonesListScreen(),
    AdminSupplicationsListScreen(),
    AdminSettingsScreen(),
  ];

  List<String> screenAr=[
    'لوحة المشرف',
    'المناطق',
    'الأدعية',
    'الإعدادات'
  ];

  List<String> screenEn=[
    'Dashboard',
    'Zones',
    'Supplications',
    'Settings'
  ];
  void changeScreen(int index) {
    currentScreen = index;
    emit(AdminChangeScreenState());
  }

}