import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../blocs/blocs.dart';
import '../../domain/usecases/trip/get_user_statistics.dart';
import '../../domain/entities/trip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(const RefreshHomeData());
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        context.read<HomeBloc>().add(const RefreshHomeData());
        return;
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.initial || state.status == HomeStatus.loading && state.statistics == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state.status == HomeStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.error ?? 'Error desconocido'),
                  const SizedBox(height: 16),
                  if (state.error != null && (
                      state.error!.contains('sesión') || 
                      state.error!.contains('token') || 
                      state.error!.contains('autent')))
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                      child: const Text('Iniciar sesión'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => context.read<HomeBloc>().add(const RefreshHomeData()),
                      child: const Text('Reintentar'),
                    ),
                ],
              ),
            );
          }
          
          final statistics = state.statistics;
          
          if (statistics == null) {
            return const Center(child: Text('No hay estadísticas disponibles'));
          }
          
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatisticsSection(statistics),
                const SizedBox(height: 24),
                _buildFuelPricesSection(state),
                const SizedBox(height: 24),
                _buildTripsMapSection(statistics.recentTrips),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¡Bienvenido!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Resumen de tus estadísticas',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatisticsSection(UserStatistics statistics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas generales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsGridView(statistics),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsGridView(UserStatistics statistics) {
    final stats = [
      {
        'icon': Icons.directions_car,
        'title': 'Vehículos',
        'value': statistics.totalVehicles.toString(),
      },
      {
        'icon': Icons.route,
        'title': 'Viajes',
        'value': statistics.totalTrips.toString(),
      },
      {
        'icon': Icons.map,
        'title': 'Distancia',
        'value': '${statistics.totalDistance.toStringAsFixed(1)} km',
      },
      {
        'icon': Icons.timer,
        'title': 'Tiempo',
        'value': '${statistics.totalDrivingTime.toStringAsFixed(1)} h',
      },
      {
        'icon': Icons.local_gas_station,
        'title': 'Combustible',
        'value': '${statistics.totalFuelConsumption.toStringAsFixed(1)} L',
      },
      {
        'icon': Icons.speed,
        'title': 'Velocidad media',
        'value': '${statistics.averageSpeed.toStringAsFixed(1)} km/h',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stat['icon'] as IconData,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  stat['title'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stat['value'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFuelPricesSection(HomeState state) {
    final fuelPrices = state.fuelPrices;
    final isLoading = state.isLoadingFuelPrices;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Precios de combustible',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (fuelPrices != null) ...[
              _buildFuelPriceRow('Gasolina 95', fuelPrices['gasolina95'] ?? 0.0),
              const Divider(),
              _buildFuelPriceRow('Gasolina 98', fuelPrices['gasolina98'] ?? 0.0),
              const Divider(),
              _buildFuelPriceRow('Diesel', fuelPrices['diesel'] ?? 0.0),
            ] else if (!isLoading) ...[
              const Center(
                child: Text('No hay datos de precios disponibles'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.read<HomeBloc>().add(const LoadFuelPrices()),
                  child: const Text('Cargar precios'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFuelPriceRow(String name, double price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
          Text(
            '${price.toStringAsFixed(3)} €/L',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTripsMapSection(List<Trip> trips) {
    List<LatLng> allPoints = [];
    
    for (var trip in trips) {
      final points = trip.gpsPoints.map((point) => 
        LatLng(point.latitude, point.longitude)).toList();
      allPoints.addAll(points);
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tus rutas recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visualización de tus últimos ${trips.length} viajes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 300,
              child: allPoints.isEmpty
                ? const Center(
                    child: Text('No hay rutas registradas para mostrar'),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: allPoints.isNotEmpty ? allPoints[0] : LatLng(40.416775, -3.703790),
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.car_app',
                      ),
                      ...trips.map((trip) {
                        final points = trip.gpsPoints.map((point) => 
                          LatLng(point.latitude, point.longitude)).toList();
                        
                        // Si no hay puntos, no dibujamos nada
                        if (points.isEmpty) return const SizedBox.shrink();
                        
                        return PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 3.0,
                            ),
                          ],
                        );
                      }),
                      // Marcadores para los puntos de inicio y fin
                      ...trips.map((trip) {
                        final points = trip.gpsPoints.map((point) => 
                          LatLng(point.latitude, point.longitude)).toList();
                          
                        if (points.isEmpty) return const SizedBox.shrink();
                        
                        return MarkerLayer(
                          markers: [
                            if (points.isNotEmpty) 
                              Marker(
                                point: points.first,
                                child: const Icon(
                                  Icons.trip_origin,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                            if (points.length > 1) 
                              Marker(
                                point: points.last,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
} 