// lib/data/repositories/obd_repository_mock.dart
import 'dart:async';
import 'dart:math';
import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/entities/obd_data.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';

class OBDRepositoryMock implements OBDRepository {
  final Random _random = Random();
  Timer? _dataEmissionTimer;
  final Map<String, StreamController<OBDData>> _pidControllers = {};
  bool _isConnected = false;
  
  @override
  bool get isConnected => _isConnected;
  
  // Valores base para cada parámetro
  final Map<String, double> _baseValues = {
    '01 0C': 1200.0, // RPM
    '01 0D': 50.0,   // Velocidad
    '01 05': 80.0,   // Temperatura
    '01 42': 12.5,   // Voltaje de Batería
  };
  
  // Rangos de variación más amplios para cada parámetro
  final Map<String, List<double>> _variationRanges = {
    '01 0C': [-500.0, 600.0],  // RPM: mayor variación
    '01 0D': [-15.0, 25.0],    // Velocidad: mayor variación
    '01 05': [-10.0, 15.0],    // Temperatura: mayor variación 
    '01 42': [-0.8, 1.2],      // Voltaje: mayor variación
  };
  
  @override
  Future<void> initialize() async {
    print("[OBDRepositoryMock] Inicializando");
    _stopDataEmission();
    await Future.delayed(const Duration(milliseconds: 500));
    print("[OBDRepositoryMock] Inicialización completada");
  }

  @override
  Future<bool> connect() async {
    if (_isConnected) {
      return true;
    }
    
    print("[OBDRepositoryMock] Conectando");
    
    // Emitir valores iniciales para cada parámetro
    for (final pid in _baseValues.keys) {
      final value = _baseValues[pid]!;
      print("[OBDRepositoryMock] Emitiendo valor inicial para $pid: $value");
      
      final controller = _getOrCreateController(pid);
      
      final data = _createOBDData(pid, value);
      controller.add(data);
    }
    
    // Iniciar emisión periódica de datos (cada 300ms en lugar de 1s)
    _startDataEmission(const Duration(milliseconds: 300));
    
    await Future.delayed(const Duration(milliseconds: 500));
    _isConnected = true;
    print("[OBDRepositoryMock] Conexión exitosa");
    return true;
  }

  @override
  Future<void> disconnect() async {
    _stopDataEmission();
    _isConnected = false;
  }

  @override
  Stream<OBDData> getParameterData(String pid) {
    if (!_isConnected) {
      throw Exception('No se puede obtener datos: OBD no conectado');
    }
    
    print("[OBDRepositoryMock] Solicitando stream para PID: $pid");
    final controller = _getOrCreateController(pid);
    
    // Emitir un valor inmediatamente
    _emitValue(pid);
    
    return controller.stream;
  }

  @override
  Future<List<String>> getDiagnosticTroubleCodes() async {
    if (!_isConnected) {
      throw Exception('No se puede obtener códigos DTC: OBD no conectado');
    }
    
    // Simular una respuesta de códigos DTC
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Generar entre 0 y 3 códigos aleatorios
    final numCodes = _random.nextInt(4);
    final List<String> codes = [];
    
    if (numCodes > 0) {
      final List<String> possibleCodes = [
        'P0100 - Fallo en sensor de flujo de masa de aire',
        'P0101 - Rango/rendimiento del circuito de flujo de masa de aire',
        'P0102 - Entrada baja del circuito de flujo de masa de aire',
        'P0103 - Entrada alta del circuito de flujo de masa de aire',
        'P0105 - Circuito intermitente del sensor MAP',
        'P0117 - Sensor de temperatura del refrigerante - señal baja',
        'P0118 - Sensor de temperatura del refrigerante - señal alta',
        'P0300 - Fallo de encendido detectado - cilindro aleatorio',
        'P0301 - Fallo de encendido detectado - cilindro 1',
        'P0302 - Fallo de encendido detectado - cilindro 2',
        'P0121 - Rango/rendimiento del circuito del sensor del acelerador',
      ];
      
      // Elegir códigos aleatorios sin repetición
      final selectedIndices = <int>{};
      while (selectedIndices.length < numCodes && selectedIndices.length < possibleCodes.length) {
        selectedIndices.add(_random.nextInt(possibleCodes.length));
      }
      
      for (final index in selectedIndices) {
        codes.add(possibleCodes[index]);
      }
    }
    
    print("[OBDRepositoryMock] Se obtuvieron ${codes.length} códigos DTC");
    return codes;
  }

  StreamController<OBDData> _getOrCreateController(String pid) {
    if (!_pidControllers.containsKey(pid)) {
      _pidControllers[pid] = StreamController<OBDData>.broadcast();
    }
    return _pidControllers[pid]!;
  }

  void _startDataEmission(Duration interval) {
    print("[OBDRepositoryMock] Iniciando emisión de datos");
    _dataEmissionTimer = Timer.periodic(interval, (_) {
      for (final pid in _pidControllers.keys) {
        _emitValue(pid);
      }
    });
  }

  void _stopDataEmission() {
    _dataEmissionTimer?.cancel();
    _dataEmissionTimer = null;
    print("[OBDRepositoryMock] Deteniendo emisión de datos");
  }

  void _emitValue(String pid) {
    if (!_pidControllers.containsKey(pid)) return;
    
    // Obtener el valor base y el rango de variación
    final baseValue = _baseValues[pid] ?? 0.0;
    final range = _variationRanges[pid] ?? [-5.0, 5.0];
    
    // Generar una variación aleatoria más pronunciada
    final variation = range[0] + _random.nextDouble() * (range[1] - range[0]);
    
    // Aplicar la variación al valor base, pero asegurarse de que se mantenga en un rango razonable
    final newBaseValue = baseValue + variation;
    
    // Actualizar el valor base para la próxima emisión
    _baseValues[pid] = _clampValue(pid, newBaseValue);
    
    final data = _createOBDData(pid, _baseValues[pid]!);
    _pidControllers[pid]!.add(data);
    
    print("[OBDRepositoryMock] Emitiendo para $pid: ${_baseValues[pid]}");
  }

  // Limitar valores para que sean realistas
  double _clampValue(String pid, double value) {
    switch (pid) {
      case '01 0C': // RPM
        return max(800.0, min(6000.0, value));
      case '01 0D': // Velocidad
        return max(0.0, min(220.0, value));
      case '01 05': // Temperatura
        return max(60.0, min(110.0, value));
      case '01 42': // Voltaje
        return max(10.5, min(14.8, value));
      default:
        return value;
    }
  }

  OBDData _createOBDData(String pid, double value) {
    String unit = '';
    String description = '';
    
    switch (pid) {
      case '01 0C':
        unit = 'RPM';
        description = 'Revoluciones del motor';
        break;
      case '01 0D':
        unit = 'km/h';
        description = 'Velocidad del vehículo';
        break;
      case '01 05':
        unit = '°C';
        description = 'Temperatura del refrigerante';
        break;
      case '01 42':
        unit = 'V';
        description = 'Voltaje de la batería';
        break;
      default:
        description = 'Parámetro desconocido';
    }
    
    return OBDData(
      pid: pid,
      value: value,
      unit: unit,
      description: description,
    );
  }
}