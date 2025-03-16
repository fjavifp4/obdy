import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/vehicle_widgets/vehicle_header.dart';
import '../widgets/vehicle_widgets/itv_section.dart';
import '../widgets/vehicle_widgets/vehicle_stats_section.dart';
import '../widgets/vehicle_widgets/vehicle_actions.dart';
import '../widgets/vehicle_widgets/maintenance_timeline.dart';

class VehicleInfoTab extends StatelessWidget {
  final String vehicleId;

  const VehicleInfoTab({
    super.key,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VehicleBloc, VehicleState>(
      builder: (context, state) {
        if (state is VehicleLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is VehicleLoaded) {
          final vehicle = state.vehicles.firstWhere(
            (v) => v.id == vehicleId,
            orElse: () => throw Exception('Vehículo no encontrado'),
          );
          
          // Para las estadísticas del vehículo
          // Normalmente obtendrías estos datos de los casos de uso
          // pero por ahora usaremos datos de ejemplo
          final totalTrips = 42;
          final totalDistance = 2543.5;
          final totalMaintenanceRecords = vehicle.maintenanceRecords.length;
          final averageTripLength = totalDistance / (totalTrips > 0 ? totalTrips : 1);
          
          // Datos ficticios para el gráfico de distancia
          final List<FlSpot> distanceData = [
            const FlSpot(0, 15),
            const FlSpot(1, 23),
            const FlSpot(2, 17),
            const FlSpot(3, 32),
            const FlSpot(4, 28),
            const FlSpot(5, 19),
            const FlSpot(6, 42),
            const FlSpot(7, 31),
            const FlSpot(8, 25),
            const FlSpot(9, 36),
          ];
          
          return SingleChildScrollView(
            child: Column(
              children: [
                // Encabezado con nombre y logo del vehículo
                VehicleHeader(
                  brand: vehicle.brand,
                  model: vehicle.model,
                  year: vehicle.year,
                  logoBase64: vehicle.logo,
                ),
                
                const SizedBox(height: 16),
                
                // Sección de estadísticas del vehículo
                VehicleStatsSection(
                  vehicleId: vehicleId,
                  totalTrips: totalTrips,
                  totalDistance: totalDistance,
                  totalMaintenanceRecords: totalMaintenanceRecords,
                  averageTripLength: averageTripLength,
                  licensePlate: vehicle.licensePlate,
                  year: vehicle.year,
                  distanceData: distanceData,
                ),
                
                const SizedBox(height: 8),
                
                // Sección de ITV
                ITVSection(
                  vehicleId: vehicleId,
                  lastItvDate: vehicle.lastItvDate,
                  nextItvDate: vehicle.nextItvDate,
                  hasLastItv: vehicle.hasLastItv,
                  hasNextItv: vehicle.hasNextItv,
                ),
                
                const SizedBox(height: 8),
                
                // Línea de tiempo de eventos
                MaintenanceTimeline(
                  maintenanceRecords: vehicle.maintenanceRecords,
                  lastItvDate: vehicle.lastItvDate,
                  nextItvDate: vehicle.nextItvDate,
                ),
                
                const SizedBox(height: 8),
                
                // Acciones de vehículo (editar, eliminar)
                VehicleActions(
                  vehicleId: vehicleId,
                  brand: vehicle.brand,
                  model: vehicle.model,
                ),
                
                // Espacio adicional al final para evitar que el FAB oculte contenido
                const SizedBox(height: 80),
              ],
            ),
          );
        } else if (state is VehicleError) {
          return Center(
            child: Text(
              'Error: ${state.message}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        } else {
          return const Center(
            child: Text('No hay información del vehículo disponible'),
          );
        }
      },
    );
  }
} 