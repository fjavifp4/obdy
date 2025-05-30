import 'dart:convert';

/// Clase utilitaria para normalizar textos con problemas de codificación
/// especialmente para caracteres especiales del español
class TextNormalizer {
  /// Mapa de reemplazos para caracteres y palabras problemáticas comunes
  static final Map<String, String> _replacements = {
    // Vocales acentuadas
    'Ã¡': 'á',
    'Ã©': 'é',
    'Ã­': 'í',
    'Ã³': 'ó',
    'Ãº': 'ú',
    'Ã\u0081': 'Á',
    'Ã\u0089': 'É',
    'Ã\u008D': 'Í',
    'Ã\u0093': 'Ó',
    'Ã\u009A': 'Ú',

    // Ñ y otros caracteres especiales
    'Ã±': 'ñ',
    'Ã\u0091': 'Ñ',
    'Ã¼': 'ü',
    'Ã\u009C': 'Ü',

    // Palabras comunes con problemas
    'baterÃ­a': 'batería',
    'distribuciÃ³n': 'distribución',
    'lÃ­quido': 'líquido',
    'neumÃ¡ticos': 'neumáticos',
    'bujÃ­as': 'bujías',
    'revisiÃ³n': 'revisión',
    'sustituciÃ³n': 'sustitución',
    'filtraciÃ³n': 'filtración',
    'verificaciÃ³n': 'verificación',
    'presiÃ³n': 'presión',
    'motorizaciÃ³n': 'motorización',
    'InspecciÃ³n': 'Inspección',
    'TÃ©cnica': 'Técnica',
    'aÃ±os': 'años',
  };

  /// Prefijos redundantes que se pueden eliminar para mejorar la presentación
  static final List<String> _redundantPrefixes = [
    /*'Cambio de ',
    'Revisar ',
    'Revisión de ',
    'Sustitución de ',*/
  ];

  /// Normaliza un texto corrigiendo problemas de codificación
  /// y eliminando prefijos redundantes si cleanRedundant es true
  static String normalize(dynamic value, {String defaultValue = '', bool cleanRedundant = false}) {
    if (value == null || value.toString() == 'null') {
      return defaultValue;
    }

    String text = value.toString();
    
    // 1. Aplicar reemplazos específicos
    _replacements.forEach((malformed, corrected) {
      text = text.replaceAll(malformed, corrected);
    });
    
    // 2. Intentar recodificar de Latin1 a UTF-8
    try {
      final bytes = latin1.encode(text);
      final decoded = utf8.decode(bytes);
      // Verificar que la decodificación hizo algún cambio
      if (decoded != text) {
        text = decoded;
      }
    } catch (e) {
      // Si falla, mantener el texto con los reemplazos ya aplicados
    }
    
    // 3. Limpiar prefijos redundantes si se solicita
    if (cleanRedundant) {
      for (var prefix in _redundantPrefixes) {
        if (text.startsWith(prefix)) {
          text = text.substring(prefix.length);
          break; // Solo eliminar el primer prefijo que coincida
        }
      }
    }
    
    // 4. Eliminar espacios en blanco sobrantes
    text = text.trim();
    
    return text;
  }

  /// Normaliza un Map<String, dynamic> de forma recursiva
  static Map<String, dynamic> normalizeMap(Map<String, dynamic> map) {
    final normalizedMap = <String, dynamic>{};
    
    map.forEach((key, value) {
      if (value is String) {
        normalizedMap[key] = normalize(value);
      } else if (value is Map<String, dynamic>) {
        normalizedMap[key] = normalizeMap(value);
      } else if (value is List) {
        normalizedMap[key] = normalizeList(value);
      } else {
        normalizedMap[key] = value;
      }
    });
    
    return normalizedMap;
  }

  /// Normaliza una lista de forma recursiva
  static List normalizeList(List list) {
    return list.map((item) {
      if (item is String) {
        return normalize(item);
      } else if (item is Map<String, dynamic>) {
        return normalizeMap(item);
      } else if (item is List) {
        return normalizeList(item);
      } else {
        return item;
      }
    }).toList();
  }
} 
