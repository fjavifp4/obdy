import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../../config/core/utils/text_normalizer.dart';

class MaintenanceDialog extends StatefulWidget {
  final String vehicleId;
  final dynamic record;
  final Map<String, dynamic>? recommendedData;

  const MaintenanceDialog({
    super.key,
    required this.vehicleId,
    this.record,
    this.recommendedData,
  });

  @override
  _MaintenanceDialogState createState() => _MaintenanceDialogState();
}

class _MaintenanceDialogState extends State<MaintenanceDialog> {
  late final TextEditingController typeController;
  late final TextEditingController lastChangeKMController;
  late final TextEditingController recommendedIntervalKMController;
  late final TextEditingController notesController;
  late final TextEditingController kmSinceLastChangeController;
  late DateTime selectedDate;
  late int nextChangeKM;

  final List<Map<String, dynamic>> maintenancePresets = [
    {
      'type': 'Cambio de aceite',
      'icon': Icons.oil_barrel,
      'recommendedIntervalKM': 10000,
    },
    {
      'type': 'Cambio de filtro de aire',
      'icon': Icons.filter_alt,
      'recommendedIntervalKM': 15000,
    },
    {
      'type': 'Cambio de pastillas de freno',
      'icon': Icons.report_problem,
      'recommendedIntervalKM': 40000,
    },
    {
      'type': 'Rotación de neumáticos',
      'icon': Icons.tire_repair,
      'recommendedIntervalKM': 10000,
    },
    {
      'type': 'Revisión de batería',
      'icon': Icons.battery_charging_full,
      'recommendedIntervalKM': 20000,
    },
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.record != null) {
      typeController = TextEditingController(text: widget.record.type);
      lastChangeKMController = TextEditingController(text: widget.record.lastChangeKM.toString());
      recommendedIntervalKMController = TextEditingController(text: widget.record.recommendedIntervalKM.toString());
      notesController = TextEditingController(text: widget.record.notes ?? '');
      kmSinceLastChangeController = TextEditingController(text: widget.record.kmSinceLastChange.toString());
      selectedDate = widget.record.lastChangeDate;
      nextChangeKM = widget.record.nextChangeKM;
    } else if (widget.recommendedData != null) {
      typeController = TextEditingController();
      lastChangeKMController = TextEditingController(text: '0');
      recommendedIntervalKMController = TextEditingController(text: '10000');
      notesController = TextEditingController();
      kmSinceLastChangeController = TextEditingController(text: '0.0');
      selectedDate = DateTime.now();
      nextChangeKM = 0;
    } else {
      typeController = TextEditingController();
      lastChangeKMController = TextEditingController(text: '0');
      recommendedIntervalKMController = TextEditingController(text: '10000');
      notesController = TextEditingController();
      kmSinceLastChangeController = TextEditingController(text: '0.0');
      selectedDate = DateTime.now();
      nextChangeKM = 0;
    }
    
    // Calcular nextChangeKM inicial
    updateNextKM();

    if (widget.recommendedData != null) {
      // Usar el normalizador centralizado para tratar los datos recomendados
      String type = TextNormalizer.normalize(
        widget.recommendedData!['type'], 
        defaultValue: 'Mantenimiento',
        cleanRedundant: true
      );
      typeController.text = type;
      
      String intervalText = '10000'; // Valor por defecto
      var interval = widget.recommendedData!['recommended_interval_km'];
      if (interval != null && interval.toString() != 'null') {
        try {
          // Intenta convertir a entero para validar que es un número
          int.parse(interval.toString());
          intervalText = interval.toString();
        } catch (e) {
          // Si no es un número válido, usa el valor por defecto
          print('Error parsing interval: $e');
        }
      }
      recommendedIntervalKMController.text = intervalText;
      
      String notes = TextNormalizer.normalize(widget.recommendedData!['notes'], defaultValue: '');
      notesController.text = notes;
      
      // Recalcular nextChangeKM después de actualizar los valores
      updateNextKM();
    }
  }

  @override
  void dispose() {
    typeController.dispose();
    lastChangeKMController.dispose();
    recommendedIntervalKMController.dispose();
    notesController.dispose();
    kmSinceLastChangeController.dispose();
    super.dispose();
  }

  void updateNextKM() {
    final lastKM = int.tryParse(lastChangeKMController.text) ?? 0;
    final interval = int.tryParse(recommendedIntervalKMController.text) ?? 0;
    setState(() {
      nextChangeKM = lastKM + interval;
    });
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      typeController.text = preset['type'];
      recommendedIntervalKMController.text = preset['recommendedIntervalKM'].toString();
      updateNextKM();
    });
  }

  void _handleSubmit() {
    final lastChangeKM = int.tryParse(lastChangeKMController.text) ?? 0;
    final recommendedInterval = int.tryParse(recommendedIntervalKMController.text) ?? 0;
    final kmSinceLastChange = double.tryParse(kmSinceLastChangeController.text) ?? 0.0;
    
    if (typeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El tipo de mantenimiento es obligatorio')),
      );
      return;
    }

    try {
      if (widget.record == null) {
        context.read<VehicleBloc>().add(
          AddMaintenanceRecord(
            vehicleId: widget.vehicleId,
            record: {
              'type': typeController.text.trim(),
              'lastChangeKM': lastChangeKM,
              'nextChangeKM': lastChangeKM + recommendedInterval,
              'recommendedIntervalKM': recommendedInterval,
              'notes': notesController.text.trim(),
              'lastChangeDate': selectedDate,
              'kmSinceLastChange': kmSinceLastChange,
            },
          ),
        );
      } else {
        context.read<VehicleBloc>().add(
          UpdateMaintenanceRecord(
            vehicleId: widget.vehicleId,
            record: {
              'id': widget.record!.id,
              'type': typeController.text,
              'lastChangeKM': lastChangeKM,
              'nextChangeKM': lastChangeKM + recommendedInterval,
              'recommendedIntervalKM': recommendedInterval,
              'notes': notesController.text,
              'lastChangeDate': selectedDate,
              'kmSinceLastChange': kmSinceLastChange,
            },
          ),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el mantenimiento: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.record == null ? 'Nuevo mantenimiento' : 'Editar mantenimiento',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.record == null) ...[
                const Text(
                  'Mantenimientos comunes:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: maintenancePresets.length,
                    itemBuilder: (context, index) {
                      final preset = maintenancePresets[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => _applyPreset(preset),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(preset['icon'] as IconData),
                                const SizedBox(height: 4),
                                Text(
                                  preset['type'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 32),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // padding 16
                      const SizedBox(height: 16),
                      TextField(
                        controller: typeController,
                        decoration: InputDecoration(
                          labelText: 'Tipo de mantenimiento',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.build),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: lastChangeKMController,
                        decoration: InputDecoration(
                          labelText: 'Kilómetros actuales',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.speed),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => updateNextKM(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: kmSinceLastChangeController,
                        decoration: InputDecoration(
                          labelText: 'KM recorridos desde el último cambio',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.speed),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: recommendedIntervalKMController,
                        decoration: InputDecoration(
                          labelText: 'Intervalo recomendado (km)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.update),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => updateNextKM(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Próximo cambio a los:',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$nextChangeKM km',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Fecha del cambio'),
                        subtitle: Text(_formatDate(selectedDate)),
                        leading: const Icon(Icons.calendar_today),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'Notas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _handleSubmit,
                    child: Text(widget.record == null ? 'Añadir' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 