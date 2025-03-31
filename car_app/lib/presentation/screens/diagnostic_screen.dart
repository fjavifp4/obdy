// lib/presentation/screens/diagnostic_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/trip.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../widgets/obd_connection_dialog.dart';
import '../blocs/obd/obd_event.dart';
//import '../widgets/diagnostic_card.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  _DiagnosticScreenState createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with AutomaticKeepAliveClientMixin {
  bool _isInitialized = false;
  late OBDBloc _obdBloc;
  late TripBloc _tripBloc;
  String? _selectedVehicleId;
  static const String _prefKey = 'selected_diagnostic_vehicle_id';
  bool _wasInSimulationMode = false; // Para rastrear cambios en el modo
  StreamSubscription<TripState>? _tripSubscription;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print("[DiagnosticScreen] initState - Inicializando pantalla de diagnóstico");
    
    // Inicializar referencias a los blocs
    _obdBloc = BlocProvider.of<OBDBloc>(context);
    _tripBloc = BlocProvider.of<TripBloc>(context);
    _wasInSimulationMode = _obdBloc.state.isSimulationMode;
    
    // Cargar los vehículos al iniciar
    context.read<VehicleBloc>().add(LoadVehicles());
    
    // Cargar el vehículo seleccionado de preferencias
    _loadSelectedVehicle();
    
    // Inicializar el OBD solo si no está ya conectado
    if (_obdBloc.state.status != OBDStatus.connected) {
      _obdBloc.add(InitializeOBDEvent());
    } else {
      print("[DiagnosticScreen] OBD ya conectado, iniciando monitoreo de parámetros");
      _startMonitoringParameters();
    }
    
    // Suscribirse a cambios en el stream de viajes para construir el widget adecuado
    _tripSubscription = _tripBloc.stream.listen((state) {
      if (mounted) {
        setState(() {
          // Solo actualizar el estado si la pantalla está montada
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("[DiagnosticScreen] didChangeDependencies");
  }
  
  @override
  void didUpdateWidget(covariant DiagnosticScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("[DiagnosticScreen] didUpdateWidget");
  }
  
  @override
  void activate() {
    super.activate();
    print("[DiagnosticScreen] activate - La pantalla vuelve a ser visible");
    
    // Si el OBD está conectado pero no estamos monitoreando parámetros, reiniciar el monitoreo
    if (_obdBloc.state.status == OBDStatus.connected && 
        (_obdBloc.state.parametersData.isEmpty || 
         !_obdBloc.state.parametersData.containsKey('01 0C'))) {
      print("[DiagnosticScreen] Reiniciando monitoreo de parámetros tras volver a la pantalla");
      _startMonitoringParameters();
    }
  }

  void _startMonitoringParameters() {
    print("[DiagnosticScreen] Iniciando monitoreo completo de parámetros");
    _obdBloc.add(const StartParameterMonitoring('01 0C')); // RPM
    _obdBloc.add(const StartParameterMonitoring('01 0D')); // Velocidad
    _obdBloc.add(const StartParameterMonitoring('01 05')); // Temperatura
    _obdBloc.add(const StartParameterMonitoring('01 42')); // Voltaje
    
    // Solicitar códigos de diagnóstico (DTC) automáticamente al iniciar
    _obdBloc.add(GetDTCCodes());
  }
  
  void _stopParameterMonitoring() {
    // Detener el monitoreo de todos los parámetros
    _obdBloc.add(const StopParameterMonitoring('01 0C')); // RPM
    _obdBloc.add(const StopParameterMonitoring('01 0D')); // Velocidad
    _obdBloc.add(const StopParameterMonitoring('01 05')); // Temperatura
    _obdBloc.add(const StopParameterMonitoring('01 42')); // Voltaje
  }
  
  @override
  void dispose() {
    print("[DiagnosticScreen] dispose - Desconectando OBD");
    
    // Detener todos los monitoreos para liberar recursos
    _stopParameterMonitoring();
    
    // Cancelar la suscripción al stream de viajes
    _tripSubscription?.cancel();
    
    // Si estamos en modo simulación, NO desconectar para mantener la simulación activa
    // Solo usamos el evento DisconnectFromOBDPreserveSimulation para mantener la conexión
    if (_obdBloc.state.isSimulationMode) {
      print("[DiagnosticScreen] Preservando simulación OBD al salir de la pantalla");
      _obdBloc.add(const DisconnectFromOBDPreserveSimulation());
    } else {
      // En modo real, desconectar normalmente
      _obdBloc.add(const DisconnectFromOBD());
    }

    super.dispose();
  }
  
  @override
  void deactivate() {
    // Este método se llama cuando el widget se desmonta temporalmente
    print("[DiagnosticScreen] deactivate - Manteniendo conexión OBD pero reduciendo monitoreo");
    
    // Mantener solo el monitoreo de velocidad para cálculo de kilómetros
    // y detener el resto de parámetros para ahorrar recursos
    _stopNonEssentialMonitoring();
    
    super.deactivate();
  }

  void _stopNonEssentialMonitoring() {
    // Detener monitoreo de parámetros no esenciales para el cálculo de kilómetros
    _obdBloc.add(const StopParameterMonitoring('01 0C')); // RPM
    _obdBloc.add(const StopParameterMonitoring('01 05')); // Temperatura
    _obdBloc.add(const StopParameterMonitoring('01 42')); // Voltaje
    
    // Mantenemos 01 0D (Velocidad) activo para cálculo de kilómetros
    print("[DiagnosticScreen] Manteniendo monitoreo de velocidad para cálculo de kilómetros");
  }
  
  Future<void> _loadSelectedVehicle() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? vehicleId = prefs.getString(_prefKey);
      if (vehicleId != null) {
        setState(() {
          _selectedVehicleId = vehicleId;
        });
      }
    } catch (e) {
      print("[DiagnosticScreen] Error al cargar vehículo seleccionado: $e");
    }
  }
  
  Future<void> _saveSelectedVehicle(String vehicleId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, vehicleId);
    } catch (e) {
      print("[DiagnosticScreen] Error al guardar vehículo seleccionado: $e");
    }
  }
  
  void _initializeOBD() {
    print("[DiagnosticScreen] Iniciando inicialización OBD");
    
    // Si ya está inicializado, no hacer nada
    if (_isInitialized) {
      print("[DiagnosticScreen] OBD ya inicializado");
      return;
    }

    // Si estamos en modo simulación, conectar automáticamente
    if (_obdBloc.state.isSimulationMode) {
      print("[DiagnosticScreen] Modo simulación detectado, conectando automáticamente");
      _obdBloc.add(InitializeOBDEvent());
      _obdBloc.add(ConnectToOBD());
    } else {
      // En modo real, solo inicializar y esperar conexión manual
      print("[DiagnosticScreen] Modo real detectado, esperando conexión manual");
      _obdBloc.add(InitializeOBDEvent());
    }
    
    _isInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return BlocProvider.value(
      value: _obdBloc,
      child: BlocListener<OBDBloc, OBDState>(
        listenWhen: (previous, current) => 
          previous.status != current.status || 
          previous.isSimulationMode != current.isSimulationMode,
        listener: (context, state) {
          print("[DiagnosticScreen] Estado OBD cambiado: ${state.status}, SimMode: ${state.isSimulationMode}");
          
          // Detectar cambio de simulación a real o viceversa
          bool simulationToReal = _wasInSimulationMode && !state.isSimulationMode;
          bool realToSimulation = !_wasInSimulationMode && state.isSimulationMode;
          _wasInSimulationMode = state.isSimulationMode;
          
          // Tres casos principales:
          // 1. Si cambiamos DE real A simulación, debemos conectar automáticamente
          if (realToSimulation && state.status == OBDStatus.initialized) {
            print("[DiagnosticScreen] Cambiando a modo simulación, conectando automáticamente");
            context.read<OBDBloc>().add(ConnectToOBD());
          } 
          // 2. Si cambiamos DE simulación A real, debemos desconectar para un reinicio limpio
          else if (simulationToReal && state.status != OBDStatus.disconnected) {
            print("[DiagnosticScreen] Cambiando a modo real, desconectando para reiniciar");
            context.read<OBDBloc>().add(DisconnectFromOBD());
          }
          // 3. Si ya estamos conectados, iniciamos monitoreo de parámetros
          else if (state.status == OBDStatus.connected) {
            // Si estamos en modo simulación y ya conectados, primero verificar si hay un viaje activo
            if (state.isSimulationMode && _selectedVehicleId != null) {
              // Primero verificar si ya hay un viaje activo
              print("[DiagnosticScreen] Modo simulación conectado, verificando viaje activo...");
              context.read<TripBloc>().add(GetCurrentTripEvent());
            }
            
            // Iniciar monitoreo de parámetros importantes
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              _startMonitoringParameters();
            });
          }
        },
        child: BlocConsumer<OBDBloc, OBDState>(
          listenWhen: (previous, current) => 
            previous.parametersData != current.parametersData,
          listener: (context, state) {
            // Añadir logs cuando los datos cambien
            print("[DiagnosticScreen] Datos actualizados: RPM=${_getRpmValue(state)}");
          },
          builder: (context, state) {
            if (state.status == OBDStatus.initial) {
              return Center(child: Text('Inicializando diagnóstico OBD...'));
            } else if (state.status == OBDStatus.connecting) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Conectando con interfaz OBD...'),
                ],
              ));
            } else if (state.status == OBDStatus.error) {
              return Center(child: Text('Error: ${state.error}'));
            }
            
            // Si no estamos en modo simulación y no estamos conectados
            if (!state.isSimulationMode && state.status != OBDStatus.connected) {
              return SafeArea(
                child: Column(
                  children: [
                    _buildStatusHeader(state),
                    _buildConnectionPrompt(context),
                  ],
                ),
              );
            }
            
            // Mostrar contenido principal scrollable
            return SafeArea(
              child: Column(
                children: [
                  // Header fijo que no se desplaza
                  _buildStatusHeader(state),
                  
                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selector de vehículos dentro del área scrollable
                          _buildCompactVehicleSelector(isDarkMode),
                          
                          // Gauges con tamaño fijo para visibilidad óptima
                          SizedBox(
                            height: MediaQuery.of(context).size.width * 1.05, // Asegura que se vean los 4 gauges
                            child: _buildGaugesGrid(state),
                          ),
                          
                          // Información del viaje activo
                          _buildActiveTrip(state),
                          
                          // Sección de DTC
                          _buildDtcSection(state),
                          
                          // Padding inferior para asegurar que se pueda hacer scroll completo
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  // Selector de vehículos más compacto y con botón elegante
  Widget _buildCompactVehicleSelector(bool isDarkMode) {
    return BlocBuilder<VehicleBloc, VehicleState>(
      builder: (context, state) {
        if (state is VehicleLoading) {
          return Container(
            height: 60,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        } else if (state is VehicleLoaded && state.vehicles.isNotEmpty) {
          // Si no hay vehículo seleccionado pero hay vehículos disponibles, 
          // seleccionar el primero automáticamente
          if (_selectedVehicleId == null && state.vehicles.isNotEmpty) {
            _selectedVehicleId = state.vehicles.first.id;
          }
          
          // Obtener el vehículo seleccionado actualmente
          final selectedVehicle = state.vehicles.firstWhere(
            (v) => v.id == _selectedVehicleId,
            orElse: () => state.vehicles.first,
          );
          
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.blueGrey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getVehicleColor(selectedVehicle, isDarkMode),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getVehicleIcon(selectedVehicle),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${selectedVehicle.brand} ${selectedVehicle.model}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${selectedVehicle.year} • ${selectedVehicle.licensePlate}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showVehicleSelectionModal(context, state.vehicles, isDarkMode);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Cambiar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (state is VehicleError) {
          return Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al cargar vehículos',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.red.shade700, size: 16),
                  onPressed: () {
                    context.read<VehicleBloc>().add(LoadVehicles());
                  },
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          );
        } else {
          // Si no hay vehículos
          return Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.blueGrey.shade700 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay vehículos disponibles',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: Icon(Icons.add, size: 14),
                  label: Text('Añadir', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Navigator.pushNamed(context, '/vehicle/add');
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size(10, 10),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _showVehicleSelectionModal(BuildContext context, List<Vehicle> vehicles, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Selecciona un vehículo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Theme.of(context).colorScheme.onSurface : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                itemCount: vehicles.length,
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  final isSelected = vehicle.id == _selectedVehicleId;
                  
                  return ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getVehicleColor(vehicle, isDarkMode),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getVehicleIcon(vehicle),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${vehicle.brand} ${vehicle.model}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Theme.of(context).colorScheme.onSurface : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '${vehicle.year} • ${vehicle.licensePlate}',
                      style: TextStyle(
                        color: isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.black54,
                      ),
                    ),
                    trailing: isSelected 
                      ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                      : null,
                    selected: isSelected,
                    onTap: () {
                      if (vehicle.id != _selectedVehicleId) {
                        setState(() {
                          _selectedVehicleId = vehicle.id;
                        });
                        
                        // Guardar la selección en SharedPreferences
                        _saveSelectedVehicle(vehicle.id);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vehículo seleccionado para diagnóstico'),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                    tileColor: isSelected 
                      ? (isDarkMode ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : Colors.blue.shade50) 
                      : null,
                  );
                },
              ),
            ),
            Padding(
          padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
            children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Método para obtener un color específico para el vehículo basado en la marca
  Color _getVehicleColor(Vehicle vehicle, bool isDarkMode) {
    final brand = vehicle.brand.toLowerCase();
    
    if (brand.contains('toyota')) return Colors.red;
    if (brand.contains('honda')) return Colors.blue;
    if (brand.contains('ford')) return Colors.blue.shade800;
    if (brand.contains('chevrolet') || brand.contains('chevy')) return Colors.amber.shade700;
    if (brand.contains('nissan')) return Colors.red.shade700;
    if (brand.contains('bmw')) return Colors.blue.shade900;
    if (brand.contains('mercedes')) return Colors.blueGrey.shade800;
    if (brand.contains('audi')) return Colors.grey.shade800;
    if (brand.contains('volkswagen') || brand.contains('vw')) return Colors.indigo;
    if (brand.contains('hyundai')) return Colors.lightBlue;
    if (brand.contains('kia')) return Colors.red.shade600;
    if (brand.contains('mazda')) return Colors.red.shade900;
    if (brand.contains('subaru')) return Colors.blue.shade800;
    if (brand.contains('lexus')) return Colors.grey.shade700;
    
    // Color por defecto
    return isDarkMode ? Colors.teal.shade600 : Colors.teal.shade700;
  }
  
  // Método para obtener un icono específico para el vehículo basado en alguna propiedad
  IconData _getVehicleIcon(Vehicle vehicle) {
    final model = vehicle.model.toLowerCase();
    final brand = vehicle.brand.toLowerCase();
    
    if (model.contains('truck') || 
        model.contains('pickup') || 
        brand.contains('ford') && model.contains('f-')) {
      return Icons.local_shipping;
    }
    
    if (model.contains('suv') || 
        model.contains('crossover') ||
        brand.contains('jeep')) {
      return Icons.directions_car_filled;
    }
    
    if (model.contains('moto') || 
        model.contains('motorcycle') ||
        brand.contains('yamaha') ||
        brand.contains('honda') && model.length <= 4) {
      return Icons.two_wheeler;
    }
    
    return Icons.directions_car;
  }
  
  Widget _buildStatusHeader(OBDState state) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isDarkMode ? Theme.of(context).colorScheme.surfaceVariant : Colors.blueGrey.shade50,
      child: Column(
        children: [
          // Selector entre modo real y simulación
          Row(
            children: [
              Text(
              'Modo:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : null,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: state.isLoading 
                ? Center(child: LinearProgressIndicator())
                : SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: const Text('Real'),
                        icon: const Icon(Icons.precision_manufacturing),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: const Text('Simulación'),
                        icon: const Icon(Icons.dashboard),
                      ),
                    ],
                    selected: {state.isSimulationMode},
                    onSelectionChanged: (Set<bool> selection) {
                      // Evitamos eventos múltiples mientras estamos cargando
                      if (!state.isLoading) {
                        context.read<OBDBloc>().add(const ToggleSimulationMode());
                      }
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Theme.of(context).colorScheme.primary;
                          }
                          return null;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Theme.of(context).colorScheme.onPrimary;
                          }
                          return Theme.of(context).colorScheme.primary;
                        },
                      ),
                      iconColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Theme.of(context).colorScheme.onPrimary;
                          } 
                          return Theme.of(context).colorScheme.primary;
                        },
                      ),
                    ),
                  ),
              ),
            ],
          ),
          // Estado de conexión
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: state.status == OBDStatus.connected ? 
                        Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Estado: ${_getStatusText(state.status)}${state.isLoading ? ' (Cambiando...)' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugesGrid(OBDState state) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.0,
      padding: const EdgeInsets.all(8),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(), // Para que se integre con el SingleChildScrollView padre
      children: [
        _buildGaugeCard(_buildRpmGauge(state), const Color(0xFFFBE9E7)),
        _buildGaugeCard(_buildSpeedGauge(state), const Color(0xFFE3F2FD)),
        _buildGaugeCard(_buildTemperatureGauge(state), const Color(0xFFFFF3E0)),
        _buildGaugeCard(_buildVoltageGauge(state), const Color(0xFFF3E5F5)),
      ],
    );
  }

  Widget _buildGaugeCard(Widget gaugeWidget, Color backgroundColor) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    // Determinar el color basado en el background para identificar el tipo de gauge
    Color gaugeColor;
    if (backgroundColor == const Color(0xFFFBE9E7)) { // RPM (color rosado)
      gaugeColor = isDarkMode ? Colors.redAccent : Colors.red;
    } else if (backgroundColor == const Color(0xFFE3F2FD)) { // Speed (color azul claro)
      gaugeColor = isDarkMode ? Colors.lightBlue : Colors.blue;
    } else if (backgroundColor == const Color(0xFFFFF3E0)) { // Temperature (color naranja claro)
      gaugeColor = isDarkMode ? Colors.amber : Colors.orange;
    } else if (backgroundColor == const Color(0xFFF3E5F5)) { // Voltage (color morado claro)
      gaugeColor = isDarkMode ? Colors.purpleAccent : Colors.purple;
    } else {
      gaugeColor = isDarkMode ? Colors.grey : Colors.grey.shade700;
    }
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.8),
                    Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.6),
                  ]
                : [
                    backgroundColor.withOpacity(0.7),
                    backgroundColor.withOpacity(0.2),
                  ],
          ),
          border: isDarkMode ? Border.all(
            color: gaugeColor.withOpacity(0.5),
            width: 1.5,
          ) : null,
        ),
        padding: const EdgeInsets.all(4.0),
        child: gaugeWidget,
      ),
    );
  }

  Widget _buildDtcSection(OBDState state) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Códigos de Diagnóstico (DTC)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.dtcCodes.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Actualizar códigos',
                  onPressed: () {
                    context.read<OBDBloc>().add(GetDTCCodes());
                  },
                ),
            ],
          ),
          SizedBox(height: 8),
          state.isLoading 
            ? Center(child: CircularProgressIndicator())
            : state.dtcCodes.isEmpty 
              ? _buildNoDtcCodesMessage()
              : _buildDtcCodesList(state.dtcCodes),
        ],
      ),
    );
  }

  Widget _buildNoDtcCodesMessage() {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
                child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
                  children: [
          Icon(
            Icons.check_circle_outline, 
            color: isDarkMode ? Colors.greenAccent : Colors.green, 
            size: 48
          ),
          SizedBox(height: 16),
                    Text(
            'No se encontraron códigos de error',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.greenAccent : Colors.green,
              fontWeight: FontWeight.w500,
                        fontSize: 16,
            ),
          ),
          TextButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Verificar nuevamente'),
            onPressed: () {
              context.read<OBDBloc>().add(GetDTCCodes());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDtcCodesList(List<String> dtcCodes) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return ListView.builder(
      itemCount: dtcCodes.length,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(), // Para que se integre con el SingleChildScrollView padre
      itemBuilder: (context, index) {
        final dtcCode = dtcCodes[index];
        String codeValue = dtcCode;
        String description = '';
        
        // Separar código y descripción si están en formato "PXXXX - Descripción"
        if (dtcCode.contains(' - ')) {
          final parts = dtcCode.split(' - ');
          codeValue = parts[0];
          description = parts[1];
        }
        
        // Determinar el tipo de DTC por la primera letra
        Color codeColor = isDarkMode ? Colors.white : Colors.black;
        if (codeValue.startsWith('P')) codeColor = Colors.red;
        if (codeValue.startsWith('C')) codeColor = Colors.orange;
        if (codeValue.startsWith('B')) codeColor = Colors.blue;
        if (codeValue.startsWith('U')) codeColor = Colors.purple;
        
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          color: isDarkMode ? Theme.of(context).colorScheme.surfaceVariant : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: codeColor.withOpacity(0.2),
              child: Text(
                codeValue.substring(0, 1),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: codeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(
              codeValue,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: codeColor,
              ),
            ),
            subtitle: description.isNotEmpty
                ? Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode 
                          ? Theme.of(context).colorScheme.onSurfaceVariant 
                          : null,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildRpmGauge(OBDState state) {
    final rpmValue = _getRpmValue(state);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return SfRadialGauge(
      animationDuration: 800,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 140,
          endAngle: 40,
          minimum: 0,
          maximum: 6000,
          interval: 1000,
          labelOffset: 8,
          canScaleToFit: true,
          radiusFactor: 0.85,
          axisLineStyle: const AxisLineStyle(
            thicknessUnit: GaugeSizeUnit.factor, 
            thickness: 0.03
          ),
          majorTickStyle: MajorTickStyle(
            length: 5,
            thickness: 1.5,
            color: isDarkMode ? Colors.white70 : Colors.black87
          ),
          minorTickStyle: MinorTickStyle(
            length: 2,
            thickness: 0.8,
            color: isDarkMode ? Colors.white60 : Colors.black54
          ),
          axisLabelStyle: GaugeTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 6000,
              sizeUnit: GaugeSizeUnit.factor,
              startWidth: 0.03,
              endWidth: 0.03,
              gradient: const SweepGradient(
                colors: <Color>[
                  Colors.green,
                  Colors.yellow,
                  Colors.red
                ],
                stops: <double>[0.0, 0.5, 1.0]
              )
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: rpmValue,
              needleLength: 0.65,
              enableAnimation: true,
              animationType: AnimationType.easeOutBack,
              needleStartWidth: 1,
              needleEndWidth: 4,
              needleColor: Colors.red,
              knobStyle: KnobStyle(
                knobRadius: 0.06,
                sizeUnit: GaugeSizeUnit.factor,
                color: isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white,
                borderColor: Colors.red,
                borderWidth: 0.03,
              )
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                'RPM',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary
                )
              ),
              angle: 90,
              positionFactor: 0.3
            ),
            GaugeAnnotation(
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _getRpmColor(rpmValue).withOpacity(0.2),
                  border: Border.all(
                    color: _getRpmColor(rpmValue),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  rpmValue.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getRpmColor(rpmValue),
                  )
                ),
              ),
              angle: 90,
              positionFactor: 0.65
            )
          ]
        )
      ]
    );
  }

  Color _getRpmColor(double value) {
    if (value < 1000) return const Color.fromRGBO(123, 199, 34, 1);
    if (value < 5000) return const Color.fromRGBO(238, 193, 34, 1);
    return const Color.fromRGBO(238, 79, 34, 1);
  }

  Widget _buildSpeedGauge(OBDState state) {
    final speedValue = _getSpeedValue(state);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return SfRadialGauge(
      animationDuration: 800,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 140,
          endAngle: 40,
          minimum: 0,
          maximum: 200,
          interval: 20,
          labelOffset: 8,
          canScaleToFit: true,
          radiusFactor: 0.85,
          axisLineStyle: const AxisLineStyle(
            thicknessUnit: GaugeSizeUnit.factor, 
            thickness: 0.03
          ),
          majorTickStyle: MajorTickStyle(
            length: 5,
            thickness: 1.5,
            color: isDarkMode ? Colors.white70 : Colors.black87
          ),
          minorTickStyle: MinorTickStyle(
            length: 2,
            thickness: 0.8,
            color: isDarkMode ? Colors.white60 : Colors.black54
          ),
          axisLabelStyle: GaugeTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 200,
              sizeUnit: GaugeSizeUnit.factor,
              startWidth: 0.03,
              endWidth: 0.03,
              gradient: const SweepGradient(
                colors: <Color>[
                  Colors.green,
                  Colors.yellow,
                  Colors.red
                ],
                stops: <double>[0.0, 0.5, 1.0]
              )
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: speedValue,
              needleLength: 0.65,
              enableAnimation: true,
              animationType: AnimationType.easeOutBack,
              needleStartWidth: 1,
              needleEndWidth: 4,
              needleColor: Colors.red,
              knobStyle: KnobStyle(
                knobRadius: 0.06,
                sizeUnit: GaugeSizeUnit.factor,
                color: isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white,
                borderColor: Colors.red,
                borderWidth: 0.03,
              )
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                'km/h',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary
                )
              ),
              angle: 90,
              positionFactor: 0.3
            ),
            GaugeAnnotation(
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _getSpeedColor(speedValue).withOpacity(0.2),
                  border: Border.all(
                    color: _getSpeedColor(speedValue),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  speedValue.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getSpeedColor(speedValue)
                  )
                ),
              ),
              angle: 90,
              positionFactor: 0.65
            )
          ]
        )
      ]
    );
  }

  Color _getSpeedColor(double value) {
    if (value < 80) return const Color.fromRGBO(123, 199, 34, 1); // Verde
    if (value < 120) return const Color.fromRGBO(238, 193, 34, 1); // Amarillo
    return const Color.fromRGBO(238, 79, 34, 1); // Rojo
  }

  Widget _buildTemperatureGauge(OBDState state) {
    final tempValue = _getTemperatureValue(state);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return SfRadialGauge(
      animationDuration: 800,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 140,
          endAngle: 40,
          minimum: 0,
          maximum: 130,
          interval: 20,
          minorTicksPerInterval: 1,
          showAxisLine: false,
          radiusFactor: 0.85,
          labelOffset: 6,
          canScaleToFit: true,
          axisLabelStyle: GaugeTextStyle(
            fontSize: 8,
            color: isDarkMode ? Colors.white70 : Colors.black,
          ),
          majorTickStyle: MajorTickStyle(
            length: 0.12,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 1.0,
            color: isDarkMode ? Colors.white70 : Colors.black
          ),
          minorTickStyle: MinorTickStyle(
            length: 0.05,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 0.5,
            color: isDarkMode ? Colors.white38 : Colors.grey
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 30,
              startWidth: 0.18,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.18,
              color: const Color.fromRGBO(20, 50, 150, 0.75), // Azul oscuro
            ),
            GaugeRange(
              startValue: 30,
              endValue: 60,
              startWidth: 0.18,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.18,
              color: const Color.fromRGBO(238, 193, 34, 0.75), // Amarillo
            ),
            GaugeRange(
              startValue: 60,
              endValue: 90,
              startWidth: 0.18,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.18,
              color: const Color.fromRGBO(123, 199, 34, 0.75), // Verde (temperatura óptima)
            ),
            GaugeRange(
              startValue: 90,
              endValue: 110,
              startWidth: 0.18,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.18,
              color: const Color.fromRGBO(238, 193, 34, 0.75), // Amarillo
            ),
            GaugeRange(
              startValue: 110,
              endValue: 130,
              startWidth: 0.18,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.18,
              color: const Color.fromRGBO(180, 30, 30, 0.75), // Rojo oscuro
            ),
          ],
          annotations: [
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.3,
              widget: Text(
                'Temp. °C',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.65,
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _getTemperatureColor(tempValue).withOpacity(0.2),
                  border: Border.all(
                    color: _getTemperatureColor(tempValue),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${tempValue.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: tempValue,
              needleStartWidth: 1,
              needleEndWidth: 4,
              needleLength: 0.65,
              animationType: AnimationType.easeOutBack,
              enableAnimation: true,
              animationDuration: 800,
              knobStyle: KnobStyle(
                knobRadius: 0.06,
                borderColor: _getTemperatureColor(tempValue),
                color: isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white,
                borderWidth: 0.03,
              ),
              tailStyle: TailStyle(
                color: _getTemperatureColor(tempValue),
                width: 3,
                length: 0.12,
              ),
              needleColor: _getTemperatureColor(tempValue),
            ),
          ],
        ),
      ],
    );
  }

  Color _getTemperatureColor(double value) {
    if (value < 30) return const Color.fromRGBO(20, 50, 150, 1); // Azul oscuro
    if (value < 60) return const Color.fromRGBO(238, 193, 34, 1); // Amarillo
    if (value < 90) return const Color.fromRGBO(123, 199, 34, 1); // Verde (óptimo)
    if (value < 110) return const Color.fromRGBO(238, 193, 34, 1); // Amarillo
    return const Color.fromRGBO(180, 30, 30, 1); // Rojo oscuro
  }

  Widget _buildVoltageGauge(OBDState state) {
    final voltageValue = _getVoltageValue(state);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return SfRadialGauge(
      animationDuration: 800,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 140,
          endAngle: 40,
          minimum: 8,
          maximum: 16,
          interval: 2,
          minorTicksPerInterval: 1,
          showAxisLine: false,
          radiusFactor: 0.85,
          labelOffset: 6,
          canScaleToFit: true,
          axisLabelStyle: GaugeTextStyle(
            fontSize: 8,
            color: isDarkMode ? Colors.white70 : Colors.black,
          ),
          majorTickStyle: MajorTickStyle(
            length: 0.12,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 1.0,
            color: isDarkMode ? Colors.white70 : Colors.black
          ),
          minorTickStyle: MinorTickStyle(
            length: 0.05,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 0.5,
            color: isDarkMode ? Colors.white38 : Colors.grey
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 8,
              endValue: 10.5,
              startWidth: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.2,
              color: const Color.fromRGBO(238, 79, 34, 0.65),
            ),
            GaugeRange(
              startValue: 10.5,
              endValue: 11.5,
              startWidth: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.2,
              color: const Color.fromRGBO(238, 193, 34, 0.75),
            ),
            GaugeRange(
              startValue: 11.5,
              endValue: 14.5,
              startWidth: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.2,
              color: const Color.fromRGBO(123, 199, 34, 0.75),
            ),
            GaugeRange(
              startValue: 14.5,
              endValue: 15.5,
              startWidth: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.2,
              color: const Color.fromRGBO(238, 193, 34, 0.75),
            ),
            GaugeRange(
              startValue: 15.5,
              endValue: 16,
              startWidth: 0.2,
              sizeUnit: GaugeSizeUnit.factor,
              endWidth: 0.2,
              color: const Color.fromRGBO(238, 79, 34, 0.65),
            ),
          ],
          annotations: [
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.35,
              widget: Text(
                'Batería (V)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.7,
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _getVoltageColor(voltageValue).withOpacity(0.2),
                  border: Border.all(
                    color: _getVoltageColor(voltageValue),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${voltageValue.toStringAsFixed(1)}V',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: voltageValue,
              needleStartWidth: 1,
              needleEndWidth: 5,
              needleLength: 0.7,
              animationType: AnimationType.easeOutBack,
              enableAnimation: true,
              animationDuration: 800,
              knobStyle: KnobStyle(
                knobRadius: 0.07,
                borderColor: _getVoltageColor(voltageValue),
                color: isDarkMode ? Theme.of(context).colorScheme.surface : Colors.white,
                borderWidth: 0.04,
              ),
              tailStyle: TailStyle(
                color: _getVoltageColor(voltageValue),
                width: 4,
                length: 0.15,
              ),
              needleColor: _getVoltageColor(voltageValue),
            ),
          ],
          ),
      ],
    );
  }

  Color _getVoltageColor(double value) {
    if (value < 10.5) return const Color.fromRGBO(238, 79, 34, 1);
    if (value < 11.5) return const Color.fromRGBO(238, 193, 34, 1);
    if (value < 14.5) return const Color.fromRGBO(123, 199, 34, 1);
    if (value < 15.5) return const Color.fromRGBO(238, 193, 34, 1);
    return const Color.fromRGBO(238, 79, 34, 1);
  }

  double _getRpmValue(OBDState state) {
    final rpmData = state.parametersData['01 0C'];
    if (rpmData != null && rpmData['value'] != null) {
      return (rpmData['value'] as double).roundToDouble();
    }
    return 0.0;
  }

  double _getSpeedValue(OBDState state) {
    final speedData = state.parametersData['01 0D'];
    if (speedData != null && speedData['value'] != null) {
      return (speedData['value'] as double).roundToDouble();
    }
    return 0.0;
  }

  double _getTemperatureValue(OBDState state) {
    final tempData = state.parametersData['01 05'];
    if (tempData != null && tempData['value'] != null) {
      return (tempData['value'] as double).roundToDouble();
    }
    return 0.0;
  }

  double _getVoltageValue(OBDState state) {
    final voltageData = state.parametersData['01 42'];
    if (voltageData != null && voltageData['value'] != null) {
      // Redondear a 1 decimal
      return (voltageData['value'] as double);
    }
    return 0.0;
  }
  
  String _getStatusText(OBDStatus status) {
    switch (status) {
      case OBDStatus.initial:
        return 'Inicializando';
      case OBDStatus.initialized:
        return 'Inicializado';
      case OBDStatus.connecting:
        return 'Conectando';
      case OBDStatus.connected:
        return 'Conectado';
      case OBDStatus.disconnected:
        return 'Desconectado';
      case OBDStatus.error:
        return 'Error';
      default:
        return 'Desconocido';
    }
  }

  Widget _buildConnectionPrompt(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled, 
              size: 80, 
              color: isDarkMode 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                : Colors.blue.withOpacity(0.6),
            ),
            SizedBox(height: 20),
            Text(
              'No hay conexión con dispositivo OBD',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode 
                    ? Theme.of(context).colorScheme.onBackground
                    : null,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'En modo real, necesitas conectar un dispositivo OBD\npara ver los datos del vehículo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDarkMode 
                    ? Theme.of(context).colorScheme.onBackground.withOpacity(0.7)
                    : Colors.grey[600],
              ),
            ),
            // Mostrar mensaje de error si existe
            if (_obdBloc.state.error != null && _obdBloc.state.error!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(isDarkMode ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(isDarkMode ? 0.5 : 0.3)),
                  ),
                  child: Text(
                    _obdBloc.state.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.red.shade300 : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const OBDConnectionDialog(),
                  );
                },
                icon: Icon(Icons.bluetooth, color: Theme.of(context).colorScheme.onPrimary,),
                label: Text('Conectar Dispositivo OBD'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para mostrar la información del viaje activo
  Widget _buildActiveTrip(OBDState state) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return BlocBuilder<TripBloc, TripState>(
      builder: (context, tripState) {
        // Agregar logs para depuración
        print("[DiagnosticScreen] _buildActiveTrip - Estado TripBloc: ${tripState.status}");
        
        // Si estamos en modo simulación y no hay un viaje activo, iniciarlo automáticamente
        if (state.isSimulationMode && (tripState.currentTrip == null || !tripState.currentTrip!.isActive) && 
            _selectedVehicleId != null && state.status == OBDStatus.connected) {
          
          // Solo intentamos iniciar un viaje si no estamos en estado de error
          // o si el error no contiene "Ya hay un viaje activo"
          bool shouldStartTrip = tripState.status != TripStatus.error || 
              (tripState.error != null && !tripState.error!.contains("Ya hay un viaje activo"));
          
          // Agregar logs para depuración
          print("[DiagnosticScreen] Condiciones para iniciar viaje simulado automáticamente: ${shouldStartTrip ? 'CUMPLIDAS' : 'NO CUMPLIDAS'}");
          print("[DiagnosticScreen] - isSimulationMode: ${state.isSimulationMode}");
          print("[DiagnosticScreen] - currentTrip: ${tripState.currentTrip}");
          print("[DiagnosticScreen] - selectedVehicleId: $_selectedVehicleId");
          print("[DiagnosticScreen] - OBDStatus: ${state.status}");
          
          if (shouldStartTrip) {
            // Si el estado es error y menciona "Ya hay un viaje activo", primero solicitar el viaje actual
            if (tripState.status == TripStatus.error && 
                tripState.error != null && 
                tripState.error!.contains("Ya hay un viaje activo")) {
              print("[DiagnosticScreen] Detectado error de viaje activo, recuperando viaje actual...");
              Future.microtask(() {
                context.read<TripBloc>().add(GetCurrentTripEvent());
              });
              
              // Mostrar indicador mientras recuperamos
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? Color(0xFF2A2A2D) 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Recuperando viaje activo...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            // Intentar iniciar un nuevo viaje solo si no estamos en estado de error por viaje activo
            print("[DiagnosticScreen] Intentando iniciar viaje simulado para vehículo: $_selectedVehicleId");
            Future.microtask(() {
              context.read<TripBloc>().add(StartTripEvent(_selectedVehicleId!));
            });
          }
          
          // Mostrar indicador de carga mientras se inicia el viaje o se recupera
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Color(0xFF2A2A2D) 
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    tripState.error != null && tripState.error!.contains("Ya hay un viaje activo")
                        ? 'Recuperando viaje existente...'
                        : 'Iniciando viaje simulado...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (tripState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Error: ${tripState.error}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        
        // Si no hay un viaje activo
        if (tripState.currentTrip == null || !tripState.currentTrip!.isActive) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Color(0xFF2A2A2D) 
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_filled,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'No hay viaje activo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode 
                        ? Colors.white 
                        : Colors.black87,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_selectedVehicleId != null) {
                      context.read<TripBloc>().add(StartTripEvent(_selectedVehicleId!));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Selecciona un vehículo para iniciar un viaje'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: Icon(Icons.play_arrow),
                  label: Text('Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Si hay un viaje activo
        return _ActiveTripInfo(
          trip: tripState.currentTrip!,
          obdState: state,
        );
      },
    );
  }
}

// Widget separado para el viaje activo que se actualiza automáticamente
class _ActiveTripInfo extends StatefulWidget {
  final Trip trip;
  final OBDState obdState;
  
  const _ActiveTripInfo({
    required this.trip,
    required this.obdState,
  });
  
  @override
  _ActiveTripInfoState createState() => _ActiveTripInfoState();
}

class _ActiveTripInfoState extends State<_ActiveTripInfo> {
  late Timer _timer;
  late Duration _elapsedTime;
  
  // Valores para tracking en modo simulación
  double _lastDistance = 0.0;
  double _lastFuelConsumption = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    // Forzar que el tiempo comience en 0
    _elapsedTime = Duration.zero;
    
    // Actualizar cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Incrementar por 1 segundo en cada tick para asegurar que empiece de 0
          _elapsedTime = _elapsedTime + const Duration(seconds: 1);
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final isSimulation = widget.obdState.isSimulationMode;
    
    // Variables para los datos a mostrar
    final hours = _elapsedTime.inHours;
    final minutes = _elapsedTime.inMinutes.remainder(60);
    final seconds = _elapsedTime.inSeconds.remainder(60);
    final durationText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    // Obtener distancia y consumo según el modo
    double distance;
    double fuelConsumptionRate; // Litros por 100km
    
    if (isSimulation) {
      // En modo simulación, obtenemos datos del OBD mock
      distance = _getSimulatedDistance(widget.obdState);
      fuelConsumptionRate = _getSimulatedFuelConsumptionRate();
      
      // Si hay cambios, grabamos los nuevos valores
      if (distance != _lastDistance) {
        _lastDistance = distance;
      }
    } else {
      // En modo real, usamos los datos del trip
      distance = widget.trip.distanceInKm;
      // Consumo del estado OBD si está disponible (litros por hora)
      double fuelConsumptionLh = 0.0;
      if (widget.obdState.parametersData.containsKey('01 5E')) {
        final fuelData = widget.obdState.parametersData['01 5E'];
        if (fuelData != null && fuelData['value'] != null) {
          fuelConsumptionLh = fuelData['value'] as double;
        }
      }
      
      // Convertir L/h a L/100km si hay velocidad disponible
      double speedKmh = 0.0;
      if (widget.obdState.parametersData.containsKey('01 0D')) {
        final speedData = widget.obdState.parametersData['01 0D'];
        if (speedData != null && speedData['value'] != null) {
          speedKmh = speedData['value'] as double;
        }
      }
      
      // Calcular consumo en L/100km
      fuelConsumptionRate = (speedKmh > 5.0) ? (fuelConsumptionLh / speedKmh) * 100 : 7.0;
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Color(0xFF3A3A3D), Color(0xFF333336)]
              : [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(isDarkMode ? 0.5 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Viaje activo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isSimulation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.blue.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.blue,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'SIM',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTripStatItem(
                  context,
                  icon: Icons.timer,
                  label: 'Tiempo',
                  value: durationText,
                  color: isDarkMode ? Colors.amber : Colors.orange,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTripStatItem(
                  context,
                  icon: Icons.map,
                  label: 'Distancia',
                  value: '${distance.toStringAsFixed(2)} km',
                  color: isDarkMode ? Colors.lightGreen : Colors.green,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTripStatItem(
                  context,
                  icon: Icons.opacity,
                  label: 'Consumo',
                  value: '${fuelConsumptionRate.toStringAsFixed(1)} L/100km',
                  color: isDarkMode ? Colors.lightBlue : Colors.blue,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Método para obtener la distancia simulada del repositorio OBD
  double _getSimulatedDistance(OBDState state) {
    if (state.parametersData.containsKey('01 FF')) {
      final distData = state.parametersData['01 FF'];
      if (distData != null && distData['value'] != null) {
        final value = distData['value'] as double;
        if (value.isFinite && value >= 0) {
          return value;
        }
      }
    }
    
    // Alternativa usando la velocidad como respaldo
    final speed = _getSimulatedSpeed(state);
    // La distancia avanza con el tiempo y la velocidad
    return (_lastDistance + (speed * 1.0) / 3600.0).clamp(0.0, double.infinity);
  }
  
  // Método para obtener la velocidad simulada
  double _getSimulatedSpeed(OBDState state) {
    if (state.parametersData.containsKey('01 0D')) {
      final speedData = state.parametersData['01 0D'];
      if (speedData != null && speedData['value'] != null) {
        return speedData['value'] as double;
      }
    }
    return 0.0;
  }
  
  // Método para obtener el consumo medio de combustible (L/100km)
  double _getSimulatedFuelConsumptionRate() {
    // Valores típicos de consumo: 
    // - Ciudad: 8-12 L/100km
    // - Carretera: 5-7 L/100km
    // - Combinado: 6-9 L/100km
    
    final speed = _getSimulatedSpeed(widget.obdState);
    
    // Ralentí o ciudad a baja velocidad (mayor consumo)
    if (speed < 20) {
      return 10.0 + (_elapsedTime.inSeconds % 10) * 0.2; // Pequeña variación para realismo
    }
    // Velocidad de crucero en ciudad/combinado
    else if (speed < 80) {
      return 7.0 + (_elapsedTime.inSeconds % 10) * 0.15;
    }
    // Velocidad de carretera (menor consumo)
    else {
      return 5.5 + (_elapsedTime.inSeconds % 10) * 0.1;
    }
  }
  
  Widget _buildTripStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDarkMode 
                      ? Colors.grey[300]
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}