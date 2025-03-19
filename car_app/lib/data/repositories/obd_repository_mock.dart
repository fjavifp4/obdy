// lib/data/repositories/obd_repository_mock.dart
import 'dart:async';
import 'dart:math';
import 'package:car_app/domain/entities/obd_data.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';

class OBDRepositoryMock implements OBDRepository {
  final Random _random = Random();
  Timer? _dataEmissionTimer;
  final Map<String, StreamController<OBDData>> _pidControllers = {};
  bool _isConnected = false;
  
  // Estado actual del vehículo simulado
  bool _isAccelerating = false;
  bool _isBraking = false;
  bool _isIdling = true;
  int _steadyStateCounter = 0;
  int _transitionCounter = 0;
  
  // Valores actuales para cada parámetro
  final Map<String, double> _currentValues = {
    '01 0C': 850.0,  // RPM
    '01 0D': 0.0,    // Velocidad
    '01 05': 70.0,   // Temperatura
    '01 42': 12.5,   // Voltaje de Batería
  };
  
  // Valores objetivo para transiciones suaves
  final Map<String, double> _targetValues = {
    '01 0C': 850.0,  // RPM
    '01 0D': 0.0,    // Velocidad
    '01 05': 70.0,   // Temperatura
    '01 42': 12.5,   // Voltaje de Batería
  };
  
  // Tiempo que permanece en un estado estable
  final int _steadyStateDuration = 10; // ciclos
  
  // Factores de aceleración para cada parámetro
  final Map<String, double> _accelerationFactors = {
    '01 0C': 0.15,   // RPM
    '01 0D': 0.1,    // Velocidad
    '01 05': 0.02,   // Temperatura
    '01 42': 0.05,   // Voltaje
  };
  
  @override
  bool get isConnected => _isConnected;
  
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
    
    // Establecer valores iniciales
    _currentValues['01 0C'] = 850.0; // RPM en ralentí
    _currentValues['01 0D'] = 0.0;   // Velocidad 0
    _currentValues['01 05'] = 70.0;  // Temperatura inicial
    _currentValues['01 42'] = 12.5;  // Voltaje inicial
    
    // Emitir valores iniciales
    for (final pid in _currentValues.keys) {
      final value = _currentValues[pid]!;
      print("[OBDRepositoryMock] Emitiendo valor inicial para $pid: $value");
      
      final controller = _getOrCreateController(pid);
      final data = _createOBDData(pid, value);
      controller.add(data);
    }
    
