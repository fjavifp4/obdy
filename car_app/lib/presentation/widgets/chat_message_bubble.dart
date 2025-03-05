import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/theme/theme_bloc.dart';

class ChatMessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessageBubble({
    super.key,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final currentTime = DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(currentTime);
    final isUserMessage = isUser;
    
    // Colores para modo claro y oscuro
    final userBubbleColor = isDarkMode ? Colors.blue.shade700 : Colors.blue.shade600;
    final assistantBubbleColor = isDarkMode ? Colors.blueGrey.shade800 : Colors.grey.shade200;
    final userTextColor = Colors.white;
    final assistantTextColor = isDarkMode ? Colors.white : Colors.black87;
    final timeColor = isDarkMode 
        ? (isUserMessage ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.7)) 
        : (isUserMessage ? Colors.white.withOpacity(0.7) : Colors.black54);
    
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
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    color: isUserMessage ? userTextColor : assistantTextColor,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 10,
                child: Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 12,
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
} 