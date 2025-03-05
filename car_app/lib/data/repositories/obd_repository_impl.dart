import 'dart:async';
import 'package:car_app/domain/entities/obd_data.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';
import 'package:flutter/services.dart';
// Importar el plugin con try/catch para evitar errores de compilación si falta
OBD2Plugin? _obd2Plugin;

/// Implementación real del OBDRepository que se conecta con dispositivos OBD físicos
/// a través del plugin OBD2.
class OBDRepositoryImpl implements OBDRepository {
  bool _isInitialized = false;
  bool _isConnected = false;
  
  // Los streams para diferentes parámetros
  final Map<String, StreamController<OBDData>> _streamControllers = {};
  
  // Configuración de PID para los parámetros que queremos monitorear
  final Map<String, Map<String, String>> _pidConfigs = {
    '01 0C': {  // RPM
      'unit': 'RPM',
      'description': 'Revoluciones del motor',
    },
    '01 0D': {  // Velocidad
      'unit': 'km/h',
      'description': 'Velocidad del vehículo',
    },
    '01 05': {  // Temperatura
      'unit': '°C',
      'description': 'Temperatura del refrigerante',
    },
    '01 42': {  // Voltaje
      'unit': 'V',
      'description': 'Voltaje de la batería',
    },
  };
  
  OBDRepositoryImpl() {
    _checkPluginAvailability();
  }
  
  // Verificar si el plugin está disponible
  void _checkPluginAvailability() {
    try {
      _obd2Plugin = loadOBD2Plugin();
      print("[OBDRepositoryImpl] Plugin OBD2 cargado correctamente");
    } catch (e) {
      print("[OBDRepositoryImpl] Error al cargar el plugin OBD2: $e");
      _obd2Plugin = null;
    }
  }
  
