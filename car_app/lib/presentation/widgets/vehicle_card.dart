import 'package:flutter/material.dart';
import '../screens/vehicle_details_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'dart:convert';

class VehicleCard extends StatelessWidget {
  final String vehicleId;
  final VoidCallback onDelete;

  const VehicleCard({
    super.key,
    required this.vehicleId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return BlocBuilder<VehicleBloc, VehicleState>(
      builder: (context, state) {
        if (state is VehicleLoaded) {
          final vehicle = state.vehicles.firstWhere(
            (v) => v.id == vehicleId,
            orElse: () => throw Exception('Vehículo no encontrado'),
          );

          return Card(
            color: Theme.of(context).colorScheme.surface,
            elevation: isDarkMode ? 1 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDarkMode 
                    ? Theme.of(context).colorScheme.outline.withOpacity(0.5)
                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VehicleDetailsScreen(
                      key: VehicleDetailsScreen.globalKey,
                      vehicleId: vehicleId,
                    ),
                  ),
                );
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Color(0xFF3A3A3D) // Gris más claro que contrasta mejor con logos oscuros
                                : Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                          ),
                          child: vehicle.hasLogo
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.memory(
                                    base64Decode(vehicle.logo!),
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Icon(
                                  Icons.directions_car,
                                  size: constraints.maxHeight * 0.35,
                                  color: isDarkMode
                                      ? Colors.grey[300]
                                      : Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                        ),
                      ),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${vehicle.brand} ${vehicle.model}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar vehículo'),
                                    content: const Text('¿Estás seguro de que quieres eliminar este vehículo?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          onDelete();
                                        },
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
} 