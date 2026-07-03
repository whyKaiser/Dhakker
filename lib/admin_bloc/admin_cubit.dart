import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Screens/Admin/Dashboard/admin_dashboard_screen.dart';
import '../Screens/Admin/Manage Supplications/admin_supplications_list_screen.dart';
import '../Screens/Admin/Manage Zones/zone_list_screen.dart';
import '../Screens/Admin/Settings/admin_settings_screen.dart';
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