import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'maintenance_dialog.dart';
import '../../config/core/utils/text_normalizer.dart';

class MaintenanceTab extends StatelessWidget {
  final String vehicleId;

  const MaintenanceTab({
    super.key,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: BlocBuilder<VehicleBloc, VehicleState>(
        builder: (context, state) {
          if (state is VehicleLoading || state is MaintenanceAnalysisInProgress) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MaintenanceAnalysisComplete) {
            // Mostrar diálogo para añadir los mantenimientos recomendados
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showRecommendationsDialog(context, state.recommendations);
            });
            // Volver al estado anterior
            context.read<VehicleBloc>().add(LoadVehicles());
          }

          if (state is VehicleLoaded) {
            final vehicle = state.vehicles.firstWhere(
              (v) => v.id == vehicleId,
              orElse: () => throw Exception('Vehículo no encontrado'),
            );

            return Stack(
              children: [
                vehicle.maintenanceRecords.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay registros de mantenimiento',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: vehicle.maintenanceRecords.length,
                        itemBuilder: (context, index) {
                          final record = vehicle.maintenanceRecords[index];
                          return _buildMaintenanceCard(context, record, vehicleId);
                        },
                      ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'analyze_manual',
                        onPressed: () => _handleAnalyzeManual(context, vehicle.hasManual),
                        child: const Icon(Icons.psychology),
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'add_maintenance',
                        onPressed: () => _showMaintenanceDialog(
                          context,
                          vehicleId: vehicleId,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Error al cargar los mantenimientos'));
        },
      ),
    );
  }

  void _handleAnalyzeManual(BuildContext context, bool hasManual) {
    if (!hasManual) {
      _showNoManualDialog(context);
      return;
    }
    _showAnalyzeConfirmationDialog(context);
  }

  Future<void> _showNoManualDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual no encontrado'),
        content: const Text(
          'Para usar esta función, primero debes subir el manual de taller del vehículo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnalyzeConfirmationDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Análisis de mantenimientos'),
        content: const Text(
          'Esta función analizará el manual de taller para extraer los '
          'mantenimientos recomendados por el fabricante.\n\n'
          'Los mantenimientos detectados deberán ser completados con información '
          'adicional como la fecha y kilometraje del último cambio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              context.read<VehicleBloc>().add(AnalyzeMaintenanceManual(vehicleId));
              Navigator.pop(context);
            },
            child: const Text('Analizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecommendationsDialog(
    BuildContext context,
    List<Map<String, dynamic>> recommendations,
  ) {
    final selectedRecommendations = List<bool>.filled(recommendations.length, true);

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Mantenimientos recomendados'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Se han encontrado los siguientes mantenimientos recomendados en el manual:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final recommendation = recommendations[index];
                      // Obtener valores normalizados usando la utilidad centralizada
                      final String type = TextNormalizer.normalize(
                        recommendation['type'], 
                        defaultValue: 'Mantenimiento',
                        cleanRedundant: true
                      );
                      final String interval = TextNormalizer.normalize(
                        recommendation['recommended_interval_km'], 
                        defaultValue: 'No especificado'
                      );
                      final String notes = TextNormalizer.normalize(
                        recommendation['notes'], 
                        defaultValue: 'Sin notas'
                      );
                      
                      return CheckboxListTile(
                        value: selectedRecommendations[index],
                        onChanged: (value) {
                          setState(() {
                            selectedRecommendations[index] = value!;
                          });
                        },
                        title: Text(type),
                        subtitle: Text(
                          'Intervalo: ${interval != "No especificado" ? "$interval km" : interval}\n'
                          'Notas: $notes',
                        ),
                        secondary: const Icon(Icons.build),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                for (var i = 0; i < recommendations.length; i++) {
                  if (selectedRecommendations[i]) {
                    // Normalizar los datos recomendados antes de pasarlos usando la utilidad centralizada
                    final rawData = recommendations[i];
                    final normalizedData = <String, dynamic>{
                      'type': TextNormalizer.normalize(rawData['type'], defaultValue: 'Mantenimiento'),
                      'recommended_interval_km': TextNormalizer.normalize(rawData['recommended_interval_km'], defaultValue: '10000'),
                      'notes': TextNormalizer.normalize(rawData['notes'], defaultValue: ''),
                    };
                    
                    _showMaintenanceDialog(
                      context,
                      vehicleId: vehicleId,
                      recommendedData: normalizedData,
                    );
                  }
                }
              },
              child: const Text('Añadir seleccionados'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(
    BuildContext context, {
    required String vehicleId,
    dynamic record,
    Map<String, dynamic>? recommendedData,
  }) {
    showDialog(
      context: context,
      builder: (context) => MaintenanceDialog(
        vehicleId: vehicleId,
        record: record,
        recommendedData: recommendedData,
      ),
    );
  }

  IconData _getMaintenanceIcon(String type) {
    type = type.toLowerCase();
    if (type.contains('aceite')) return Icons.oil_barrel;
    if (type.contains('freno')) return Icons.report_problem;
    if (type.contains('filtro')) return Icons.filter_alt;
    if (type.contains('llanta') || type.contains('neumatico')) return Icons.tire_repair;
    if (type.contains('bateria')) return Icons.battery_charging_full;
    return Icons.build;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMaintenanceCard(BuildContext context, dynamic record, String vehicleId) {
    // Normalizar el tipo de mantenimiento para asegurar que se muestra correctamente
    final String normalizedType = TextNormalizer.normalize(record.type, cleanRedundant: true);
    
    // Normalizar las notas
    final String? normalizedNotes = record.notes != null ? 
        TextNormalizer.normalize(record.notes) : null;
    
    // Calcular el progreso del mantenimiento
    final double kmSinceLastChange = record.kmSinceLastChange;
    final double totalInterval = record.recommendedIntervalKM.toDouble();
    final double progressPercentage = (kmSinceLastChange / totalInterval).clamp(0.0, 1.0);
    
    // Determinar los colores del gradiente según el progreso
    List<Color> gradientColors = [];
    
    if (progressPercentage < 0.5) {
      // Menos del 50%: Solo verde claro
      gradientColors = [
        Colors.green.shade200,
        Colors.green.shade300,
      ];
    } else if (progressPercentage < 0.75) {
      // Entre 50% y 75%: Verde y amarillo
      gradientColors = [
        Colors.green.shade300,
        Colors.green,
        Colors.yellow,
      ];
    } else {
      // Más del 75%: Verde, amarillo y rojo
      gradientColors = [
        Colors.green.shade300,
        Colors.green,
        Colors.yellow,
        Colors.orange,
        Colors.red,
      ];
    }
    
    // Calcular kilómetros restantes
    final int kmRestantes = (totalInterval - kmSinceLastChange).round();
    final bool isUrgent = kmRestantes <= (record.recommendedIntervalKM * 0.1);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent 
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _getMaintenanceIcon(normalizedType), 
                  color: Theme.of(context).colorScheme.primary,
                  size: 28
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    normalizedType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  onPressed: () => _showMaintenanceDialog(
                    context,
                    vehicleId: vehicleId,
                    record: record,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar',
                  onPressed: () => _showDeleteConfirmation(
                    context,
                    vehicleId: vehicleId,
                    maintenanceId: record.id,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de progreso de mantenimiento con gradiente
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          height: 10,
                          width: constraints.maxWidth * progressPercentage,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Información del progreso
                Text(
                  '${(progressPercentage * 100).toInt()}% km recorridos',
                  style: TextStyle(
                    color: progressPercentage > 0.75
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Último cambio: ${_formatDate(record.lastChangeDate)}',
                  style: const TextStyle(fontSize: 14),
                ),
                
                const SizedBox(height: 16),
                
                // Información detallada del mantenimiento
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMaintenanceInfo(
                        context,
                        'Último cambio',
                        '${record.lastChangeKM} km',
                        Icons.history,
                      ),
                      _buildMaintenanceInfo(
                        context,
                        'Intervalo',
                        '${record.recommendedIntervalKM} km',
                        Icons.update,
                      ),
                      _buildMaintenanceInfo(
                        context,
                        'Próximo cambio',
                        '${record.nextChangeKM} km',
                        Icons.arrow_forward,
                      ),
                      _buildMaintenanceInfo(
                        context,
                        'Restantes',
                        '$kmRestantes km',
                        Icons.watch_later_outlined,
                        isWarning: isUrgent,
                      ),
                    ],
                  ),
                ),
                
                // Mostrar notas si existen y no están vacías
                if (normalizedNotes != null && normalizedNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Notas:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          normalizedNotes,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Botón para marcar como completado
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _completeMaintenanceConfirmation(
                      context,
                      vehicleId: vehicleId,
                      maintenanceId: record.id,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Completar mantenimiento'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceInfo(
    BuildContext context,
    String label,
    String value, 
    IconData icon, {
    bool isWarning = false,
  }) {
    final color = isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isWarning
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  bool _isMaintenanceNeeded(record) {
    return record.nextChangeKM - record.lastChangeKM <= record.recommendedIntervalKM * 0.1;
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context, {
    required String vehicleId,
    required String maintenanceId,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Text('Eliminar registro'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este registro de mantenimiento?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              context.read<VehicleBloc>().add(
                DeleteMaintenanceRecord(
                  vehicleId: vehicleId,
                  maintenanceId: maintenanceId,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Método para mostrar la confirmación de completar mantenimiento
  void _completeMaintenanceConfirmation(
    BuildContext context, {
    required String vehicleId,
    required String maintenanceId,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar mantenimiento'),
        content: const Text(
          '¿Has realizado este mantenimiento? Al confirmarlo, se actualizará la fecha y se reiniciará el contador de kilómetros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<VehicleBloc>().add(
                CompleteMaintenanceRecord(
                  vehicleId: vehicleId,
                  maintenanceId: maintenanceId,
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}