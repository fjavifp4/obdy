import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../blocs/blocs.dart';
import '../../domain/usecases/trip/get_user_statistics.dart';
import '../../domain/entities/trip.dart';
import '../widgets/fuel_favorites_widget.dart';
import '../widgets/fuel_map_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enumeración para el período de filtrado
enum StatsPeriod { all, month, week, day }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  // Estado para el período de filtrado
  StatsPeriod _selectedPeriod = StatsPeriod.all;
  static const String _prefKey = 'stats_filter_period';
  
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(const RefreshHomeData());
    _loadSelectedPeriod();
  }
  
  // Cargar el último período seleccionado
  Future<void> _loadSelectedPeriod() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? savedPeriod = prefs.getInt(_prefKey);
      
      if (!mounted) return;
      
      if (savedPeriod != null && savedPeriod >= 0 && savedPeriod < StatsPeriod.values.length) {
        setState(() {
          _selectedPeriod = StatsPeriod.values[savedPeriod];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar el período de filtrado: $e');
    }
  }
  
  // Guardar el período seleccionado
  Future<void> _saveSelectedPeriod(StatsPeriod period) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, period.index);
    } catch (e) {
      debugPrint('Error al guardar el período de filtrado: $e');
    }
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildStatisticsSection(statistics),
                    const SizedBox(height: 20),
                    // Mapa de estaciones de combustible
                    _buildFuelMapSection(),
                    const SizedBox(height: 20),
                    // Estaciones favoritas
                    _buildFuelFavoritesSection(),
                    const SizedBox(height: 20),
                    // Mapa de viajes
                    _buildTripsMapSection(statistics.recentTrips),
                    const SizedBox(height: 16),
                  ],
                );
              }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: const Text(
                    'Estadísticas generales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPeriodFilter(),
              ],
            ),
            const SizedBox(height: 16),
            _buildFilterDescription(),
            const SizedBox(height: 12),
            _buildStatsGridView(statistics),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPeriodFilter() {
    return Container(
      height: 36,
      constraints: const BoxConstraints(maxWidth: 150),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StatsPeriod>(
          value: _selectedPeriod,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          iconSize: 18,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          borderRadius: BorderRadius.circular(18),
          items: [
            DropdownMenuItem(
              value: StatsPeriod.all,
              child: Text('Todo', style: Theme.of(context).textTheme.bodySmall),
            ),
            DropdownMenuItem(
              value: StatsPeriod.month,
              child: Text('Último mes', style: Theme.of(context).textTheme.bodySmall),
            ),
            DropdownMenuItem(
              value: StatsPeriod.week,
              child: Text('Última semana', style: Theme.of(context).textTheme.bodySmall),
            ),
            DropdownMenuItem(
              value: StatsPeriod.day,
              child: Text('Último día', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
          onChanged: (StatsPeriod? newValue) {
            if (newValue != null && newValue != _selectedPeriod) {
              setState(() {
                _selectedPeriod = newValue;
              });
              // Guardar la selección en preferencias
              _saveSelectedPeriod(newValue);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildFilterDescription() {
    String periodText;
    switch (_selectedPeriod) {
      case StatsPeriod.all:
        periodText = 'Estadísticas de todo el tiempo';
        break;
      case StatsPeriod.month:
        final startDate = DateTime.now().subtract(const Duration(days: 30));
        periodText = 'Desde el ${DateFormat('d MMM').format(startDate)}';
        break;
      case StatsPeriod.week:
        final startDate = DateTime.now().subtract(const Duration(days: 7));
        periodText = 'Desde el ${DateFormat('d MMM').format(startDate)}';
        break;
      case StatsPeriod.day:
        periodText = 'Últimas 24 horas';
        break;
    }
    
    return Text(
      periodText,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }
  
  // Método para filtrar las estadísticas según el período seleccionado
  UserStatistics _getFilteredStatistics(UserStatistics statistics) {
    if (_selectedPeriod == StatsPeriod.all) {
      return statistics;
    }
    
    // Define la fecha de inicio según el período seleccionado
    DateTime startDate;
    switch (_selectedPeriod) {
      case StatsPeriod.month:
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
      case StatsPeriod.week:
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case StatsPeriod.day:
        startDate = DateTime.now().subtract(const Duration(days: 1));
        break;
      default:
        return statistics; // No debería ocurrir
    }
    
    // Filtra los viajes según la fecha
    final filteredTrips = statistics.recentTrips.where((trip) => 
      trip.startTime.isAfter(startDate)).toList();
    
    // Calculamos valores filtrados
    final totalTrips = filteredTrips.length;
    final totalDistance = filteredTrips.fold(0.0, (sum, trip) => sum + trip.distanceInKm);
    final totalDrivingSeconds = filteredTrips.fold(0, (sum, trip) => sum + trip.durationSeconds);
    final totalDrivingTime = totalDrivingSeconds / 3600; // convertir a horas
    final totalFuelConsumption = filteredTrips.fold(0.0, (sum, trip) => sum + trip.fuelConsumptionLiters);
    
    // Velocidad media y consumo medio
    double averageSpeed = 0.0;
    double averageFuelConsumption = 0.0;
    
    if (totalDrivingTime > 0) {
      averageSpeed = totalDistance / totalDrivingTime;
    } else if (filteredTrips.isNotEmpty) {
      averageSpeed = filteredTrips.fold(0.0, (sum, trip) => sum + trip.averageSpeedKmh) / filteredTrips.length;
    }
    
    if (totalDistance > 0) {
      averageFuelConsumption = (totalFuelConsumption / totalDistance) * 100; // L/100km
    }
    
    // Retornamos las estadísticas filtradas
    return UserStatistics(
      totalVehicles: statistics.totalVehicles, // No se filtra
      totalTrips: totalTrips,
      totalDistance: totalDistance,
      totalDrivingTime: totalDrivingTime,
      totalFuelConsumption: totalFuelConsumption,
      averageDailyDistance: statistics.averageDailyDistance, // No se filtra
      averageSpeed: averageSpeed,
      recentTrips: filteredTrips,
    );
  }
  
  Widget _buildStatsGridView(UserStatistics rawStatistics) {
    // Aplicamos el filtro a las estadísticas
    final statistics = _getFilteredStatistics(rawStatistics);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    // Calculamos el consumo medio (L/100km)
    double averageFuelConsumption = 0.0;
    if (statistics.totalDistance > 0) {
      averageFuelConsumption = (statistics.totalFuelConsumption / statistics.totalDistance) * 100;
    }
    
    final stats = [
      {
        'icon': Icons.directions_car,
        'title': 'Vehículos',
        'value': statistics.totalVehicles.toString(),
        'color': isDarkMode ? Colors.redAccent : Colors.red,
      },
      {
        'icon': Icons.route,
        'title': 'Viajes',
        'value': statistics.totalTrips.toString(),
        'color': isDarkMode ? Colors.lightBlue : Colors.blue,
      },
      {
        'icon': Icons.map,
        'title': 'Distancia',
        'value': '${statistics.totalDistance.toStringAsFixed(1)} km',
        'color': isDarkMode ? Colors.lightGreen : Colors.green,
      },
      {
        'icon': Icons.timer,
        'title': 'Tiempo',
        'value': '${statistics.totalDrivingTime.toStringAsFixed(1)} h',
        'color': isDarkMode ? Colors.amber : Colors.orange,
      },
      {
        'icon': Icons.local_gas_station,
        'title': 'Combustible',
        'value': '${statistics.totalFuelConsumption.toStringAsFixed(1)} L',
        'color': isDarkMode ? Colors.purpleAccent : Colors.purple,
        'subtitle': 'Total',
      },
      {
        'icon': Icons.speed,
        'title': 'Velocidad',
        'value': '${statistics.averageSpeed.toStringAsFixed(1)} km/h',
        'color': isDarkMode ? Colors.tealAccent : Colors.teal,
        'subtitle': 'Media',
      },
      {
        'icon': Icons.opacity,
        'title': 'Consumo',
        'value': '${averageFuelConsumption.toStringAsFixed(1)} L/100km',
        'color': isDarkMode ? Colors.amberAccent : Colors.amber.shade700,
        'subtitle': 'Medio',
      },
      {
        'icon': Icons.eco,
        'title': 'CO₂',
        'value': '${(statistics.totalFuelConsumption * 2.471).toStringAsFixed(1)} kg',
        'color': isDarkMode ? Colors.green.shade300 : Colors.green.shade800,
        'subtitle': 'Emisiones',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Theme.of(context).colorScheme.surfaceVariant
                : (stat['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (stat['color'] as Color).withOpacity(isDarkMode ? 0.5 : 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      stat['icon'] as IconData,
                      color: stat['color'] as Color,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stat['title'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode 
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stat['value'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: stat['color'] as Color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (stat.containsKey('subtitle')) 
                  Text(
                    stat['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode 
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFuelMapSection() {
    // Usamos RepaintBoundary para aislar este widget y reducir reconstrucciones
    return RepaintBoundary(
      child: const FuelMapWidget(),
    );
  }
  
  Widget _buildFuelFavoritesSection() {
    // Contenedor separado para estaciones favoritas
    return RepaintBoundary(
      child: const FuelFavoritesWidget(),
    );
  }
  
  Widget _buildTripsMapSection(List<Trip> trips) {
    final isDarkMode = context.watch<ThemeBloc>().state;
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tus rutas recientes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visualización de tus últimos ${trips.length} viajes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.grey[700],
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
              height: 250,
              child: allPoints.isEmpty
                ? Center(
                    child: Text(
                      'No hay rutas registradas para mostrar',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: allPoints.isNotEmpty ? allPoints[0] : LatLng(40.416775, -3.703790),
                      initialZoom: 8,
                      minZoom: 4,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: isDarkMode 
                            ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
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
                              color: isDarkMode 
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                  : Theme.of(context).colorScheme.primary,
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
                                child: Icon(
                                  Icons.trip_origin,
                                  color: isDarkMode ? Colors.greenAccent : Colors.green,
                                  size: 18,
                                ),
                              ),
                            if (points.length > 1) 
                              Marker(
                                point: points.last,
                                child: Icon(
                                  Icons.location_on,
                                  color: isDarkMode ? Colors.redAccent : Colors.red,
                                  size: 18,
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