  // Método para cargar el plugin que puede ser reemplazado en pruebas
  OBD2Plugin? loadOBD2Plugin() {
    try {
      return OBD2Plugin();
    } catch (e) {
      print("[OBDRepositoryImpl] Error al crear instancia del plugin: $e");
      return null;
    }
  }
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      print("[OBDRepositoryImpl] Ya inicializado, ignorando llamada");
      return;
    }
    
    print("[OBDRepositoryImpl] Inicializando");
    
    if (_obd2Plugin == null) {
      print("[OBDRepositoryImpl] No se puede inicializar: Plugin no disponible");
      _isInitialized = false;
      throw Exception("Plugin OBD2 no disponible");
    }
    
    try {
      // Inicializar el Bluetooth
      final bluetoothState = await _obd2Plugin!.initBluetooth;
      print("[OBDRepositoryImpl] Estado Bluetooth: $bluetoothState");
      
      // Verificar si el Bluetooth está habilitado
      final isEnabled = await _obd2Plugin!.isBluetoothEnable;
      if (!isEnabled) {
        print("[OBDRepositoryImpl] Bluetooth desactivado, intentando activar");
        final enableResult = await _obd2Plugin!.enableBluetooth;
        if (!enableResult) {
          print("[OBDRepositoryImpl] No se pudo activar Bluetooth");
          throw Exception("No se pudo activar Bluetooth");
        }
      }
      
      // Configurar el handler de respuestas OBD
      if (!await _obd2Plugin!.isListenToDataInitialed) {
        await _obd2Plugin!.setOnDataReceived((command, response, requestCode) {
          _handleOBDResponse(command, response, requestCode);
        });
      }
      
      _isInitialized = true;
      print("[OBDRepositoryImpl] Inicialización completa");
    } catch (e) {
      print("[OBDRepositoryImpl] Error durante la inicialización: $e");
      _isInitialized = false;
      throw Exception("Error al inicializar OBD: $e");
    }
  }
  
  void _handleOBDResponse(String command, String response, int requestCode) {
    print("[OBDRepositoryImpl] Respuesta recibida: $command, $response, $requestCode");
    
    if (command == "PARAMETER" && response.isNotEmpty) {
      try {
        final List<dynamic> params = _decodeParameterResponse(response);
        
        // Procesar cada parámetro recibido
        for (final param in params) {
          final pid = param["PID"] as String;
          if (_streamControllers.containsKey(pid)) {
            final double value = double.tryParse(param["response"].toString()) ?? 0.0;
            final data = OBDData(
              pid: pid,
              value: value,
              unit: param["unit"] as String? ?? "",
              description: param["description"] as String? ?? "",
            );
            _streamControllers[pid]!.add(data);
          }
        }
      } catch (e) {
        print("[OBDRepositoryImpl] Error al procesar parámetros: $e");
      }
    } else if (command == "DTC" && response.isNotEmpty) {
      // El manejo de los códigos DTC se implementaría aquí
      print("[OBDRepositoryImpl] Códigos DTC recibidos: $response");
    }
  }
  
  List<dynamic> _decodeParameterResponse(String response) {
    try {
      // Aquí decodificaríamos la respuesta JSON del plugin
      // En una implementación real, esto sería:
      // return json.decode(response);
      
      // Para simplificar, retornamos una lista vacía
      return [];
    } catch (e) {
      print("[OBDRepositoryImpl] Error al decodificar respuesta: $e");
      return [];
    }
  }
  
  @override
  Future<bool> connect() async {
    if (_isConnected) {
      print("[OBDRepositoryImpl] Ya conectado, ignorando llamada");
      return true;
    }
    
    if (!_isInitialized) {
      print("[OBDRepositoryImpl] No inicializado, no se puede conectar");
      throw Exception("OBD no inicializado");
    }
    
    if (_obd2Plugin == null) {
      print("[OBDRepositoryImpl] Plugin no disponible, no se puede conectar");
      throw Exception("Plugin OBD2 no disponible");
    }
    
    try {
      print("[OBDRepositoryImpl] Buscando dispositivos pareados");
      final pairedDevices = await _obd2Plugin!.getPairedDevices;
      
      if (pairedDevices.isEmpty) {
        print("[OBDRepositoryImpl] No hay dispositivos OBD emparejados");
        // En lugar de lanzar una excepción, simplemente retornamos false
        // para indicar que no se pudo conectar pero de forma controlada
        return false;
      }
      
      // Conectar al primer dispositivo (en una app real, el usuario seleccionaría)
      final device = pairedDevices.first;
      print("[OBDRepositoryImpl] Intentando conectar a: ${device.name}");
      
      await _obd2Plugin!.getConnection(
        device,
        (connection) async {
          if (connection != null) {
            print("[OBDRepositoryImpl] Conexión establecida");
            _isConnected = true;
            
            // Configurar el OBD con los comandos iniciales
            await _configureOBD();
          } else {
            print("[OBDRepositoryImpl] Conexión fallida");
            _isConnected = false;
          }
        },
        (errorMessage) {
          print("[OBDRepositoryImpl] Error de conexión: $errorMessage");
          _isConnected = false;
        }
      );
      
      // Esperar un tiempo razonable para la conexión
      await Future.delayed(const Duration(seconds: 2));
      
      return _isConnected;
    } catch (e) {
      print("[OBDRepositoryImpl] Error al conectar: $e");
      _isConnected = false;
      return false; // Retornamos false en lugar de lanzar una excepción
    }
  }
  
  Future<void> _configureOBD() async {
    if (!_isConnected || _obd2Plugin == null) return;
    
    try {
      // Ejemplo de configuración básica (en la implementación real, esto vendría del plugin)
      final configJson = '''
      [
        {"command": "AT Z", "description": "Reset all"},
        {"command": "AT E0", "description": "Echo off"},
        {"command": "AT L0", "description": "Linefeeds off"},
        {"command": "AT SP 0", "description": "Auto protocol"}
      ]
      ''';
      
      print("[OBDRepositoryImpl] Configurando OBD");
      final configTime = await _obd2Plugin!.configObdWithJSON(configJson);
      await Future.delayed(Duration(milliseconds: configTime));
      print("[OBDRepositoryImpl] Configuración completa");
    } catch (e) {
      print("[OBDRepositoryImpl] Error en configuración: $e");
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (!_isConnected) {
      print("[OBDRepositoryImpl] No está conectado, ignorando llamada");
      return;
    }
    
    print("[OBDRepositoryImpl] Desconectando");
    
    // Detener todas las actualizaciones de parámetros
    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.add(OBDData(
          pid: "",
          value: 0.0,
          unit: "",
          description: "Desconectado",
        ));
      }
    }
    
    // Desconectar del dispositivo
    if (_obd2Plugin != null) {
      try {
        final result = await _obd2Plugin!.disconnect();
        print("[OBDRepositoryImpl] Desconexión: $result");
      } catch (e) {
        print("[OBDRepositoryImpl] Error al desconectar: $e");
      }
    }
    
    _isConnected = false;
  }
  
  @override
  Stream<OBDData> getParameterData(String pid) {
    if (!_isConnected) {
      print("[OBDRepositoryImpl] No conectado, no se pueden obtener datos para $pid");
      throw Exception("No se puede obtener datos: OBD no conectado");
    }
    
    print("[OBDRepositoryImpl] Solicitando datos para PID: $pid");
    
    // Crear controller si no existe
    if (!_streamControllers.containsKey(pid)) {
      _streamControllers[pid] = StreamController<OBDData>.broadcast();
      
      // Solo si estamos conectados, empezamos a monitorear este parámetro
      if (_isConnected && _obd2Plugin != null) {
        _startMonitoringParameter(pid);
      }
    }
    
    return _streamControllers[pid]!.stream;
  }
  
  void _startMonitoringParameter(String pid) {
    if (!_isConnected || _obd2Plugin == null) return;
    
    try {
      // Crear configuración para este PID
      final paramConfig = _pidConfigs[pid];
      if (paramConfig == null) {
        print("[OBDRepositoryImpl] Configuración no encontrada para PID: $pid");
        return;
      }
      
      final paramJson = '''
      [
        {
          "PID": "$pid",
          "description": "${paramConfig['description']}",
          "unit": "${paramConfig['unit']}"
        }
      ]
      ''';
      
      // Iniciar monitoreo del parámetro
      _obd2Plugin!.getParamsFromJSON(paramJson);
    } catch (e) {
      print("[OBDRepositoryImpl] Error al iniciar monitoreo para $pid: $e");
    }
  }
  
  @override
  Future<List<String>> getDiagnosticTroubleCodes() async {
    if (!_isConnected) {
      print("[OBDRepositoryImpl] No conectado, no se pueden obtener códigos DTC");
      throw Exception("No se puede obtener códigos DTC: OBD no conectado");
    }
    
    print("[OBDRepositoryImpl] Solicitando códigos DTC");
    
    try {
      // Ejemplo de configuración para obtener DTCs (en la implementación real, esto vendría del plugin)
      final dtcJson = '''
      [
        {"command": "03", "description": "Trouble codes"}
      ]
      ''';
      
      // En una implementación real, procesaríamos la respuesta
      final dtcTime = await _obd2Plugin!.getDTCFromJSON(dtcJson);
      await Future.delayed(Duration(milliseconds: dtcTime));
      
      // Por ahora, retornamos una lista vacía
      return [];
    } catch (e) {
      print("[OBDRepositoryImpl] Error al obtener códigos DTC: $e");
      return [];
    }
  }
}

