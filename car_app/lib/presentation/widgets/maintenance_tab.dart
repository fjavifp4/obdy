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
          if (state is VehicleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is MaintenanceAnalysisInProgress) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Círculo externo animado con rotación continua
                        const _RotatingProgressCircle(
                          size: 120,
                          strokeWidth: 4,
                        ),
                        
                        // Icono pulsante de IA
                        const _PulsatingIcon(
                          icon: Icons.psychology,
                          size: 48,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Analizando manual',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Extrayendo mantenimientos recomendados...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
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
                        child: Icon(
                          Icons.psychology,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'add_maintenance',
                        onPressed: () => _showMaintenanceDialog(
                          context,
                          vehicleId: vehicleId,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
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
                        // Intentar diferentes campos que podrían contener el tipo de mantenimiento
                        recommendation['tipo de mantenimiento'] ?? 
                        recommendation['type'] ?? 
                        recommendation['maintenance_type'] ?? 
                        recommendation['nombre'] ?? 
                        recommendation['title'],
                        defaultValue: 'Mantenimiento',
                        cleanRedundant: true
                      );
                      final String interval = TextNormalizer.normalize(
                        recommendation['recommended_interval_km'] ?? 
                        recommendation['interval_km'] ?? 
                        recommendation['intervalo'] ?? 
                        recommendation['recommended_interval'],
                        defaultValue: 'No especificado'
                      );
                      final String notes = TextNormalizer.normalize(
                        recommendation['notes'] ?? 
                        recommendation['notas'] ?? 
                        recommendation['description'] ?? 
                        recommendation['descripcion'],
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
                
                // Filtrar los mantenimientos seleccionados
                final List<Map<String, dynamic>> selectedMaintenance = [];
                for (var i = 0; i < recommendations.length; i++) {
                  if (selectedRecommendations[i]) {
                    // Normalizar los datos recomendados usando la utilidad centralizada
                    final rawData = recommendations[i];
                    final normalizedData = <String, dynamic>{
                      'type': TextNormalizer.normalize(
                        rawData['tipo de mantenimiento'] ?? 
                        rawData['type'] ?? 
                        rawData['maintenance_type'] ?? 
                        rawData['nombre'] ?? 
                        rawData['title'],
                        defaultValue: 'Mantenimiento'
                      ),
                      'recommended_interval_km': TextNormalizer.normalize(
                        rawData['recommended_interval_km'] ?? 
                        rawData['interval_km'] ?? 
                        rawData['intervalo'] ?? 
                        rawData['recommended_interval'],
                        defaultValue: '10000'
                      ),
                      'notes': TextNormalizer.normalize(
                        rawData['notes'] ?? 
                        rawData['notas'] ?? 
                        rawData['description'] ?? 
                        rawData['descripcion'],
                        defaultValue: ''
                      ),
                    };
                    selectedMaintenance.add(normalizedData);
                  }
                }
                
                // Mostrar los diálogos de forma secuencial
                if (selectedMaintenance.isNotEmpty) {
                  _showSequentialMaintenanceDialogs(context, vehicleId, selectedMaintenance);
                }
              },
              child: const Text('Añadir seleccionados'),
            ),
          ],
        ),
      ),
    );
  }

  // Método para iniciar la secuencia de diálogos de mantenimiento
  void _showSequentialMaintenanceDialogs(
    BuildContext context,
    String vehicleId,
    List<Map<String, dynamic>> maintenanceList,
  ) {
    // Crear un widget temporal que utilizará BlocListener para manejar los estados
    // y mostrar los diálogos de forma secuencial
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) => _SequentialDialogHandler(
          vehicleId: vehicleId,
          maintenanceList: maintenanceList,
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
    final theme = Theme.of(context);
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
        theme.colorScheme.primary.withOpacity(0.3),
        theme.colorScheme.primary.withOpacity(0.5),
      ];
    } else if (progressPercentage < 0.75) {
      // Entre 50% y 75%: Verde y amarillo
      gradientColors = [
        theme.colorScheme.primary.withOpacity(0.5),
        theme.colorScheme.primary,
        theme.colorScheme.tertiary,
      ];
    } else {
      // Más del 75%: Verde, amarillo y rojo
      gradientColors = [
        theme.colorScheme.primary.withOpacity(0.5),
        theme.colorScheme.primary,
        theme.colorScheme.tertiary,
        theme.colorScheme.error.withOpacity(0.7),
        theme.colorScheme.error,
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
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
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
                  color: theme.colorScheme.primary,
                  size: 28
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    normalizedType,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  color: theme.colorScheme.primary.withOpacity(0.8),
                  onPressed: () => _showMaintenanceDialog(
                    context,
                    vehicleId: vehicleId,
                    record: record,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar',
                  color: theme.colorScheme.error.withOpacity(0.8),
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
                        color: theme.colorScheme.surfaceVariant,
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
                  ).merge(Theme.of(context).textTheme.bodyMedium),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Último cambio: ${_formatDate(record.lastChangeDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
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
                      ),/*
                      _buildMaintenanceInfo(
                        context,
                        'Intervalo',
                        '${record.recommendedIntervalKM} km',
                        Icons.update,
                      ),*/
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
                              ).merge(Theme.of(context).textTheme.labelMedium),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          normalizedNotes,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

// Widget para manejar la secuencia de diálogos de mantenimiento
class _SequentialDialogHandler extends StatefulWidget {
  final String vehicleId;
  final List<Map<String, dynamic>> maintenanceList;

  const _SequentialDialogHandler({
    required this.vehicleId,
    required this.maintenanceList,
  });

  @override
  _SequentialDialogHandlerState createState() => _SequentialDialogHandlerState();
}

class _SequentialDialogHandlerState extends State<_SequentialDialogHandler> {
  int _currentIndex = 0;
  bool _processingDialog = false;
  int? _currentKilometers;

  @override
  void initState() {
    super.initState();
    
    // Obtener el kilometraje actual del vehículo al inicio
    final vehicleState = context.read<VehicleBloc>().state;
    if (vehicleState is VehicleLoaded) {
      final vehicle = vehicleState.vehicles.firstWhere(
        (v) => v.id == widget.vehicleId,
        orElse: () => throw Exception('Vehículo no encontrado'),
      );
      _currentKilometers = vehicle.currentKilometers;
    }
    
    // Iniciar la secuencia de diálogos después de que el widget se haya construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNextDialog();
    });
  }

  void _showNextDialog() {
    if (_currentIndex >= widget.maintenanceList.length || _processingDialog) {
      // Hemos terminado o ya hay un diálogo procesándose
      if (_currentIndex >= widget.maintenanceList.length) {
        Navigator.of(context).pop(); // Cerrar este widget temporal
      }
      return;
    }

    setState(() {
      _processingDialog = true;
    });

    // Añadir el kilometraje actual a los datos recomendados para garantizar consistencia
    final recomendadoConKilometraje = Map<String, dynamic>.from(widget.maintenanceList[_currentIndex]);
    
    // Si tenemos kilometraje actual, lo añadimos a los datos para que el diálogo lo utilice
    if (_currentKilometers != null) {
      recomendadoConKilometraje['current_kilometers'] = _currentKilometers.toString();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => MaintenanceDialog(
        vehicleId: widget.vehicleId,
        recommendedData: recomendadoConKilometraje,
      ),
    ).then((_) {
      // Esperar un momento antes de mostrar el siguiente diálogo para
      // dar tiempo a que la operación de añadir se complete
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _currentIndex++;
            _processingDialog = false;
            _showNextDialog();
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Este widget es invisible, solo escucha cambios en el BlocState
    return BlocListener<VehicleBloc, VehicleState>(
      listener: (context, state) {
        // Si ocurre un error, detenemos la secuencia
        if (state is VehicleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
          Navigator.of(context).pop(); // Cerrar este widget temporal
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}

// Painter personalizado para dibujar un círculo de progreso
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    
    // Dibuja el círculo de fondo completo
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Dibuja el arco de progreso
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, // Comienza desde arriba (270 grados o -π/2)
      progress * 2 * 3.14, // Ángulo en radianes
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// Widget para mostrar un icono pulsante
class _PulsatingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const _PulsatingIcon({
    required this.icon,
    required this.size,
    this.color,
  });

  @override
  _PulsatingIconState createState() => _PulsatingIconState();
}

class _PulsatingIconState extends State<_PulsatingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: color,
          ),
        );
      },
    );
  }
}

// Widget para mostrar un círculo de progreso con rotación infinita
class _RotatingProgressCircle extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const _RotatingProgressCircle({
    required this.size,
    required this.strokeWidth,
    this.color,
  });

  @override
  _RotatingProgressCircleState createState() => _RotatingProgressCircleState();
}

class _RotatingProgressCircleState extends State<_RotatingProgressCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CircleProgressPainter(
            progress: _controller.value,
            color: color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}