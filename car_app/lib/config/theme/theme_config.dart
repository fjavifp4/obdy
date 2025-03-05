import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedColor = Colors.blue;
  
  // Paleta de colores personalizada para modo claro
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
    background: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
    surfaceVariant: Colors.grey.shade100,
    onSurfaceVariant: Colors.black87,
    primaryContainer: Colors.blue.shade50,
    onPrimaryContainer: Colors.blue.shade900,
    secondaryContainer: Colors.grey.shade200,
    onSecondaryContainer: Colors.black87,
    error: Colors.red.shade700,
  );

  // Paleta de colores personalizada para modo oscuro
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
    background: Colors.blueGrey.shade900,
    surface: Colors.blueGrey.shade800,
    onSurface: Colors.white,
    surfaceVariant: Colors.blueGrey.shade700,
    onSurfaceVariant: Colors.white,
    primaryContainer: Colors.blue.shade900,
    onPrimaryContainer: Colors.white,
    secondaryContainer: Colors.blueGrey.shade700,
    onSecondaryContainer: Colors.white,
    error: Colors.red.shade400,
  );

  // Color de fondo para páginas en modo oscuro
  static final LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.blueGrey.shade900,
      Colors.blueGrey.shade800,
    ],
  );

  static ThemeData getTheme(bool isDarkMode) {
    final colorScheme = isDarkMode ? darkColorScheme : lightColorScheme;
    
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      
      // Colores básicos
      scaffoldBackgroundColor: colorScheme.background,
      canvasColor: colorScheme.background,
      dividerColor: isDarkMode 
          ? Colors.white.withOpacity(0.2) 
          : Colors.black.withOpacity(0.1),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        iconTheme: IconThemeData(
          color: colorScheme.onPrimary,
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: isDarkMode ? colorScheme.surfaceVariant : colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: isDarkMode ? Colors.black87 : Colors.black38,
      ),
      
      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDarkMode ? colorScheme.surface : colorScheme.primary,
        selectedItemColor: isDarkMode ? colorScheme.primary : colorScheme.onPrimary,
        unselectedItemColor: isDarkMode 
            ? colorScheme.onSurface.withOpacity(0.7) 
            : colorScheme.onPrimary.withOpacity(0.7),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      
      // Floating Action Button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        highlightElevation: 8,
      ),
      
      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      
      // Input Decoration theme para TextFields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode 
            ? Colors.blueGrey.shade700 
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
        ),
      ),
      
      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: colorScheme.onBackground,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: colorScheme.onBackground,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: colorScheme.onBackground,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: colorScheme.onBackground,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: colorScheme.onBackground,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: colorScheme.onBackground,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: colorScheme.onBackground,
        ),
        bodyMedium: TextStyle(
          color: colorScheme.onBackground,
        ),
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: isDarkMode 
            ? Colors.blueGrey.shade700 
            : Colors.grey.shade300,
        thickness: 1,
        space: 1,
      ),

      // Icono theme
      iconTheme: IconThemeData(
        color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
        size: 24,
      ),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }
  
  // Método para obtener el fondo adecuado según el tema
  static BoxDecoration getPageBackgroundDecoration(bool isDarkMode) {
    if (isDarkMode) {
      return BoxDecoration(
        gradient: darkBackgroundGradient,
      );
    } else {
      return BoxDecoration(
        color: Colors.white,
      );
    }
  }
} 