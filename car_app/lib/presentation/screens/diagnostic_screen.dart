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
// import '../blocs/obd/obd_event.dart'; // No importar el event directamente
import 'package:car_app/domain/entities/obd_data.dart';
//import '../widgets/diagnostic_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart'; // <-- Import añadido
import 'package:permission_handler/permission_handler.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  _DiagnosticScreenState createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isInitialized = false;
  late OBDBloc _obdBloc; // Mantener referencia directa al BLoC
  late TripBloc _tripBloc;
  String? _selectedVehicleId;
  static const String _prefKey = 'selected_diagnostic_vehicle_id';
  bool _wasInSimulationMode = false; // Para rastrear cambios en el modo
  StreamSubscription<TripState>? _tripSubscription;
  StreamSubscription? _obdStatusSubscription;
  final Map<String, OBDData> _latestData = {};
  final List<String> _essentialPids = ['0C', '0D']; // RPM y Velocidad
  final List<String> _nonEssentialPids = ['05', '42', '5E']; // Temperatura, Voltaje, Consumo
  bool _isMonitoringActive = false;
  Timer? _connectionCheckTimer;
  bool _showSupportedPids = false; // Nuevo estado para controlar visibilidad
  PageController _pageController = PageController();
  bool _isBottomBarVisible = true;
  double _gaugeAnimationValue = 0.0;
  double _gaugeTargetValue = 0.0;
  final Map<String, ScrollController> _scrollControllers = {};
  int _currentTabIndex = 0;
  bool _isRequestingActiveTrip = false; // Nueva bandera para evitar bucles infinitos
  Trip? _lastActiveTrip; // Nueva variable para almacenar el viaje activo anterior
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print("[DiagnosticScreen] initState - Inicializando pantalla de diagnóstico");
    
    // Obtener la referencia al BLoC aquí de forma segura
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
    
    // Verificar si hay un viaje activo al iniciar
    Future.microtask(() {
      _tripBloc.add(GetCurrentTripEvent());
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
         !_obdBloc.state.parametersData.containsKey('0C'))) { // Usar '0C' como clave
      print("[DiagnosticScreen] Reiniciando monitoreo de parámetros tras volver a la pantalla");
      _startMonitoringParameters();
    }
  }

  void _startMonitoringParameters() {
    // Usar la referencia _obdBloc
    
    // Lista de PIDs a monitorear (SIN prefijo 01)
    final pids = [
      '0C', // RPM
      '0D', // Velocidad
      '05', // Temperatura
      '42', // Voltaje
    ];
    
    // Iniciar monitoreo de cada parámetro
    for (final pid in pids) {
      _obdBloc.add(StartParameterMonitoring(pid));
    }
  }

  void _stopParameterMonitoring() {
    print("[DiagnosticScreen] Deteniendo monitoreo de todos los PIDs");
    final allPids = [..._essentialPids, ..._nonEssentialPids];
    for (final pid in allPids) {
      _obdBloc.add(StopParameterMonitoring(pid));
    }
    _isMonitoringActive = false; // Marcar como inactivo
  }

  void _onConnectPressed() {
    // Usar la referencia _obdBloc
    
    if (_obdBloc.state.status == OBDStatus.connected) {
      // Si está conectado, desconectar
      _obdBloc.add(const DisconnectFromOBD());
      _stopParameterMonitoring();
    } else {
      // Si no está conectado, inicializar y conectar
      _obdBloc.add(InitializeOBDEvent());
    }
  }

  void _onSimulationToggled() {
    // Usar la referencia _obdBloc
    _obdBloc.add(const ToggleSimulationMode());
  }
  
  @override
  void dispose() {
    print("[DiagnosticScreen] dispose - Iniciando limpieza...");
    _stopParameterMonitoring(); // Usar el nombre correcto del método
    // _obdBloc.add(DisconnectFromOBD()); // NO DESCONECTAR AQUÍ
    _obdStatusSubscription?.cancel();
    _tripSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _connectionCheckTimer?.cancel();
    print("[DiagnosticScreen] dispose - Limpieza completada.");
    super.dispose();
  }
  
  @override
  void deactivate() {
    print("[DiagnosticScreen] deactivate - No hacer nada aquí, mover lógica a dispose");
    super.deactivate(); 
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
    final themeState = context.watch<ThemeBloc>().state;
    final isDarkMode = themeState;
    
    return BlocListener<TripBloc, TripState>(
      listener: (context, tripState) {
        // Mostrar mensaje de error si hubo un problema al iniciar el viaje
        if (tripState.status == TripStatus.error && tripState.error != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${tripState.error}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        // Si se ha finalizado un viaje, mostrar notificación
        if (tripState.status == TripStatus.ready && 
            tripState.lastCompletedTrip != null && 
            tripState.currentTrip == null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Viaje finalizado correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Refrescar el estado para asegurar que la UI se actualice
          setState(() {});
        }
      },
      child: Scaffold(
        body: MultiBlocListener(
          listeners: [
            BlocListener<OBDBloc, OBDState>(
              listenWhen: (previous, current) => previous.isSimulationMode != current.isSimulationMode,
              listener: (context, state) {
                print("[DiagnosticScreen] Modo cambiado: simulación=${state.isSimulationMode}");
                _onToggleSimulationMode(state.isSimulationMode);
              },
            ),
            BlocListener<OBDBloc, OBDState>(
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
            ),
          ],
          child: BlocProvider.value(
            value: _obdBloc,
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
                      // Header fijo
                  _buildStatusHeader(state),
                  
                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              // Selector de vehículos
                          _buildCompactVehicleSelector(isDarkMode),
                          
                              // Gauges
                          SizedBox(
                                height: MediaQuery.of(context).size.width * 1.05,
                            child: _buildGaugesGrid(state),
                          ),
                          
                          // Información del viaje activo
                              _buildActiveTripCard(context, state, _tripBloc.state),
                          
                          // Sección de DTC
                          _buildDtcSection(state),
                          
                              // Nueva sección para PIDs Soportados
                              _buildSupportedPidsSection(state),
                              
                              // Padding inferior
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
              child: state.isLoading && state.status != OBDStatus.connected
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
                'Estado: ${_getStatusText(state.status)}${state.isLoading && state.status != OBDStatus.connected ? ' (Cambiando...)' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                ),
              ),
              // Agregar indicador de actividad cuando se están consultando PIDs pero ya está conectado
              if (state.isLoading && state.status == OBDStatus.connected)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
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
                  tooltip: 'Actualizar códigos DTC',
                  onPressed: () {
                    context.read<OBDBloc>().add(GetDTCCodes());
                  },
                ),
            ],
          ),
          SizedBox(height: 8),
          state.isLoading && state.dtcCodes.isEmpty // Mostrar indicador solo si está cargando y no hay códigos
            ? Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator()))
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
    final rpmData = state.parametersData['0C']; // Usar '0C'
    if (rpmData != null && rpmData['value'] != null) {
      return (rpmData['value'] as double).roundToDouble();
    }
    return 0.0;
  }

  double _getSpeedValue(OBDState state) {
    final speedData = state.parametersData['0D']; // Usar '0D'
    if (speedData != null && speedData['value'] != null) {
      return (speedData['value'] as double).roundToDouble();
    }
    return 0.0;
  }

  double _getTemperatureValue(OBDState state) {
    final tempData = state.parametersData['05']; // Usar '05'
    if (tempData != null && tempData['value'] != null) {
      return (tempData['value'] as double).roundToDouble();
    }
    return 0.0;
  }

  double _getVoltageValue(OBDState state) {
    final voltageData = state.parametersData['42']; // Usar '42'
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

  // Método para construir la tarjeta de viaje activo
  Widget _buildActiveTripCard(BuildContext context, OBDState state, TripState tripState) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    // Verificar si hay un viaje activo en el Bloc
    if (tripState.currentTrip != null && tripState.currentTrip!.isActive) {
      print("[DiagnosticScreen] Mostrando tarjeta para viaje activo: ${tripState.currentTrip!.id}");
      
      // Comparar IDs para verificar si es un nuevo viaje diferente al anterior
      final String? lastTripId = _lastActiveTrip?.id;
      final currentTripId = tripState.currentTrip!.id;
      
      if (lastTripId != null && lastTripId != currentTripId) {
        print("[DiagnosticScreen] Detectado nuevo viaje: $lastTripId -> $currentTripId");
      }
      
      // Actualizar referencia al viaje activo actual
      _lastActiveTrip = tripState.currentTrip;
      
      return ActiveTripInfoWidget(
        key: ValueKey("activeTrip_${tripState.currentTrip!.id}"), // Usar key basada en el ID del viaje
        trip: tripState.currentTrip!,
        obdState: state,
      );
    }
    
    // Si no hay viaje activo pero hay uno completado, mostrar resumen
    if (tripState.lastCompletedTrip != null && !tripState.lastCompletedTrip!.isActive) {
      // Limpiar la referencia al viaje activo anterior
      _lastActiveTrip = null;
      
      return _buildCompletedTripSummary(context, tripState.lastCompletedTrip!, isDarkMode);
    }
    
    // Si no hay viaje activo ni completado, mostrar tarjeta similar pero con botón para iniciar
    final hasVehicle = _selectedVehicleId != null;
    
    // Limpiar la referencia al viaje activo anterior
    _lastActiveTrip = null;
    
    // Verificar si hay error de viaje activo y recuperarlo
            if (tripState.status == TripStatus.error && 
                tripState.error != null && 
                tripState.error!.contains("Ya hay un viaje activo")) {
              print("[DiagnosticScreen] Detectado error de viaje activo, recuperando viaje actual...");
      
      // Limitar a una sola solicitud para evitar bucles
      if (!_isRequestingActiveTrip) {
        _isRequestingActiveTrip = true;
        
              Future.microtask(() {
                context.read<TripBloc>().add(GetCurrentTripEvent());
          
          // Restaurar la bandera después de un tiempo para permitir solicitudes futuras
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isRequestingActiveTrip = false;
              });
            }
          });
        });
      }
              
              // Mostrar indicador mientras recuperamos
      return _buildLoadingTripCard(context, isDarkMode, "Recuperando viaje existente...");
    }
    
    // Mostrar tarjeta similar a la de viaje activo, pero con estado pausado
    return _buildInactiveTripCard(context, state, isDarkMode, hasVehicle);
  }

  // Nuevo método para mostrar la tarjeta de viaje inactivo con formato similar al de viaje activo
  Widget _buildInactiveTripCard(BuildContext context, OBDState state, bool isDarkMode, bool hasVehicle) {
    // Valores por defecto para viaje inactivo
    final durationText = '00:00:00';
    final distanceText = '0.00 km';
    final consumoText = '0.00 L/h';
    
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
                      Text(
                      'Viaje pausado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
              ),
              // Botón unificado para iniciar viaje
              ElevatedButton.icon(
                onPressed: hasVehicle
                  ? () {
                      // Iniciar viaje manualmente al presionar el botón
                      state.isSimulationMode
                        ? context.read<TripBloc>().add(StartTripEvent(_selectedVehicleId!))
                        : _showRealTripConfirmationDialog(context);
                    } 
                  : null,
                icon: Icon(Icons.play_arrow, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                label: Text('Iniciar viaje', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade400,
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
                  value: distanceText,
                  color: isDarkMode ? Colors.lightGreen : Colors.green,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTripStatItem(
                  context,
                  icon: Icons.local_gas_station,
                  label: 'Consumo',
                  value: consumoText,
                  color: Colors.orange,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          if (!hasVehicle)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Selecciona un vehículo para iniciar un viaje',
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
                ),
              );
            }
            
  // Método auxiliar para mostrar el indicador de carga
  Widget _buildLoadingTripCard(BuildContext context, bool isDarkMode, String message) {
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
              message,
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
        
  // Método para mostrar un resumen del viaje completado
  Widget _buildCompletedTripSummary(BuildContext context, Trip trip, bool isDarkMode) {
    // Formatear la duración
    final hours = trip.durationSeconds ~/ 3600;
    final minutes = (trip.durationSeconds % 3600) ~/ 60;
    final seconds = trip.durationSeconds % 60;
    final durationText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Color(0xFF3A3A3D), Color(0xFF333336)]
              : [Colors.green.shade50, Colors.green.shade100],
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
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
                ),
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                      'Viaje finalizado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Finalizado: ${_formatDateTime(trip.endTime ?? DateTime.now())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Botón unificado para iniciar nuevo viaje
                ElevatedButton.icon(
                onPressed: _selectedVehicleId != null 
                  ? () {
                      // Iniciar un nuevo viaje
                      _obdBloc.state.isSimulationMode
                        ? _tripBloc.add(StartTripEvent(_selectedVehicleId!))
                        : _showRealTripConfirmationDialog(context);
                  }
                  : null,
                icon: Icon(Icons.play_arrow, size: 18),
                label: Text('Nuevo viaje'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade400,
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
                  value: '${trip.distanceInKm.toStringAsFixed(2)} km',
                  color: isDarkMode ? Colors.lightGreen : Colors.green,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTripStatItem(
                  context,
                  icon: Icons.local_gas_station,
                  label: 'Consumo',
                  value: '${trip.fuelConsumptionLiters.toStringAsFixed(2)} L',
                  color: Colors.orange,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Método para formatear la fecha y hora
  String _formatDateTime(DateTime dateTime) {
    final spanishMonth = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ][dateTime.month - 1];
    
    return '${dateTime.day} $spanishMonth, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Método para mostrar el diálogo de confirmación para viajes reales
  void _showRealTripConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Iniciar viaje real'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Estás seguro de que deseas iniciar un nuevo viaje?'),
            SizedBox(height: 8),
            Text(
              'El viaje se registrará en la base de datos y actualizará el kilometraje del vehículo.',
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey[600]
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
                  onPressed: () {
              Navigator.pop(context);
              print("[DiagnosticScreen] Iniciando viaje real para vehículo: $_selectedVehicleId");
              
              // Mostrar indicador de carga
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      ),
                      SizedBox(width: 12),
                      Text('Iniciando viaje...'),
                    ],
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
              
              context.read<TripBloc>().add(StartTripEvent(_selectedVehicleId!));
            },
            child: Text('Iniciar viaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
    );
  }

  // Variable para rastrear el último intento de reconexión
  DateTime _lastReconnectAttempt = DateTime.now().subtract(const Duration(minutes: 1));

  // Esta función comprueba si todos los parámetros tienen error, lo que podría indicar
  // un problema de conexión que requiere reconexión
  void _checkForConnectionIssues(OBDState state) {
    if (!state.isSimulationMode && state.status == OBDStatus.connected) {
      // Si tenemos datos pero todos son errores, podría haber un problema de conexión
      if (state.parametersData.isNotEmpty && state.parametersData.length >= 2) {
        bool allHaveErrors = true;
        
        // Verificar si todos los parámetros tienen errores
        state.parametersData.forEach((pid, data) {
          // Usar la clave limpia (sin '01 ') para chequear
          String cleanPid = pid.replaceAll(' ', '');
          if (cleanPid.startsWith("01")) cleanPid = cleanPid.substring(2);

          if (state.parametersData[cleanPid]?['description'] != null && 
              !state.parametersData[cleanPid]!['description'].toString().toLowerCase().contains('error')) {
            allHaveErrors = false;
          }
        });
        
        // Si todos tienen errores y tenemos al menos 2 parámetros monitoreados,
        // podría ser que la conexión se haya perdido
        if (allHaveErrors) {
          print("[DiagnosticScreen] Posible pérdida de conexión detectada, todos los parámetros reportan error");
          
          // Intentamos reconectar cada 10 segundos para no saturar
          if (DateTime.now().difference(_lastReconnectAttempt).inSeconds > 10) {
            _lastReconnectAttempt = DateTime.now();
            
            print("[DiagnosticScreen] Intentando reconectar con OBD...");
            
            // Reiniciar la conexión
            _obdBloc.add(const DisconnectFromOBD());
            
            // Esperar brevemente y reconectar
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              print("[DiagnosticScreen] Reconectando OBD después de desconexión...");
              _obdBloc.add(InitializeOBDEvent());
              
              Future.delayed(const Duration(seconds: 1), () {
                if (!mounted) return;
                _obdBloc.add(ConnectToOBD());
              });
            });
          }
        }
      }
    }
  }

  // Método para construir elementos de estadísticas de viaje
  Widget _buildTripStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // --- Nueva sección para PIDs Soportados ---
  Widget _buildSupportedPidsSection(OBDState state) {
    final isDarkMode = context.watch<ThemeBloc>().state;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: Colors.cyan),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PIDs Soportados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Botón para mostrar/ocultar y refrescar
              TextButton.icon(
                icon: Icon(
                  _showSupportedPids 
                    ? Icons.visibility_off_outlined 
                    : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(_showSupportedPids ? 'Ocultar' : 'Mostrar'),
                onPressed: () {
                  if (!_showSupportedPids) {
                    // Si no se muestran, solicitar PIDs si no están en caché
                    if (state.supportedPids == null) {
                       context.read<OBDBloc>().add(FetchSupportedPids());
                    }
                  }
                  setState(() {
                    _showSupportedPids = !_showSupportedPids;
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
               // Botón de refrescar solo visible si se están mostrando
              if (_showSupportedPids)
                IconButton(
                  icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary, size: 20),
                  tooltip: 'Actualizar PIDs Soportados',
                  onPressed: () {
                    context.read<OBDBloc>().add(FetchSupportedPids());
                  },
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                  splashRadius: 20,
                ),
            ],
          ),
          SizedBox(height: 8),
          // Contenido condicional
          if (_showSupportedPids)
            state.isLoading && state.supportedPids == null // Indicador solo si está cargando por primera vez
              ? Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator()))
              : state.supportedPids == null
                 ? Center(child: Text('Pulsa "Mostrar" para obtener los PIDs.'))
                 : state.supportedPids!.isEmpty
                   ? Center(child: Text('No se encontraron PIDs soportados o hubo un error.'))
                   : _buildSupportedPidsGrid(state.supportedPids!), // Mostrar Grid

          if (state.error != null && state.error!.contains("PIDs soportados"))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Error: ${state.error}',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportedPidsGrid(List<String> pids) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // Ajusta el número de columnas según necesites
        childAspectRatio: 2.5, // Ajusta para el tamaño de los items
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: pids.length,
      itemBuilder: (context, index) {
        final pid = pids[index];
        return Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              pid,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        );
      },
    );
  }

  // Primero, asegurar que cuando cambiamos a modo simulación o real, se maneje correctamente el viaje
  void _onToggleSimulationMode(bool currentIsSimulation) {
    if (!mounted) return;
    
    // Si estamos cambiando a simulación, no necesitamos hacer nada específico con los viajes
    if (currentIsSimulation) {
      print("[DiagnosticScreen] Cambiando a modo simulación, los viajes no se guardarán en la BD");
      return;
    }
    
    // Si estamos cambiando de simulación a modo real, necesitamos verificar si hay un viaje activo
    // y finalizarlo para evitar datos incorrectos
    if (!currentIsSimulation && _tripBloc.state.currentTrip != null) {
      print("[DiagnosticScreen] Cambiando a modo real, finalizando viaje simulado si existe");
      _tripBloc.add(EndTripEvent(_tripBloc.state.currentTrip!.id));
    }
  }

  // Nuevo método para construir la tarjeta de DTCs
  Widget _buildDTCCard(BuildContext context, OBDState state) {
    final theme = Theme.of(context);
    final isDarkMode = context.watch<ThemeBloc>().state;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Códigos de Error (DTC)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Leer DTCs'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: theme.textTheme.labelSmall,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: state.isLoading
                      ? null // Deshabilitar si ya está cargando algo
                      : () => context.read<OBDBloc>().add(GetDTCCodes()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Mostrar indicador de carga si está buscando DTCs
            if (state.isLoading && state.dtcCodes.isEmpty && state.error == null)
              const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            // Mostrar error si existe
            if (state.error != null && state.error!.contains('DTC')) // Filtrar errores de DTC
              Center(
                child: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            // Mostrar lista de DTCs o mensaje si no hay
            if (!state.isLoading && state.error == null)
              state.dtcCodes.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron códigos de error.',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    )
                  : Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: state.dtcCodes.map((code) => Chip(
                        label: Text(code),
                        backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.7),
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )).toList(),
                    ),
          ],
        ),
      ),
    );
  }

  // Método para construir selectores de modo y vehículo
  Widget _buildModeAndVehicleSelectors(BuildContext context, OBDState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Selector de Modo (Simulación/Real)
        SegmentedButton<bool>(
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
        // Selector de Vehículo
        BlocBuilder<VehicleBloc, VehicleState>(
          builder: (context, vehicleState) {
            final List<Vehicle> vehicles = (vehicleState is VehicleLoaded) ? vehicleState.vehicles : [];
            final isDarkMode = context.read<ThemeBloc>().state;
            
            // Construir el nombre del vehículo seleccionado
            final selectedVehicle = vehicles.firstWhereOrNull((v) => v.id == _selectedVehicleId);
            final vehicleLabel = selectedVehicle != null
                ? '${selectedVehicle.brand} ${selectedVehicle.model}'
                : 'Seleccionar vehículo';

            return ElevatedButton.icon(
              icon: const Icon(Icons.directions_car),
              label: Text(vehicleLabel), // Usar la etiqueta construida
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
              onPressed: () => _showVehicleSelectionModal(context, vehicles, isDarkMode),
            );
          },
        ),
      ],
    );
  }
}

