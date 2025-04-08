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
import 'package:car_app/domain/entities/obd_data.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme/theme_config.dart';
import '../widgets/background_container.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  _DiagnosticScreenState createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isInitialized = false;
  late OBDBloc obdBloc; // <-- Hacer pública la variable
  late TripBloc _tripBloc;
  String? selectedVehicleId; // <-- Hacer pública la variable
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
    
    // Usar nombre público para asignar
    obdBloc = BlocProvider.of<OBDBloc>(context);
    _tripBloc = BlocProvider.of<TripBloc>(context);
    _wasInSimulationMode = obdBloc.state.isSimulationMode; // <-- Usar nombre público
    
    // Cargar los vehículos al iniciar
    context.read<VehicleBloc>().add(LoadVehicles());
    
    // Cargar el vehículo seleccionado de preferencias
    _loadSelectedVehicle();
    
    // Inicializar el OBD solo si no está ya conectado
    if (obdBloc.state.status != OBDStatus.connected) { // <-- Usar nombre público
      obdBloc.add(InitializeOBDEvent()); // <-- Usar nombre público
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
    
    // Usar nombre público
    if (obdBloc.state.status == OBDStatus.connected && 
        (obdBloc.state.parametersData.isEmpty || 
         !obdBloc.state.parametersData.containsKey('0C'))) { 
      print("[DiagnosticScreen] Reiniciando monitoreo de parámetros tras volver a la pantalla");
      _startMonitoringParameters();
    }
  }

  void _startMonitoringParameters() {
    // Usar la referencia obdBloc
    
    // Lista de PIDs a monitorear (SIN prefijo 01)
    final pids = [
      '0C', // RPM
      '0D', // Velocidad
      '05', // Temperatura
      '42', // Voltaje
    ];
    
    // Usar nombre público
    for (final pid in pids) {
      obdBloc.add(StartParameterMonitoring(pid)); 
    }
  }

  void _stopParameterMonitoring() {
    print("[DiagnosticScreen] Deteniendo monitoreo de todos los PIDs");
    final allPids = [..._essentialPids, ..._nonEssentialPids];
    // Usar nombre público
    for (final pid in allPids) {
      obdBloc.add(StopParameterMonitoring(pid)); 
    }
    _isMonitoringActive = false; // Marcar como inactivo
  }

  void _onConnectPressed() {
    // Usar la referencia obdBloc
    
    if (obdBloc.state.status == OBDStatus.connected) {
      // Si está conectado, desconectar
      obdBloc.add(const DisconnectFromOBD());
      _stopParameterMonitoring();
    } else {
      // Si no está conectado, inicializar y conectar
      obdBloc.add(InitializeOBDEvent());
    }
  }

  void _onSimulationToggled() {
    // Usar la referencia obdBloc
    obdBloc.add(const ToggleSimulationMode());
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
          selectedVehicleId = vehicleId; // <-- Usar nombre público
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
      setState(() { // Actualizar UI también
         selectedVehicleId = vehicleId; // <-- Usar nombre público
      });
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
    if (obdBloc.state.isSimulationMode) {
      print("[DiagnosticScreen] Modo simulación detectado, conectando automáticamente");
      obdBloc.add(InitializeOBDEvent());
      obdBloc.add(ConnectToOBD());
    } else {
      // En modo real, solo inicializar y esperar conexión manual
      print("[DiagnosticScreen] Modo real detectado, esperando conexión manual");
      obdBloc.add(InitializeOBDEvent());
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
        body: BackgroundContainer(
          child: MultiBlocListener(
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
            if (state.isSimulationMode && selectedVehicleId != null) {
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
            value: obdBloc,
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
          if (selectedVehicleId == null && state.vehicles.isNotEmpty) {
            selectedVehicleId = state.vehicles.first.id;
          }
          
          // Obtener el vehículo seleccionado actualmente
          final selectedVehicle = state.vehicles.firstWhere(
            (v) => v.id == selectedVehicleId,
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

  void _showVehicleSelectionModal(BuildContext context, List<Vehicle> vehicles, bool isDarkMode) async {
    // Primero verificar si hay un viaje activo
    bool canProceed = await _checkForActiveTrip(context, 'Cambiar de vehículo');
    
    if (!canProceed) {
      print("[DiagnosticScreen] Cambio de vehículo cancelado porque hay un viaje activo");
      return;
    }
    
    // Continuar con la lógica original
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
                  final isSelected = vehicle.id == selectedVehicleId;
                  
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
                      if (vehicle.id != selectedVehicleId) {
                        setState(() {
                          selectedVehicleId = vehicle.id;
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
            if (obdBloc.state.error != null && obdBloc.state.error!.isNotEmpty)
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
                    obdBloc.state.error!,
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
    final hasVehicle = selectedVehicleId != null;
    
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
    final currentTime = DateTime.now();
    
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1F2024) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                    Text(
                      'Último: ${_formatDateTime(currentTime)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ElevatedButton.icon(
                onPressed: hasVehicle
                  ? () {
                      // Iniciar viaje manualmente al presionar el botón
                      state.isSimulationMode
                        ? context.read<TripBloc>().add(StartTripEvent(selectedVehicleId!))
                        : _showRealTripConfirmationDialog(context);
                    } 
                  : null,
                icon: Icon(Icons.play_arrow, size: 18, color: Theme.of(context).colorScheme.onPrimary),
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
              print("[DiagnosticScreen] Iniciando viaje real para vehículo: $selectedVehicleId");
              
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
              
              context.read<TripBloc>().add(StartTripEvent(selectedVehicleId!));
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
            obdBloc.add(const DisconnectFromOBD());
            
            // Esperar brevemente y reconectar
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              print("[DiagnosticScreen] Reconectando OBD después de desconexión...");
              obdBloc.add(InitializeOBDEvent());
              
              Future.delayed(const Duration(seconds: 1), () {
                if (!mounted) return;
                obdBloc.add(ConnectToOBD());
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
          onSelectionChanged: (Set<bool> selection) async {
            // Evitamos eventos múltiples mientras estamos cargando
            if (!state.isLoading) {
              bool simulationValue = selection.first;
              
              // Si intentamos cambiar de modo y este cambio es distinto del actual
              if (simulationValue != state.isSimulationMode) {
                // Verificar si hay un viaje activo
                bool canProceed = await _checkForActiveTrip(
                  context, 
                  state.isSimulationMode 
                      ? 'Cambiar a modo real' 
                      : 'Cambiar a modo simulación'
                );
                
                if (!canProceed) {
                  print("[DiagnosticScreen] Cambio de modo cancelado porque hay un viaje activo");
                  return;
                }
                
                // Si podemos proceder, realizar el cambio
                context.read<OBDBloc>().add(const ToggleSimulationMode());
              }
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
            final selectedVehicle = vehicles.firstWhereOrNull((v) => v.id == selectedVehicleId);
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

  Widget _buildLoadingTripCard(BuildContext context, bool isDarkMode, String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1F2024) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildCompletedTripSummary(BuildContext context, Trip trip, bool isDarkMode) {
    final hours = trip.durationSeconds ~/ 3600;
    final minutes = (trip.durationSeconds % 3600) ~/ 60;
    final seconds = trip.durationSeconds % 60;
    final durationText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1F2024) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen del viaje',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: Theme.of(context).textTheme.labelSmall,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () {
                  context.read<OBDBloc>().add(GetDTCCodes());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
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
  // Timers
  Timer? _elapsedTimer;
  Timer? _gpsCaptureTimer;
  Timer? _periodicUpdateTimer;

  // Estado local del viaje (acumulado)
  Duration _elapsedTime = Duration.zero;
  double _accumulatedDistanceKm = 0.0;
  double _accumulatedFuelLiters = 0.0;
  double _averageSpeedKmh = 0.0;
  List<GpsPoint> _bufferedGpsPoints = []; // Buffer para puntos GPS
  
  // Variables de control
  DateTime _lastUpdateTime = DateTime.now();
  DateTime _lastPeriodicUpdate = DateTime.now(); // <-- _lastBackendUpdate eliminada
  
  // Configuración
  final int _maxBufferedPoints = 10; // Puntos GPS a acumular antes de forzar envío
  final Duration _minGpsCaptureInterval = Duration(seconds: 10); // Intervalo captura GPS
  final Duration _periodicUpdateInterval = Duration(seconds: 20); // Intervalo envío backend
  
  bool _isActive = false; // Para saber si este widget debe estar activo y timers corriendo

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
    print("[ActiveTripInfoWidget] initState para viaje: ${widget.trip.id}");
    _resetTripStatistics();
    _initializeTimersIfNeeded();
  }

  // Método para verificar si el viaje realmente está activo según TripBloc
  bool _isTripActiveInBloc(BuildContext context) {
    // Usar read para obtener el estado actual sin suscribirse
    final tripState = context.read<TripBloc>().state;
    return tripState.status == TripStatus.active && 
           tripState.currentTrip != null && 
           tripState.currentTrip!.isActive &&
           tripState.currentTrip!.id == widget.trip.id;
  }

  void _initializeTimersIfNeeded() {
    // Determinar si los timers deberían estar activos
    final shouldBeActive = widget.trip.isActive && _isTripActiveInBloc(context);
    
    if (shouldBeActive && !_isActive) {
      // Pasar de inactivo a activo: Iniciar timers
      print("[ActiveTripInfoWidget] Inicializando timers para viaje ${widget.trip.id}");
      _isActive = true;
      _lastUpdateTime = DateTime.now(); // Reiniciar para cálculo de delta
      
      _cancelTimers(); // Asegurarse de que no haya timers previos
      
      // Timer para actualizar el tiempo transcurrido y acumular datos (1 segundo)
      _elapsedTimer = Timer.periodic(Duration(seconds: 1), _updateElapsedTimeAndAccumulateData);
      
      // Timer para la captura periódica de GPS (solo si no es simulación)
      if (!widget.obdState.isSimulationMode) {
        _gpsCaptureTimer = Timer.periodic(_minGpsCaptureInterval, (timer) => _captureGpsPosition());
        _captureGpsPosition(); // Capturar una posición inicial al empezar
      }
      
      // Timer para enviar actualizaciones periódicas al backend
      _periodicUpdateTimer = Timer.periodic(_periodicUpdateInterval, (timer) => _sendPeriodicUpdate());
      _lastPeriodicUpdate = DateTime.now(); // Resetear tiempo de última actualización
      
    } else if (!shouldBeActive && _isActive) {
      // Pasar de activo a inactivo: Cancelar timers
      print("[ActiveTripInfoWidget] Viaje ya no activo (${widget.trip.id}), cancelando timers");
      _cancelTimers();
      _isActive = false;
    }
    // Si shouldBeActive == _isActive, no hacer nada (estado consistente)
  }

  void _cancelTimers() {
    _elapsedTimer?.cancel();
    _gpsCaptureTimer?.cancel();
    _periodicUpdateTimer?.cancel();
    _elapsedTimer = null;
    _gpsCaptureTimer = null;
    _periodicUpdateTimer = null;
    print("[ActiveTripInfoWidget] Timers cancelados");
  }

  void _resetTripStatistics() {
    print("[ActiveTripInfoWidget] Reseteando estadísticas locales para viaje ${widget.trip.id}");
    // Usar datos del widget.trip como estado inicial
    _elapsedTime = widget.trip.endTime != null 
        ? widget.trip.endTime!.difference(widget.trip.startTime) 
        : Duration(seconds: widget.trip.durationSeconds); // Usar duración si no hay endTime
    _accumulatedDistanceKm = widget.trip.distanceInKm;
    _accumulatedFuelLiters = widget.trip.fuelConsumptionLiters;
    _averageSpeedKmh = widget.trip.averageSpeedKmh;
    _bufferedGpsPoints = [];
    _lastUpdateTime = DateTime.now();
    _lastPeriodicUpdate = DateTime.now();
  }
  
  // --- Lógica de Ciclo de Vida y Actualización --- 

  @override
  void didUpdateWidget(ActiveTripInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("[ActiveTripInfoWidget] didUpdateWidget: Old=${oldWidget.trip.id}, New=${widget.trip.id}, Active=${widget.trip.isActive}");
    
    // Si el ID del viaje cambia, resetear todo y reiniciar timers
    if (widget.trip.id != oldWidget.trip.id) {
      print("[ActiveTripInfoWidget] CAMBIO DE VIAJE DETECTADO");
      _cancelTimers();
      _resetTripStatistics();
      _initializeTimersIfNeeded(); // Esto decidirá si iniciar timers basado en el nuevo viaje
    } else {
       // Si el ID es el mismo, pero cambia el estado activo, reevaluar timers
       if (widget.trip.isActive != oldWidget.trip.isActive || widget.obdState != oldWidget.obdState) {
           print("[ActiveTripInfoWidget] Cambio detectado (isActive o obdState), reevaluando timers...");
           _initializeTimersIfNeeded();
       }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      if (_isActive) {
        print("[ActiveTripInfoWidget] App en background, cancelando timers y enviando update final si hay datos");
        if (_bufferedGpsPoints.isNotEmpty) {
          _sendPeriodicUpdate(forceSend: true); // Enviar datos pendientes
        }
        _cancelTimers();
        _isActive = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      print("[ActiveTripInfoWidget] App en primer plano, verificando estado y reiniciando timers si es necesario");
      // Esperar a que el frame se construya para acceder al context
      WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
          _initializeTimersIfNeeded();
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
  
  // --- Lógica de Acumulación y Actualización --- 

  void _updateElapsedTimeAndAccumulateData(Timer timer) {
     if (!mounted || !_isActive) {
      print("[ActiveTripInfoWidget] _updateElapsedTime llamado pero widget no montado o inactivo. Cancelando timer.");
      _cancelTimers(); // Cancelar todos por seguridad
      return;
    }

    final now = DateTime.now();
    final timeDiffSeconds = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    if (timeDiffSeconds <= 0) return; // Evitar cálculos si no ha pasado tiempo

    // Obtener datos OBD necesarios ANTES del setState
    final speedKmh = _getCurrentSpeedKmh();
    final fuelRateLph = _getCurrentFuelRateLph(); // L/h

    setState(() {
      // 1. Actualizar Tiempo Transcurrido
       if (widget.obdState.isSimulationMode) {
         // En simulación, sumar el delta de tiempo real
         _elapsedTime += Duration(milliseconds: (timeDiffSeconds * 1000).round());
       } else {
         // En modo real, calcular desde el startTime del viaje
         _elapsedTime = now.difference(widget.trip.startTime);
       }

      // 2. Acumular Distancia (solo si hay velocidad)
      if (speedKmh > 0) {
        final distanceIncrementKm = (speedKmh / 3600.0) * timeDiffSeconds;
        _accumulatedDistanceKm += distanceIncrementKm;
      }
      
      // 3. Acumular Consumo (siempre que haya tasa)
      if (fuelRateLph > 0) {
        final fuelIncrementLiters = (fuelRateLph / 3600.0) * timeDiffSeconds;
        _accumulatedFuelLiters += fuelIncrementLiters;
      }

      // 4. Recalcular Velocidad Media
      final totalHours = _elapsedTime.inSeconds / 3600.0;
      _averageSpeedKmh = (totalHours > 0) ? _accumulatedDistanceKm / totalHours : 0.0;
      
      // Actualizar marca de tiempo para el próximo cálculo
      _lastUpdateTime = now;
    });
  }
  
  // Método para obtener la velocidad actual desde OBDState
  double _getCurrentSpeedKmh() {
    if (widget.obdState.isSimulationMode) {
      return _getSimulatedSpeed(widget.obdState); // Usar método helper si existe
    }
    // En modo real
        final speedData = widget.obdState.parametersData['0D'];
    if (speedData != null && speedData['value'] is num) {
      return (speedData['value'] as num).toDouble();
    }
    return 0.0;
  }

  // Método para obtener el consumo instantáneo desde OBDState (con fallback)
  double _getCurrentFuelRateLph() {
     if (widget.obdState.isSimulationMode) {
       // En modo simulación, calcular basado en velocidad y RPM
       final speed = _getCurrentSpeedKmh();
       if (speed < 1.0) {
         // En ralentí
         return 0.8 + ((_elapsedTime.inSeconds % 10) * 0.05); // 0.8-1.3 L/h en ralentí
       } else if (speed < 60) {
         // Ciudad
         return 5.0 + (speed / 15.0) + ((_elapsedTime.inSeconds % 10) * 0.2); // ~5-9 L/h
       } else if (speed < 100) {
         // Mixto
         return 6.0 + (speed / 25.0) + ((_elapsedTime.inSeconds % 10) * 0.3); // ~6-12 L/h
      } else {
         // Carretera
         return 7.0 + ((speed - 100) / 30.0) + ((_elapsedTime.inSeconds % 10) * 0.4); // ~7-15 L/h
       }
    }
    
    // En modo real
    final fuelRateData = widget.obdState.parametersData['5E'];
    if (fuelRateData != null && fuelRateData['value'] is num) {
      final value = (fuelRateData['value'] as num).toDouble();
      return value;
    }
    
    // Si no hay datos, devolver un valor simulado basado en la velocidad actual
    final speed = _getCurrentSpeedKmh();
    if (speed < 1.0) return 0.8; // Ralentí
    if (speed < 60) return 5.0 + (speed / 15.0); // Ciudad
    if (speed < 100) return 6.0 + (speed / 25.0); // Mixto
    return 7.0 + ((speed - 100) / 30.0); // Carretera
  }
  
  // --- Lógica de GPS --- 

  void _captureGpsPosition() async {
    if (!mounted || !_isActive || widget.obdState.isSimulationMode) return;

    try {
      print("[ActiveTripInfoWidget] Capturando posición GPS periódica...");
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8), // Un poco más de tiempo límite
      ).catchError((e) {
        print("[ActiveTripInfoWidget] Error obteniendo posición GPS: $e");
        // Considerar si reintentar o esperar al siguiente ciclo
        return null;
      });

      if (position != null) {
        final newPoint = GpsPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(), // Usar hora actual de captura
        );
        // Añadir al buffer SI la precisión es aceptable (opcional)
        if (position.accuracy < 100) { // Ejemplo: ignorar puntos con precisión > 100m
           _bufferedGpsPoints.add(newPoint);
           print("[ActiveTripInfoWidget] Punto GPS añadido al buffer (${_bufferedGpsPoints.length} puntos)");
           // Forzar envío si el buffer está lleno
           if (_bufferedGpsPoints.length >= _maxBufferedPoints) {
             print("[ActiveTripInfoWidget] Buffer GPS lleno, forzando envío periódico.");
             _sendPeriodicUpdate(forceSend: true);
           }
      } else {
          print("[ActiveTripInfoWidget] Punto GPS descartado por baja precisión (${position.accuracy}m)");
        }
      } else {
        print("[ActiveTripInfoWidget] No se pudo obtener posición GPS en esta captura.");
      }
    } catch (e) {
      print("[ActiveTripInfoWidget] Excepción capturando posición GPS: $e");
    }
  }

  // --- Lógica de Envío al Backend --- 

  void _sendPeriodicUpdate({bool forceSend = false}) {
     if (!mounted) return; // Si no está montado, no hacer nada
     // Si no estamos activos pero forzamos (ej. al finalizar), proceder
     if (!_isActive && !forceSend) return; 

     final now = DateTime.now();
     // Comprobar si forzamos o si ha pasado el intervalo
     if (!forceSend && now.difference(_lastPeriodicUpdate) < _periodicUpdateInterval) {
       return; // Aún no es tiempo
     }

     if (_bufferedGpsPoints.isEmpty && !forceSend) {
       print("[ActiveTripInfoWidget] No hay puntos GPS nuevos para enviar en actualización periódica.");
       _lastPeriodicUpdate = now; // Actualizar tiempo aunque no enviemos
       return;
     }

     print("[ActiveTripInfoWidget] Enviando actualización periódica al backend...");

     // Crear copia del buffer y limpiarlo
     final pointsToSend = List<GpsPoint>.from(_bufferedGpsPoints);
     _bufferedGpsPoints = [];

     // Enviar evento al Bloc
     context.read<TripBloc>().add(UpdatePeriodicTripEvent(
       tripId: widget.trip.id,
       batchPoints: pointsToSend,
       totalDistance: _accumulatedDistanceKm,
       totalFuelConsumed: _accumulatedFuelLiters,
       averageSpeed: _averageSpeedKmh,
       durationSeconds: _elapsedTime.inSeconds,
     ));

     // Actualizar marca de tiempo
     _lastPeriodicUpdate = now;
  }

  // --- Finalizar Viaje --- 
  
  void _finishTrip(BuildContext context) {
    // Mostrar diálogo de confirmación
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Finalizar viaje'),
        content: Text('¿Estás seguro de que deseas finalizar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              print("[ActiveTripInfoWidget] Finalizando viaje ${widget.trip.id}");

              // Marcar que estamos procesando para evitar acciones concurrentes
              final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
              if (diagnosticScreenState != null) {
                diagnosticScreenState._isRequestingActiveTrip = true;
              }

              // 1. Cancelar timers inmediatamente
              _cancelTimers();
              _isActive = false;
              
              // 2. Enviar última actualización periódica con datos restantes
              _sendPeriodicUpdate(forceSend: true); 

              // 3. Mostrar SnackBar de carga
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [ 
                    SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                    ), 
                    SizedBox(width: 12), 
                    Text('Finalizando viaje...')
                  ]),
                  duration: Duration(seconds: 5),
                ),
              );
              
              // 4. Guardar tiempo para evitar verificaciones inmediatas
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('last_trip_end_time', DateTime.now().toIso8601String());
              });

              // 5. Disparar evento de finalización en el Bloc
              context.read<TripBloc>().add(EndTripEvent(widget.trip.id));
              
              // 6. (Opcional) Forzar reconstrucción UI después de un delay
              Future.delayed(Duration(seconds: 2), () {
                if (diagnosticScreenState != null && diagnosticScreenState.mounted) {
                   diagnosticScreenState._isRequestingActiveTrip = false;
                   diagnosticScreenState.setState(() {});
                }
              });
            },
            child: Text('Finalizar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400], foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
  
  // --- Build Method --- 

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    final isSimulation = widget.obdState.isSimulationMode;
    final tripState = context.watch<TripBloc>().state;

    // Verificar si este widget debe estar activo
    final bool shouldBeActive = tripState.status == TripStatus.active && 
                             tripState.currentTrip != null && 
                             tripState.currentTrip!.isActive &&
                             tripState.currentTrip!.id == widget.trip.id;
                             
    // Si el estado del bloc indica que no deberíamos estar activos, pero _isActive es true,
    // forzar cancelación de timers post-frame.
    if (!_isActive && shouldBeActive) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initializeTimersIfNeeded();
      });
    } else if (_isActive && !shouldBeActive) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print("[ActiveTripInfoWidget] Detectada inconsistencia (Bloc inactivo, widget activo). Cancelando timers.");
          _cancelTimers();
          _isActive = false;
          // Podríamos forzar un setState si es necesario, pero el watch del bloc debería reconstruir
        }
      });
    }
    
    // Obtener datos para mostrar (usar estado local acumulado)
    final durationText = _formatDuration(_elapsedTime);
    final distance = _accumulatedDistanceKm;
    final speedKmh = _getCurrentSpeedKmh(); // Velocidad instantánea para cálculo de consumo
    final fuelRateLph = _getCurrentFuelRateLph(); // Consumo instantáneo
    
    // Calcular consumo L/100km o L/h para mostrar
    double displayFuelConsumptionRate = 0;
    String fuelConsumptionUnit = 'L/100km';
    if (speedKmh > 5) { // Mostrar L/100km si se mueve
      if (fuelRateLph > 0) { // Evitar división por cero
        displayFuelConsumptionRate = (fuelRateLph / speedKmh) * 100;
      }
    } else { // Mostrar L/h si está parado o muy lento
      displayFuelConsumptionRate = fuelRateLph;
      fuelConsumptionUnit = 'L/h';
    }

    // Formatear hora de inicio
    final formattedStartTime = _formatDateTime(widget.trip.startTime);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1F2024) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                    'Viaje Activo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Iniciado: $formattedStartTime',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Usar shouldBeActive para la lógica del botón
                  if (shouldBeActive) {
                    _finishTrip(context);
                  } else {
                    // Si estamos en simulación y el widget cree que está activo pero TripBloc no
                    if (isSimulation && widget.trip.isActive) {
                      _finishTrip(context); // Intentar finalizar de todas formas
                    } else {
                       // Intentar iniciar un nuevo viaje (requiere ID de vehículo)
                       final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
                       if (diagnosticScreenState?.selectedVehicleId != null) {
                          _startNewTrip(context); 
                       } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Selecciona un vehículo para iniciar un viaje.'),
                            backgroundColor: Colors.orange,
                          ));
                       }
                    }
                  }
                },
                icon: Icon(
                  shouldBeActive ? Icons.stop : Icons.play_arrow, 
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  shouldBeActive ? 'Finalizar viaje' : 'Iniciar viaje',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: shouldBeActive ? Colors.red[400] : Theme.of(context).colorScheme.primary,
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
                  value: '${displayFuelConsumptionRate.toStringAsFixed(1)} $fuelConsumptionUnit',
                  color: Colors.orange,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
          // Mostrar puntos pendientes solo si hay y no es simulación
          if (_bufferedGpsPoints.isNotEmpty && !isSimulation)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gps_not_fixed, // Cambiado icono
                    size: 14,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_bufferedGpsPoints.length} puntos GPS pendientes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }
  
  // --- Métodos Helper --- 

  // Helper para formatear duración
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  // Método para construir cada item de estadística
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
         // Usar AppTheme aquí también si es necesario
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // --- Métodos de Simulación (Adaptar si es necesario) --- 
  // Estos métodos ya existen y podrían necesitar ajustarse si la lógica de simulación cambia
  
   double _getSimulatedSpeed(OBDState state) {
     if (state.parametersData.containsKey('0D')) { 
      final speedData = state.parametersData['0D'];
      if (speedData != null && speedData['value'] is num) {
        return (speedData['value'] as num).toDouble();
      }
    }
    // Devolver una velocidad simulada si no hay datos OBD
    return 30.0 + (_elapsedTime.inSeconds % 30);
  }
  
  double _getSimulatedFuelConsumptionRate(OBDState state) {
    final speed = _getSimulatedSpeed(state);
    if (speed < 20) {
      return 1.5 + (_elapsedTime.inSeconds % 10) * 0.1; // Ralentí/baja velocidad
    } else if (speed < 80) {
      return 7.0 + (_elapsedTime.inSeconds % 10) * 0.15; // Velocidad media
    } else {
      return 9.5 + (_elapsedTime.inSeconds % 10) * 0.1; // Alta velocidad
    }
  }
  
}

