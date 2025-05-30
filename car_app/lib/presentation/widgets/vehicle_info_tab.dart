import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/vehicle_widgets/vehicle_header.dart';
import '../widgets/vehicle_widgets/itv_section.dart';
import '../widgets/vehicle_widgets/vehicle_stats_section.dart';
import '../widgets/vehicle_widgets/vehicle_actions.dart';
import '../widgets/vehicle_widgets/maintenance_timeline.dart';
import '../widgets/vehicle_widgets/trip_map_section.dart';

class VehicleInfoTab extends StatefulWidget {
  final String vehicleId;

  const VehicleInfoTab({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleInfoTab> createState() => _VehicleInfoTabState();
}

class _VehicleInfoTabState extends State<VehicleInfoTab> {
  @override
  void initState() {
    super.initState();
    // Cargar las estadísticas del vehículo
    context.read<TripBloc>().add(GetVehicleStatsEvent(vehicleId: widget.vehicleId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VehicleBloc, VehicleState>(
      builder: (context, vehicleState) {
        if (vehicleState is VehicleLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (vehicleState is VehicleLoaded) {
          final vehicle = vehicleState.vehicles.firstWhere(
            (v) => v.id == widget.vehicleId,
            orElse: () => throw Exception('Vehículo no encontrado'),
          );
          
          return BlocBuilder<TripBloc, TripState>(
            builder: (context, tripState) {
              // Datos predeterminados por si no hay estadísticas disponibles
              int totalTrips = 0;
              double totalDistance = 0.0;
              double averageTripLength = 0.0;
              List<FlSpot> distanceData = List.generate(10, (i) => FlSpot(i.toDouble(), 0));
              
              // Si hay estadísticas disponibles, usarlas
              if (tripState.vehicleStats != null) {
                totalTrips = tripState.vehicleStats!.totalTrips;
                totalDistance = tripState.vehicleStats!.totalDistance;
                averageTripLength = tripState.vehicleStats!.averageTripLength;
                
                // Convertir los viajes recientes en datos para el gráfico
                if (tripState.vehicleStats!.recentTrips.isNotEmpty) {
                  distanceData = List.generate(
                    tripState.vehicleStats!.recentTrips.length,
                    (i) => FlSpot(
                      i.toDouble(),
                      tripState.vehicleStats!.recentTrips[i].distanceInKm,
                    ),
                  );
                }
              }
              
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
                      vehicleId: widget.vehicleId,
                      totalTrips: totalTrips,
                      totalDistance: totalDistance,
                      totalMaintenanceRecords: vehicle.maintenanceRecords.length,
                      averageTripLength: averageTripLength,
                      licensePlate: vehicle.licensePlate,
                      year: vehicle.year,
                      distanceData: distanceData,
                      isLoading: tripState.status == TripStatus.loading,
                      currentKilometers: vehicle.currentKilometers,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Sección de mapa de viajes
                    TripMapSection(
                      vehicleId: widget.vehicleId,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Sección de ITV
                    ITVSection(
                      vehicleId: widget.vehicleId,
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
                      vehicleId: widget.vehicleId,
                      brand: vehicle.brand,
                      model: vehicle.model,
                    ),
                    
                    // Espacio adicional al final para evitar que el FAB oculte contenido
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        } else if (vehicleState is VehicleError) {
          return Center(
            child: Text(
              'Error: ${vehicleState.message}',
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
