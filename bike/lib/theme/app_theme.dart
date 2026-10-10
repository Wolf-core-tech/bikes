import 'package:flutter/material.dart';

class RideWolfColors {
  static const Color black = Color(0xFF050505);
  static const Color racingRed = Color.fromARGB(255, 188, 0, 16);
  static const Color darkRed = Color.fromARGB(255, 188, 0, 16);
  static const Color silver = Color(0xFF909090);
  static const Color white = Color(0xFFF5F5F5);
  static const Color charcoal = Color(0xFF202020);
}

class AppColors {
  static const backgroundLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF5F5F5);
  static const cardLight = Color(0xFFF5F5F5);
  static const backgroundDark = Color.fromARGB(255, 0, 0, 0);
  static const surfaceDark = Color.fromARGB(255, 0, 0, 0);
  static const cardDark = Color.fromARGB(255, 59, 63, 69);
  static const orange = Color.fromARGB(255, 188, 0, 16);
  static const orangeDim = Color.fromARGB(255, 188, 0, 16);
  static const orangeGlow = Color(0x33BC0010);
  static const blue = Color.fromARGB(255, 255, 255, 255);
  static const blueDim = Color.fromARGB(255, 244, 245, 245);
  static const blueGlow = Color(0x330066CC);
  static const danger = Color.fromARGB(255, 188, 0, 16);
  static const success = Color(0xFF30D158);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F5F5);
  static const card = Color(0xFFF5F5F5);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const grey = Color(0xFF333333);
  static const greyDark = Color(0xFFDDDDDD);

  static bool _useDarkMode = false;

  static void syncTheme(bool useDarkMode) {
    _useDarkMode = useDarkMode;
  }

  static Color get themedBackground =>
      _useDarkMode ? RideWolfColors.black : backgroundLight;
  static Color get themedSurface =>
      _useDarkMode ? RideWolfColors.charcoal : surfaceLight;
  static Color get themedCard =>
      _useDarkMode ? RideWolfColors.charcoal : cardLight;
  static Color get themedText => _useDarkMode ? RideWolfColors.white : black;
  static Color get themedGrey => _useDarkMode ? RideWolfColors.silver : grey;
  static Color get themedGreyBorder =>
      _useDarkMode ? RideWolfColors.silver : greyDark;
}

class AppTheme extends ChangeNotifier {
  AppTheme({bool isDarkMode = false}) : _isDarkMode = isDarkMode {
    _syncColors();
  }

  bool _isDarkMode;

  bool get isDarkMode => _isDarkMode;

  void _syncColors() {
    AppColors.syncTheme(_isDarkMode);
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _syncColors();
    notifyListeners();
  }

  void setTheme(bool value) {
    _isDarkMode = value;
    _syncColors();
    notifyListeners();
  }

  ThemeData get themeData => _isDarkMode ? _darkTheme : _lightTheme;

  static ThemeData get light => _lightTheme;
  static ThemeData get dark => _darkTheme;

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    primaryColor: const Color.fromARGB(255, 188, 0, 16),
    colorScheme: const ColorScheme.light(
      primary: Color.fromARGB(255, 188, 0, 16),
      surface: AppColors.surfaceLight,
      error: Color.fromARGB(255, 188, 0, 16),
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundLight,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.black,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.orange),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.black,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: AppColors.black,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: AppColors.black,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(color: AppColors.black),
      bodyLarge: TextStyle(color: AppColors.black),
      bodyMedium: TextStyle(color: AppColors.grey),
      labelLarge: TextStyle(
        color: AppColors.orange,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    ),
    dividerColor: AppColors.greyDark,
    iconTheme: const IconThemeData(color: AppColors.orange),
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RideWolfColors.black,
    primaryColor: RideWolfColors.racingRed,
    colorScheme: const ColorScheme.dark(
      primary: RideWolfColors.racingRed,
      secondary: RideWolfColors.darkRed,
      surface: RideWolfColors.charcoal,
      error: AppColors.orange,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: RideWolfColors.black,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: RideWolfColors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: RideWolfColors.racingRed),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: RideWolfColors.white,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: RideWolfColors.white,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: RideWolfColors.white,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(color: RideWolfColors.white),
      bodyLarge: TextStyle(color: RideWolfColors.white),
      bodyMedium: TextStyle(color: RideWolfColors.silver),
      labelLarge: TextStyle(
        color: RideWolfColors.racingRed,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    ),
    dividerColor: RideWolfColors.silver,
    iconTheme: IconThemeData(color: RideWolfColors.racingRed),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(RideWolfColors.racingRed),
      trackColor: WidgetStatePropertyAll(RideWolfColors.darkRed),
    ),
  );
}
