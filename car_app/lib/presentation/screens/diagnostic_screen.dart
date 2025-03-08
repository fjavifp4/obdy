// lib/presentation/screens/diagnostic_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../../domain/entities/vehicle.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
//import '../widgets/diagnostic_card.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({Key? key}) : super(key: key);

  @override
  _DiagnosticScreenState createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with AutomaticKeepAliveClientMixin {
  bool _isInitialized = false;
  late OBDBloc _obdBloc;
  String? _selectedVehicleId;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print("[DiagnosticScreen] initState");
    _obdBloc = BlocProvider.of<OBDBloc>(context);
    _initializeOBD();
    
    // Cargar los vehículos al iniciar
    context.read<VehicleBloc>().add(LoadVehicles());
  }
  
  void _initializeOBD() {
    print("[DiagnosticScreen] Iniciando inicialización OBD");
    
    // Comprobar el estado actual antes de inicializar
    if (_obdBloc.state.status == OBDStatus.disconnected || 
        _obdBloc.state.status == OBDStatus.initial ||
        _obdBloc.state.status == OBDStatus.error) {
      print("[DiagnosticScreen] Enviando evento InitializeOBDEvent");
      _obdBloc.add(InitializeOBDEvent());
      _isInitialized = true;
    } else if (_obdBloc.state.status == OBDStatus.initialized) {
      // Solo conectamos automáticamente en modo simulación
      if (_obdBloc.state.isSimulationMode) {
        print("[DiagnosticScreen] OBD ya inicializado, conectando en modo simulación...");
        _obdBloc.add(ConnectToOBD());
      } else {
        print("[DiagnosticScreen] OBD ya inicializado en modo real, esperando conexión manual...");
      }
      _isInitialized = true;
    } else if (_obdBloc.state.status == OBDStatus.connected) {
      print("[DiagnosticScreen] OBD ya conectado, reiniciando monitoreo...");
      _startMonitoringParameters();
      _isInitialized = true;
    }
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("[DiagnosticScreen] didChangeDependencies");
  }

  @override
  void activate() {
    // Este método se llama cuando el widget se reactiva después de haber sido desactivado
    super.activate();
    print("[DiagnosticScreen] activate - Verificando conexión OBD");
    
    // Verificar si la conexión OBD sigue activa
    if (_obdBloc.state.status != OBDStatus.connected) {
      print("[DiagnosticScreen] Reconectando OBD después de activarse");
      _initializeOBD();
    } else {
      print("[DiagnosticScreen] OBD sigue conectado, restaurando monitoreo completo");
      _startMonitoringParameters();
    }
  }

  @override
  void dispose() {
    print("[DiagnosticScreen] dispose");
    super.dispose();
  }

  void _startMonitoringParameters() {
    _obdBloc.add(const StartParameterMonitoring('01 0C')); // RPM
    _obdBloc.add(const StartParameterMonitoring('01 0D')); // Velocidad
    _obdBloc.add(const StartParameterMonitoring('01 05')); // Temperatura
    _obdBloc.add(const StartParameterMonitoring('01 42')); // Voltaje
    
    // Solicitar códigos de diagnóstico (DTC) automáticamente al iniciar
    _obdBloc.add(GetDTCCodes());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return BlocProvider.value(
      value: _obdBloc,
      child: BlocListener<OBDBloc, OBDState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          print("[DiagnosticScreen] Estado OBD cambiado: ${state.status}");
          
          if (state.status == OBDStatus.initialized && state.isSimulationMode) {
            // Solo conectamos automáticamente en modo simulación
            print("[DiagnosticScreen] Conectando automáticamente en modo simulación");
            context.read<OBDBloc>().add(ConnectToOBD());
          } else if (state.status == OBDStatus.connected) {
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
                    _buildCompactVehicleSelector(isDarkMode),
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
                  _buildCompactVehicleSelector(isDarkMode),
                  
                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gauges con tamaño fijo para visibilidad óptima
                          Container(
                            height: MediaQuery.of(context).size.width * 1.05, // Asegura que se vean los 4 gauges
                            child: _buildGaugesGrid(state),
                          ),
                          
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${selectedVehicle.year} • ${selectedVehicle.licensePlate}',
                        style: TextStyle(
                          fontSize: 12,
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
      backgroundColor: isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
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
                      color: isDarkMode ? Colors.white : Colors.black87,
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
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '${vehicle.year} • ${vehicle.licensePlate}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
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
                      ? (isDarkMode ? Colors.blueGrey.shade800 : Colors.blue.shade50) 
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blueGrey.shade50,
      child: Column(
        children: [
          // Selector entre modo real y simulación
          Row(
            children: [
              Text(
              'Modo:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 16),
            Expanded(
              child: state.isLoading 
                ? Center(child: LinearProgressIndicator())
                : SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Real'),
                        icon: Icon(Icons.precision_manufacturing),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Simulación'),
                        icon: Icon(Icons.dashboard),
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
                      backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.selected)) {
                            return Theme.of(context).colorScheme.primary;
                          }
                          return null;
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
                style: TextStyle(fontWeight: FontWeight.bold),
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
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor.withOpacity(0.7),
              backgroundColor.withOpacity(0.2),
            ],
          ),
        ),
        padding: const EdgeInsets.all(4.0),
        child: gaugeWidget,
      ),
    );
  }

  Widget _buildDtcSection(OBDState state) {
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.dtcCodes.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.blue),
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
                child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
                  children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          SizedBox(height: 16),
                    Text(
            'No se encontraron códigos de error',
            style: TextStyle(
              color: Colors.green,
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
        Color codeColor = Colors.black;
        if (codeValue.startsWith('P')) codeColor = Colors.red;
        if (codeValue.startsWith('C')) codeColor = Colors.orange;
        if (codeValue.startsWith('B')) codeColor = Colors.blue;
        if (codeValue.startsWith('U')) codeColor = Colors.purple;
        
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: codeColor.withOpacity(0.2),
              child: Text(
                codeValue.substring(0, 1),
                style: TextStyle(
                  color: codeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(
              codeValue,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: codeColor,
              ),
            ),
            subtitle: description.isNotEmpty
                ? Text(description)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildRpmGauge(OBDState state) {
    final rpmValue = _getRpmValue(state);
    
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
          majorTickStyle: const MajorTickStyle(
            length: 5,
            thickness: 1.5
          ),
          minorTickStyle: const MinorTickStyle(
            length: 2,
            thickness: 0.8
          ),
          axisLabelStyle: const GaugeTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold
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
              knobStyle: const KnobStyle(
                knobRadius: 0.06,
                sizeUnit: GaugeSizeUnit.factor,
                color: Colors.white,
                borderColor: Colors.red,
                borderWidth: 0.03,
              )
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                'RPM',
                style: TextStyle(
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
                  '${rpmValue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
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
          majorTickStyle: const MajorTickStyle(
            length: 5,
            thickness: 1.5
          ),
          minorTickStyle: const MinorTickStyle(
            length: 2,
            thickness: 0.8
          ),
          axisLabelStyle: const GaugeTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold
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
              knobStyle: const KnobStyle(
                knobRadius: 0.06,
                sizeUnit: GaugeSizeUnit.factor,
                color: Colors.white,
                borderColor: Colors.red,
                borderWidth: 0.03,
              )
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                'km/h',
                style: TextStyle(
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
                  '${speedValue.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 14,
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
          axisLabelStyle: const GaugeTextStyle(
            fontSize: 8,
            color: Colors.black,
          ),
          majorTickStyle: const MajorTickStyle(
            length: 0.12,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 1.0,
            color: Colors.black
          ),
          minorTickStyle: const MinorTickStyle(
            length: 0.05,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 0.5,
            color: Colors.grey
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary, 
                  fontSize: 12,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _getTemperatureColor(tempValue),
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
                color: Colors.white,
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
          axisLabelStyle: const GaugeTextStyle(
            fontSize: 8,
            color: Colors.black,
          ),
          majorTickStyle: const MajorTickStyle(
            length: 0.12,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 1.0,
            color: Colors.black
          ),
          minorTickStyle: const MinorTickStyle(
            length: 0.05,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 0.5,
            color: Colors.grey
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary, 
                  fontSize: 14,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _getVoltageColor(voltageValue),
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
                color: Colors.white,
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
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled, 
              size: 80, 
              color: Colors.blue.withOpacity(0.6),
            ),
            SizedBox(height: 20),
            Text(
              'No hay conexión con dispositivo OBD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'En modo real, necesitas conectar un dispositivo OBD\npara ver los datos del vehículo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            // Mostrar mensaje de error si existe
            if (_obdBloc.state.error != null && _obdBloc.state.error!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _obdBloc.state.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Mostrar diálogo de selección de dispositivo Bluetooth
                    context.read<OBDBloc>().add(ConnectToOBD());
                  },
                  icon: Icon(Icons.bluetooth_searching),
                  label: Text('Conectar Dispositivo OBD'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}