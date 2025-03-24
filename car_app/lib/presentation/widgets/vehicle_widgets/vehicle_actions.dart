import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';

class VehicleActions extends StatelessWidget {
  final String vehicleId;
  final String brand;
  final String model;

  const VehicleActions({
    super.key,
    required this.vehicleId,
    required this.brand,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.primaryContainer.withOpacity(0.1),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Acciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    title: 'Editar Vehículo',
                    icon: Icons.edit,
                    color: colorScheme.primary,
                    onTap: () => _showEditDialog(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    context,
                    title: 'Eliminar Vehículo',
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: () => _showDeleteConfirmation(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    // Valores iniciales para el formulario
    final TextEditingController brandController = TextEditingController(text: brand);
    final TextEditingController modelController = TextEditingController(text: model);
    final TextEditingController currentKilometersController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Editar Vehículo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: brandController,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentKilometersController,
                decoration: const InputDecoration(
                  labelText: 'Kilometraje actual',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (brandController.text.isNotEmpty && modelController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  
                  // Preparar las actualizaciones
                  final Map<String, dynamic> updates = {
                    'brand': brandController.text.trim(),
                    'model': modelController.text.trim(),
                  };
                  
                  // Añadir el kilometraje actual si se ha proporcionado
                  if (currentKilometersController.text.isNotEmpty) {
                    final km = int.tryParse(currentKilometersController.text);
                    if (km != null && km >= 0) {
                      updates['current_kilometers'] = km;
                    }
                  }
                  
                  // Actualizar el vehículo
                  context.read<VehicleBloc>().add(
                    UpdateVehicle(
                      id: vehicleId,
                      updates: updates,
                    ),
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vehículo actualizado')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              const Text('Eliminar Vehículo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de eliminar el vehículo $brand $model?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta acción no se puede deshacer y se eliminarán todos los datos asociados, incluyendo registros de mantenimiento y viajes.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Eliminar el vehículo
                context.read<VehicleBloc>().add(DeleteVehicle(vehicleId));
                
                // Navegar hacia atrás después de eliminar
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vehículo eliminado')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }
} 