import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/background_container.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    context.read<VehicleBloc>().add(LoadVehicles());
    context.read<ChatBloc>().add(const LoadChat(vehicleId: null));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0, // Como el ListView está en reverse: true, 0 es el final
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: BlocBuilder<VehicleBloc, VehicleState>(
            builder: (context, vehicleState) {
              if (vehicleState is VehicleLoaded) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _selectedVehicleId,
                          hint: Row(
                            children: [
                              Icon(
                                Icons.garage_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Asistente Automotriz',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          menuMaxHeight: 300,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.support_agent,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Asistente General',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...vehicleState.vehicles.map((vehicle) {
                              return DropdownMenuItem(
                                value: vehicle.id,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${vehicle.brand} ${vehicle.model}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (String? newValue) {
                            setState(() => _selectedVehicleId = newValue);
                            context.read<ChatBloc>().add(
                              LoadChat(vehicleId: newValue),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const Text('Asistente Automotriz');
            },
          ),
          actions: [
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoaded) {
                  return IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Limpiar conversación',
                    color: Theme.of(context).colorScheme.onSurface,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 8),
                              const Text('Limpiar conversación'),
                            ],
                          ),
                          content: const Text('¿Estás seguro de que quieres borrar toda la conversación?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () {
                                context.read<ChatBloc>().add(ClearChat(state.chat.id));
                                Navigator.pop(context);
                              },
                              child: const Text('Limpiar'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.info_outline),
                color: Theme.of(context).colorScheme.onSurface,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Asistente Automotriz'),
                      ],
                    ),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¡Bienvenido al Asistente Automotriz!'),
                        SizedBox(height: 8),
                        Text('Puedes preguntarme sobre:'),
                        SizedBox(height: 4),
                        Text('• Mantenimiento preventivo'),
                        Text('• Diagnóstico de problemas'),
                        Text('• Especificaciones técnicas'),
                        Text('• Consejos de conducción'),
                        Text('• Mejoras y modificaciones'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Entendido'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: BlocConsumer<ChatBloc, ChatState>(
          listener: (context, state) {
            if (state is ChatLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: _buildChatContent(state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatContent(ChatState state) {
    if (state is ChatLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ChatError) {
      return Center(child: Text('Error: ${state.message}'));
    }

    if (state is ChatLoaded) {
      // Scroll cuando se envía un mensaje
      if (state is ChatSending) {
        _scrollToBottom();
      }
      
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: state.chat.messages.length,
              itemBuilder: (context, index) {
                final message = state.chat.messages[index];
                return ChatMessageBubble(
                  content: message.content,
                  isUser: message.isUser,
                  timestamp: message.createdAt,
                );
              },
            ),
          ),
          if (state is ChatSending) ...[
            ChatMessageBubble(
              content: state.pendingMessage,
              isUser: true,
              timestamp: DateTime.now(),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: TypingIndicator(),
            ),
          ],
          _buildInputBar(context),
        ],
      );
    }

    return const Center(child: Text('Inicia una conversación'));
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Pregunta sobre tu vehículo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.auto_awesome),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.onPrimary,
              onPressed: () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String message) {
    if (message.trim().isNotEmpty) {
      final state = context.read<ChatBloc>().state;
      if (state is ChatLoaded) {
        context.read<ChatBloc>().add(
          SendMessage(
            chatId: state.chat.id,
            message: message.trim(),
          ),
        );
        _messageController.clear();
      }
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const _MessageBubble({
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
} 