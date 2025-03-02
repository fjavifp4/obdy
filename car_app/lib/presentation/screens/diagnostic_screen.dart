// lib/presentation/screens/diagnostic_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/obd/obd_bloc.dart';
import '../blocs/obd/obd_event.dart';
import '../blocs/obd/obd_state.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../domain/entities/obd_data.dart';
import '../../domain/repositories/obd_repository.dart';
import 'package:get_it/get_it.dart';
import '../../presentation/blocs/service_locator.dart';
//import '../widgets/diagnostic_card.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({Key? key}) : super(key: key);

  @override
  _DiagnosticScreenState createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with AutomaticKeepAliveClientMixin {
  bool _isInitialized = false;
  late OBDBloc _obdBloc;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print("[DiagnosticScreen] initState");
    _obdBloc = BlocProvider.of<OBDBloc>(context);
    _initializeOBD();
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
      print("[DiagnosticScreen] OBD ya inicializado, conectando...");
      _obdBloc.add(ConnectToOBD());
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
    
    return BlocProvider.value(
      value: _obdBloc,
      child: BlocListener<OBDBloc, OBDState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          print("[DiagnosticScreen] Estado OBD cambiado: ${state.status}");
          
          if (state.status == OBDStatus.initialized) {
            print("[DiagnosticScreen] Enviando evento ConnectToOBD");
            context.read<OBDBloc>().add(ConnectToOBD());
          } else if (state.status == OBDStatus.connected) {
            // Iniciar monitoreo de parámetros importantes
            Future.delayed(const Duration(milliseconds: 500), () {
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
            
            // Mostrar contenido principal - sin AppBar
            return SafeArea(
              child: Column(
                children: [
                  _buildStatusHeader(state),
                  // Contenedor para los gauges (65% de la pantalla)
                  Expanded(
                    flex: 65,
                    child: _buildGaugesGrid(state),
                  ),
                  // Divisor
                  Divider(thickness: 2, color: Colors.blueGrey.shade200),
                  // Contenedor para los DTC (35% de la pantalla)
                  Expanded(
                    flex: 35,
                    child: _buildDtcSection(state),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildStatusHeader(OBDState state) {
    Color statusColor = Colors.grey;
    if (state.status == OBDStatus.connected) {
      statusColor = Colors.green;
    } else if (state.status == OBDStatus.error) {
      statusColor = Colors.red;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.blueGrey.shade50,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Estado: ${_getStatusText(state.status)}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Spacer(),
          Text(
            'Diagnóstico OBD',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugesGrid(OBDState state) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.0,
      padding: EdgeInsets.all(8),
      physics: NeverScrollableScrollPhysics(),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: _buildRpmGauge(state),
          ),
        ),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: _buildSpeedGauge(state),
          ),
        ),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: _buildTemperatureGauge(state),
          ),
        ),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: _buildVoltageGauge(state),
          ),
        ),
      ],
    );
  }

  Widget _buildDtcSection(OBDState state) {
    return Container(
      padding: EdgeInsets.all(12),
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
          Expanded(
            child: _buildDtcList(state),
          ),
        ],
      ),
    );
  }

  Widget _buildDtcList(OBDState state) {
    if (state.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (state.dtcCodes.isEmpty) {
      return Center(
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
    
    return ListView.builder(
      itemCount: state.dtcCodes.length,
      itemBuilder: (context, index) {
        final dtcCode = state.dtcCodes[index];
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
      title: GaugeTitle(
        text: 'RPM',
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 8000,
          labelOffset: 15,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 1000, color: Colors.green),
            GaugeRange(startValue: 1000, endValue: 5000, color: Colors.orange),
            GaugeRange(startValue: 5000, endValue: 8000, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: rpmValue,
              enableAnimation: true,
              animationDuration: 100,
              needleColor: Colors.red,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '$rpmValue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedGauge(OBDState state) {
    final speedValue = _getSpeedValue(state);
    
    return SfRadialGauge(
      title: GaugeTitle(
        text: 'Velocidad (km/h)',
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 240,
          labelOffset: 15,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 80, color: Colors.green),
            GaugeRange(startValue: 80, endValue: 120, color: Colors.orange),
            GaugeRange(startValue: 120, endValue: 240, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: speedValue,
              enableAnimation: true,
              animationDuration: 100,
              needleColor: Colors.blue,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '$speedValue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemperatureGauge(OBDState state) {
    final tempValue = _getTemperatureValue(state);
    
    return SfRadialGauge(
      title: GaugeTitle(
        text: 'Temperatura (°C)',
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 140,
          labelOffset: 15,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 60, color: Colors.blue),
            GaugeRange(startValue: 60, endValue: 95, color: Colors.green),
            GaugeRange(startValue: 95, endValue: 140, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: tempValue,
              enableAnimation: true,
              animationDuration: 100,
              needleColor: Colors.orange,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '$tempValue °C',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoltageGauge(OBDState state) {
    final voltageValue = _getVoltageValue(state);
    
    return SfRadialGauge(
      title: GaugeTitle(
        text: 'Voltaje de Batería (V)',
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 8,
          maximum: 16,
          labelOffset: 15,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 8, endValue: 11.5, color: Colors.red),
            GaugeRange(startValue: 11.5, endValue: 15, color: Colors.green),
            GaugeRange(startValue: 15, endValue: 16, color: Colors.orange),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: voltageValue,
              enableAnimation: true,
              animationDuration: 100,
              needleColor: Colors.purple,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '$voltageValue V',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
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
}