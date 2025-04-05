import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/maintenance_record.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';

class MaintenanceTimeline extends StatefulWidget {
  final List<MaintenanceRecord> maintenanceRecords;
  final DateTime? lastItvDate;
  final DateTime? nextItvDate;

  const MaintenanceTimeline({
    super.key,
    required this.maintenanceRecords,
    this.lastItvDate,
    this.nextItvDate,
  });

  @override
  State<MaintenanceTimeline> createState() => _MaintenanceTimelineState();
}

class _MaintenanceTimelineState extends State<MaintenanceTimeline> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<TimelineEvent> _filteredEvents = [];
  late List<TimelineEvent> _allEvents;
  bool _showFilterOptions = false;

  @override
  void initState() {
    super.initState();
    _generateAllEvents();
  }

  @override
  void didUpdateWidget(MaintenanceTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maintenanceRecords != widget.maintenanceRecords ||
        oldWidget.lastItvDate != widget.lastItvDate ||
        oldWidget.nextItvDate != widget.nextItvDate) {
      _generateAllEvents();
    }
  }

  void _generateAllEvents() {
    // Crear una lista combinada de eventos ordenados por fecha
    _allEvents = <TimelineEvent>[];
    
    // Añadir mantenimientos (solo fechas pasadas)
    for (var record in widget.maintenanceRecords) {
      _allEvents.add(
        TimelineEvent(
          date: record.lastChangeDate,
          title: record.type,
          description: 'Realizado a los ${record.lastChangeKM} km',
          icon: Icons.build,
          isPast: true,
          type: EventType.maintenance,
        ),
      );
    }
    
    // Añadir ITV (tanto pasada como futura)
    if (widget.lastItvDate != null) {
      _allEvents.add(
        TimelineEvent(
          date: widget.lastItvDate!,
          title: 'ITV',
          description: 'Última inspección realizada',
          icon: Icons.directions_car,
          isPast: true,
          type: EventType.itv,
        ),
      );
    }
    
    if (widget.nextItvDate != null) {
      _allEvents.add(
        TimelineEvent(
          date: widget.nextItvDate!,
          title: 'Próxima ITV',
          description: 'Próxima inspección programada',
          icon: Icons.directions_car_outlined,
          isPast: false,
          type: EventType.itv,
          isFuture: true,
        ),
      );
    }
    
    // Ordenar eventos por fecha
    _allEvents.sort((a, b) => a.date.compareTo(b.date));
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      if (_startDate == null && _endDate == null) {
        _filteredEvents = List.from(_allEvents);
      } else {
        _filteredEvents = _allEvents.where((event) {
          bool matchesStart = _startDate == null || 
            !event.date.isBefore(_startDate!);
          
          bool matchesEnd = _endDate == null || 
            !event.date.isAfter(_endDate!.add(const Duration(days: 1)));
          
          return matchesStart && matchesEnd;
        }).toList();
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_ES');
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
              isDarkMode ? Color(0xFF3A3A3D) : colorScheme.surface,
              isDarkMode ? Color(0xFF333336) : colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con botón de filtro
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Línea de Tiempo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Indicador de filtro activo
                if (_startDate != null || _endDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Filtro activo',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showFilterOptions = !_showFilterOptions;
                    });
                  },
                  tooltip: 'Filtrar por fecha',
                ),
              ],
            ),
            
            // Panel de filtros
            if (_showFilterOptions)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar por fecha:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filtros de fecha
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                locale: const Locale('es', 'ES'),
                                confirmText: 'Aceptar',
                              );
                              if (date != null) {
                                setState(() {
                                  _startDate = date;
                                  _applyFilters();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _startDate != null 
                                          ? dateFormat.format(_startDate!) 
                                          : 'Fecha inicial',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _startDate != null 
                                            ? colorScheme.onSurface 
                                            : colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                locale: const Locale('es', 'ES'),
                                confirmText: 'Aceptar',
                              );
                              if (date != null) {
                                setState(() {
                                  _endDate = date;
                                  _applyFilters();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _endDate != null 
                                          ? dateFormat.format(_endDate!) 
                                          : 'Fecha final',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _endDate != null 
                                            ? colorScheme.onSurface 
                                            : colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _applyFilters,
                          icon: const Icon(Icons.filter_alt),
                          label: const Text('Aplicar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            const Divider(height: 24),
            
            if (_filteredEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No hay eventos de mantenimiento o ITV en el período seleccionado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredEvents.length,
                itemBuilder: (context, index) {
                  final event = _filteredEvents[index];
                  final isFirst = index == 0;
                  final isLast = index == _filteredEvents.length - 1;
                  
                  // Determinar color según tipo de evento
                  final Color eventColor = event.type == EventType.maintenance
                      ? Colors.blue
                      : Colors.green;
                  
                  return TimelineTile(
                    alignment: TimelineAlign.manual,
                    lineXY: 0.1,
                    isFirst: isFirst,
                    isLast: isLast,
                    indicatorStyle: IndicatorStyle(
                      width: 30,
                      height: 30,
                      indicator: Container(
                        decoration: BoxDecoration(
                          color: event.isPast ? eventColor : eventColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 2,
                            color: eventColor,
                          ),
                        ),
                        child: Icon(
                          event.icon,
                          size: 16,
                          color: event.isPast ? Colors.white : eventColor,
                        ),
                      ),
                    ),
                    beforeLineStyle: LineStyle(
                      color: colorScheme.primary.withOpacity(0.3),
                      thickness: 2,
                    ),
                    afterLineStyle: LineStyle(
                      color: colorScheme.primary.withOpacity(0.3),
                      thickness: 2,
                    ),
                    endChild: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 2,
                        color: event.isPast
                            ? eventColor.withOpacity(0.1)
                            : colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: event.isPast
                                ? eventColor.withOpacity(0.4)
                                : eventColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: event.isPast
                                          ? eventColor.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      event.isPast ? 'Completado' : 'Pendiente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: event.isPast
                                            ? eventColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    dateFormat.format(event.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  if (!event.isPast) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _getRemainingDays(event.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.description,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    startChild: const SizedBox.shrink(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  String _getRemainingDays(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference < 0) {
      return 'Atrasado ${-difference} días';
    } else if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Mañana';
    } else {
      return 'En $difference días';
    }
  }
}

enum EventType {
  maintenance,
  itv,
}

class TimelineEvent {
  final DateTime date;
  final String title;
  final String description;
  final IconData icon;
  final bool isPast;
  final EventType type;
  final bool isFuture;
  
  TimelineEvent({
    required this.date,
    required this.title,
    required this.description,
    required this.icon,
    required this.isPast,
    required this.type,
    this.isFuture = false,
  });
} 