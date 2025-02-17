import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';

class NewChatDialog extends StatefulWidget {
  const NewChatDialog({Key? key}) : super(key: key);

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _messageController = TextEditingController();
  String? _selectedVehicleId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo chat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<VehicleBloc, VehicleState>(
            builder: (context, state) {
              if (state is VehicleLoaded) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Vehículo (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedVehicleId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Chat general'),
                    ),
                    ...state.vehicles.map((vehicle) {
                      return DropdownMenuItem(
                        value: vehicle.id,
                        child: Text('${vehicle.brand} ${vehicle.model}'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedVehicleId = value);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Mensaje inicial',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_messageController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, escribe un mensaje'),
                      ),
                    );
                    return;
                  }

                  setState(() => _isLoading = true);
                  context.read<ChatBloc>().add(
                        CreateChat(
                          message: _messageController.text.trim(),
                          vehicleId: _selectedVehicleId,
                        ),
                      );
                  Navigator.pop(context);
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
} 