    // Iniciar emisión periódica de datos
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
    final data = _createOBDData(pid, _currentValues[pid] ?? 0.0);
    controller.add(data);
    
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
      _updateVehicleState();
      _updateParameterValues();
      _emitCurrentValues();
    });
  }

  void _stopDataEmission() {
    _dataEmissionTimer?.cancel();
    _dataEmissionTimer = null;
    print("[OBDRepositoryMock] Deteniendo emisión de datos");
  }

  void _updateVehicleState() {
    _transitionCounter++;
    
    // Gestionar los cambios de estado del vehículo
    if (_steadyStateCounter > 0) {
      _steadyStateCounter--;
    } else {
      // Decidir un nuevo estado
      final stateChange = _random.nextDouble();
      
      if (_isIdling) {
        // Si está en ralentí, puede empezar a acelerar
        if (stateChange < 0.2) {
          _isIdling = false;
          _isAccelerating = true;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(15);
          _setTargetForAcceleration();
        }
      } else if (_isAccelerating) {
        // Si está acelerando, puede mantener velocidad o frenar
        if (stateChange < 0.3) {
          _isIdling = false;
          _isAccelerating = false;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(20);
          _setTargetForCruising();
        } else if (stateChange < 0.4) {
          _isIdling = false;
          _isAccelerating = false;
          _isBraking = true;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
          _setTargetForBraking();
        }
      } else if (_isBraking) {
        // Si está frenando, puede volver a ralentí o acelerar de nuevo
        if (_currentValues['01 0D']! < 5.0) {
          // Si la velocidad es muy baja, volver a ralentí
          _isIdling = true;
          _isAccelerating = false;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(15);
          _setTargetForIdling();
        } else if (stateChange < 0.3) {
          // Puede volver a acelerar
          _isIdling = false;
          _isAccelerating = true;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
          _setTargetForAcceleration();
        }
      } else {
        // Si está a velocidad constante, puede acelerar, frenar o seguir igual
        if (stateChange < 0.2) {
          _isIdling = false;
          _isAccelerating = true;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
          _setTargetForAcceleration();
        } else if (stateChange < 0.4) {
          _isIdling = false;
          _isAccelerating = false;
          _isBraking = true;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(15);
          _setTargetForBraking();
        } else {
          // Seguir a velocidad constante
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(20);
        }
      }
    }
  }

  void _setTargetForIdling() {
    _targetValues['01 0C'] = 850.0 + _random.nextDouble() * 100.0;
    _targetValues['01 0D'] = 0.0;
    // La temperatura tiende a bajar un poco en ralentí
    _targetValues['01 05'] = max(70.0, _currentValues['01 05']! - _random.nextDouble() * 2.0);
    _targetValues['01 42'] = 12.5 + _random.nextDouble() * 0.5;
  }

  void _setTargetForAcceleration() {
    final currentSpeed = _currentValues['01 0D']!;
    // Las RPM suben más rápido al inicio de la aceleración
    if (currentSpeed < 20.0) {
      _targetValues['01 0C'] = 2500.0 + _random.nextDouble() * 500.0;
    } else {
      _targetValues['01 0C'] = 2000.0 + _random.nextDouble() * 1000.0;
    }
    
    // La velocidad aumenta a un objetivo realista
    _targetValues['01 0D'] = min(220.0, currentSpeed + 20.0 + _random.nextDouble() * 40.0);
    
    // La temperatura aumenta con la aceleración
    _targetValues['01 05'] = min(95.0, _currentValues['01 05']! + _random.nextDouble() * 5.0);
    
    // El voltaje puede subir ligeramente 
    _targetValues['01 42'] = min(14.8, 13.0 + _random.nextDouble() * 0.8);
  }

  void _setTargetForBraking() {
    // RPM bajan al frenar
    _targetValues['01 0C'] = max(850.0, _currentValues['01 0C']! * 0.7);
    
    // La velocidad disminuye
    _targetValues['01 0D'] = max(0.0, _currentValues['01 0D']! * 0.6);
    
    // La temperatura se mantiene o baja ligeramente
    _targetValues['01 05'] = _currentValues['01 05']! - _random.nextDouble() * 2.0;
    
    // El voltaje puede variar ligeramente
    _targetValues['01 42'] = max(12.0, min(14.5, _currentValues['01 42']! + (_random.nextDouble() * 0.4 - 0.2)));
  }

  void _setTargetForCruising() {
    // RPM se estabilizan según la velocidad
    final speed = _currentValues['01 0D']!;
    if (speed < 60.0) {
      _targetValues['01 0C'] = 1500.0 + speed * 5.0;
    } else {
      _targetValues['01 0C'] = 1800.0 + speed * 3.0;
    }
    
    // La velocidad se mantiene con pequeñas variaciones
    _targetValues['01 0D'] = max(0.0, min(220.0, speed + (_random.nextDouble() * 10.0 - 5.0)));
    
    // La temperatura tiende a estabilizarse
    _targetValues['01 05'] = min(95.0, 80.0 + speed / 10.0);
    
    // El voltaje se estabiliza
    _targetValues['01 42'] = 13.5 + _random.nextDouble() * 0.5;
  }

  void _updateParameterValues() {
    for (final pid in _currentValues.keys) {
      final currentValue = _currentValues[pid]!;
      final targetValue = _targetValues[pid]!;
      final factor = _accelerationFactors[pid]!;
      
      // Calcular el nuevo valor usando una transición suave
      double newValue;
      
      if ((targetValue - currentValue).abs() < 0.1) {
        // Si estamos muy cerca del objetivo, establecerlo directamente
        newValue = targetValue;
      } else {
        // Transición suave hacia el valor objetivo
        newValue = currentValue + (targetValue - currentValue) * factor;
        
        // Añadir pequeñas variaciones aleatorias para más realismo
        final noiseScale = _getNoiseScale(pid);
        newValue += (_random.nextDouble() * 2.0 - 1.0) * noiseScale;
      }
      
      // Asegurar que los valores estén dentro de rangos realistas
      _currentValues[pid] = _clampValue(pid, newValue);
    }
    
    // Comportamientos especiales para simulación de conducción real
    _simulateEngineLoad();
  }
  
  double _getNoiseScale(String pid) {
    switch (pid) {
      case '01 0C': // RPM
        return _isIdling ? 20.0 : 50.0;
      case '01 0D': // Velocidad
        return _isIdling ? 0.0 : 0.5;
      case '01 05': // Temperatura
        return 0.1;
      case '01 42': // Voltaje
        return 0.05;
      default:
        return 0.0;
    }
  }

  void _simulateEngineLoad() {
    final rpm = _currentValues['01 0C']!;
    final speed = _currentValues['01 0D']!;
    
    // Simular cambios de marcha (las RPM bajan al cambiar de marcha)
    if (_isAccelerating && _transitionCounter % 10 == 0) {
      // Probabilidad de cambio de marcha al acelerar
      if (speed > 20 && rpm > 2800 && _random.nextDouble() < 0.3) {
        _currentValues['01 0C'] = max(1200.0, rpm * 0.7);
      }
    }
    
    // Asegurar correlación entre velocidad y RPM
    if (!_isAccelerating && !_isBraking && speed > 5.0) {
      // En velocidad constante, RPM debe correlacionarse con velocidad
      final expectedRpm = 1000.0 + (speed * 10.0);
      if ((rpm - expectedRpm).abs() > 500.0) {
        _currentValues['01 0C'] = expectedRpm + (_random.nextDouble() * 200.0 - 100.0);
      }
    }
    
    // Temperatura aumenta con velocidad sostenida y RPM altas
    if (speed > 80.0 && rpm > 2500.0 && _currentValues['01 05']! < 90.0) {
      _currentValues['01 05'] = _currentValues['01 05']! + 0.05;
    }
  }

  void _emitCurrentValues() {
    for (final pid in _currentValues.keys) {
      if (_pidControllers.containsKey(pid)) {
        final data = _createOBDData(pid, _currentValues[pid]!);
        _pidControllers[pid]!.add(data);
      }
    }
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