// Añadir método para iniciar un nuevo viaje
void _startNewTrip(BuildContext context) {
  final diagnosticScreenState = context.findAncestorStateOfType<_DiagnosticScreenState>();
  final selectedVehicleId = diagnosticScreenState?.selectedVehicleId; // <-- Usar nombre público

  if (selectedVehicleId == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Selecciona un vehículo primero'),
      backgroundColor: Colors.orange,
    ));
    return;
  }
  
  if (diagnosticScreenState?.obdBloc.state.isSimulationMode == true) {
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

// Este método verifica si hay un viaje activo y muestra un diálogo de advertencia
Future<bool> _checkForActiveTrip(BuildContext context, String action) async {
  // Verificar si hay un viaje activo en el TripBloc
  final tripState = context.read<TripBloc>().state;
  
  if (tripState.currentTrip != null && tripState.currentTrip!.isActive) {
    // Hay un viaje activo, mostrar diálogo de advertencia
    bool proceed = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Viaje en curso'),
          content: Text('Hay un viaje activo en progreso. $action requiere finalizar el viaje actual. ¿Deseas continuar?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // No continuar
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Continuar y finalizar el viaje
              },
              child: const Text('Finalizar viaje y continuar'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (proceed) {
      // Finalizar el viaje si el usuario decide continuar
      context.read<TripBloc>().add(EndTripEvent(tripState.currentTrip!.id));
      
      // Esperar a que el viaje se complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mostrar snackbar de confirmación
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viaje finalizado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return true; // Proceder con la acción original
    } else {
      return false; // No proceder con la acción original
    }
  }
  
  return true; // No hay viaje activo, proceder con normalidad
}
