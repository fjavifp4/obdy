import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';

class VehicleStatsSection extends StatelessWidget {
  final String vehicleId;
  final int totalTrips;
  final double totalDistance;
  final int totalMaintenanceRecords;
  final double averageTripLength;
  final String licensePlate;
  final int year;
  final List<FlSpot>? distanceData;
  final bool isLoading;
  final int? currentKilometers;

  const VehicleStatsSection({
    super.key,
    required this.vehicleId,
    required this.totalTrips,
    required this.totalDistance,
    required this.totalMaintenanceRecords,
    required this.averageTripLength,
    required this.licensePlate,
    required this.year,
    required this.currentKilometers,
    this.distanceData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = context.watch<ThemeBloc>().state;
    
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
              isDarkMode ? Color(0xFF3A3A3D) : colorScheme.background,
              isDarkMode ? Color(0xFF333336) : colorScheme.background.withOpacity(0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de la sección
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Estadísticas del Vehículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Grid de estadísticas
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard(
                    context,
                    title: 'Kilometraje Actual',
                    value: currentKilometers != null ? '$currentKilometers km' : 'No disponible',
                    icon: Icons.speed,
                    color: isDarkMode ? Colors.redAccent : Colors.red,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Distancia',
                    value: '${totalDistance.toStringAsFixed(1)} km',
                    icon: Icons.directions_car,
                    color: isDarkMode ? Colors.lightGreen : Colors.green,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Viajes',
                    value: '$totalTrips',
                    icon: Icons.route,
                    color: isDarkMode ? Colors.lightBlue : Colors.blue,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Mantenimientos',
                    value: '$totalMaintenanceRecords',
                    icon: Icons.build,
                    color: isDarkMode ? Colors.amber : Colors.orange,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Información adicional
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      context,
                      title: 'Matrícula',
                      value: licensePlate,
                      icon: Icons.badge,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoCard(
                      context,
                      title: 'Año',
                      value: year.toString(),
                      icon: Icons.date_range,
                    ),
                  ),
                ],
              ),
              
              if (distanceData != null && distanceData!.isNotEmpty) ...[
                const SizedBox(height: 20),
                
                // Título del gráfico
                Row(
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Distancia por viaje (últimos 10)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Gráfico de distancia
                Container(
                  height: 150,
                  padding: const EdgeInsets.only(top: 16, right: 16),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 10,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // Mostrar solo algunos valores en el eje X
                              if (value % 3 == 0) {
                                return Text('${value.toInt() + 1}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ));
                              }
                              return const SizedBox();
                            },
                            reservedSize: 22,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ));
                            },
                            reservedSize: 40,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      minX: 0,
                      maxX: distanceData!.length.toDouble() - 1,
                      minY: 0,
                      maxY: distanceData!
                              .map((spot) => spot.y)
                              .reduce((max, value) => value > max ? value : max) *
                          1.2,
                      lineBarsData: [
                        LineChartBarData(
                          spots: distanceData!,
                          isCurved: true,
                          color: colorScheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: colorScheme.primary,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: colorScheme.primary.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Theme.of(context).colorScheme.surfaceVariant
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.5 : 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
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
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final color = title == 'Matrícula' 
        ? (isDarkMode ? Colors.purpleAccent : Colors.purple)
        : (isDarkMode ? Colors.tealAccent : Colors.teal);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Theme.of(context).colorScheme.surfaceVariant
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.5 : 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode 
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.grey[800],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 