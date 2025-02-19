import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'maintenance_dialog.dart';

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
          if (state is VehicleLoading) {
            return const Center(child: CircularProgressIndicator());
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
                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              onTap: () => _showMaintenanceDialog(
                                context,
                                vehicleId: vehicleId,
                                record: record,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getMaintenanceIcon(record.type),
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                record.type,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Último: ${_formatDate(record.lastChangeDate)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () => _showMaintenanceDialog(
                                                context,
                                                vehicleId: vehicleId,
                                                record: record,
                                              ),
                                              tooltip: 'Editar',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () => _showDeleteConfirmation(
                                                context,
                                                vehicleId: vehicleId,
                                                maintenanceId: record.id,
                                              ),
                                              tooltip: 'Eliminar',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildMaintenanceInfo(
                                          context,
                                          'Kilómetros',
                                          '${record.lastChangeKM}',
                                          Icons.speed,
                                        ),
                                        _buildMaintenanceInfo(
                                          context,
                                          'Intervalo',
                                          '${record.recommendedIntervalKM}',
                                          Icons.update,
                                        ),
                                        _buildMaintenanceInfo(
                                          context,
                                          'Próximo cambio',
                                          '${record.nextChangeKM}',
                                          Icons.schedule,
                                          isWarning: _isMaintenanceNeeded(record),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () => _showMaintenanceDialog(
                      context,
                      vehicleId: vehicleId,
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Estado no manejado'));
        },
      ),
    );
  }

  Future<void> _showMaintenanceDialog(
    BuildContext context, {
    required String vehicleId,
    dynamic record,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MaintenanceDialog(
        vehicleId: vehicleId,
        record: record,
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
    // Ajusta esta lógica según tus necesidades
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
} 