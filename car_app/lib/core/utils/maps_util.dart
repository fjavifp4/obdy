import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

/// Clase utilitaria para funciones relacionadas con mapas
class MapsUtil {
  /// Abre Google Maps o Apple Maps con las coordenadas especificadas
  /// 
  /// [latitude] - Latitud de la ubicación
  /// [longitude] - Longitud de la ubicación
  /// [name] - Nombre del lugar (opcional)
  static Future<bool> openMapsWithLocation(double latitude, double longitude, {String? name}) async {
    final encodedName = name != null ? Uri.encodeComponent(name) : '';
    final label = name != null ? '&q=$encodedName' : '';
    
    Uri uri;
    
    if (Platform.isIOS) {
      // URL para Apple Maps en iOS
      uri = Uri.parse('https://maps.apple.com/?ll=$latitude,$longitude$label');
    } else {
      // URL para Google Maps en Android y otros
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    }
    
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        return launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback en caso de que no se pueda abrir la URL específica de la plataforma
        final googleUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        );
        return launchUrl(
          googleUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Error al abrir mapa: $e');
      return false;
    }
  }
} 