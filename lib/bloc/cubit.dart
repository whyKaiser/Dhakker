import 'package:dhakker/Screens/Piligram/Home/Home_Screen.dart';
import 'package:dhakker/Screens/Piligram/Map/Map_Screen.dart';

import 'package:dhakker/bloc/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Screens/Piligram/Duas/Duas_Screen.dart';
import '../Screens/Piligram/Settings/Settings_Screen.dart';
import '../Screens/Piligram/Tasbih/Tasbih_Screen.dart';



class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppInitState());

  static AppCubit get(BuildContext context) => BlocProvider.of(context);

  int currentScreen = 0;

  final List<Widget> screens =  [
    HomeScreen(),
    MapScreen(),
    DuasScreen(),
    TasbihScreen(),
    SettingsScreen(),
  ];

  void changeScreen(int index) {
    currentScreen = index;
    emit(AppChangeScreenState());
  }
}
