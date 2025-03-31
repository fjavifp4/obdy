import 'package:car_app/domain/repositories/obd_repository.dart';
import 'package:car_app/data/repositories/obd_repository_mock.dart';
import 'package:car_app/data/repositories/obd_repository_impl.dart';
import 'package:car_app/domain/entities/obd_data.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Clase que proporciona la implementación correcta del OBDRepository
/// según si estamos en modo simulación o real.
class OBDRepositoryProvider implements OBDRepository {
  // La implementación mock siempre está disponible para el modo simulación
  final OBDRepositoryMock _mockRepository = OBDRepositoryMock();
  
  // La implementación real para el modo real
  final OBDRepository _realRepository;
  
  // Indica si estamos en modo simulación
  bool _isSimulationMode = false;
  
  // Constructor que acepta una implementación real opcional
  OBDRepositoryProvider({OBDRepository? realRepository}) 
      : _realRepository = realRepository ?? OBDRepositoryImpl();
  
  // Getter para verificar si estamos en modo simulación
  bool get isSimulationMode => _isSimulationMode;
  
  // Método para cambiar el modo
  void setSimulationMode(bool isSimulation) {
    // Solo actualizamos si el modo cambia
    if (_isSimulationMode != isSimulation) {
      print("[OBDRepositoryProvider] Cambiando a modo: ${isSimulation ? 'Simulación' : 'Real'}");
      _isSimulationMode = isSimulation;
    }
  }
  
  // Implementación de los métodos del OBDRepository delegando a la implementación adecuada
  @override
  Future<void> initialize() async {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Inicializando en modo simulación");
      return _mockRepository.initialize();
    } else {
      print("[OBDRepositoryProvider] Inicializando en modo real");
      try {
        return await _realRepository.initialize();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al inicializar en modo real: $e");
        print("[OBDRepositoryProvider] Fallback a mock por error de inicialización");
        return _mockRepository.initialize();
      }
    }
  }
  
  @override
  Future<bool> connect() async {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Conectando en modo simulación");
      return _mockRepository.connect();
    } else {
      print("[OBDRepositoryProvider] Conectando en modo real");
      try {
        final result = await _realRepository.connect();
        if (!result) {
          print("[OBDRepositoryProvider] No se pudo establecer conexión con dispositivo OBD");
          return false;
        }
        return result;
      } catch (e) {
        print("[OBDRepositoryProvider] Error al conectar en modo real: $e");
        // En lugar de propagar la excepción, simplemente retornamos false
        return false;
      }
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Desconectando en modo simulación");
      
      // No podemos acceder directamente a la variable privada _dataEmissionTimer
      // En lugar de verificar directamente, confiamos en que el mock implementa
      // la lógica para detectar si la simulación está activa
      print("[OBDRepositoryProvider] Delegando la decisión de desconexión al mock");
      return _mockRepository.disconnect();
    } else {
      print("[OBDRepositoryProvider] Desconectando en modo real");
      try {
        return await _realRepository.disconnect();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al desconectar en modo real: $e");
        // No throw exception en desconexión, solo loggear
      }
    }
  }
  
  @override
  Stream<OBDData> getParameterData(String pid) {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Obteniendo datos para $pid en modo simulación");
      return _mockRepository.getParameterData(pid);
    } else {
      print("[OBDRepositoryProvider] Obteniendo datos para $pid en modo real");
      try {
        return _realRepository.getParameterData(pid);
      } catch (e) {
        print("[OBDRepositoryProvider] Error al obtener datos en modo real: $e");
        throw Exception("No se pueden obtener datos del dispositivo OBD: $e");
      }
    }
  }
  
  @override
  Future<List<String>> getDiagnosticTroubleCodes() {
    if (_isSimulationMode) {
      print("[OBDRepositoryProvider] Obteniendo códigos DTC en modo simulación");
      return _mockRepository.getDiagnosticTroubleCodes();
    } else {
      print("[OBDRepositoryProvider] Obteniendo códigos DTC en modo real");
      try {
        return _realRepository.getDiagnosticTroubleCodes();
      } catch (e) {
        print("[OBDRepositoryProvider] Error al obtener códigos DTC en modo real: $e");
        throw Exception("No se pueden obtener códigos de error del dispositivo OBD: $e");
      }
    }
  }
  
  @override
  bool get isConnected {
    if (_isSimulationMode) {
      return _mockRepository.isConnected;
    } else {
      return _realRepository.isConnected;
    }
  }

  @override
  Future<List<BluetoothDevice>> getAvailableDevices() {
    return _realRepository.getAvailableDevices();
  }
} 