import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color principal: Un azul eléctrico moderno que recuerda a los coches deportivos
  static const Color seedColor = Color(0xFF0066FF);
  
  // Paleta de colores personalizada para modo claro
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
    background: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    surfaceVariant: Color(0xFFF5F7FA),
    onSurfaceVariant: Color(0xFF4A4A4A),
    primaryContainer: Color(0xFFE6F0FF),
    onPrimaryContainer: Color(0xFF003D99),
    secondaryContainer: Color(0xFFF0F2F5),
    onSecondaryContainer: Color(0xFF2C3E50),
    error: Color(0xFFE53935),
  );

  // Paleta de colores personalizada para modo oscuro
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
    background: Color(0xFF1A1B1E),
    surface: Color(0xFF1F2024),
    onSurface: Colors.white,
    surfaceVariant: Color(0xFF2C2D31),
    onSurfaceVariant: Color(0xFFE0E0E0),
    primaryContainer: Color(0xFF003D99),
    onPrimaryContainer: Color(0xFFE6F0FF),
    secondaryContainer: Color(0xFF2C3E50),
    onSecondaryContainer: Color(0xFFF0F2F5),
    error: Color(0xFFEF5350),
  );

  // Color de fondo para páginas en modo oscuro
  static final LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1B1E),
      Color(0xFF1F2024),
    ],
  );

  static ThemeData getTheme(bool isDarkMode) {
    final colorScheme = isDarkMode ? darkColorScheme : lightColorScheme;
    
    // Definimos los estilos de texto base con la fuente Montserrat
    final TextTheme montserratTextTheme = GoogleFonts.montserratTextTheme(
      isDarkMode ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      
      // Fuentes personalizadas para toda la aplicación
      fontFamily: GoogleFonts.montserrat().fontFamily,
      
      // Colores básicos
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: isDarkMode 
          ? colorScheme.onSurface.withOpacity(0.2) 
          : colorScheme.onBackground.withOpacity(0.1),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode 
            ? Color(0xFF2A2A2D) // Color oscuro más adecuado para modo oscuro
            : colorScheme.primary,
        foregroundColor: isDarkMode
            ? colorScheme.onSurface
            : colorScheme.onPrimary,
        elevation: isDarkMode ? 0 : 2,
        iconTheme: IconThemeData(
          color: isDarkMode
              ? colorScheme.onSurface
              : colorScheme.onPrimary,
        ),
        titleTextStyle: GoogleFonts.montserrat(
          color: isDarkMode
              ? colorScheme.onSurface
              : colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: isDarkMode ? colorScheme.surfaceContainerHighest : colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: colorScheme.shadow,
      ),
      
      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDarkMode 
            ? Color(0xFF2A2A2D) // Color oscuro más adecuado para modo oscuro
            : colorScheme.primary,
        selectedItemColor: isDarkMode 
            ? colorScheme.primary 
            : colorScheme.onPrimary,
        unselectedItemColor: isDarkMode 
            ? colorScheme.onSurface.withOpacity(0.7) 
            : colorScheme.onPrimary.withOpacity(0.7),
        elevation: isDarkMode ? 0 : 8,
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
        iconSize: 24,
        enableFeedback: true,
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
          textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration theme para TextFields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode 
            ? colorScheme.surfaceVariant
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        labelStyle: GoogleFonts.montserrat(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: GoogleFonts.montserrat(
          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
      
      // Text Theme completamente personalizado con Montserrat
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        displaySmall: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        headlineMedium: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleLarge: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleSmall: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontSize: 12,
        ),
        labelLarge: GoogleFonts.montserrat(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: isDarkMode 
            ? colorScheme.surfaceVariant
            : colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Icono theme
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
      ),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.montserrat(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.montserrat(
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
        color: lightColorScheme.background,
      );
    }
  }
} 