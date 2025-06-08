// lib/data/repositories/obd_repository_mock.dart
import 'dart:async';
import 'dart:math';
import 'package:obdy/domain/entities/obd_data.dart';
import 'package:obdy/domain/repositories/obd_repository.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
  
  // Control de tiempo de simulación
  DateTime? _simulationStartTime;
  double _totalDistanceKm = 0.0;
  double _totalFuelConsumptionL = 0.0;
  
  // Valores actuales para cada parámetro
  final Map<String, double> _currentValues = {
    '0C': 850.0,  // RPM
    '0D': 0.0,    // Velocidad
    '05': 70.0,   // Temperatura
    '42': 12.5,   // Voltaje de Batería
    // '5E': 0.0,    // Consumo de combustible (L/h) - Ahora se intentará leer del real
    // 'FF': 0.0,    // Distancia total recorrida (km) - No usado actualmente
  };
  
  // Valores objetivo para transiciones suaves
  final Map<String, double> _targetValues = {
    '0C': 850.0,  // RPM
    '0D': 0.0,    // Velocidad
    '05': 70.0,   // Temperatura
    '42': 12.5,   // Voltaje de Batería
    // '5E': 0.0,    // Consumo de combustible
    // 'FF': 0.0,    // Distancia total
  };
  
  // Tiempo que permanece en un estado estable
  final int _steadyStateDuration = 10; // ciclos
  
  // Factores de aceleración para cada parámetro
  final Map<String, double> _accelerationFactors = {
    '0C': 0.15,   // RPM
    '0D': 0.1,    // Velocidad
    '05': 0.02,   // Temperatura
    '42': 0.05,   // Voltaje
    // '5E': 0.1,    // Consumo de combustible
    // 'FF': 0.2,    // Distancia total
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
    
    // Establecer valores iniciales con claves limpias
    _currentValues['0C'] = 1800.0 + _random.nextDouble() * 300; // RPM
    _currentValues['0D'] = 30.0 + _random.nextDouble() * 15.0;   // Velocidad
    _currentValues['05'] = 70.0 + _random.nextDouble() * 15.0;  // Temperatura
    _currentValues['42'] = 12.5 + _random.nextDouble() * 1.0;  // Voltaje
    // _currentValues['5E'] = 2.0 + _random.nextDouble() * 1.5;   // Consumo
    // _currentValues['FF'] = 0.0;   // Distancia
    
    // Iniciar con estado de aceleración
    _isIdling = false;
    _isAccelerating = true;
    _isBraking = false;
    
    // Resetear valores objetivo con claves limpias
    _targetValues['0C'] = 2200.0 + _random.nextDouble() * 500; // RPM
    _targetValues['0D'] = 60.0 + _random.nextDouble() * 20.0;  // Velocidad
    _targetValues['05'] = 85.0 + _random.nextDouble() * 5.0;   // Temperatura
    _targetValues['42'] = 13.0 + _random.nextDouble() * 1.0;   // Voltaje
    // _targetValues['5E'] = 4.0 + _random.nextDouble() * 2.0;    // Consumo
    // _targetValues['FF'] = 0.0;    // Distancia
    
    // Resetear contadores y acumuladores
    _totalDistanceKm = 0.0;
    _totalFuelConsumptionL = 0.0;
    _steadyStateCounter = _random.nextInt(15) + 10; // Duración aleatoria del estado inicial
    _transitionCounter = 0;
    
    // Iniciar tiempo de simulación
    _simulationStartTime = DateTime.now();
    
    // Emitir valores iniciales usando claves limpias
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
    print("[OBDRepositoryMock] Solicitud de desconexión recibida");
    
    // Detener siempre la emisión de datos sin importar el motivo de la desconexión
    _stopDataEmission();
    
    // Cerrar y limpiar todos los controladores de stream
    for (final controller in _pidControllers.values) {
      try {
        await controller.close();
      } catch (e) {
        print("[OBDRepositoryMock] Error al cerrar controlador: $e");
      }
    }
    _pidControllers.clear();
    
    // Resetear todos los valores de la simulación
    _isConnected = false;
    _simulationStartTime = null;
    _totalDistanceKm = 0.0;
    _totalFuelConsumptionL = 0.0;
    
    // Resetear estados del vehículo
    _isAccelerating = false;
    _isBraking = false;
    _isIdling = true;
    
    print("[OBDRepositoryMock] Desconexión completa - simulación detenida");
  }

  @override
  Stream<OBDData> getParameterData(String pid) {
    if (!_isConnected) {
      return Stream.error(Exception('No se puede obtener datos: OBD no conectado'));
    }
    
    print("[OBDRepositoryMock] Solicitando stream para PID: $pid");
    final controller = _getOrCreateController(pid);
    
    // Emitir valor actual inmediatamente
    final currentValue = _currentValues[pid] ?? 0.0;
    final data = _createOBDData(pid, currentValue);
    if (!controller.isClosed) {
       controller.add(data);
    } else {
       print("[OBDRepositoryMock] Advertencia: Controlador para $pid ya cerrado al solicitar stream.");
    }
    
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

  @override
  Future<List<BluetoothDevice>> getAvailableDevices() async {
    // En el mock, devolvemos una lista vacía ya que no necesitamos dispositivos reales
    return [];
  }

  @override
  Future<List<String>> getSupportedPids() async {
    if (!_isConnected) {
      throw Exception("No conectado para obtener PIDs soportados (Mock)");
    }
    print("[OBDRepositoryMock] Devolviendo PIDs soportados simulados.");
    await Future.delayed(const Duration(milliseconds: 300)); // Simular delay
    // Devolver una lista fija de PIDs comunes
    return [
      '01', // STATUS
      '03', // FUEL_STATUS
      '04', // ENGINE_LOAD
      '05', // COOLANT_TEMP
      '0C', // RPM
      '0D', // SPEED
      '0E', // TIMING_ADVANCE
      '0F', // INTAKE_TEMP
      '10', // MAF
      '11', // THROTTLE_POS
      '1C', // OBD_COMPLIANCE
      '1F', // RUN_TIME
      '20', // PIDS_B
      '2F', // FUEL_LEVEL
      '31', // DISTANCE_SINCE_DTC_CLEAR
      '33', // BAROMETRIC_PRESSURE
      '40', // PIDS_C
      '42', // CONTROL_MODULE_VOLTAGE
      '46', // AMBIANT_AIR_TEMP
      '51', // FUEL_TYPE
      '5E', // FUEL_RATE
    ]..sort();
  }

  StreamController<OBDData> _getOrCreateController(String pid) {
    if (!_pidControllers.containsKey(pid)) {
      _pidControllers[pid] = StreamController<OBDData>.broadcast();
    }
    return _pidControllers[pid]!;
  }

  void _startDataEmission(Duration interval) {
    print("[OBDRepositoryMock] Iniciando emisión de datos");
    
    // Si ya hay un timer activo, no crear otro
    if (_dataEmissionTimer != null && _dataEmissionTimer!.isActive) {
      print("[OBDRepositoryMock] Ya hay un timer de emisión activo, no se crea otro");
      return;
    }
    
    _dataEmissionTimer = Timer.periodic(interval, (_) {
      _updateVehicleState();
      _updateParameterValues();
      _emitCurrentValues();
    });
  }

  void _stopDataEmission() {
    if (_dataEmissionTimer != null) {
      if (_dataEmissionTimer!.isActive) {
        _dataEmissionTimer!.cancel();
        print("[OBDRepositoryMock] Timer de emisión de datos cancelado");
      }
      _dataEmissionTimer = null;
    }
    print("[OBDRepositoryMock] Emisión de datos detenida");
  }

  void _updateVehicleState() {
    _transitionCounter++;
    
    // Gestionar los cambios de estado del vehículo
    if (_steadyStateCounter > 0) {
      _steadyStateCounter--;
    } else {
      // Decidir un nuevo estado basado en el estado actual
      final stateChange = _random.nextDouble();
      
      if (_isIdling) {
        // Si está en ralentí, tiene alta probabilidad de empezar a acelerar
        if (stateChange < 0.7) { // 70% probabilidad de acelerar desde ralentí
          _isIdling = false;
          _isAccelerating = true;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(15);
          _setTargetForAcceleration();
          print("[OBDRepositoryMock] Cambiando de ralentí a ACELERACIÓN");
        }
      } else if (_isAccelerating) {
        // Si está acelerando, probablemente mantendrá velocidad o frenará
        if (stateChange < 0.6) { // 60% probabilidad de mantener velocidad
          _isIdling = false;
          _isAccelerating = false;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(20);
          _setTargetForCruising();
          print("[OBDRepositoryMock] Cambiando de aceleración a CRUCERO");
        } else if (stateChange < 0.9) { // 30% probabilidad de frenar
          _isIdling = false;
          _isAccelerating = false;
          _isBraking = true;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
          _setTargetForBraking();
          print("[OBDRepositoryMock] Cambiando de aceleración a FRENADO");
        } else { // 10% probabilidad de continuar acelerando más
          _setTargetForMoreAcceleration();
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(8);
          print("[OBDRepositoryMock] Continuando ACELERACIÓN");
        }
      } else if (_isBraking) {
        // Si está frenando, puede detenerse o volver a acelerar
        final currentSpeed = _currentValues['0D'] ?? 0.0;
        
        if (currentSpeed < 5.0) { 
          // Si ya casi está detenido, 50/50 entre detenerse o volver a acelerar
          if (stateChange < 0.5) {
            _isIdling = true;
            _isAccelerating = false;
            _isBraking = false;
            _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
            _setTargetForIdling();
            print("[OBDRepositoryMock] Cambiando de frenado a RALENTÍ");
          } else {
            _isIdling = false;
            _isAccelerating = true;
            _isBraking = false;
            _steadyStateCounter = _steadyStateDuration + _random.nextInt(12);
            _setTargetForAcceleration();
            print("[OBDRepositoryMock] Cambiando de frenado a ACELERACIÓN");
          }
        } else if (stateChange < 0.7) { // 70% probabilidad de seguir frenando
          _setTargetForMoreBraking();
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(5);
          print("[OBDRepositoryMock] Continuando FRENADO");
        } else { // 30% probabilidad de volver a acelerar
          _isIdling = false;
          _isAccelerating = true;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
          _setTargetForAcceleration();
          print("[OBDRepositoryMock] Cambiando de frenado a ACELERACIÓN");
        }
      } else {
        // Si está en crucero, puede acelerar, frenar o seguir
        if (stateChange < 0.3) { // 30% probabilidad de acelerar
          _isIdling = false;
          _isAccelerating = true;
          _isBraking = false;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(10);
          _setTargetForAcceleration();
          print("[OBDRepositoryMock] Cambiando de crucero a ACELERACIÓN");
        } else if (stateChange < 0.6) { // 30% probabilidad de frenar
          _isIdling = false;
          _isAccelerating = false;
          _isBraking = true;
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(8);
          _setTargetForBraking();
          print("[OBDRepositoryMock] Cambiando de crucero a FRENADO");
        } else { // 40% probabilidad de seguir en crucero
          _steadyStateCounter = _steadyStateDuration + _random.nextInt(15);
          _setTargetForCruising();
          print("[OBDRepositoryMock] Continuando CRUCERO");
        }
      }
    }
  }

  void _setTargetForIdling() {
    _targetValues['0C'] = 800.0 + _random.nextDouble() * 200.0; // RPM entre 800-1000
    _targetValues['0D'] = 0.0;                                  // Velocidad 0
    _targetValues['05'] = max(70.0, _currentValues['05']! - 5.0); // Temperatura bajando ligeramente
    _targetValues['42'] = max(12.0, _currentValues['42']! - 0.5); // Voltaje bajando ligeramente
    _targetValues['5E'] = 0.5 + _random.nextDouble() * 0.5;     // Consumo bajo en ralentí
  }

  void _setTargetForAcceleration() {
    final currentSpeed = _currentValues['0D']!;
    // Las RPM suben más rápido al inicio de la aceleración
    if (currentSpeed < 20.0) {
      _targetValues['0C'] = 2500.0 + _random.nextDouble() * 500.0;
    } else {
      _targetValues['0C'] = 2000.0 + _random.nextDouble() * 1000.0;
    }
    
    // La velocidad aumenta a un objetivo realista
    final speedIncrement = 20.0 + _random.nextDouble() * 40.0;
    _targetValues['0D'] = min(180.0, currentSpeed + speedIncrement);
    
    // La temperatura aumenta con la aceleración
    _targetValues['05'] = min(95.0, _currentValues['05']! + _random.nextDouble() * 5.0);
    
    // El voltaje puede subir ligeramente 
    _targetValues['42'] = min(14.8, 13.0 + _random.nextDouble() * 0.8);
    
    // Consumo alto en aceleración
    _targetValues['5E'] = 10.0 + _random.nextDouble() * 8.0;
  }

  void _setTargetForBraking() {
    // RPM bajan al frenar pero no demasiado de golpe
    _targetValues['0C'] = max(900.0, _currentValues['0C']! * 0.8);
    
    // La velocidad disminuye de manera variable
    final speedReduction = _random.nextDouble() * 0.6; // Reduce entre 0% y 60%
    _targetValues['0D'] = max(0.0, _currentValues['0D']! * (1.0 - speedReduction));
    
    // La temperatura se mantiene o baja ligeramente
    _targetValues['05'] = _currentValues['05']! - _random.nextDouble() * 2.0;
    
    // El voltaje puede variar ligeramente
    _targetValues['42'] = max(12.0, min(14.5, _currentValues['42']! + (_random.nextDouble() * 0.4 - 0.2)));
    
    // Consumo medio-bajo al frenar
    _targetValues['5E'] = 2.0 + _random.nextDouble() * 1.0;
  }

  void _setTargetForCruising() {
    // RPM se estabilizan según la velocidad
    final speed = _currentValues['0D']!;
    if (speed < 60.0) {
      _targetValues['0C'] = 1500.0 + speed * 5.0;
    } else {
      _targetValues['0C'] = 1800.0 + speed * 3.0;
    }
    
    // La velocidad se mantiene con pequeñas variaciones
    _targetValues['0D'] = max(0.0, min(180.0, speed + (_random.nextDouble() * 10.0 - 5.0)));
    
    // La temperatura tiende a estabilizarse
    _targetValues['05'] = min(95.0, 80.0 + speed / 10.0);
    
    // El voltaje se estabiliza
    _targetValues['42'] = 13.5 + _random.nextDouble() * 0.5;
    
    // Consumo medio en velocidad constante, depende de la velocidad
    if (speed < 60.0) {
      // Ciudad
      _targetValues['5E'] = 5.0 + speed / 15.0;
    } else if (speed < 100.0) {
      // Mixto
      _targetValues['5E'] = 6.0 + speed / 25.0;
    } else {
      // Carretera
      _targetValues['5E'] = 7.0 + (speed - 100) / 30.0;
    }
  }

  void _updateParameterValues() {
    // Actualizar tiempo de simulación en curso si estamos conectados
    if (_isConnected && _simulationStartTime != null) {
      final currentSpeed = _currentValues['0D']!; // km/h
      final elapsedSeconds = 0.3; // intervalo en segundos entre actualizaciones
      
      // Calcular distancia recorrida en este intervalo (km)
      // La velocidad está en km/h, necesitamos convertir a km/s multiplicando por elapsedSeconds/3600
      final distanceIncrement = currentSpeed * (elapsedSeconds / 3600);
      _totalDistanceKm += distanceIncrement;
      
      // Registrar cada 10 segundos aproximadamente
      if (_transitionCounter % 30 == 0) {
        print("[OBDRepositoryMock] Datos actualizados:");
        print("[OBDRepositoryMock] - Velocidad: $currentSpeed km/h");
        print("[OBDRepositoryMock] - Distancia total: $_totalDistanceKm km");
        print("[OBDRepositoryMock] - Consumo: ${_currentValues['5E']!} L/h");
        print("[OBDRepositoryMock] - RPM: ${_currentValues['0C']!} RPM");
      }
      
      // Actualizar consumo de combustible
      final fuelConsumptionRate = _currentValues['5E']!; // L/h
      // L/h * h = L
      final fuelIncrement = fuelConsumptionRate * (elapsedSeconds / 3600);
      _totalFuelConsumptionL += fuelIncrement;
      
      // Actualizar valores acumulados
      _currentValues['FF'] = _totalDistanceKm;
    }
    
    for (final pid in _currentValues.keys) {
      final currentValue = _currentValues[pid]!;
      // _TypeError (Null check operator used on a null value) 
      // esto es porque el operador sobre null
      // para solucionar esto se puede usar el operador ?? para asignar un valor por defecto
      final targetValue = _targetValues[pid] ?? 0.0;
      final factor = _accelerationFactors[pid] ?? 0.0;
      
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
    
    // Forzar consistencia entre parámetros relacionados
    _ensureParameterConsistency();
  }
  
  double _getNoiseScale(String pid) {
    switch (pid) {
      case '0C': // RPM
        return _isIdling ? 20.0 : 50.0;
      case '0D': // Velocidad
        return _isIdling ? 0.0 : 0.5;
      case '05': // Temperatura
        return 0.1;
      case '42': // Voltaje
        return 0.05;
      case '5E': // Consumo
        return 0.2;
      case 'FF': // Distancia
        return 0.0; // No añadir ruido a la distancia acumulada
      default:
        return 0.0;
    }
  }

  void _simulateEngineLoad() {
    final rpm = _currentValues['0C']!;
    final speed = _currentValues['0D']!;
    
    // Simular cambios de marcha (las RPM bajan al cambiar de marcha)
    if (_isAccelerating && _transitionCounter % 10 == 0) {
      // Probabilidad de cambio de marcha al acelerar
      if (speed > 20 && rpm > 2800 && _random.nextDouble() < 0.3) {
        _currentValues['0C'] = max(1200.0, rpm * 0.7);
      }
    }
    
    // Asegurar correlación entre velocidad y RPM
    if (!_isAccelerating && !_isBraking && speed > 5.0) {
      // En velocidad constante, RPM debe correlacionarse con velocidad
      final expectedRpm = 1000.0 + (speed * 10.0);
      if ((rpm - expectedRpm).abs() > 500.0) {
        _currentValues['0C'] = expectedRpm + (_random.nextDouble() * 200.0 - 100.0);
      }
    }
    
    // Temperatura aumenta con velocidad sostenida y RPM altas
    if (speed > 80.0 && rpm > 2500.0 && _currentValues['05']! < 90.0) {
      _currentValues['05'] = _currentValues['05']! + 0.05;
    }
  }

  void _emitCurrentValues() {
    for (final pid in _currentValues.keys) {
      final controller = _getOrCreateController(pid);
      if (!controller.isClosed) {
        final data = _createOBDData(pid, _currentValues[pid]!);
        controller.add(data);
      }
    }
  }

  // Limitar valores para que sean realistas
  double _clampValue(String pid, double value) {
    switch (pid) {
      case '0C': // RPM
        return max(800.0, min(6000.0, value));
      case '0D': // Velocidad
        return max(0.0, min(220.0, value));
      case '05': // Temperatura
        return max(60.0, min(110.0, value));
      case '42': // Voltaje
        return max(10.5, min(14.8, value));
      case '5E': // Consumo
        return max(0.0, min(20.0, value));
      case 'FF': // Distancia
        return max(0.0, value);
      default:
        return value;
    }
  }

  OBDData _createOBDData(String pid, double value) {
    String unit = "";
    String description = "";
    double processedValue = value;

    switch (pid) {
      case '0C':
        unit = "RPM";
        description = "RPM del motor";
        processedValue = value.roundToDouble(); // Redondear RPM
        break;
      case '0D':
        unit = "km/h";
        description = "Velocidad";
        processedValue = value.roundToDouble(); // Redondear velocidad
        break;
      case '05':
        unit = "°C";
        description = "Temperatura refrigerante";
        processedValue = (value * 10).round() / 10.0; // Redondear a 1 decimal
        break;
      case '42':
        unit = "V";
        description = "Voltaje batería";
        processedValue = (value * 100).round() / 100.0; // Redondear a 2 decimales
        break;
      case '5E':
        unit = "L/h";
        description = "Ratio consumo combustible";
        processedValue = (value * 10).round() / 10.0; // Redondear a 1 decimal
        break;
       case 'FF':
        unit = "km";
        description = "Distancia total simulada";
        processedValue = (value * 100).round() / 100.0; // Redondear a 2 decimales
        break;
      default:
        description = "Parámetro desconocido";
    }

    return OBDData(
      pid: pid,
      value: processedValue,
      unit: unit,
      description: description,
    );
  }

  // Método para asegurar que los parámetros sean consistentes entre sí
  void _ensureParameterConsistency() {
    // Asegurar que el consumo esté relacionado con RPM y velocidad
    final rpm = _currentValues['0C']!;
    final speed = _currentValues['0D']!;
    
    // Calcular consumo basado en RPM y velocidad con fórmulas más realistas
    double expectedConsumption;
    
    if (speed < 2.0) {
      // En ralentí, el consumo depende un poco de las RPM
      expectedConsumption = 0.7 + (rpm - 800) / 1500; // Aprox 0.7-0.9 L/h
    } else {
      // En movimiento, usar L/100km como base
      double baseL100km;
      if (speed < 70) {
        // Ciudad, más sensible a RPM altas (aceleraciones)
        baseL100km = 8.0 + (rpm > 2500 ? (rpm - 2500) / 500 : 0); // Base 8L/100km, aumenta con RPM
      } else {
        // Carretera, más eficiente
        baseL100km = 6.0 + (rpm > 2200 ? (rpm - 2200) / 800 : 0); // Base 6L/100km
      }
      // Convertir L/100km a L/h
      expectedConsumption = (baseL100km * speed) / 100.0;
    }
    
    //aqui esta dando fallo por usar el operador sobre null
    final currentConsumption = _currentValues['5E'];
    if (currentConsumption != null) {
      _currentValues['5E'] = (currentConsumption * 0.8) + (expectedConsumption * 0.2);
    } else {
      // Si es nulo (posiblemente la primera vez), asignar el esperado directamente
      _currentValues['5E'] = expectedConsumption;
    }
    _currentValues['5E'] = _clampValue('5E', _currentValues['5E']!);
  }

  // Método para establecer valores objetivo para aceleración continuada
  void _setTargetForMoreAcceleration() {
    final currentSpeed = _currentValues['0D']!;
    final currentRPM = _currentValues['0C']!;
    
    // Incremento de velocidad basado en la actual
    _targetValues['0D'] = min(140.0, currentSpeed + 15.0 + _random.nextDouble() * 10.0);
    
    // RPM aumentan significativamente durante aceleración fuerte
    _targetValues['0C'] = min(4500.0, currentRPM + 500.0 + _random.nextDouble() * 500.0);
    
    // Temperatura aumenta ligeramente
    _targetValues['05'] = min(95.0, _currentValues['05']! + 2.0 + _random.nextDouble() * 3.0);
    
    // Voltaje se mantiene estable o aumenta ligeramente
    _targetValues['42'] = min(14.5, _currentValues['42']! + _random.nextDouble() * 0.5);
    
    // Consumo de combustible aumenta significativamente
    _targetValues['5E'] = min(12.0, _currentValues['5E']! + 2.0 + _random.nextDouble() * 2.0);
  }

  // Método para establecer valores objetivo para frenado continuado
  void _setTargetForMoreBraking() {
    final currentSpeed = _currentValues['0D']!;
    
    // Reducción de velocidad basada en la actual
    _targetValues['0D'] = max(0.0, currentSpeed - 15.0 - _random.nextDouble() * 10.0);
    
    // RPM disminuyen durante frenado fuerte
    _targetValues['0C'] = max(800.0, _currentValues['0C']! - 300.0 - _random.nextDouble() * 300.0);
    
    // Temperatura se mantiene estable o baja ligeramente
    _targetValues['05'] = max(70.0, _currentValues['05']! - _random.nextDouble() * 2.0);
    
    // Voltaje se mantiene estable
    _targetValues['42'] = _currentValues['42']!;
    
    // Consumo de combustible disminuye durante frenado
    _targetValues['5E'] = max(0.5, _currentValues['5E']! - 1.0 - _random.nextDouble() * 1.0);
  }
}
