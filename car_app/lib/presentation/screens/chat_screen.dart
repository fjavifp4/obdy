import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/background_container.dart';
import '../../config/core/utils/text_normalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/vehicle.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedVehicleId;
  static const String _prefKey = 'last_selected_vehicle_chat';

  @override
  void initState() {
    super.initState();
    context.read<VehicleBloc>().add(LoadVehicles());
    _loadLastSelectedVehicle();
  }
  
  // Carga el último vehículo seleccionado
  Future<void> _loadLastSelectedVehicle() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? lastVehicleId = prefs.getString(_prefKey);
      
      if (!mounted) return;
      
      // Ahora sí actualizamos el estado para reflejar el ID guardado
      setState(() {
        _selectedVehicleId = lastVehicleId;
      });
      
      // Y cargamos el chat con este ID
      context.read<ChatBloc>().add(LoadChat(vehicleId: lastVehicleId));
      
    } catch (e) {
      debugPrint('Error al cargar último vehículo: $e');
      // Si hay error, cargamos el chat general
      if (mounted) {
        context.read<ChatBloc>().add(const LoadChat(vehicleId: null));
      }
    }
  }
  
  // Guarda el vehículo seleccionado
  Future<void> _saveSelectedVehicle(String? vehicleId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (vehicleId != null) {
        await prefs.setString(_prefKey, vehicleId);
      } else {
        // Si se selecciona el chat general, eliminamos la preferencia
        await prefs.remove(_prefKey);
      }
    } catch (e) {
      debugPrint('Error al guardar vehículo seleccionado: $e');
    }
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
          _scrollController.position.maxScrollExtent,
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
          automaticallyImplyLeading: false,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          backgroundColor: Theme.of(context).colorScheme.surface,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: BlocBuilder<VehicleBloc, VehicleState>(
            builder: (context, vehicleState) {
              if (vehicleState is VehicleLoaded) {
                // Validar si el ID guardado existe en la lista de vehículos
                final availableIds = vehicleState.vehicles.map((v) => v.id).toList();
                // Si el _selectedVehicleId no está en la lista de ids disponibles, lo ponemos a null
                if (_selectedVehicleId != null && !availableIds.contains(_selectedVehicleId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedVehicleId = null;
                    });
                  });
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Container(
                    height: 40,
                    constraints: const BoxConstraints(maxWidth: 240),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _getValidDropdownValue(vehicleState.vehicles),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        iconSize: 20,
                        isDense: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: BorderRadius.circular(16),
                        hint: Row(
                          children: [
                            Icon(
                              Icons.garage_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Asistente Automotriz',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Asistente General',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${vehicle.brand} ${vehicle.model}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue == _selectedVehicleId) return;
                          
                          setState(() => _selectedVehicleId = newValue);
                          _saveSelectedVehicle(newValue);
                          context.read<ChatBloc>().add(
                            LoadChat(vehicleId: newValue),
                          );
                        },
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
                  final theme = Theme.of(context);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 3, 
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Limpiar conversación',
                      color: theme.colorScheme.error.withOpacity(0.8),
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
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 3, 
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
            ),
          ],
        ),
        body: BlocConsumer<ChatBloc, ChatState>(
          listener: (context, state) {
            if (state is ChatLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              
              // Sincronizar _selectedVehicleId con el vehicleId del chat
              if (state.chat.vehicleId != _selectedVehicleId) {
                setState(() {
                  _selectedVehicleId = state.chat.vehicleId;
                });
              }
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
              content: TextNormalizer.normalize(state.pendingMessage),
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Pregunta sobre tu vehículo...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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

  // Método para asegurar que el valor seleccionado sea válido
  String? _getValidDropdownValue(List<Vehicle> availableVehicles) {
    // Si no hay un valor seleccionado, retornamos null (es un valor válido)
    if (_selectedVehicleId == null) return null;
    
    // Verificar si el _selectedVehicleId existe en la lista de vehículos disponibles
    final vehicleExists = availableVehicles.any((v) => v.id == _selectedVehicleId);
    
    // Si el vehículo existe, retornamos su ID, si no, retornamos null
    return vehicleExists ? _selectedVehicleId : null;
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
