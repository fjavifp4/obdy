import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/theme/theme_bloc.dart';
import 'dart:convert';
import 'package:html_unescape/html_unescape.dart';

class ChatMessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  
  // Instancia estática para la decodificación HTML
  static final _htmlUnescape = HtmlUnescape();

  const ChatMessageBubble({
    super.key,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final formattedTime = DateFormat('HH:mm', 'es_ES').format(timestamp);
    final isUserMessage = isUser;
    final theme = Theme.of(context);
    
    // Colores para modo claro y oscuro
    final userBubbleColor = theme.colorScheme.primary;
    final assistantBubbleColor = isDarkMode ? theme.colorScheme.surfaceVariant : theme.colorScheme.secondaryContainer;
    final userTextColor = theme.colorScheme.onPrimary;
    final assistantTextColor = isDarkMode ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSecondaryContainer;
    final timeColor = (isUserMessage ? theme.colorScheme.onPrimary : assistantTextColor).withOpacity(0.7);
    
    // Procesar el contenido para eliminar etiquetas y corregir caracteres
    String processedContent = _processContent(content);
    
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          elevation: isDarkMode ? 3 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isUserMessage ? userBubbleColor : assistantBubbleColor,
          margin: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 10,
                  bottom: 22, // Espacio para el timestamp
                ),
                child: Text(
                  processedContent,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isUserMessage ? userTextColor : assistantTextColor,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 10,
                child: Text(
                  formattedTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: timeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Método principal para procesar el contenido
  String _processContent(String text) {
    try {
      // Paso 1: Eliminar etiquetas HTML comunes
      String cleaned = text;
      cleaned = cleaned.replaceAll('<think>', '');
      cleaned = cleaned.replaceAll('</think>', '');
      cleaned = cleaned.replaceAll('<thinking>', '');
      cleaned = cleaned.replaceAll('</thinking>', '');
      
      // Paso 2: Eliminar proceso de pensamiento al inicio
      if (cleaned.startsWith('Vale, el usuario') || 
          cleaned.startsWith('El usuario') ||
          cleaned.startsWith('Debo') ||
          cleaned.startsWith('Voy a') ||
          cleaned.startsWith('Necesito')) {
        int endIndex = cleaned.indexOf("\n\n");
        if (endIndex != -1 && endIndex < cleaned.length - 2) {
          cleaned = cleaned.substring(endIndex + 2);
        }
      }
      
      // Paso 3: Decodificar entidades HTML
      cleaned = _htmlUnescape.convert(cleaned);
      
      // Paso 4: Intentar decodificar UTF-8
      try {
        List<int> bytes = cleaned.codeUnits;
        cleaned = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        print('Error en decodificación UTF-8: $e');
      }
      
      // Paso 5: Correcciones manuales para caracteres comunes
      final replacements = {
        'Ã¡': 'á',
        'Ã©': 'é',
        'Ã­': 'í',
        'Ã³': 'ó',
        'Ãº': 'ú',
        'Ã±': 'ñ',
      };
      
      replacements.forEach((key, value) {
        cleaned = cleaned.replaceAll(key, value);
      });
      
      // Paso 6: Corregir formato markdown y listas
      cleaned = cleaned.replaceAll('**', '');
      cleaned = cleaned.replaceAll('__', '');
      cleaned = cleaned.replaceAll('- ', '• ');
      cleaned = cleaned.replaceAll('* ', '• ');
      cleaned = cleaned.replaceAll('#', '');
      cleaned = cleaned.replaceAll('---', '');
      
      // Paso 7: Eliminar problemas con $1, $2, $3
      cleaned = cleaned.replaceAll(r'$1', '');
      cleaned = cleaned.replaceAll(r'$2', '');
      cleaned = cleaned.replaceAll(r'$3', '');
      
      return cleaned;
    } catch (e) {
      print('Error al procesar texto: $e');
      return text;
    }
  }
}