// Clase auxiliar para simular el plugin OBD2 cuando no está disponible
class OBD2Plugin {
  OBD2Plugin() {
    // En una implementación real, aquí se inicializaría el plugin
  }
  
  Future<dynamic> get initBluetooth async {
    // Simular inicialización de Bluetooth
    return "INITIALIZED";
  }
  
  Future<bool> get isBluetoothEnable async {
    // Simular verificación de Bluetooth
    return true;
  }
  
  Future<bool> get enableBluetooth async {
    // Simular activación de Bluetooth
    return true;
  }
  
  Future<List<dynamic>> get getPairedDevices async {
    // Simular dispositivos pareados
    return [];
  }
  
  Future<bool> get isListenToDataInitialed async {
    return false;
  }
  
  Future<void> setOnDataReceived(Function(String, String, int) callback) async {
    // Configurar callback de datos
  }
  
  Future<void> getConnection(dynamic device, Function(dynamic) onConnected, Function(String) onError) async {
    // Simular conexión
    onError("Función no implementada");
  }
  
  Future<bool> disconnect() async {
    // Simular desconexión
    return true;
  }
  
  Future<int> configObdWithJSON(String json) async {
    // Simular configuración
    return 1000; // Tiempo en milisegundos
  }
  
  Future<int> getParamsFromJSON(String json) async {
    // Simular obtención de parámetros
    return 500; // Tiempo en milisegundos
  }
  
  Future<int> getDTCFromJSON(String json) async {
    // Simular obtención de DTCs
    return 1000; // Tiempo en milisegundos
  }
} 