// Asegúrate de que la definición de la clase ActiveTripInfoWidget esté presente
// o importada correctamente.
class ActiveTripInfoWidget extends StatefulWidget {
  final Trip trip;
  final OBDState obdState;
  
  const ActiveTripInfoWidget({
    Key? key,
    required this.trip,
    required this.obdState,
  }) : super(key: key);
  
  @override
  _ActiveTripInfoWidgetState createState() => _ActiveTripInfoWidgetState();
}

class _ActiveTripInfoWidgetState extends State<ActiveTripInfoWidget> with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _gpsTimer; // Timer para captura periódica de GPS
  Duration _elapsedTime = Duration.zero;
  
  // Variables para el manejo de distancia y puntos GPS
  double _lastDistance = 0.0;
  DateTime _lastUpdateTime = DateTime.now();
  DateTime _lastGpsCheck = DateTime.now();
  DateTime _lastBackendUpdate = DateTime.now();
  
  // Lista para almacenar puntos GPS antes de enviarlos al backend
  List<GpsPoint> _bufferedGpsPoints = [];
  
  // Configuración para el envío de puntos GPS
  final int _maxBufferedPoints = 5;
  final Duration _minUpdateInterval = Duration(seconds: 10);
  
  bool _isFirstBuild = true;
  bool _isActive = false; // Nueva variable para rastrear si el widget está activo
  
  // Método para formatear la fecha y hora
  String _formatDateTime(DateTime dateTime) {
    final spanishMonth = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ][dateTime.month - 1];
    
    return '${dateTime.day} $spanishMonth, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Resetear todas las estadísticas
    _resetTripStatistics();
    
    // Inicializar timers solo si el viaje está activo
    _initializeTimers();
  }
  
  // Método para verificar si el viaje realmente está activo según TripBloc
  bool _isTripActiveInBloc(BuildContext context) {
    final tripState = context.read<TripBloc>().state;
    return tripState.status == TripStatus.active && 
           tripState.currentTrip != null && 
           tripState.currentTrip!.isActive &&
           tripState.currentTrip!.id == widget.trip.id;
  }
  
  // Nuevo método para inicializar los timers
  void _initializeTimers() {
    // Cancelar timers existentes si hay alguno
    _cancelTimers();
    
    print("[ActiveTripInfoWidget] Inicializando timers para viaje ${widget.trip.id}");
    
    // Solo inicializar timers si el viaje está activo
    _isActive = widget.trip.isActive;
    
    if (_isActive) {
      // Iniciar el temporizador para actualizar el tiempo transcurrido
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted && _isActive) {
        setState(() {
            if (widget.obdState.isSimulationMode) {
              // En simulación, simplemente incrementar el tiempo en 1 segundo
              _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
            } else {
              // En modo real, calcular desde el startTime pero ajustando por zona horaria
              final now = DateTime.now().toUtc(); // Convertir a UTC para comparar
              final startTimeUtc = widget.trip.startTime.toUtc(); // Convertir a UTC
              _elapsedTime = now.difference(startTimeUtc);
            }
        });
      }
    });
      
      // Iniciar el temporizador para la captura periódica de GPS cada 10 segundos
      _gpsTimer = Timer.periodic(Duration(seconds: 10), (timer) {
        if (mounted && _isActive && !widget.obdState.isSimulationMode) {
          print("[ActiveTripInfoWidget] Ejecutando captura GPS periódica");
          _captureGpsPosition();
        }
      });
    }
  }
  
  // Método para cancelar los timers
  void _cancelTimers() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    if (_gpsTimer != null) {
      _gpsTimer!.cancel();
      _gpsTimer = null;
    }
  }
  
  // Método para resetear todas las estadísticas del viaje
  void _resetTripStatistics() {
    print("[ActiveTripInfoWidget] Reseteando estadísticas de viaje");
    _lastDistance = widget.trip.distanceInKm;
    _elapsedTime = Duration.zero;
    _lastUpdateTime = DateTime.now();
    _lastGpsCheck = DateTime.now();
    _lastBackendUpdate = DateTime.now();
    _bufferedGpsPoints = [];
  }
  
  @override
  void didUpdateWidget(ActiveTripInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Si el ID del viaje ha cambiado, significa que es un nuevo viaje
    if (widget.trip.id != oldWidget.trip.id) {
      print("[ActiveTripInfoWidget] Detectado cambio de viaje: ${oldWidget.trip.id} -> ${widget.trip.id}");
      _resetTripStatistics();
      _initializeTimers(); // Reiniciar los timers con el nuevo viaje
    }
    
    // Si cambia el estado activo del viaje, actualizar timers
    if (widget.trip.isActive != oldWidget.trip.isActive) {
      print("[ActiveTripInfoWidget] Cambio en estado activo: ${oldWidget.trip.isActive} -> ${widget.trip.isActive}");
      _isActive = widget.trip.isActive;
      
      if (_isActive) {
        _initializeTimers();
      } else {
        _cancelTimers();
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al entrar en background, cancelar timers para ahorrar recursos
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      print("[ActiveTripInfoWidget] App en background, cancelando timers");
      _cancelTimers();
    } else if (state == AppLifecycleState.resumed) {
      // Al volver a primer plano, verificar si el viaje sigue activo y reiniciar timers si es necesario
      print("[ActiveTripInfoWidget] App en primer plano, verificando estado del viaje");
      
      // Usar callback post-frame para acceder al BuildContext de manera segura
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final tripActive = _isTripActiveInBloc(context);
          if (tripActive && _isActive) {
            print("[ActiveTripInfoWidget] Viaje sigue activo, reiniciando timers");
            _initializeTimers();
          } else if (!tripActive && _isActive) {
            print("[ActiveTripInfoWidget] Viaje ya no está activo, actualizando estado");
            _isActive = false;
          }
        }
      });
    }
  }
  
    @override
  void dispose() {
    print("[ActiveTripInfoWidget] Dispose llamado para viaje ${widget.trip.id}");
    _cancelTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final isSimulation = widget.obdState.isSimulationMode;
    final tripState = context.watch<TripBloc>().state;
    
    // Verificar si el viaje realmente está activo según el TripBloc
    final isTripActiveInBloc = tripState.status == TripStatus.active && 
                           tripState.currentTrip != null && 
                           tripState.currentTrip!.isActive;
    
    // Si el viaje que nos pasaron no coincide con el viaje activo en el bloc, verificar inconsistencia
    if (!isSimulation && isTripActiveInBloc && tripState.currentTrip!.id != widget.trip.id) {
      print("[ActiveTripInfoWidget] ADVERTENCIA: ID de viaje no coincide - " +
            "Widget: ${widget.trip.id}, " +
            "Bloc: ${tripState.currentTrip!.id}");
    }
    
    // Actualizar el estado activo basado en el estado del bloc
    if (_isActive != isTripActiveInBloc && !isSimulation) {
      print("[ActiveTripInfoWidget] Actualizando _isActive: $_isActive -> $isTripActiveInBloc");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isActive = isTripActiveInBloc;
          });
          
          // Gestionar timers según el estado actualizado
          if (_isActive) {
            _initializeTimers();
          } else {
            _cancelTimers();
          }
        }
      });
    }
    
    // Si es la primera construcción y estamos en modo real, verificar que el viaje exista en el backend
    // pero solo si el BlOC no indica claramente que no hay viaje activo
    if (_isFirstBuild && !isSimulation && (isTripActiveInBloc || tripState.status != TripStatus.ready)) {
      _isFirstBuild = false;
      // Usar postFrameCallback para verificar el viaje después de completar el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _verifyTripExists(context);
        }
      });
    }
    
    // Si hemos finalizado un viaje recientemente, asegurarnos de que la UI se actualice
    if (!isSimulation && tripState.status == TripStatus.ready && widget.trip.isActive) {
      // Si el BLoC indica que no hay viaje activo pero nuestra UI muestra uno, sincronizar
      print("[ActiveTripInfoWidget] Detectada inconsistencia de UI después de finalizar un viaje");
      
      // Buscar estado del DiagnosticScreen para verificar si ya se está recuperando
      final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
      if (diagnosticScreenState != null && !diagnosticScreenState._isRequestingActiveTrip) {
        // Hacer esto una sola vez para evitar bucles
        diagnosticScreenState._isRequestingActiveTrip = true;
        
        // Forzar un timer que actualice la pantalla principal después de completar el build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            diagnosticScreenState.setState(() {
              // Este setState forzará una reconstrucción completa del árbol de widgets
              print("[ActiveTripInfoWidget] Forzando reconstrucción para sincronizar estado del viaje");
            });
          }
          
          // Restaurar bandera después de un tiempo
          Future.delayed(Duration(seconds: 3), () {
            if (diagnosticScreenState.mounted) {
              diagnosticScreenState._isRequestingActiveTrip = false;
            }
          });
        });
      }
    }
    
    // Determinar qué mostrar basado en el estado actual
    final bool shouldShowActive = isSimulation ? widget.trip.isActive : isTripActiveInBloc;
    
    // Resto del código de build sin cambios
    final hours = _elapsedTime.inHours;
    final minutes = _elapsedTime.inMinutes.remainder(60);
    final seconds = _elapsedTime.inSeconds.remainder(60);
    final durationText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    double distance;
    double fuelConsumptionRate;
    String fuelConsumptionUnit;
    
    if (isSimulation) {
      distance = _lastDistance; // Usar valor acumulado en simulación
      fuelConsumptionRate = _getSimulatedFuelConsumptionRate(widget.obdState);
      double simSpeed = _getSimulatedSpeed(widget.obdState);
      fuelConsumptionUnit = (simSpeed > 5.0) ? "L/100km" : "L/h";
      
      // No registramos datos de viaje simulado en la base de datos
    } else {
      // En modo real, usamos los datos del viaje real
      distance = _lastDistance; // Usamos nuestra copia local que se mantiene actualizada
      double fuelConsumptionLh = 0.0;
      bool fuelRateAvailable = false;
      
      if (widget.obdState.parametersData.containsKey('5E')) {
        final fuelData = widget.obdState.parametersData['5E'];
        if (fuelData != null && fuelData['value'] != null && fuelData['value'] is double) {
          fuelConsumptionLh = fuelData['value'] as double;
          fuelRateAvailable = true;
        }
      }
      
      double speedKmh = 0.0;
      if (widget.obdState.parametersData.containsKey('0D')) {
        final speedData = widget.obdState.parametersData['0D'];
        if (speedData != null && speedData['value'] != null && speedData['value'] is double) {
          speedKmh = speedData['value'] as double;
          
          // Actualizar datos del viaje real si hay velocidad > 0
          if (speedKmh > 0) {
            _updateRealTripData(context, speedKmh);
          }
        }
      }
      
      if (!fuelRateAvailable) {
        fuelConsumptionRate = 0.0;
        fuelConsumptionUnit = "N/A";
      } else if (speedKmh > 5.0) {
        fuelConsumptionRate = (fuelConsumptionLh / speedKmh) * 100;
        fuelConsumptionUnit = "L/100km";
      } else {
        fuelConsumptionRate = fuelConsumptionLh;
        fuelConsumptionUnit = "L/h";
      }
    }
    
    // Resto del código build...
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
                        Text(
                          'Viaje activo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                    if (!isSimulation)
                      Text(
                        _formatDateTime(widget.trip.startTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                    ),
                  ],
                ),
              ),
              // Botón unificado para iniciar/finalizar viaje
              ElevatedButton.icon(
                onPressed: () {
                  // Usar el estado de TripBloc para determinar la acción correcta
                  if (isTripActiveInBloc) {
                    _finishTrip(context);
                  } else {
                    // Si estamos en simulación y el widget cree que está activo pero TripBloc no
                    if (isSimulation && widget.trip.isActive) {
                      _finishTrip(context);
                    } else {
                      _startNewTrip(context);
                    }
                  }
                },
                icon: Icon(
                  // Usar el estado de TripBloc para determinar el icono
                  isTripActiveInBloc ? Icons.stop : Icons.play_arrow, 
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  // Usar el estado de TripBloc para determinar el texto
                  isTripActiveInBloc ? 'Finalizar viaje' : 'Iniciar viaje',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTripActiveInBloc ? const Color.fromARGB(255, 236, 106, 97) : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  icon: Icons.local_gas_station,
                  label: 'Consumo',
                  value: fuelConsumptionRate > 0
                      ? '${fuelConsumptionRate.toStringAsFixed(1)} $fuelConsumptionUnit'
                      : 'N/A',
                  color: Colors.orange,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          if (_bufferedGpsPoints.isNotEmpty && !isSimulation)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gps_fixed,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_bufferedGpsPoints.length} puntos pendientes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }
  
  // Método para verificar que el viaje existe en el backend
  Future<void> _verifyTripExists(BuildContext context) async {
    // Si está en modo simulación, no es necesario verificar
    if (widget.obdState.isSimulationMode) return;

    // Referencia al state del DiagnosticScreen
    final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
    if (diagnosticScreenState == null) return;

    // Si ya estamos solicitando, evitar múltiples solicitudes
    if (diagnosticScreenState._isRequestingActiveTrip) {
      print("[ActiveTripInfoWidget] Ya hay una verificación en curso, ignorando solicitud");
      return;
    }

    // Actualizar la variable pero sin llamar a setState
    diagnosticScreenState._isRequestingActiveTrip = true;
    print("[ActiveTripInfoWidget] Iniciando verificación de viaje ${widget.trip.id}");

    try {
      // Verificar si el viaje todavía está activo en la UI
      if (!widget.trip.isActive) {
        print("[ActiveTripInfoWidget] El viaje ya no está activo en la UI, cancelando verificación");
        return;
      }

      final tripBloc = context.read<TripBloc>();
      final currentState = tripBloc.state;
      
      // Si ya tenemos un viaje activo en el bloc que coincide con nuestro ID, no hay necesidad de verificar
      if (currentState.status == TripStatus.active && 
          currentState.currentTrip != null && 
          currentState.currentTrip!.isActive &&
          currentState.currentTrip!.id == widget.trip.id) {
        print("[ActiveTripInfoWidget] El viaje ya está actualizado en el bloc, omitiendo verificación");
        return;
      }

      // Comprobar si se ha finalizado recientemente un viaje
      final prefs = await SharedPreferences.getInstance();
      final lastTripEndTimeStr = prefs.getString('last_trip_end_time');
      if (lastTripEndTimeStr != null) {
        final lastTripEndTime = DateTime.parse(lastTripEndTimeStr);
        final now = DateTime.now();
        final diff = now.difference(lastTripEndTime);
        
        // Si se finalizó un viaje hace menos de 10 segundos, no verificar
        if (diff.inSeconds < 10) {
          print("[ActiveTripInfoWidget] Se finalizó un viaje hace ${diff.inSeconds} segundos, omitiendo verificación");
          return;
        }
      }
      
      // Solo ahora realizamos la verificación en el backend
      print("[ActiveTripInfoWidget] Verificando estado actual del viaje en el backend");
      tripBloc.add(GetCurrentTripEvent());
    } catch (e) {
      print("[ActiveTripInfoWidget] Error al verificar viaje: $e");
    } finally {
      // Restaurar la bandera después de un tiempo para permitir futuras verificaciones
      Future.delayed(Duration(seconds: 3), () {
        if (diagnosticScreenState.mounted) {
          diagnosticScreenState._isRequestingActiveTrip = false;
          print("[ActiveTripInfoWidget] Verificación completada, permitiendo nuevas verificaciones");
        }
      });
    }
  }
  
  // Método para finalizar un viaje activo
  void _finishTrip(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Finalizar viaje'),
        content: Text('¿Estás seguro de que deseas finalizar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Buscar el estado de DiagnosticScreen y marcar que estamos procesando
              final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
              if (diagnosticScreenState != null) {
                diagnosticScreenState._isRequestingActiveTrip = true;
              }
              
              // Enviar los puntos GPS acumulados antes de finalizar
              _sendBufferedGpsPoints(context, forceSend: true);
              
              // Cancelar los temporizadores inmediatamente para evitar cambios de estado después de finalizar
              _timer?.cancel();
              _gpsTimer?.cancel();
              
              // Mostrar indicador de carga
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      ),
                      SizedBox(width: 12),
                      Text('Finalizando viaje...'),
                    ],
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
              
              // Almacenar inmediatamente que se está finalizando un viaje para evitar verificaciones
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('last_trip_end_time', DateTime.now().toIso8601String());
              });
              
              // Finalizar el viaje a través del BLoC
              context.read<TripBloc>().add(EndTripEvent(widget.trip.id));
              
              // Después de un tiempo prudencial, forzar una actualización completa del widget tree
              Future.delayed(Duration(seconds: 2), () {
                if (diagnosticScreenState != null && diagnosticScreenState.mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (diagnosticScreenState.mounted) {
                      // Restaurar la bandera y forzar reconstrucción
                      diagnosticScreenState._isRequestingActiveTrip = false;
                      diagnosticScreenState.setState(() {
                        // La reconstrucción completa debería mostrar la UI sin viaje activo
                        print("[ActiveTripInfoWidget] Reconstruyendo UI después de finalizar viaje");
                      });
                    }
                  });
                }
              });
            },
            child: Text('Finalizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 236, 106, 97),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  // Método para actualizar datos del viaje real usando GPS y OBD
  void _updateRealTripData(BuildContext context, double speedKmh) async {
    try {
      // Ejecutar solo para viajes reales
      if (widget.obdState.isSimulationMode) return;
      
      // Obtener posición actual usando Geolocator
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 2),
      ).catchError((e) {
        print("[ActiveTripInfoWidget] Error obteniendo posición: $e");
        return null;
      });
      
      if (position != null) {
        final newPoint = GpsPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );
        
        // Calcular la distancia incrementada basada en la velocidad OBD
        final currentTime = DateTime.now();
        final secondsElapsed = currentTime.difference(_lastUpdateTime).inMilliseconds / 1000;
        _lastUpdateTime = currentTime;
        _lastGpsCheck = currentTime; // Actualizar también el tiempo de verificación GPS
        
        // Convertir km/h a km/s y multiplicar por tiempo en segundos
        final distanceInKm = (speedKmh / 3600.0) * secondsElapsed;
        
        // Siempre actualizar la distancia acumulada, aunque sea pequeña
        _lastDistance += distanceInKm;
        
        // Añadir punto GPS al buffer (sin restricción de distancia mínima)
        _bufferedGpsPoints.add(newPoint);
        print("[ActiveTripInfoWidget] Punto GPS añadido al buffer por velocidad: ${_bufferedGpsPoints.length}, lat=${newPoint.latitude}, lon=${newPoint.longitude}");
        
        // Verificar si debemos enviar los puntos al backend
        _sendBufferedGpsPointsIfNeeded(context, distanceInKm);
      }
    } catch (e) {
      print("[ActiveTripInfoWidget] Error actualizando datos del viaje real: $e");
    }
  }
  
  // Método para enviar puntos GPS al backend si se cumplen las condiciones
  void _sendBufferedGpsPointsIfNeeded(BuildContext context, double incrementalDistance) {
    // Verificar si tenemos suficientes puntos o ha pasado suficiente tiempo
    bool shouldSendByCount = _bufferedGpsPoints.length >= _maxBufferedPoints;
    bool shouldSendByTime = DateTime.now().difference(_lastBackendUpdate) > _minUpdateInterval;
    
    if (shouldSendByCount || shouldSendByTime) {
      print("[ActiveTripInfoWidget] Enviando puntos GPS porque: " + 
            (shouldSendByCount ? "máximo número alcanzado" : "tiempo superado"));
      _sendBufferedGpsPoints(context, incrementalDistance: incrementalDistance);
    }
  }
  
  // Método para enviar los puntos GPS acumulados al backend
  void _sendBufferedGpsPoints(BuildContext context, {double? incrementalDistance, bool forceSend = false}) {
    if (_bufferedGpsPoints.isEmpty) return;
    
    if (forceSend || _bufferedGpsPoints.length >= 2) {
      print("[ActiveTripInfoWidget] Enviando ${_bufferedGpsPoints.length} puntos GPS al backend");
      
      // Obtener el último punto para la actualización
      final lastPoint = _bufferedGpsPoints.last;
      
      // Si tenemos una distancia incremental, usarla, de lo contrario calcular basado en los puntos
      final distanceToAdd = incrementalDistance ?? _calculateDistanceFromPoints();
      
      // Enviar actualización al backend con el último punto
      if (distanceToAdd > 0) {
        context.read<TripBloc>().add(UpdateTripDistanceEvent(
          tripId: widget.trip.id,
          distanceInKm: distanceToAdd,
          newPoint: lastPoint,
          batchPoints: List.from(_bufferedGpsPoints), // Enviar todos los puntos acumulados
        ));
      }
      
      // Limpiar el buffer y actualizar la marca de tiempo
      _bufferedGpsPoints = [];
      _lastBackendUpdate = DateTime.now();
    }
  }
  
  // Método para calcular la distancia total basada en los puntos GPS acumulados
  double _calculateDistanceFromPoints() {
    if (_bufferedGpsPoints.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 1; i < _bufferedGpsPoints.length; i++) {
      final prevPoint = _bufferedGpsPoints[i-1];
      final currPoint = _bufferedGpsPoints[i];
      
      // Calcular distancia entre puntos con la fórmula de Haversine
      final distanceInMeters = Geolocator.distanceBetween(
        prevPoint.latitude,
        prevPoint.longitude,
        currPoint.latitude,
        currPoint.longitude,
      );
      
      totalDistance += distanceInMeters / 1000.0; // Convertir a km
    }
    
    return totalDistance;
  }
  
  // Método para enviar un punto GPS individual al backend
  void _sendGpsPointToBackend(BuildContext context, GpsPoint point) {
    // Esta implementación enviará cada punto individualmente al endpoint
    // En una versión futura, se podría crear un endpoint que acepte múltiples puntos
    try {
      // Implementar llamada al endpoint /trips/{trip_id}/gps-point directamente
      // Esto lo maneja actualmente el TripBloc cuando enviamos UpdateTripDistanceEvent
    } catch (e) {
      print("[ActiveTripInfoWidget] Error enviando punto GPS al backend: $e");
    }
  }
  
  // Métodos helper para simulación (privados de este State)
  double _getSimulatedSpeed(OBDState state) {
     if (state.parametersData.containsKey('0D')) { 
      final speedData = state.parametersData['0D'];
      if (speedData != null && speedData['value'] != null) {
        return speedData['value'] as double;
      }
    }
    return 0.0;
  }
  
  double _getSimulatedFuelConsumptionRate(OBDState state) {
    final speed = _getSimulatedSpeed(state);
    if (speed < 20) {
      return 10.0 + (_elapsedTime.inSeconds % 10) * 0.2;
    } else if (speed < 80) {
      return 7.0 + (_elapsedTime.inSeconds % 10) * 0.15;
    } else {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Nuevo método para capturar posición GPS independientemente de la velocidad
  void _captureGpsPosition() async {
    if (widget.obdState.isSimulationMode) return;
    
    try {
      print("[ActiveTripInfoWidget] Capturando posición GPS periódica...");
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 4),
      ).catchError((e) {
        print("[ActiveTripInfoWidget] Error obteniendo posición GPS: $e");
        return null;
      });
      
      if (position != null) {
        final newPoint = GpsPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );
        
        print("[ActiveTripInfoWidget] Nueva posición GPS capturada: Lat=${position.latitude}, Lon=${position.longitude}");
        
        // Añadir punto GPS al buffer
        _bufferedGpsPoints.add(newPoint);
        
        // Verificar si debemos enviar los puntos al backend
        bool shouldSendByCount = _bufferedGpsPoints.length >= _maxBufferedPoints;
        bool shouldSendByTime = DateTime.now().difference(_lastBackendUpdate) > _minUpdateInterval;
        
        if (shouldSendByCount || shouldSendByTime) {
          print("[ActiveTripInfoWidget] Enviando puntos GPS por verificación periódica");
          
          // Verificar si hay suficientes puntos para calcular la distancia
          double distanceToAdd = 0.0;
          if (_bufferedGpsPoints.length > 1) {
            distanceToAdd = _calculateDistanceFromPoints();
            _lastDistance += distanceToAdd;
          }
          
          _sendBufferedGpsPoints(context, incrementalDistance: distanceToAdd);
        }
      } else {
        print("[ActiveTripInfoWidget] No se pudo obtener posición GPS en la verificación periódica");
      }
    } catch (e) {
      print("[ActiveTripInfoWidget] Error capturando posición GPS: $e");
    }
  }
}

// Añadir método para iniciar un nuevo viaje
void _startNewTrip(BuildContext context) {
  final state = context.read<OBDBloc>().state;
  
  // Obtener _selectedVehicleId de la pantalla principal
  final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
  final selectedVehicleId = diagnosticScreenState?._selectedVehicleId;
  
  if (selectedVehicleId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selecciona un vehículo primero'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (state.isSimulationMode) {
    context.read<TripBloc>().add(StartTripEvent(selectedVehicleId));
  } else {
    // Mostrar diálogo de confirmación para viajes reales
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Iniciar viaje real'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Estás seguro de que deseas iniciar un nuevo viaje?'),
            SizedBox(height: 8),
            Text(
              'El viaje se registrará en la base de datos y actualizará el kilometraje del vehículo.',
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey[600]
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              print("[ActiveTripInfoWidget] Iniciando viaje real para vehículo: $selectedVehicleId");
              
              // Mostrar indicador de carga
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      ),
                      SizedBox(width: 12),
                      Text('Iniciando viaje...'),
                    ],
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
              
              context.read<TripBloc>().add(StartTripEvent(selectedVehicleId));
            },
            child: Text('Iniciar viaje'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
