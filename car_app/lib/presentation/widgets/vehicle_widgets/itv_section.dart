import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';

class ITVSection extends StatefulWidget {
  final String vehicleId;
  final DateTime? lastItvDate;
  final DateTime? nextItvDate;
  final bool hasLastItv;
  final bool hasNextItv;

  const ITVSection({
    super.key,
    required this.vehicleId,
    this.lastItvDate,
    this.nextItvDate,
    required this.hasLastItv,
    required this.hasNextItv,
  });

  @override
  State<ITVSection> createState() => _ITVSectionState();
}

class _ITVSectionState extends State<ITVSection> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_ES');
    final colorScheme = Theme.of(context).colorScheme;
    final daysUntilNextItv = widget.hasNextItv 
        ? widget.nextItvDate!.difference(DateTime.now()).inDays
        : null;
    
    // Determinar el color de status (verde, naranja o rojo)
    final statusColor = widget.hasNextItv 
        ? (daysUntilNextItv! > 30 
            ? Colors.green 
            : (daysUntilNextItv > 7 ? Colors.orange : Colors.red))
        : Colors.grey;
        
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con título e icono de información
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_filled,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Inspección Técnica (ITV)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        onPressed: () => _showHelpDialog(context),
                        tooltip: 'Información sobre la ITV',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          onPressed: () => _showItvUpdateDialog(context),
                          tooltip: 'Actualizar ITV',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          iconSize: 20,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(20, 20),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Información del estado actual 
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: statusColor.withOpacity(0.1),
                  border: Border.all(
                    color: statusColor,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Icon(
                          widget.hasNextItv 
                              ? (daysUntilNextItv! > 30 
                                  ? Icons.check_circle
                                  : (daysUntilNextItv > 7 
                                      ? Icons.access_time 
                                      : Icons.warning))
                              : Icons.help_outline,
                          color: statusColor,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.hasNextItv 
                                ? (daysUntilNextItv! > 30 
                                    ? 'ITV en regla'
                                    : (daysUntilNextItv > 7 
                                        ? 'ITV próximamente'
                                        : 'ITV urgente'))
                                : 'Sin información de ITV',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          if (widget.hasNextItv)
                            Text(
                              daysUntilNextItv! > 0
                                  ? 'Próxima revisión en $daysUntilNextItv días'
                                  : daysUntilNextItv == 0
                                      ? 'La ITV es hoy'
                                      : 'ITV retrasada ${-daysUntilNextItv} días',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Fechas de ITV
              if (widget.hasLastItv)
                _buildDateInfoRow(
                  context,
                  'Última ITV', 
                  dateFormat.format(widget.lastItvDate!),
                  Icons.event_available,
                ),
                
              if (widget.hasNextItv)
                _buildDateInfoRow(
                  context,
                  'Próxima ITV', 
                  dateFormat.format(widget.nextItvDate!),
                  Icons.event,
                ),
              
              // Si no hay fechas, mostrar mensaje
              if (!widget.hasLastItv && !widget.hasNextItv)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No hay fechas de ITV registradas. Pulsa el botón editar para añadir información.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                ),
                
              const SizedBox(height: 16),
              
              // Botón para marcar como completada
              if (widget.hasNextItv)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _completeItv(context),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Marcar ITV como completada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDateInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Acerca de la ITV'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'La Inspección Técnica de Vehículos (ITV) es obligatoria para circular legalmente.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('En esta sección puedes:'),
              SizedBox(height: 8),
              Text('• Registrar la fecha de la última ITV realizada'),
              Text('• Programar la fecha de la próxima ITV'),
              Text('• Marcar como completada una ITV cuando la hayas pasado'),
              SizedBox(height: 12),
              Text(
                'Cuando registras una ITV pasada, el sistema calculará automáticamente la fecha de la próxima revisión según la normativa vigente.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }
  
  void _showItvUpdateDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isTimeSelected = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isFutureDate = selectedDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Fecha de ITV'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona la fecha de la ITV:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))
                      ? 'Se registrará como próxima ITV'
                      : 'Se registrará como ITV pasada',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000, 1),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        locale: const Locale('es', 'ES'),
                        confirmText: 'Aceptar',
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                          // Resetear selección de hora si cambia la fecha
                          isTimeSelected = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  
                  // Selector de hora solo para fechas futuras
                  if (selectedDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Hora de la cita (opcional):',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: Icon(
                        Icons.access_time,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(
                        isTimeSelected
                          ? selectedTime.format(context)
                          : 'Seleccionar hora',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedTime = picked;
                            isTimeSelected = true;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Guardar'),
                  onPressed: () {
                    DateTime finalDateTime = selectedDate;
                    
                    // Si es fecha futura y se seleccionó hora, combinar fecha y hora
                    if (isFutureDate && isTimeSelected) {
                      finalDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                    }
                    
                    Navigator.of(context).pop();
                    _updateItv(context, finalDateTime);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateItv(BuildContext context, DateTime date) {
    context.read<VehicleBloc>().add(UpdateItv(widget.vehicleId, date));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fecha de ITV actualizada')),
    );
  }

  void _completeItv(BuildContext context) {
    context.read<VehicleBloc>().add(CompleteItv(widget.vehicleId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ITV marcada como completada')),
    );
  }
} 
