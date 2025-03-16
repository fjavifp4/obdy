import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/maintenance_record.dart';

class MaintenanceTimeline extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    // Crear una lista combinada de eventos ordenados por fecha
    final allEvents = <TimelineEvent>[];
    
    // Añadir mantenimientos
    for (var record in maintenanceRecords) {
      allEvents.add(
        TimelineEvent(
          date: record.lastChangeDate,
          title: record.type,
          description: 'Mantenimiento a ${record.lastChangeKM} km',
          icon: Icons.build,
          isPast: true,
          type: EventType.maintenance,
        ),
      );
      
      // Si hay una fecha próxima, añadirla también
      if (record.nextChangeKM > record.lastChangeKM) {
        // Calcular fecha aproximada basada en el ritmo actual de km
        final daysPerKm = 90 / (record.recommendedIntervalKM / 4); // Estimación basada en 3 meses para 1/4 del intervalo
        final daysToAdd = ((record.nextChangeKM - record.lastChangeKM) * daysPerKm).round();
        final estimatedNextDate = record.lastChangeDate.add(Duration(days: daysToAdd));
        
        allEvents.add(
          TimelineEvent(
            date: estimatedNextDate,
            title: 'Próximo ${record.type}',
            description: 'Recomendado a ${record.nextChangeKM} km',
            icon: Icons.build_outlined,
            isPast: false,
            type: EventType.maintenance,
          ),
        );
      }
    }
    
    // Añadir eventos de ITV
    if (lastItvDate != null) {
      allEvents.add(
        TimelineEvent(
          date: lastItvDate!,
          title: 'ITV realizada',
          description: 'Inspección técnica del vehículo',
          icon: Icons.directions_car,
          isPast: true,
          type: EventType.itv,
        ),
      );
    }
    
    if (nextItvDate != null) {
      allEvents.add(
        TimelineEvent(
          date: nextItvDate!,
          title: 'Próxima ITV',
          description: 'Fecha programada para la revisión',
          icon: Icons.directions_car_outlined,
          isPast: false,
          type: EventType.itv,
        ),
      );
    }
    
    // Ordenar eventos por fecha
    allEvents.sort((a, b) => a.date.compareTo(b.date));
    
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
              colorScheme.surface,
              colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
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
              ],
            ),
            
            const Divider(height: 24),
            
            if (allEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No hay eventos de mantenimiento o ITV registrados',
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
                itemCount: allEvents.length,
                itemBuilder: (context, index) {
                  final event = allEvents[index];
                  final isFirst = index == 0;
                  final isLast = index == allEvents.length - 1;
                  
                  // Determinar color según tipo de evento
                  final Color eventColor = event.type == EventType.maintenance
                      ? Colors.blue
                      : Colors.green;
                  
                  return TimelineTile(
                    alignment: TimelineAlign.manual,
                    lineXY: 0.2,
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
                    startChild: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                      child: Text(
                        dateFormat.format(event.date),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: event.isPast
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
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
                                  if (!event.isPast)
                                    Text(
                                      _getRemainingDays(event.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
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
                  );
                },
              ),
              
              if (allEvents.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Desliza para ver todos los eventos',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
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
  
  TimelineEvent({
    required this.date,
    required this.title,
    required this.description,
    required this.icon,
    required this.isPast,
    required this.type,
  });
} 