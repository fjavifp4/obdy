import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../blocs/blocs.dart';

// Enumeración para el período de filtrado
enum StatsPeriod { all, month, week, day }

class VehicleStatsSection extends StatefulWidget {
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
  State<VehicleStatsSection> createState() => _VehicleStatsSectionState();
}

class _VehicleStatsSectionState extends State<VehicleStatsSection> {
  // Estado para el período de filtrado
  StatsPeriod _selectedPeriod = StatsPeriod.all;
  static const String _prefKey = 'vehicle_stats_filter_period_';
  
  // Método para calcular el máximo valor para el eje Y
  double _calculateMaxY(List<FlSpot> data) {
    if (data.isEmpty) return 10.0; 
    
    // Obtener el valor máximo de las distancias
    double maxValue = data.map((spot) => spot.y).reduce((max, value) => value > max ? value : max);
    
    // Si el máximo es 0, devolver 0 (solo se mostrará el 0 en el eje Y)
    if (maxValue <= 0) return 0;
    
    // Redondear al siguiente múltiplo de 10 para tener un número "redondo"
    return ((maxValue / 10).ceil() * 10).toDouble();
  }
  
  // Método para calcular el intervalo entre los valores del eje Y
  double _calculateYAxisInterval(List<FlSpot> data) {
    double maxY = _calculateMaxY(data);
    
    // Si el máximo es 0, no necesitamos intervalos
    if (maxY <= 0) return 1;
    
    // Dividir el máximo en 4 partes (0, 1/4, 2/4, 3/4, 4/4)
    return maxY / 4;
  }
  
  @override
  void initState() {
    super.initState();
    _loadSelectedPeriod();
  }
  
  // Cargar el último período seleccionado
  Future<void> _loadSelectedPeriod() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? savedPeriod = prefs.getInt('${_prefKey}${widget.vehicleId}');
      
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
      await prefs.setInt('${_prefKey}${widget.vehicleId}', period.index);
    } catch (e) {
      debugPrint('Error al guardar el período de filtrado: $e');
    }
  }

  // Método para filtrar las estadísticas según el período seleccionado
  Map<String, dynamic> _getFilteredStats() {
    if (_selectedPeriod == StatsPeriod.all) {
      return {
        'totalTrips': widget.totalTrips,
        'totalDistance': widget.totalDistance,
        'totalMaintenanceRecords': widget.totalMaintenanceRecords,
        'averageTripLength': widget.averageTripLength,
        'currentKilometers': widget.currentKilometers,
        'distanceData': widget.distanceData,
      };
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
        return {
          'totalTrips': widget.totalTrips,
          'totalDistance': widget.totalDistance,
          'totalMaintenanceRecords': widget.totalMaintenanceRecords,
          'averageTripLength': widget.averageTripLength,
          'currentKilometers': widget.currentKilometers,
          'distanceData': widget.distanceData,
        };
    }
    
    // TODO: Implementar la lógica de filtrado real cuando tengamos acceso a los datos detallados
    // Por ahora, solo devolvemos los datos sin filtrar
    return {
      'totalTrips': widget.totalTrips,
      'totalDistance': widget.totalDistance,
      'totalMaintenanceRecords': widget.totalMaintenanceRecords,
      'averageTripLength': widget.averageTripLength,
      'currentKilometers': widget.currentKilometers,
      'distanceData': widget.distanceData,
    };
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
              child: const Text('Todo', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: StatsPeriod.month,
              child: const Text('Último mes', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: StatsPeriod.week,
              child: const Text('Última semana', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: StatsPeriod.day,
              child: const Text('Último día', style: TextStyle(fontSize: 12)),
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
                  if (widget.isLoading)
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
              
              // Fila con descripción y selector de período
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDescription(),
                  ),
                  const SizedBox(width: 16),
                  _buildPeriodFilter(),
                ],
              ),
              const SizedBox(height: 16),
              
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
                    value: widget.currentKilometers != null ? '${widget.currentKilometers} km' : 'No disponible',
                    icon: Icons.speed,
                    color: isDarkMode ? Colors.redAccent : Colors.red,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Distancia',
                    value: '${widget.totalDistance.toStringAsFixed(1)} km',
                    icon: Icons.directions_car,
                    color: isDarkMode ? Colors.lightGreen : Colors.green,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Viajes',
                    value: '${widget.totalTrips}',
                    icon: Icons.route,
                    color: isDarkMode ? Colors.lightBlue : Colors.blue,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Mantenimientos',
                    value: '${widget.totalMaintenanceRecords}',
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
                      value: widget.licensePlate,
                      icon: Icons.badge,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoCard(
                      context,
                      title: 'Año',
                      value: widget.year.toString(),
                      icon: Icons.date_range,
                    ),
                  ),
                ],
              ),
              
              if (widget.distanceData != null && widget.distanceData!.isNotEmpty) ...[
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
                  padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _calculateYAxisInterval(widget.distanceData!),
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
                              // Mostrar solo viajes pares en el eje X
                              if (value.toInt() % 2 == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('${value.toInt() + 1}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      )),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // Si el valor es 0, o si está dentro de nuestros intervalos, mostrarlo
                              double maxY = _calculateMaxY(widget.distanceData!);
                              double interval = _calculateYAxisInterval(widget.distanceData!);
                              
                              // Si el máximo es 0, solo mostrar el 0
                              if (maxY <= 0 && value == 0) {
                                return Text(
                                  '0 km',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              
                              // Comprobamos si el valor actual es uno de nuestros intervalos
                              for (int i = 0; i <= 4; i++) {
                                if ((i * interval).toStringAsFixed(1) == value.toStringAsFixed(1)) {
                                  return Text(
                                    '${value.toInt()} km',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                              }
                              
                              return const SizedBox();
                            },
                            reservedSize: 40,
                            interval: _calculateYAxisInterval(widget.distanceData!),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      minX: 0,
                      maxX: widget.distanceData!.length.toDouble() - 1,
                      minY: 0,
                      maxY: _calculateMaxY(widget.distanceData!),
                      lineBarsData: [
                        LineChartBarData(
                          spots: widget.distanceData!,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode 
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.grey[800],
                  ),
                  softWrap: true,
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