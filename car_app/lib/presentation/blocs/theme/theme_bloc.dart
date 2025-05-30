import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeBloc extends Cubit<bool> {
  final SharedPreferences prefs;
  static const String _themeKey = 'isDarkMode';

  ThemeBloc(this.prefs) : super(prefs.getBool(_themeKey) ?? false);

  void toggleTheme() {
    final newValue = !state;
    prefs.setBool(_themeKey, newValue);
    emit(newValue);
  }
} 
